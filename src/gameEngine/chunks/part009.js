      if (random() < stealChance) {
        const stealer = pickPressStealer(trapDefenders, random);
        recordTurnover(state, offenseTeamId, ballHandler, defenseTeamId, stealer);
        pushEvent(state, {
          type: "turnover_liveball",
          offenseTeam: offense.name,
          defenderTeam: defense.name,
          playType: "press_break",
          defender: stealer?.bio?.name || "Unknown",
          detail: "Ball-handler lost the dribble to press pressure.",
        });
        beginNewPossession(state, defenseTeamId, null, {
          transition: {
            sourceType: "steal",
            initiator: stealer,
          },
        });
        return {
          handled: true,
          playType: "press_break",
          possessionChanged: true,
          shotClockMode: "hold",
        };
      }
      pushEvent(state, {
        type: "reset",
        offenseTeam: offense.name,
        defenseTeam: defense.name,
        playType: "press_break",
        detail: "Dribble advance stalled against pressure.",
      });
    } else {
      const dribbleEdge =
        (getRating(ballHandler, "athleticism.speed") +
          getRating(ballHandler, "athleticism.burst") +
          getRating(ballHandler, "skills.ballHandling")) /
          3 -
        average(
          trapDefenders.map((player) =>
            average([
              getRating(player, "athleticism.speed"),
              getRating(player, "defense.lateralQuickness"),
              getRating(player, "defense.perimeterDefense"),
            ]),
          ),
        );
      const fullAdvanceChance = clamp(0.08 + dribbleEdge / 150, 0.02, 0.46);
      const progressGain = random() < fullAdvanceChance ? 2 : 1;
      pending.progress = Math.min(2, pending.progress + progressGain);
      pending.ballHandler = ballHandler;
      pushEvent(state, {
        type: "press_break_dribble",
        offenseTeam: offense.name,
        defenseTeam: defense.name,
        playType: "press_break",
        detail:
          progressGain >= 2
            ? "Ball-handler split pressure and reached frontcourt."
            : "Ball-handler dribbled through the first line of pressure.",
      });
    }
  }

  if (pending.progress >= 2) {
    state.pendingPress = null;
    state.possessionNeedsSetup = false;
    const pressBreakAttack = getTeamTendencyMultiplier(offense, "pressBreakAttack", 1);
    const attackChance = clamp(
      PRESS_ATTACK_AFTER_BREAK_BASE_CHANCE +
        (pressBreakAttack - 1) * 0.24 +
        getTeamFastBreakIntent(offense, "fastBreakOffense") * 0.35,
      0.24,
      0.92,
    );
    const attackNow = random() < attackChance;
    if (attackNow) {
      state.pendingTransition = {
        phase: 1,
        sourceType: "press_break",
        initiator: pending.ballHandler,
        defenseHeadStart: -0.1,
      };
      pushEvent(state, {
        type: "press_break_advance",
        offenseTeam: offense.name,
        defenseTeam: defense.name,
        playType: "press_break",
        detail: "Press broken cleanly; offense pushed into transition.",
      });
    } else {
      pushEvent(state, {
        type: "press_break_advance",
        offenseTeam: offense.name,
        defenseTeam: defense.name,
        playType: "press_break",
        detail: "Press broken; offense slowed into half-court.",
      });
    }
    return {
      handled: true,
      playType: "press_break",
      possessionChanged: false,
      shotClockMode: "tick",
    };
  }

  pending.chunksInBackcourt += 1;
  if (pending.chunksInBackcourt >= 2) {
    addPlayerStat(state, offenseTeamId, pending.ballHandler || ballHandler, "turnovers", 1);
    addTeamExtra(state, offenseTeamId, "turnovers", 1);
    pushEvent(state, {
      type: "turnover_ten_second",
      offenseTeam: offense.name,
      defenderTeam: defense.name,
      playType: "press_break",
      detail: "Ten-second violation under full-court pressure.",
    });
    beginNewPossession(state, defenseTeamId, "out_of_bounds");
    return {
      handled: true,
      playType: "press_break",
      possessionChanged: true,
      shotClockMode: "hold",
    };
  }

  state.pendingPress = pending;
  pushEvent(state, {
    type: "press_break_continue",
    offenseTeam: offense.name,
    defenseTeam: defense.name,
    playType: "press_break",
    detail: "Press still active in the backcourt.",
  });
  return {
    handled: true,
    playType: "press_break",
    possessionChanged: false,
    shotClockMode: "tick",
  };
}

function shouldTakeShotThisAction({
  state,
  shooter,
  shotQuality = 0,
  random = Math.random,
  forceShotThresholdSeconds = 5,
}) {
  if (state.shotClockRemaining <= forceShotThresholdSeconds) return true;

  const shotIQ = getRating(shooter, "skills.shotIQ");
  const shootVsPass = getRating(shooter, "tendencies.shootVsPass");
  const elapsedClock = SHOT_CLOCK_SECONDS - state.shotClockRemaining;
  const pressureSpan = SHOT_CLOCK_SECONDS - forceShotThresholdSeconds;
  const clockPressure = pressureSpan <= 0 ? 1 : clamp(elapsedClock / pressureSpan, 0, 1);
  const paceShotBias = getPaceShotBias(state, state.possessionTeamId);
  const earlyClockRestraint = Math.pow(1 - clockPressure, 1.35) * 0.095;
  // Shot quality matters less as the clock winds down — late in the clock, any look goes up.
  const qualityWeight = 1 - 0.75 * clockPressure;
  const qualityBoost = clamp(shotQuality, 0, 1.2) * 0.23 * qualityWeight;
  const shotChance = clamp(
    0.23 +
      EARLY_CLOCK_SHOT_ATTEMPT_BONUS +
      Math.pow(clockPressure, 1.35) * 0.73 +
      (shotIQ - 60) / 300 +
      (shootVsPass - 55) / 300 +
      paceShotBias +
      qualityBoost,
    0.1,
    0.98,
  );

  return random() < clamp(shotChance - earlyClockRestraint, 0.08, 0.98);
}

function resolveActionChunk(state, random = Math.random) {
  syncPossessionTeamRoles(state);
  syncClutchTimeState(state);
  const offenseTeamId = state.possessionTeamId;
  const defenseTeamId = nextDefenseTeamId(state.possessionTeamId);
  const offense = state.teams[offenseTeamId];
  const defense = state.teams[defenseTeamId];
  const involvementByTeam = [new Map(), new Map()];
  const markInvolvement = (teamId, player, amount = 1) => {
    if (!player) return;
    const map = involvementByTeam[teamId];
    map.set(player, (map.get(player) || 0) + amount);
  };

  if (maybeTakeTimeout(state, random)) {
    return;
  }

  const offenseLineup = offense.lineup;
  const defenseLineup = defense.lineup;
  const defenseScheme = defense.defenseScheme || DefenseScheme.MAN_TO_MAN;

  if (state.possessionNeedsSetup && state.pendingTransition) {
    const transitionResult = resolveFastBreakWindow({
      state,
      offenseTeamId,
      defenseTeamId,
      offense,
      defense,
      offenseLineup,
      defenseLineup,
      defenseScheme,
      markInvolvement,
      random,
    });

    if (transitionResult.handled) {
      applyChunkClock(state, transitionResult.shotClockMode || "tick");
      applyChunkMinutesAndEnergy(state, involvementByTeam);

      if (!transitionResult.possessionChanged && state.shotClockRemaining <= 0) {
        pushEvent(state, {
          type: "turnover_shot_clock",
          offenseTeam: offense.name,
          playType: transitionResult.playType || "fast_break",
        });
        addTeamExtra(state, offenseTeamId, "turnovers", 1);
        beginNewPossession(state, nextDefenseTeamId(state.possessionTeamId), "out_of_bounds");
      }
      return;
    }
  }

  if (state.possessionNeedsSetup) {
    const pressResult = resolvePressBreakWindow({
      state,
      offenseTeamId,
      defenseTeamId,
      offense,
      defense,
      offenseLineup,
      defenseLineup,
      markInvolvement,
      random,
    });
    if (pressResult.handled) {
      applyChunkClock(state, pressResult.shotClockMode || "tick");
      applyChunkMinutesAndEnergy(state, involvementByTeam);

      if (!pressResult.possessionChanged && state.shotClockRemaining <= 0) {
        pushEvent(state, {
          type: "turnover_shot_clock",
          offenseTeam: offense.name,
          playType: pressResult.playType || "press_break",
        });
        addTeamExtra(state, offenseTeamId, "turnovers", 1);
        beginNewPossession(state, nextDefenseTeamId(state.possessionTeamId), "out_of_bounds");
      }
      return;
    }

    state.possessionNeedsSetup = false;
    applyChunkClock(state, "tick");
    offenseLineup.forEach((player) => markInvolvement(offenseTeamId, player, 0.15));
    defenseLineup.forEach((player) => markInvolvement(defenseTeamId, player, 0.15));
    applyChunkMinutesAndEnergy(state, involvementByTeam);
    pushEvent(state, {
      type: "setup",
      offenseTeam: offense.name,
      defenseTeam: defense.name,
      detail: "Ball advanced into half-court set.",
    });

    if (state.shotClockRemaining <= 0) {
      pushEvent(state, {
        type: "turnover_shot_clock",
        offenseTeam: offense.name,
      });
      addTeamExtra(state, offenseTeamId, "turnovers", 1);
      beginNewPossession(state, nextDefenseTeamId(state.possessionTeamId), "out_of_bounds");
    }

    return;
  }

  const formation = getCurrentOffensiveFormation(offense);
  const offensiveAssignments = assignOffensiveSpots(offenseLineup, formation, random);
  const ballHandlerIndex = pickBallHandler(offensiveAssignments, random);
  const ballHandler = offensiveAssignments[ballHandlerIndex].player;
  const ballHandlerSpot = offensiveAssignments[ballHandlerIndex].spot;
  const onBall = getOnBallDefender({
    defenseScheme,
    defenseLineup,
    offensiveAssignments,
    ballHandlerIndex,
  });

  const zonePenalty = onBall.isZone
    ? -0.08 + zoneDistanceAdvantage(onBall.defender, onBall.startDistance)
    : 0;
  if (state.pendingAssist) {
    const pending = state.pendingAssist;
    if (
      pending.teamId !== offenseTeamId ||
      pending.receiver !== ballHandler ||
      !pending.validForNextAction
    ) {
      clearPendingAssist(state);
    } else {
      pending.validForNextAction = false;
    }
  }
  markInvolvement(offenseTeamId, ballHandler, 1);
  markInvolvement(defenseTeamId, onBall.defender, 0.9);

  offense.context = { ballHandlerSpot, formation };
  const playType = choosePlayType({ offenseTeam: offense, ballHandler, random });
  delete offense.context;

  let possessionChanged = false;
  let shotClockMode = "tick";
  const resolveLateClockBailout = ({
    shooter,
    defender,
    shooterSpot = null,
    sourceDetail,
    shotQualityEdge = -0.2,
  }) => {
    if (state.shotClockRemaining > 5) return false;

    const forcedShotType = chooseShotFromTendencies(shooter, random);
    const forcedShot = resolveShot({
      shooter,
      defender,
      shotType: forcedShotType,
      shooterSpot,
      zonePenalty,
      shotQualityEdge,
      contested: true,
      random,
    });
    forcedShot.shooter = shooter;
    markInvolvement(offenseTeamId, shooter, 1);
    markInvolvement(defenseTeamId, defender, 0.9);

    pushEvent(state, {
      type: "forced_shot_clock",
      offenseTeam: offense.name,
      playType,
      shotType: forcedShotType,
      shooter: shooter?.bio?.name,
      detail: sourceDetail,
    });

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
      shotType: forcedShotType,
      shot: forcedShot,
      random,
    });
    possessionChanged = endState.possessionChanged;
    shotClockMode = endState.shotClockMode;
    return true;
  };

  if (playType === "dribble_drive") {
    const drive = resolveInteraction({
      offensePlayer: ballHandler,
      defensePlayer: onBall.defender,
      offenseRatings: [
        "athleticism.agility",
        "athleticism.burst",
        "skills.ballHandling",
        "athleticism.speed",
      ],
      defenseRatings: [
        "defense.lateralQuickness",
        "defense.perimeterDefense",
        "athleticism.agility",
      ],
      contextEdge: zonePenalty - 0.04,
      random,
    });

    const decisiveOWin = drive.edge >= 0.64;
    const oWin = drive.edge >= 0.14;
    const decisiveDWin = drive.edge <= -0.6;
    const dTieOrSmallWin = !oWin && !decisiveDWin;

    if (decisiveDWin) {
      const stealChance = clamp(
        0.04 + (getRating(onBall.defender, "defense.steals") - getRating(ballHandler, "skills.ballSafety")) / 220,
        0.01,
        0.26,
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
          sourceDetail: "Defense cut off the drive; late-clock bailout shot.",
        })) {
          pushEvent(state, {
            type: "reset",
            offenseTeam: offense.name,
            playType,
            detail: "Defense cut off the drive.",
          });
        }
      }
    } else if (dTieOrSmallWin) {
      if (!resolveLateClockBailout({
        shooter: ballHandler,
        defender: onBall.defender,
        shooterSpot: ballHandlerSpot,
        sourceDetail: "Drive stalled; late-clock bailout shot.",
      })) {
        pushEvent(state, {
          type: "reset",
          offenseTeam: offense.name,
          playType,
          detail: "Drive stalled.",
        });
      }
    } else {
      const helpCandidates = defenseLineup.filter((_, idx) => idx !== ballHandlerIndex);
      const helpQuality = average(
        helpCandidates.map((d) =>
