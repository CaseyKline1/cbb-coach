        }
        actionDone = true;
        break;
      }

      setPendingAssist(state, offenseTeamId, currentHandler, best.player);
      passesCompleted += 1;
      openBeforeCatch = best.evalResult.openLevel;
      scrambleBonus = clamp(
        Math.max(scrambleBonus * 0.3, (best.evalResult.openLevel - 0.34) * 0.5),
        0,
        0.4,
      );
      scrambleFresh = true;
      currentHandlerIndex = best.idx;
      currentHandler = best.player;
      currentHandlerSpot = best.spot;
      currentDefender = best.cover.defender;
      currentZonePenalty = defenseScheme === DefenseScheme.MAN_TO_MAN
        ? 0
        : -0.08 + zoneDistanceAdvantage(best.cover.defender, best.cover.distance);
    }

    if (!actionDone && !possessionChanged) {
      pushEvent(state, {
        type: "reset",
        offenseTeam: offense.name,
        playType,
        detail: "Pass-around action timed out and reset to neutral offense.",
      });
    }
  } else if (playType === "post_up") {
    const postEligibleSpots = new Set([
      OffensiveSpot.RIGHT_POST,
      OffensiveSpot.LEFT_POST,
      OffensiveSpot.MIDDLE_PAINT,
      OffensiveSpot.RIGHT_SLOT,
      OffensiveSpot.LEFT_SLOT,
      OffensiveSpot.RIGHT_ELBOW,
      OffensiveSpot.LEFT_ELBOW,
    ]);

    if (!postEligibleSpots.has(ballHandlerSpot)) {
      if (!resolveLateClockBailout({
        shooter: ballHandler,
        defender: onBall.defender,
        shooterSpot: ballHandlerSpot,
        sourceDetail: "No post angle; late-clock bailout shot.",
      })) {
        pushEvent(state, {
          type: "reset",
          offenseTeam: offense.name,
          playType,
          detail: "No post touch angle available.",
        });
      }
    } else {
      const weightEdge = (getWeightPounds(ballHandler) - getWeightPounds(onBall.defender)) / 220;
      const postBattle = resolveInteraction({
        offensePlayer: ballHandler,
        defensePlayer: onBall.defender,
        offenseRatings: [
          "postGame.postControl",
          "athleticism.strength",
          "skills.ballHandling",
        ],
        defenseRatings: [
          "defense.postDefense",
          "athleticism.strength",
          "defense.defensiveControl",
        ],
        contextEdge: weightEdge,
        random,
      });

      let postTier = "tie";
      if (postBattle.edge >= 0.7) postTier = "dom_win";
      else if (postBattle.edge >= 0.18) postTier = "win";
      else if (postBattle.edge <= -0.72) postTier = "dom_loss";
      else if (postBattle.edge <= -0.2) postTier = "loss";

      if (postTier === "dom_loss") {
        const stealChance = clamp(
          0.035 + (getRating(onBall.defender, "defense.steals") - getRating(ballHandler, "skills.ballSafety")) / 240,
          0.01,
          0.24,
        );
        if (random() < stealChance) {
          recordTurnover(state, offenseTeamId, ballHandler, defenseTeamId, onBall.defender);
          pushEvent(state, {
            type: "turnover_liveball",
            offenseTeam: offense.name,
            defenderTeam: defense.name,
            playType,
            defender: onBall.defender?.bio?.name,
          });
          beginNewPossession(state, nextDefenseTeamId(state.possessionTeamId), null, {
            transition: {
              sourceType: "steal",
              initiator: onBall.defender,
            },
          });
          possessionChanged = true;
          shotClockMode = "hold";
        } else {
          if (!resolveLateClockBailout({
            shooter: ballHandler,
            defender: onBall.defender,
            shooterSpot: ballHandlerSpot,
            sourceDetail: "Post entry neutralized; late-clock bailout shot.",
          })) {
            pushEvent(state, {
              type: "reset",
              offenseTeam: offense.name,
              playType,
              detail: "Post entry neutralized.",
            });
          }
        }
      } else {
        const shootVsPass = getRating(ballHandler, "tendencies.shootVsPass");
        const scoringThreat = average([
          getRating(ballHandler, "postGame.postControl"),
          getRating(ballHandler, "postGame.postHooks"),
          getRating(ballHandler, "postGame.postFadeaways"),
          getRating(ballHandler, "shooting.closeShot"),
        ]);
        const threatBonus = clamp((scoringThreat - 60) / 120, 0, 0.24);
        const passChance = clamp((48 - shootVsPass) / 110 + threatBonus * 0.45, 0.03, 0.5);
        const giveUpChance = clamp((45 - getRating(ballHandler, "skills.shotIQ")) / 200, 0.03, 0.25);

        if (random() < giveUpChance && postTier !== "dom_win") {
          if (!resolveLateClockBailout({
            shooter: ballHandler,
            defender: onBall.defender,
            shooterSpot: ballHandlerSpot,
            sourceDetail: "Post touch kicked out; late-clock bailout shot.",
          })) {
            pushEvent(state, {
              type: "reset",
              offenseTeam: offense.name,
              playType,
              detail: "Post touch kicked back out.",
            });
          }
        } else if (random() < passChance) {
          const targets = offensiveAssignments
            .map((assignment, idx) => ({ ...assignment, idx }))
            .filter((entry) => entry.idx !== ballHandlerIndex);

          const targetScores = targets.map((target) => {
            const cover = getDefenderForOffensiveIndex({
              defenseScheme,
              defenseLineup,
              offensiveAssignments,
              offenseIndex: target.idx,
            });
            const evalResult = evaluatePassTarget({
              passer: ballHandler,
              receiver: target.player,
              receiverDefender: cover.defender,
              receiverSpot: target.spot,
              threatBonus,
              random,
            });

            return {
              ...target,
              cover,
              evalResult,
              score:
                evalResult.openLevel *
                estimateOpenShotValue(target.player, target.spot) *
                (evalResult.canSeeWindow ? 1.25 : 0.5),
            };
          });

          targetScores.sort((a, b) => b.score - a.score);
          const best = targetScores[0];

          if (!best || !best.evalResult.canSeeWindow) {
            if (!resolveLateClockBailout({
              shooter: ballHandler,
              defender: onBall.defender,
              shooterSpot: ballHandlerSpot,
              sourceDetail: "Post kick-out window closed; late-clock bailout shot.",
            })) {
              pushEvent(state, {
                type: "reset",
                offenseTeam: offense.name,
                playType,
                detail: "Post kick-out window closed.",
              });
            }
          } else {
            const passDelivery = resolvePassDelivery({
              passer: ballHandler,
              receiver: best.player,
              defenseContributors: [onBall.defender, best.cover.defender],
              zonePenalty,
              random,
            });
            markInvolvement(offenseTeamId, ballHandler, 0.55);
            markInvolvement(offenseTeamId, best.player, 0.7);
            markInvolvement(defenseTeamId, onBall.defender, 0.35);
            markInvolvement(defenseTeamId, best.cover.defender, 0.45);

            if (passDelivery.turnover) {
              recordTurnover(
                state,
                offenseTeamId,
                ballHandler,
                defenseTeamId,
                passDelivery.stealByPlayer,
              );
              pushEvent(state, {
                type: "turnover_pass",
                offenseTeam: offense.name,
                defenderTeam: defense.name,
                playType,
                detail: `Steal by ${passDelivery.stealBy}`,
              });
              beginNewPossession(state, nextDefenseTeamId(state.possessionTeamId), null, {
                transition: {
                  sourceType: "steal",
                  initiator: passDelivery.stealByPlayer,
                },
              });
              possessionChanged = true;
              shotClockMode = "hold";
            } else if (passDelivery.looseBall) {
              clearPendingAssist(state);
              const looseBall = resolveLooseBallRecovery({
                offenseLineup,
                defenseLineup,
                offenseTeamId,
                defenseTeamId,
                offensiveAssignments,
                defenseScheme,
                receiverSpot: best.spot,
                random,
              });

              if (looseBall.recoveredByTeam === "defense") {
                addPlayerStat(state, offenseTeamId, ballHandler, "turnovers", 1);
                pushEvent(state, {
                  type: "loose_ball_recovery",
                  offenseTeam: offense.name,
                  defenderTeam: defense.name,
                  playType,
                  detail: `Loose ball recovered by ${looseBall.recoveredByPlayer?.bio?.name || "Unknown"}.`,
                });
                beginNewPossession(state, nextDefenseTeamId(state.possessionTeamId));
                possessionChanged = true;
                shotClockMode = "hold";
              } else {
                pushEvent(state, {
                  type: "loose_ball_recovery",
                  offenseTeam: offense.name,
                  playType,
                  detail: `Loose ball recovered by ${looseBall.recoveredByPlayer?.bio?.name || "Unknown"} (${offense.name}).`,
                });
              }
            } else {
              setPendingAssist(state, offenseTeamId, ballHandler, best.player);
              if (!shouldTakeShotThisAction({
                state,
                shooter: best.player,
                shotQuality: best.evalResult.openLevel,
                random,
              })) {
                if (!resolveLateClockBailout({
                  shooter: best.player,
                  defender: best.cover.defender,
                  shooterSpot: best.spot,
                  sourceDetail: "Kick-out window there; late-clock catch-and-shoot bailout.",
                  shotQualityEdge: best.evalResult.openLevel * 0.14 - 0.08,
                })) {
                  pushEvent(state, {
                    type: "reset",
                    offenseTeam: offense.name,
                    playType,
                    detail: "Kick-out was there, but offense waited for late clock.",
                  });
                }
              } else {
                const shotType = chooseShotFromTendencies(best.player, random);
                const contested = best.evalResult.openLevel < 0.56;
                const shot = resolveShot({
                  shooter: best.player,
                  defender: best.cover.defender,
                  shotType,
                  shooterSpot: best.spot,
                  zonePenalty,
                  shotQualityEdge: best.evalResult.openLevel * 0.25,
                  contested,
                  random,
                });
                shot.shooter = best.player;
                shot.assister = ballHandler;
                markInvolvement(offenseTeamId, best.player, 0.9);
                markInvolvement(offenseTeamId, ballHandler, 0.35);
                markInvolvement(defenseTeamId, best.cover.defender, 0.75);

                const endState = resolvePossessionEndAfterShot({
                  state,
                  offenseTeamId,
                  defenseTeamId,
                  offense,
                  defense,
                  offenseLineup,
                  defenseLineup,
                  defenseScheme,
                  offensiveAssignments,
                  playType,
                  shotType,
                  shot,
                  random,
                });
                possessionChanged = endState.possessionChanged;
                shotClockMode = endState.shotClockMode;
              }
            }
          }
        } else {
          const tierShotEdgeByTier = {
            dom_win: 0.5,
            win: 0.22,
            tie: 0.02,
            loss: -0.22,
          };
          const tierShotEdge = tierShotEdgeByTier[postTier] ?? 0;

          const hookWeight = getRating(ballHandler, "postGame.postHooks");
          const fadeWeight = getRating(ballHandler, "postGame.postFadeaways") * 0.9;
          const layWeight = getRating(ballHandler, "shooting.layups") * (postTier === "dom_win" ? 1.5 : 0.6);
          const dunkWeight = getRating(ballHandler, "shooting.dunks") * (postTier === "dom_win" ? 1.4 : 0.55);
          const shotType = pickWeighted(
            [
              { value: "hook", weight: hookWeight },
              { value: "fadeaway", weight: fadeWeight },
              { value: "layup", weight: layWeight },
              { value: "dunk", weight: dunkWeight },
            ],
            random,
          );

          if (!shouldTakeShotThisAction({
            state,
            shooter: ballHandler,
            shotQuality: postTier === "dom_win" ? 0.9 : postTier === "win" ? 0.65 : 0.35,
            random,
          })) {
            if (!resolveLateClockBailout({
              shooter: ballHandler,
              defender: onBall.defender,
              shooterSpot: ballHandlerSpot,
              sourceDetail: "Post touch hesitated; late-clock bailout shot.",
            })) {
              pushEvent(state, {
                type: "reset",
                offenseTeam: offense.name,
                playType,
                detail: "Post touch didn't force a shot; offense reset.",
              });
            }
          } else {
            const shot = resolveShot({
              shooter: ballHandler,
              defender: onBall.defender,
              shotType,
              shooterSpot: ballHandlerSpot,
              zonePenalty,
              shotQualityEdge: tierShotEdge,
              contested: shotType !== "fadeaway",
              random,
            });
            shot.shooter = ballHandler;
            markInvolvement(offenseTeamId, ballHandler, 1);
            markInvolvement(defenseTeamId, onBall.defender, 0.85);

            if (!shot.made && (shotType === "hook" || shotType === "layup" || shotType === "dunk")) {
              const blockChance = clamp(
                0.015 +
                  (getRating(onBall.defender, "defense.shotBlocking") - 50) / 250 +
                  (postTier === "loss" ? 0.06 : 0) +
                  (postTier === "tie" ? 0.02 : 0),
                0.01,
                0.28,
              );
              if (random() < blockChance) {
                shot.blockedByDefense = true;
              }
            }

            const endState = resolvePossessionEndAfterShot({
              state,
              offenseTeamId,
              defenseTeamId,
              offense,
              defense,
              offenseLineup,
              defenseLineup,
              defenseScheme,
              offensiveAssignments,
              playType,
              shotType,
              shot,
              random,
            });
            possessionChanged = endState.possessionChanged;
            shotClockMode = endState.shotClockMode;
          }
        }
      }
    }
  }

  applyChunkClock(state, shotClockMode);
  applyChunkMinutesAndEnergy(state, involvementByTeam);

  if (!possessionChanged && state.shotClockRemaining <= 0) {
    pushEvent(state, {
      type: "turnover_shot_clock",
      offenseTeam: offense.name,
      playType,
    });
    addTeamExtra(state, offenseTeamId, "turnovers", 1);
    beginNewPossession(state, nextDefenseTeamId(state.possessionTeamId), "out_of_bounds");
  }
}

function simulateHalf(state, random = Math.random) {
  while (state.gameClockRemaining > 0) {
    resolveActionChunk(state, random);
  }
}

function simulateGame(homeTeam, awayTeam, options = {}) {
  const random = options.random || Math.random;
  const state = createInitialGameState(homeTeam, awayTeam, random);

  simulateHalf(state, random);

  recoverAllPlayers(state, HALFTIME_RECOVERY);
  runDeadBallSubstitutions(state, "halftime");
  state.currentHalf = 2;
  state.gameClockRemaining = HALF_SECONDS;
  state.shotClockRemaining = SHOT_CLOCK_SECONDS;
  state.possessionNeedsSetup = true;
