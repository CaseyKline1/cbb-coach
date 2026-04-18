          average([
            getRating(d, "defense.offballDefense"),
            getRating(d, "defense.perimeterDefense"),
            getRating(d, "athleticism.burst"),
          ]),
        ),
      );
      const helpChance = clamp(0.2 + (helpQuality - 50) / 130, 0.06, 0.72);
      const helpArrives = random() < helpChance;

      const shootVsPass = getRating(ballHandler, "tendencies.shootVsPass");
      const passChance = clamp(
        (54 - shootVsPass) / 100 + (helpArrives ? 0.22 : 0.08),
        0.06,
        decisiveOWin ? 0.82 : 0.72,
      );
      const jumpChance = decisiveOWin ? 0 : clamp((shootVsPass - 58) / 220, 0, 0.16);
      const passDecision = random() < passChance;
      const jumpDecision = !passDecision && random() < jumpChance;

      if (passDecision) {
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

          const threatBonus = decisiveOWin && helpArrives ? 0.22 : 0.04;
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
              (evalResult.canSeeWindow ? 1.3 : 0.45),
          };
        });

        targetScores.sort((a, b) => b.score - a.score);
        const best = targetScores[0];
        if (!best || !best.evalResult.canSeeWindow) {
          if (!resolveLateClockBailout({
            shooter: ballHandler,
            defender: onBall.defender,
            shooterSpot: ballHandlerSpot,
            sourceDetail: "Drive-and-kick read not found; late-clock bailout shot.",
          })) {
            pushEvent(state, {
              type: "reset",
              offenseTeam: offense.name,
              playType,
              detail: "Drive-and-kick read not found.",
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
                  sourceDetail: "Kick-out caught; late-clock catch-and-shoot bailout.",
                  shotQualityEdge: best.evalResult.openLevel * 0.15 - 0.08,
                })) {
                pushEvent(state, {
                  type: "reset",
                  offenseTeam: offense.name,
                  playType,
                  detail: "Kick-out caught, offense reset for a later shot.",
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
                shotQualityEdge: best.evalResult.openLevel * 0.32,
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
        if (!shouldTakeShotThisAction({
          state,
          shooter: ballHandler,
          shotQuality: decisiveOWin ? 0.8 : (helpArrives ? 0.35 : 0.55),
          random,
        })) {
          if (!resolveLateClockBailout({
            shooter: ballHandler,
            defender: onBall.defender,
            shooterSpot: ballHandlerSpot,
            sourceDetail: "Drive advantage faded; late-clock bailout shot.",
          })) {
            pushEvent(state, {
              type: "reset",
              offenseTeam: offense.name,
              playType,
              detail: "Drive advantage wasn't enough, offense reset.",
            });
          }
        } else {
          const shotType = jumpDecision ? chooseShotFromTendencies(ballHandler, random) : chooseDriveFinishType(ballHandler, random);
          const contestWeight = decisiveOWin ? 0.08 : 0.2;
          const shotQualityEdge = decisiveOWin ? 0.32 : 0.1;
          const shot = resolveShot({
            shooter: ballHandler,
            defender: onBall.defender,
            shotType,
            shooterSpot: ballHandlerSpot,
            zonePenalty,
            shotQualityEdge: shotQualityEdge - (helpArrives ? contestWeight : 0),
            contested: true,
            random,
          });
          shot.shooter = ballHandler;
          markInvolvement(offenseTeamId, ballHandler, 1);
          markInvolvement(defenseTeamId, onBall.defender, 0.85);

          if (!shot.made && (shotType === "layup" || shotType === "dunk")) {
            const oLength =
              (getHeightInches(ballHandler) + getWingspanInches(ballHandler)) / 2;
            const dLength =
              (getHeightInches(onBall.defender) + getWingspanInches(onBall.defender)) / 2;
            const blockRating = getRating(onBall.defender, "defense.shotBlocking");
            const blockChance = clamp(
              0.02 +
                (dLength - oLength) / 180 +
                (blockRating - 50) / 220 +
                (decisiveOWin ? -0.02 : 0.04),
              0.01,
              0.26,
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
  } else if (playType === "pick_and_roll" || playType === "pick_and_pop") {
    const screenerIndex = pickScreenerIndex({
      offensiveAssignments,
      ballHandlerIndex,
      random,
    });
    const screenerEntry = offensiveAssignments[screenerIndex];
    const screener = screenerEntry?.player;
    const screenerSpot = screenerEntry?.spot || OffensiveSpot.FT_LINE;

    if (!screener || screener === ballHandler) {
      if (!resolveLateClockBailout({
        shooter: ballHandler,
        defender: onBall.defender,
        shooterSpot: ballHandlerSpot,
        sourceDetail: "Screen action had no screener outlet; late-clock bailout shot.",
      })) {
        pushEvent(state, {
          type: "reset",
          offenseTeam: offense.name,
          playType,
          detail: "Screen action dissolved before contact.",
        });
      }
    } else {
      const screenerCover = getDefenderForOffensiveIndex({
        defenseScheme,
        defenseLineup,
        offensiveAssignments,
        offenseIndex: screenerIndex,
      });
      const screenerDefender = screenerCover?.defender || onBall.defender;
      const screenerZonePenalty = defenseScheme === DefenseScheme.MAN_TO_MAN
        ? 0
        : -0.08 + zoneDistanceAdvantage(screenerDefender, screenerCover?.distance || 1.6);

      const dynamics = resolvePickActionDynamics({
        ballHandler,
        screener,
        onBallDefender: onBall.defender,
        screenerDefender,
        actionType: playType,
        zonePenalty: zonePenalty + screenerZonePenalty * 0.45,
        random,
      });

      const ballHandlerOpen = clamp(
        1 - dynamics.ballHandlerPressure + dynamics.disruption * 0.18,
        0,
        1,
      );
      const screenerOpen = clamp(
        1 - dynamics.screenerPressure + dynamics.disruption * 0.22,
        0,
        1,
      );
      const screenReadGap = Math.abs(ballHandlerOpen - screenerOpen);
      const passIQ = getRating(ballHandler, "skills.passingIQ");
      const readBestOptionChance = clamp(
        0.45 + (passIQ - 50) / 95 + screenReadGap * 0.4,
        0.08,
        0.96,
      );
      const betterOption = screenerOpen > ballHandlerOpen ? "screener" : "ball_handler";
      let primaryDecision;
      if (random() < readBestOptionChance) {
        primaryDecision = betterOption;
      } else {
        const shootVsPass = getRating(ballHandler, "tendencies.shootVsPass");
        const ballChance = clamp(
          0.35 + (shootVsPass - 50) / 120 + (ballHandlerOpen - screenerOpen) * 0.35,
          0.08,
          0.92,
        );
        primaryDecision = random() < ballChance ? "ball_handler" : "screener";
      }

      markInvolvement(offenseTeamId, screener, 0.82);
      markInvolvement(defenseTeamId, screenerDefender, 0.78);

      if (primaryDecision === "screener") {
        const passDelivery = resolvePassDelivery({
          passer: ballHandler,
          receiver: screener,
          defenseContributors: [onBall.defender, screenerDefender],
          zonePenalty: zonePenalty + screenerZonePenalty + dynamics.disruption * 0.12,
          random,
        });

        markInvolvement(offenseTeamId, ballHandler, 0.48);
        markInvolvement(offenseTeamId, screener, 0.62);
        markInvolvement(defenseTeamId, onBall.defender, 0.38);
        markInvolvement(defenseTeamId, screenerDefender, 0.45);

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
            detail: `Screen pass picked off by ${passDelivery.stealBy}.`,
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
            receiverSpot: screenerSpot,
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
        } else if (playType === "pick_and_roll") {
          setPendingAssist(state, offenseTeamId, ballHandler, screener);

          const onBallRollStopShare = (1 - dynamics.onBallGuardBallShare) * dynamics.onBallDriveFocus;
          const screenerRollStopShare = (1 - dynamics.screenerGuardBallShare) * dynamics.screenerDriveFocus;
          const rollDefender =
            onBallRollStopShare >= screenerRollStopShare ? onBall.defender : screenerDefender;
          const rollStopPressure = Math.max(onBallRollStopShare, screenerRollStopShare);
          const rollQuality = clamp(
            screenerOpen * 0.58 + dynamics.disruption * 0.34 + (1 - rollStopPressure) * 0.2,
            0.08,
            1.08,
          );
          const rollShotType = chooseDriveFinishType(screener, random);
          const shot = resolveShot({
            shooter: screener,
            defender: rollDefender,
            shotType: rollShotType,
            shooterSpot: OffensiveSpot.MIDDLE_PAINT,
            zonePenalty: Math.max(zonePenalty, screenerZonePenalty),
            shotQualityEdge: rollQuality * 0.34 - rollStopPressure * 0.22,
            contested: rollQuality < 0.62,
            random,
          });
