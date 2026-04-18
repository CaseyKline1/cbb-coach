          shot.shooter = screener;
          shot.assister = ballHandler;
          markInvolvement(offenseTeamId, screener, 0.95);
          markInvolvement(offenseTeamId, ballHandler, 0.36);
          markInvolvement(defenseTeamId, rollDefender, 0.86);

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
            shotType: rollShotType,
            shot,
            random,
          });
          possessionChanged = endState.possessionChanged;
          shotClockMode = endState.shotClockMode;
        } else {
          const popDestination = choosePopDestination(screener, random);
          const popShotRating = popDestination.shotType === "three"
            ? getRating(screener, "shooting.threePointShooting")
            : getRating(screener, "shooting.midrangeShot");
          const onBallPopStopShare =
            (1 - dynamics.onBallGuardBallShare) * (1 - dynamics.onBallDriveFocus);
          const screenerPopStopShare =
            (1 - dynamics.screenerGuardBallShare) * (1 - dynamics.screenerDriveFocus);
          const popDefender =
            onBallPopStopShare >= screenerPopStopShare ? onBall.defender : screenerDefender;
          const popStopPressure = Math.max(onBallPopStopShare, screenerPopStopShare);
          const popOpenLevel = clamp(
            screenerOpen * 0.7 + dynamics.disruption * 0.2 + (1 - popStopPressure) * 0.18,
            0,
            1,
          );
          const avoidBadShot = popShotRating < 58 && getRating(screener, "skills.shotIQ") < 60;

          if (
            avoidBadShot ||
            !shouldTakeShotThisAction({
              state,
              shooter: screener,
              shotQuality: popOpenLevel * 0.95,
              random,
            })
          ) {
            if (!resolveLateClockBailout({
              shooter: ballHandler,
              defender: onBall.defender,
              shooterSpot: ballHandlerSpot,
              sourceDetail: "Pop target wasn't open enough; late-clock bailout shot.",
              shotQualityEdge: popOpenLevel * 0.08 - 0.08,
            })) {
              pushEvent(state, {
                type: "reset",
                offenseTeam: offense.name,
                playType,
                detail:
                  avoidBadShot
                    ? "Pop target declined the look and reset the action."
                    : "Pop window closed before a clean shot.",
              });
            }
          } else {
            setPendingAssist(state, offenseTeamId, ballHandler, screener);
            const shot = resolveShot({
              shooter: screener,
              defender: popDefender,
              shotType: popDestination.shotType,
              shooterSpot: popDestination.spot,
              zonePenalty: Math.max(zonePenalty, screenerZonePenalty),
              shotQualityEdge:
                popOpenLevel * 0.31 +
                dynamics.screenEffectiveness * 0.14 -
                popStopPressure * 0.18 +
                popDestination.expectedShotValue * 0.03,
              contested: popOpenLevel < 0.6,
              random,
            });
            shot.shooter = screener;
            shot.assister = ballHandler;
            markInvolvement(offenseTeamId, screener, 0.94);
            markInvolvement(offenseTeamId, ballHandler, 0.34);
            markInvolvement(defenseTeamId, popDefender, 0.82);

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
              shotType: popDestination.shotType,
              shot,
              random,
            });
            possessionChanged = endState.possessionChanged;
            shotClockMode = endState.shotClockMode;
          }
        }
      } else {
        const totalDriveDefense =
          dynamics.onBallGuardBallShare * dynamics.onBallDriveFocus +
          dynamics.screenerGuardBallShare * dynamics.screenerDriveFocus;
        const totalShotDefense =
          dynamics.onBallGuardBallShare * (1 - dynamics.onBallDriveFocus) +
          dynamics.screenerGuardBallShare * (1 - dynamics.screenerDriveFocus);
        const driveIntent = clamp(
          0.45 +
            (getRating(ballHandler, "tendencies.drive") - 50) / 120 +
            (totalShotDefense - totalDriveDefense) * 0.5,
          0.1,
          0.9,
        );
        const attackDrive = random() < driveIntent;
        const attackerDefender = attackDrive
          ? dynamics.onBallGuardBallShare * dynamics.onBallDriveFocus >=
            dynamics.screenerGuardBallShare * dynamics.screenerDriveFocus
            ? onBall.defender
            : screenerDefender
          : dynamics.onBallGuardBallShare * (1 - dynamics.onBallDriveFocus) >=
            dynamics.screenerGuardBallShare * (1 - dynamics.screenerDriveFocus)
            ? onBall.defender
            : screenerDefender;

        if (
          !shouldTakeShotThisAction({
            state,
            shooter: ballHandler,
            shotQuality: attackDrive ? 0.58 + dynamics.disruption * 0.28 : 0.45 + ballHandlerOpen * 0.42,
            random,
          })
        ) {
          if (!resolveLateClockBailout({
            shooter: ballHandler,
            defender: attackerDefender,
            shooterSpot: ballHandlerSpot,
            sourceDetail: "Ball-handler read favored patience; late-clock bailout shot.",
            shotQualityEdge: dynamics.disruption * 0.14 - 0.1,
          })) {
            pushEvent(state, {
              type: "reset",
              offenseTeam: offense.name,
              playType,
              detail: "Screen created a read, but ball-handler reset the possession.",
            });
          }
        } else {
          const shotType = attackDrive ? chooseDriveFinishType(ballHandler, random) : chooseShotFromTendencies(ballHandler, random);
          const defensePressure = attackDrive ? totalDriveDefense : totalShotDefense;
          const shot = resolveShot({
            shooter: ballHandler,
            defender: attackerDefender,
            shotType,
            shooterSpot: ballHandlerSpot,
            zonePenalty,
            shotQualityEdge:
              dynamics.disruption * 0.2 +
              (1 - defensePressure) * (attackDrive ? 0.3 : 0.24) -
              defensePressure * 0.2,
            contested: defensePressure > 0.42,
            random,
          });
          shot.shooter = ballHandler;
          markInvolvement(offenseTeamId, ballHandler, 1);
          markInvolvement(offenseTeamId, screener, 0.52);
          markInvolvement(defenseTeamId, attackerDefender, 0.86);
          markInvolvement(defenseTeamId, onBall.defender, 0.28);
          markInvolvement(defenseTeamId, screenerDefender, 0.28);

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
  } else if (playType === "pass_around_for_shot") {
    const pgStarterIndex = offensiveAssignments.findIndex(
      (assignment) => assignment.player?.bio?.position === "PG",
    );
    const starterIndex = pgStarterIndex >= 0 ? pgStarterIndex : ballHandlerIndex;
    const starterOnBall = getOnBallDefender({
      defenseScheme,
      defenseLineup,
      offensiveAssignments,
      ballHandlerIndex: starterIndex,
    });

    let currentHandlerIndex = starterIndex;
    let currentHandler = offensiveAssignments[currentHandlerIndex].player;
    let currentHandlerSpot = offensiveAssignments[currentHandlerIndex].spot;
    let currentDefender = starterOnBall.defender;
    let currentZonePenalty = starterOnBall.isZone
      ? -0.08 + zoneDistanceAdvantage(starterOnBall.defender, starterOnBall.startDistance)
      : 0;
    let openBeforeCatch = clamp(starterOnBall.isZone ? 0.34 + starterOnBall.startDistance * 0.03 : 0.3, 0.2, 0.6);
    let passesCompleted = 0;
    let scrambleBonus = 0;
    let scrambleFresh = false;
    const maxPasses = 4;
    let actionDone = false;
    markInvolvement(offenseTeamId, currentHandler, 0.55);
    markInvolvement(defenseTeamId, currentDefender, 0.45);

    while (!actionDone && !possessionChanged) {
      const canStillPass = passesCompleted < maxPasses;
      const hasCompletedRequiredPass = passesCompleted > 0;
      const activeScrambleBonus = scrambleBonus;
      const shotQuality = clamp(openBeforeCatch * 0.85 + activeScrambleBonus * 0.4, 0.1, 1.05);
      const shouldShoot = hasCompletedRequiredPass && shouldTakeShotThisAction({
        state,
        shooter: currentHandler,
        shotQuality,
        random,
      });

      if (shouldShoot || !canStillPass) {
        if (!shouldShoot && !resolveLateClockBailout({
          shooter: currentHandler,
          defender: currentDefender,
          shooterSpot: currentHandlerSpot,
          sourceDetail: "Pass limit reached; offense resets without a shot.",
          shotQualityEdge: openBeforeCatch * 0.12 - 0.06,
        })) {
          pushEvent(state, {
            type: "reset",
            offenseTeam: offense.name,
            playType,
            detail: "Pass-around hit max passes and reset to neutral offense.",
          });
          actionDone = true;
          break;
        }
        if (!shouldShoot) {
          actionDone = true;
          break;
        }

        const shotType = chooseShotFromTendencies(currentHandler, random);
        const contested = openBeforeCatch < 0.62;
        const shot = resolveShot({
          shooter: currentHandler,
          defender: currentDefender,
          shotType,
          shooterSpot: currentHandlerSpot,
          zonePenalty: currentZonePenalty,
          shotQualityEdge: openBeforeCatch * 0.28 + scrambleBonus * 0.1,
          contested,
          random,
        });
        shot.shooter = currentHandler;
        markInvolvement(offenseTeamId, currentHandler, 0.95);
        markInvolvement(defenseTeamId, currentDefender, 0.8);

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
        actionDone = true;
        break;
      }

      maybeRelocateOffBallPlayers({
        offensiveAssignments,
        ballHandlerIndex: currentHandlerIndex,
        random,
      });

      const targets = offensiveAssignments
        .map((assignment, idx) => ({ ...assignment, idx }))
        .filter((entry) => entry.idx !== currentHandlerIndex);
      const threatBonus =
        clamp((getRating(currentHandler, "skills.passingVision") - 55) / 180, -0.05, 0.2) +
        activeScrambleBonus;

      const targetScores = targets.map((target) => {
        const cover = getDefenderForOffensiveIndex({
          defenseScheme,
          defenseLineup,
          offensiveAssignments,
          offenseIndex: target.idx,
        });

        const evalResult = evaluatePassTarget({
          passer: currentHandler,
          receiver: target.player,
          receiverDefender: cover.defender,
          receiverSpot: target.spot,
          threatBonus,
          random,
        });

        markInvolvement(offenseTeamId, target.player, 0.16);
        markInvolvement(defenseTeamId, cover.defender, 0.12);

        const getsOpen = evalResult.getOpen.success;
        return {
          ...target,
          cover,
          evalResult,
          getsOpen,
          score:
            evalResult.openLevel *
            estimateOpenShotValue(target.player, target.spot) *
            (getsOpen ? 1.25 : 0.25) *
            (evalResult.canSeeWindow ? 1.25 : 0.35),
        };
      });

      targetScores.sort((a, b) => b.score - a.score);
      const best = targetScores.find((candidate) => candidate.getsOpen && candidate.evalResult.canSeeWindow);
      if (activeScrambleBonus > 0) {
        if (scrambleFresh) scrambleFresh = false;
        else scrambleBonus *= 0.28;
      }
      if (!best) {
        const canLateClockBailout = hasCompletedRequiredPass && resolveLateClockBailout({
          shooter: currentHandler,
          defender: currentDefender,
          shooterSpot: currentHandlerSpot,
          sourceDetail: "No passing window opened in action; neutral reset.",
          shotQualityEdge: openBeforeCatch * 0.11 - 0.07,
        });
        if (!canLateClockBailout) {
          pushEvent(state, {
            type: "reset",
            offenseTeam: offense.name,
            playType,
            detail: "Pass-around found no clean option and reset to neutral offense.",
          });
          actionDone = true;
          break;
        }
        actionDone = true;
        break;
      }

      const defenseContributors = getNearbyPassDefenders({
        defenseScheme,
        defenseLineup,
        offensiveAssignments,
        ballHandlerDefender: currentDefender,
        receiverDefender: best.cover.defender,
        receiverSpot: best.spot,
      });
      const passDelivery = resolvePassDelivery({
        passer: currentHandler,
        receiver: best.player,
        defenseContributors,
        zonePenalty: currentZonePenalty,
        random,
      });

      markInvolvement(offenseTeamId, currentHandler, 0.52);
      markInvolvement(offenseTeamId, best.player, 0.7);
      defenseContributors.forEach((defender) => markInvolvement(defenseTeamId, defender, 0.18));

      if (passDelivery.turnover) {
        recordTurnover(
          state,
          offenseTeamId,
          currentHandler,
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
        actionDone = true;
        break;
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
          addPlayerStat(state, offenseTeamId, currentHandler, "turnovers", 1);
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
