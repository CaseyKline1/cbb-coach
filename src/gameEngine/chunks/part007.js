  const urgencyByTime = secondsLeftInGame <= 60 ? 1 : 0.7;
  const urgencyByMargin = clamp(Math.abs(scoreDiff) / 10, 0.2, 1.2);
  const magnitude = 0.02 + 0.06 * urgencyByTime * urgencyByMargin;

  if (scoreDiff >= 2) return -magnitude;
  if (scoreDiff <= -2) return magnitude;
  return 0;
}

function getPaceShotBias(state, offenseTeamId) {
  const offense = state.teams?.[offenseTeamId];
  const baseBias = PACE_TO_SHOT_BIAS[normalizePaceProfile(offense?.pace)];
  return clamp(baseBias + getLateGamePaceShotBias(state, offenseTeamId), -0.18, 0.18);
}

function getTeamTendencyMultiplier(team, key, fallback = 1) {
  const raw = Number(team?.tendencies?.[key]);
  if (!Number.isFinite(raw)) return fallback;
  return clamp(raw, 0.35, 2.8);
}

function getPaceFastBreakBias(team) {
  return PACE_TO_FASTBREAK_BIAS[normalizePaceProfile(team?.pace)] ?? 0;
}

function getTeamFastBreakIntent(team, tendencyKey) {
  const tendency = getTeamTendencyMultiplier(team, tendencyKey, 1);
  return clamp((tendency - 1) * 0.18 + getPaceFastBreakBias(team), -0.26, 0.3);
}

function pickTransitionRunner(lineup, random = Math.random) {
  return pickWeighted(
    lineup.map((player) => {
      const runScore =
        getRating(player, "athleticism.burst") * 0.28 +
        getRating(player, "athleticism.speed") * 0.27 +
        getRating(player, "skills.offballOffense") * 0.2 +
        getRating(player, "skills.hands") * 0.12 +
        getRating(player, "skills.shotIQ") * 0.13;
      const interiorPenalty = clamp((getWeightPounds(player) - 220) / 60, 0, 0.3);
      return {
        value: player,
        weight: Math.max(1, runScore * (1 - interiorPenalty) * (0.87 + random() * 0.26)),
      };
    }),
    random,
  );
}

function pickTransitionPointDefender(lineup, random = Math.random) {
  return pickWeighted(
    lineup.map((player) => {
      const recovery =
        getRating(player, "athleticism.burst") * 0.26 +
        getRating(player, "athleticism.speed") * 0.26 +
        getRating(player, "defense.lateralQuickness") * 0.18 +
        getRating(player, "defense.offballDefense") * 0.18 +
        getRating(player, "defense.shotContest") * 0.12;
      return {
        value: player,
        weight: Math.max(1, recovery * (0.85 + random() * 0.3)),
      };
    }),
    random,
  );
}

function chooseFastBreakFinishType(player, random = Math.random) {
  const dunkLean =
    getRating(player, "shooting.dunks") * 0.5 +
    getRating(player, "athleticism.vertical") * 0.3 +
    getRating(player, "athleticism.strength") * 0.2;
  const layupLean =
    getRating(player, "shooting.layups") * 0.62 +
    getRating(player, "shooting.closeShot") * 0.24 +
    getRating(player, "skills.shotIQ") * 0.14;

  return pickWeighted(
    [
      { value: "layup", weight: Math.max(1, layupLean) },
      { value: "dunk", weight: Math.max(1, dunkLean) },
    ],
    random,
  );
}

function getReboundTradeoffProfile({ offenseTeam, defenseTeam }) {
  const offenseCrash = getTeamTendencyMultiplier(offenseTeam, "crashBoardsOffense", 1);
  const offenseRetreat = getTeamTendencyMultiplier(offenseTeam, "defendFastBreakOffense", 1);
  const defenseCrash = getTeamTendencyMultiplier(defenseTeam, "crashBoardsDefense", 1);
  const defenseLeak = getTeamTendencyMultiplier(defenseTeam, "attemptFastBreakDefense", 1);

  const offenseCrashMultiplier = clamp(0.86 + (offenseCrash - 1) * 0.34 - (offenseRetreat - 1) * 0.22, 0.62, 1.45);
  const defenseCrashMultiplier = clamp(0.87 + (defenseCrash - 1) * 0.38 - (defenseLeak - 1) * 0.27, 0.62, 1.45);
  const defenseHeadStart = clamp((defenseLeak - 1) * 0.14 - (offenseRetreat - 1) * 0.15, -0.18, 0.2);

  return {
    offenseCrashMultiplier,
    defenseCrashMultiplier,
    defenseHeadStart,
  };
}

function resolveTransitionMissRebound({
  offenseLineup,
  defenseLineup,
  shooter,
  random = Math.random,
}) {
  const transitionRoleMultiplier = (player) => {
    const roleOptions = getPositionRoleOptions(player?.bio?.position);
    if (roleOptions.includes("PF") || roleOptions.includes("C")) return 1.14;
    if (roleOptions.includes("SF")) return 1.04;
    return 0.93;
  };

  const weighted = [
    ...offenseLineup.map((player) => {
      const score =
        getRating(player, "rebounding.offensiveRebounding") * 0.5 +
        getRating(player, "skills.hustle") * 0.15 +
        getRating(player, "athleticism.burst") * 0.15 +
        getRating(player, "athleticism.speed") * 0.1 +
        getRating(player, "rebounding.boxouts") * 0.1;
      const shooterPenalty = player === shooter ? 0.52 : 1.18;
      return {
        value: { player, team: "offense" },
        weight: Math.max(1, score * shooterPenalty * transitionRoleMultiplier(player) * (0.85 + random() * 0.3)),
      };
    }),
    ...defenseLineup.map((player) => {
      const score =
        getRating(player, "rebounding.defensiveRebound") * 0.52 +
        getRating(player, "skills.hustle") * 0.13 +
        getRating(player, "athleticism.burst") * 0.13 +
        getRating(player, "athleticism.speed") * 0.08 +
        getRating(player, "rebounding.boxouts") * 0.14;
      return {
        value: { player, team: "defense" },
        weight: Math.max(1, score * transitionRoleMultiplier(player) * (0.85 + random() * 0.3)),
      };
    }),
  ];

  const rebounder = pickWeighted(weighted, random);
  return {
    offensiveRebound: rebounder.team === "offense",
    rebounder: rebounder.player,
  };
}

function resolveFastBreakWindow({
  state,
  offenseTeamId,
  defenseTeamId,
  offense,
  defense,
  offenseLineup,
  defenseLineup,
  defenseScheme,
  markInvolvement,
  random = Math.random,
}) {
  const transition = state.pendingTransition;
  if (!transition || !state.possessionNeedsSetup) return { handled: false };

  const phase = transition.phase || 1;
  const sourceType = transition.sourceType || "def_rebound";
  const initiator = transition.initiator || pickTransitionRunner(offenseLineup, random);
  const sourceBoost = sourceType === "steal" ? 0.12 : sourceType === "press_break" ? 0.1 : 0.03;
  const pushIntent = getTeamFastBreakIntent(offense, "fastBreakOffense");
  const defenseRecoveryIntent = getTeamFastBreakIntent(defense, "defendFastBreakOffense");
  const headStart = transition.defenseHeadStart || 0;

  if (phase === 1) {
    const pushChance = clamp(
      0.08 + (sourceType === "steal" ? 0.12 : sourceType === "press_break" ? 0.09 : 0) + pushIntent * 0.9 + headStart * 0.35,
      0.02,
      0.82,
    );

    if (random() >= pushChance) {
      state.pendingTransition = null;
      state.possessionNeedsSetup = false;
      pushEvent(state, {
        type: "setup",
        offenseTeam: offense.name,
        defenseTeam: defense.name,
        detail: "Ball secured, but offense pulled it back into half-court.",
      });
      return {
        handled: true,
        playType: "fast_break",
        possessionChanged: false,
        shotClockMode: "tick",
      };
    }

    const runner = pickTransitionRunner(offenseLineup, random);
    const leadDefender = pickTransitionPointDefender(defenseLineup, random);
    const canPassAhead = runner !== initiator;
    const passAhead =
      canPassAhead &&
      random() <
        clamp(
          0.33 +
            (getRating(initiator, "skills.passingVision") - 55) / 240 +
            (getRating(runner, "athleticism.speed") - 55) / 260,
          0.12,
          0.78,
        );
    const passEdge = passAhead
      ? clamp(
          (getRating(initiator, "skills.passingAccuracy") - 60) / 180 +
            (getRating(runner, "skills.hands") - 60) / 220,
          -0.1,
          0.22,
        )
      : 0;
    const runnerWithBall = passAhead ? runner : initiator;
    const runScore =
      getRating(runnerWithBall, "athleticism.burst") * 0.38 +
      getRating(runnerWithBall, "athleticism.speed") * 0.34 +
      getRating(runnerWithBall, "skills.ballHandling") * 0.14 +
      getRating(runnerWithBall, "skills.offballOffense") * 0.14;
    const recoveryScore =
      getRating(leadDefender, "athleticism.burst") * 0.33 +
      getRating(leadDefender, "athleticism.speed") * 0.31 +
      getRating(leadDefender, "defense.lateralQuickness") * 0.2 +
      getRating(leadDefender, "defense.shotContest") * 0.16;
    const raceEdge =
      (runScore - recoveryScore) / 100 + sourceBoost + pushIntent - defenseRecoveryIntent * 0.4 - headStart * 0.3 + passEdge;
    const beatDefenseChance = clamp(0.2 + raceEdge * 0.5, 0.04, 0.86);

    markInvolvement(offenseTeamId, initiator, 0.65);
    markInvolvement(offenseTeamId, runnerWithBall, 0.95);
    markInvolvement(defenseTeamId, leadDefender, 0.85);
    offenseLineup.forEach((player) => {
      if (player !== initiator && player !== runnerWithBall) markInvolvement(offenseTeamId, player, 0.14);
    });
    defenseLineup.forEach((player) => {
      if (player !== leadDefender) markInvolvement(defenseTeamId, player, 0.16);
    });

    if (random() < beatDefenseChance) {
      const shotType = chooseFastBreakFinishType(runnerWithBall, random);
      const shot = resolveShot({
        shooter: runnerWithBall,
        defender: leadDefender,
        shotType,
        shooterSpot: OffensiveSpot.MIDDLE_PAINT,
        zonePenalty: 0,
        shotQualityEdge: 0.56,
        contested: false,
        random,
      });
      shot.shooter = runnerWithBall;
      if (passAhead && initiator !== runnerWithBall) {
        shot.assister = initiator;
      }
      state.pendingTransition = null;
      pushEvent(state, {
        type: "fast_break_primary",
        offenseTeam: offense.name,
        defenseTeam: defense.name,
        playType: "fast_break",
        shooter: runnerWithBall?.bio?.name,
        defender: leadDefender?.bio?.name,
        detail: passAhead ? "Lead pass hit a runner in stride." : "Ball-handler pushed the break end-to-end.",
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
        offensiveAssignments: [],
        playType: "fast_break_primary",
        shotType,
        shot,
        transitionReboundMode: "trailers",
        random,
      });
      return {
        handled: true,
        playType: "fast_break_primary",
        possessionChanged: endState.possessionChanged,
        shotClockMode: endState.shotClockMode,
      };
    }

    state.pendingTransition = { ...transition, phase: 2, initiator, runner: runnerWithBall };
    pushEvent(state, {
      type: "reset",
      offenseTeam: offense.name,
      defenseTeam: defense.name,
      playType: "fast_break_primary",
      detail: passAhead ? "Lead pass connected, but defense recovered in front." : "Defense beat the push and set at the rim.",
    });
    return {
      handled: true,
      playType: "fast_break_primary",
      possessionChanged: false,
      shotClockMode: "tick",
    };
  }

  const leadDefender = pickTransitionPointDefender(defenseLineup, random);
  const secondaryWindow = clamp(
    0.26 + pushIntent * 0.8 - defenseRecoveryIntent * 0.4 - headStart * 0.15 + sourceBoost * 0.55,
    0,
    0.84,
  );
  const attackChance = clamp(0.44 + secondaryWindow * 0.58, 0.14, 0.9);
  const attackSecondary = random() < attackChance && secondaryWindow >= 0.12;

  const runner = transition.runner || pickTransitionRunner(offenseLineup, random);
  markInvolvement(offenseTeamId, runner, 0.72);
  markInvolvement(defenseTeamId, leadDefender, 0.68);
  offenseLineup.forEach((player) => {
    if (player !== runner) markInvolvement(offenseTeamId, player, 0.18);
  });
  defenseLineup.forEach((player) => {
    if (player !== leadDefender) markInvolvement(defenseTeamId, player, 0.2);
  });

  state.pendingTransition = null;
  state.possessionNeedsSetup = false;

  if (!attackSecondary) {
    pushEvent(state, {
      type: "reset",
      offenseTeam: offense.name,
      defenseTeam: defense.name,
      playType: "fast_break_secondary",
      detail: "Secondary break never opened; offense settled into half-court.",
    });
    return {
      handled: true,
      playType: "fast_break_secondary",
      possessionChanged: false,
      shotClockMode: "tick",
    };
  }

  const shooter = pickWeighted(
    offenseLineup.map((player) => {
      const shotProfile =
        average([
          getRating(player, "shooting.closeShot"),
          getRating(player, "shooting.midrangeShot"),
          getRating(player, "shooting.threePointShooting"),
        ]) * 0.6 +
        getRating(player, "skills.offballOffense") * 0.22 +
        getRating(player, "skills.shotIQ") * 0.18;
      return {
        value: player,
        weight: Math.max(1, shotProfile * (0.88 + random() * 0.25)),
      };
    }),
    random,
  );
  const shotType = chooseShotFromTendencies(shooter, random);
  const openLookChance = clamp(0.38 + secondaryWindow * 0.62, 0.22, 0.9);
  const shot = resolveShot({
    shooter,
    defender: leadDefender,
    shotType,
    zonePenalty: 0,
    shotQualityEdge: 0.12 + secondaryWindow * 0.33,
    contested: random() >= openLookChance,
    random,
  });
  shot.shooter = shooter;

  pushEvent(state, {
    type: "fast_break_secondary_shot",
    offenseTeam: offense.name,
    defenseTeam: defense.name,
    playType: "fast_break_secondary",
    shotType,
    shooter: shooter?.bio?.name,
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
    offensiveAssignments: [],
    playType: "fast_break_secondary",
    shotType,
    shot,
    random,
  });
  return {
    handled: true,
    playType: "fast_break_secondary",
    possessionChanged: endState.possessionChanged,
    shotClockMode: endState.shotClockMode,
  };
}

function shouldApplyPressThisPossession({
  state,
  offense,
  defense,
  random = Math.random,
}) {
  if (!offense || !defense) return false;
  const pressTendency = getTeamTendencyMultiplier(defense, "press", 1);
  const trailingMargin = (offense.score || 0) - (defense.score || 0);
  const secondsLeftInGame = getSecondsLeftInGame(state);
  const lateGameTrailPress = secondsLeftInGame <= 120 && trailingMargin >= 2;
  const pressingByTendency = pressTendency > 1.05;

  if (!pressingByTendency && !lateGameTrailPress) return false;

  const deficitPressure = lateGameTrailPress
    ? clamp(trailingMargin / 10, 0.2, 1.2) * clamp((120 - secondsLeftInGame) / 120 + 0.45, 0.45, 1.2)
    : 0;
  const triggerChance = clamp(
    PRESS_BASE_TRIGGER_CHANCE +
      Math.max(0, pressTendency - 1) * PRESS_HIGH_TENDENCY_TRIGGER_BONUS +
      deficitPressure * PRESS_LATE_GAME_TRAIL_BONUS,
    0.04,
    0.96,
  );

  return random() < triggerChance;
}

function pickPressBallHandler(lineup, random = Math.random) {
  return pickWeighted(
    lineup.map((player) => {
      const control =
        getRating(player, "skills.ballHandling") * 0.42 +
        getRating(player, "skills.ballSafety") * 0.22 +
        getRating(player, "skills.passingIQ") * 0.16 +
        getRating(player, "skills.passingVision") * 0.1 +
        getRating(player, "athleticism.speed") * 0.1;
      return {
        value: player,
        weight: Math.max(1, control * (0.85 + random() * 0.3)),
      };
    }),
    random,
  );
}

function pickPressReceiver(lineup, ballHandler, random = Math.random) {
