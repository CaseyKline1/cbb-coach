      addPlayerStat(state, offenseTeamId, shooter, "points", bonus);
      addTeamPoints(state, offenseTeamId, bonus);
      recoverAllPlayers(state, FREE_THROW_BREAK_RECOVERY);
      foulDetail = ` + ${bonus} FT`;
    }

    pushEvent(state, {
      type: "made_shot",
      offenseTeam: offense.name,
      points: shot.points,
      playType,
      shotType,
      shooter: shooter?.bio?.name,
      assister: shot.assister?.bio?.name,
      detail: foulDetail || undefined,
    });
    beginNewPossession(state, nextDefenseTeamId(state.possessionTeamId), "made_basket");
    return { possessionChanged: true, shotClockMode: "hold" };
  }

  if (shot.isShootingFoul) {
    addPlayerStat(state, defenseTeamId, primaryDefender, "fouls", 1);
    const ftMade = resolveFreeThrows(shooter, shot.foulShotsAwarded, random);
    recordFreeThrows(state, offenseTeamId, shooter, shot.foulShotsAwarded, ftMade);
    addPlayerStat(state, offenseTeamId, shooter, "points", ftMade);
    addTeamPoints(state, offenseTeamId, ftMade);
    recoverAllPlayers(state, FREE_THROW_BREAK_RECOVERY);
    pushEvent(state, {
      type: "shooting_foul",
      offenseTeam: offense.name,
      playType,
      shotType,
      points: ftMade,
      shooter: shooter?.bio?.name,
    });
    beginNewPossession(state, nextDefenseTeamId(state.possessionTeamId), "free_throws");
    return { possessionChanged: true, shotClockMode: "hold" };
  }

  const rebound = resolveRebound({
    offenseLineup,
    defenseLineup,
    defenseScheme,
    offensiveAssignments,
    offenseTeam: offense,
    defenseTeam: defense,
    shooter,
    shotType,
    transitionReboundMode,
    random,
  });

  if (shot.blockedByDefense) {
    addPlayerStat(state, defenseTeamId, primaryDefender, "blocks", 1);
    const rebounder = pickNearestDefenderTeammate({
      blocker: primaryDefender,
      defenseLineup,
      defenseScheme,
      offensiveAssignments,
    });
    recordRebound(state, defenseTeamId, rebounder, false);
    pushEvent(state, {
      type: "blocked_shot",
      offenseTeam: offense.name,
      defenseTeam: defense.name,
      playType,
      shotType,
      shooter: shooter?.bio?.name,
      blocker: primaryDefender?.bio?.name,
      rebounder: rebounder?.bio?.name,
    });
    const reboundTradeoff = getReboundTradeoffProfile({ offenseTeam: offense, defenseTeam: defense });
    beginNewPossession(state, nextDefenseTeamId(state.possessionTeamId), null, {
      transition: {
        sourceType: "def_rebound",
        initiator: rebounder,
        defenseHeadStart: reboundTradeoff.defenseHeadStart,
      },
    });
    return { possessionChanged: true, shotClockMode: "hold" };
  }

  if (rebound.offensiveRebound) {
    recordRebound(state, offenseTeamId, rebound.rebounder, true);
    state.shotClockRemaining = SHOT_CLOCK_SECONDS;
    pushEvent(state, {
      type: "miss_oreb",
      offenseTeam: offense.name,
      playType,
      shotType,
      shooter: shooter?.bio?.name,
      rebounder: rebound.rebounder?.bio?.name,
    });
    return { possessionChanged: false, shotClockMode: "tick" };
  }

  recordRebound(state, defenseTeamId, rebound.rebounder, false);
  pushEvent(state, {
    type: "miss_dreb",
    offenseTeam: offense.name,
    defenseTeam: defense.name,
    playType,
    shotType,
    shooter: shooter?.bio?.name,
    rebounder: rebound.rebounder?.bio?.name,
  });
  beginNewPossession(state, nextDefenseTeamId(state.possessionTeamId), null, {
    transition: {
      sourceType: "def_rebound",
      initiator: rebound.rebounder,
      defenseHeadStart: rebound.defenseHeadStart || 0,
    },
  });
  return { possessionChanged: true, shotClockMode: "hold" };
}

function resolveRebound({
  offenseLineup,
  defenseLineup,
  defenseScheme,
  offensiveAssignments,
  offenseTeam,
  defenseTeam,
  shooter,
  shotType,
  transitionReboundMode = null,
  random = Math.random,
}) {
  const offensePositions = getOffenderCourtPositions({
    offenseLineup,
    offensiveAssignments,
  });
  const defensePositions = getDefenderCourtPositions({
    defenseScheme,
    defenseLineup,
    offensiveAssignments,
  });
  const positioning = resolveBoxoutPositioning({
    offenseLineup,
    defenseLineup,
    offensePositions,
    defensePositions,
    defenseScheme,
    random,
  });

  const reboundTradeoff = getReboundTradeoffProfile({ offenseTeam, defenseTeam });

  if (transitionReboundMode === "trailers") {
    const transitionRebound = resolveTransitionMissRebound({
      offenseLineup,
      defenseLineup,
      shooter,
      random,
    });
    return {
      ...transitionRebound,
      direction: "middle",
      isLong: false,
      landingSpot: { x: 0, y: 1.7 },
      defenseHeadStart: reboundTradeoff.defenseHeadStart,
    };
  }

  const direction = pickReboundDirection({ shooter, offensiveAssignments, random });
  let isLong = random() < baseLongReboundChance(shotType);
  let landingSpot = buildReboundLandingSpot({ direction, isLong, random });
  let radius = isLong ? 3.3 : 2.2;
  let candidates = collectReboundCandidates({
    offensePositions,
    defensePositions,
    landingSpot,
    radius,
  });

  if (!isLong && candidates.length === 0) {
    isLong = true;
    landingSpot = buildReboundLandingSpot({ direction, isLong, random });
    radius = 3.3;
    candidates = collectReboundCandidates({
      offensePositions,
      defensePositions,
      landingSpot,
      radius,
    });
  }

  const fallbackCandidates =
    candidates.length > 0
      ? candidates
      : [
          ...offensePositions.map(({ player, coord }) => ({
            player,
            team: "offense",
            distance: dist(coord, landingSpot),
          })),
          ...defensePositions.map(({ player, coord }) => ({
            player,
            team: "defense",
            distance: dist(coord, landingSpot),
          })),
        ];

  const rebounder = pickWeighted(
    fallbackCandidates.map((entry) => {
      const player = entry.player;
      const reachScore = getHeightInches(player) * 0.42 + getWingspanInches(player) * 0.58;
      const verticalScore = getRating(player, "athleticism.vertical");
      const reboundingScore =
        entry.team === "offense"
          ? getRating(player, "rebounding.offensiveRebounding")
          : getRating(player, "rebounding.defensiveRebound");
      const positioningScore = positioning.get(player) || 1;
      const distanceScore = clamp(1 - entry.distance / (radius + 0.15), 0.18, 1);
      const weight =
        (reboundingScore * 0.47 + reachScore * 0.22 + verticalScore * 0.21 + getRating(player, "rebounding.boxouts") * 0.1) *
        positioningScore *
        distanceScore *
        (entry.team === "offense" ? reboundTradeoff.offenseCrashMultiplier : reboundTradeoff.defenseCrashMultiplier);
      return {
        value: entry,
        weight: Math.max(1, weight),
      };
    }),
    random,
  );

  const offensiveRebound = rebounder.team === "offense";
  return {
    offensiveRebound,
    rebounder: rebounder.player,
    direction,
    isLong,
    landingSpot,
    defenseHeadStart: reboundTradeoff.defenseHeadStart,
  };
}

function nextDefenseTeamId(currentOffenseTeamId) {
  return currentOffenseTeamId === 0 ? 1 : 0;
}

function clearPendingAssist(state) {
  state.pendingAssist = null;
}

function setPendingAssist(state, teamId, passer, receiver) {
  if (!passer || !receiver || passer === receiver) {
    clearPendingAssist(state);
    return;
  }

  state.pendingAssist = { teamId, passer, receiver, validForNextAction: true };
}

function applyPendingAssistIfEligible(state, offenseTeamId, shooter, shot) {
  if (shot.assister || !shooter) return;
  const pending = state.pendingAssist;
  if (!pending || pending.teamId !== offenseTeamId) return;
  if (pending.receiver !== shooter) return;
  if (pending.passer === shooter) return;
  shot.assister = pending.passer;
}

function createInitialGameState(homeTeam, awayTeam, random = Math.random, options = {}) {
  const neutralSite = options.gameSiteType === "neutral" || options.neutralSite === true;
  const homeLineup = getDefaultLineup(homeTeam);
  const awayLineup = getDefaultLineup(awayTeam);
  const teams = [
    initializeTeamFormationState({
      ...homeTeam,
      players: homeTeam.players?.length ? homeTeam.players : homeLineup,
      lineup: homeLineup,
      score: 0,
      isHomeTeam: !neutralSite,
      timeoutsRemaining: Number.isFinite(homeTeam.timeouts) ? homeTeam.timeouts : 4,
    }),
    initializeTeamFormationState({
      ...awayTeam,
      players: awayTeam.players?.length ? awayTeam.players : awayLineup,
      lineup: awayLineup,
      score: 0,
      isHomeTeam: false,
      timeoutsRemaining: Number.isFinite(awayTeam.timeouts) ? awayTeam.timeouts : 4,
    }),
  ];

  teams.forEach((team) => {
    getTeamRoster(team).forEach((player) => ensurePlayerCondition(player));
  });

  const state = {
    teams,
    gameSiteType: neutralSite ? "neutral" : "home",
    boxScore: initializeBoxScoreTracker(teams),
    possessionTeamId: random() < 0.5 ? 0 : 1,
    gameClockRemaining: HALF_SECONDS,
    currentHalf: 1,
    shotClockRemaining: SHOT_CLOCK_SECONDS,
    possessionNeedsSetup: true,
    pendingAssist: null,
    pendingTransition: null,
    pendingPress: null,
    playByPlay: [],
  };
  applyTeamCoachingModifiers(state);
  syncPossessionTeamRoles(state);
  syncClutchTimeState(state);
  return state;
}

function beginNewPossession(state, offenseTeamId, deadBallReason = null, options = null) {
  clearPendingAssist(state);
  state.possessionTeamId = offenseTeamId;
  syncPossessionTeamRoles(state);
  advanceTeamOffensiveFormation(state.teams[offenseTeamId]);
  state.shotClockRemaining = SHOT_CLOCK_SECONDS;
  state.possessionNeedsSetup = true;
  state.pendingPress = null;
  state.pendingTransition = deadBallReason
    ? null
    : options?.transition
      ? { phase: 1, ...options.transition }
      : null;
  if (deadBallReason) {
    runDeadBallSubstitutions(state, deadBallReason);
  }
}

function pushEvent(state, event) {
  const elapsed = getElapsedGameSeconds(state);
  state.playByPlay.push({
    half: state.currentHalf,
    elapsedSecondsInHalf: getElapsedSecondsInCurrentPeriod(state),
    elapsedGameSeconds: elapsed,
    ...event,
  });
}

function applyChunkClock(state, shotClockMode = "tick") {
  state.gameClockRemaining = Math.max(0, state.gameClockRemaining - CHUNK_SECONDS);

  if (shotClockMode === "tick") {
    state.shotClockRemaining = Math.max(0, state.shotClockRemaining - CHUNK_SECONDS);
  }
}

function normalizePaceProfile(value) {
  if (typeof value !== "string") return PaceProfile.NORMAL;
  const normalized = value.trim().toLowerCase().replace(/[\s-]+/g, "_");
  if (PACE_TO_SHOT_BIAS[normalized] !== undefined) return normalized;
  return PaceProfile.NORMAL;
}

function getTeamCoachingStaff(team) {
  if (team?.coachingStaff) return team.coachingStaff;
  if (Array.isArray(team?.coaches) && team.coaches.length) {
    return {
      headCoach: team.coaches[0],
      assistants: team.coaches.slice(1),
      gamePrepAssistantIndex: null,
    };
  }
  return {
    headCoach: null,
    assistants: [],
    gamePrepAssistantIndex: null,
  };
}

function getAssistantByGamePrepDesignation(team, assistants) {
  const designatedIndex = Number(team?.coachingStaff?.gamePrepAssistantIndex);
  if (
    Number.isInteger(designatedIndex) &&
    designatedIndex >= 0 &&
    designatedIndex < assistants.length
  ) {
    return assistants[designatedIndex];
  }
  return assistants.find((assistant) => assistant?.isGamePrep || assistant?.gamePrep) || null;
}

function getTeamCoachingGameEffect(team) {
  const staff = getTeamCoachingStaff(team);
  const head = staff.headCoach || null;
  const assistants = Array.isArray(staff.assistants) ? staff.assistants : [];
  const gamePrep = getAssistantByGamePrepDesignation(team, assistants);

  const headOffense = Number(head?.skills?.offensiveCoaching);
  const headDefense = Number(head?.skills?.defensiveCoaching);
  const prepOffense = Number(gamePrep?.skills?.offensiveCoaching);
  const prepDefense = Number(gamePrep?.skills?.defensiveCoaching);

  const resolveRating = (value, fallback = 50) =>
    Number.isFinite(value) ? clamp(Math.round(value), 1, 100) : fallback;

  const headOff = resolveRating(headOffense);
  const headDef = resolveRating(headDefense);
  const prepOff = resolveRating(prepOffense, headOff);
  const prepDef = resolveRating(prepDefense, headDef);

  const prepWeight = gamePrep ? GAME_PREP_ASSISTANT_GAME_IMPACT_WEIGHT : 0;
  const headWeight = 1 - prepWeight;

  const offensiveComposite = headOff * headWeight + prepOff * prepWeight;
  const defensiveComposite = headDef * headWeight + prepDef * prepWeight;

  const toModifier = (compositeRating) =>
    clamp(1 + ((compositeRating - 50) / 50) * COACHING_EDGE_MAX_MULTIPLIER, 0.94, 1.06);

  return {
    offensiveModifier: toModifier(offensiveComposite),
    defensiveModifier: toModifier(defensiveComposite),
  };
}

function applyTeamCoachingModifiers(state) {
  state.teams.forEach((team) => {
    const effect = getTeamCoachingGameEffect(team);
    getTeamRoster(team).forEach((player) => {
      ensurePlayerCondition(player);
      player.condition.offensiveCoachingModifier = effect.offensiveModifier;
      player.condition.defensiveCoachingModifier = effect.defensiveModifier;
    });
  });
}

function syncPossessionTeamRoles(state) {
  const offenseTeamId = state.possessionTeamId;
  const defenseTeamId = nextDefenseTeamId(offenseTeamId);
  state.teams.forEach((team, teamId) => {
    const role = teamId === offenseTeamId ? "offense" : teamId === defenseTeamId ? "defense" : null;
    getTeamRoster(team).forEach((player) => {
      ensurePlayerCondition(player);
      player.condition.possessionRole = role;
    });
  });
}

function getSecondsLeftInGame(state) {
  if (state.currentHalf === 1) return HALF_SECONDS + state.gameClockRemaining;
  if (state.currentHalf === 2) return state.gameClockRemaining;
  return 0;
}

function getLateGamePaceShotBias(state, offenseTeamId) {
  const offense = state.teams?.[offenseTeamId];
  const defense = state.teams?.[nextDefenseTeamId(offenseTeamId)];
  if (!offense || !defense) return 0;

  const secondsLeftInGame = getSecondsLeftInGame(state);
  if (secondsLeftInGame > 120) return 0;

  const scoreDiff = (offense.score || 0) - (defense.score || 0);
