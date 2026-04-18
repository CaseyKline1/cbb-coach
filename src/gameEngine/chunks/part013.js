  state.pendingTransition = null;
  state.pendingPress = null;
  syncClutchTimeState(state);

  simulateHalf(state, random);

  let overtimeNumber = 0;
  while (state.teams[0].score === state.teams[1].score) {
    overtimeNumber += 1;
    state.currentHalf = REGULATION_HALVES + overtimeNumber;
    state.gameClockRemaining = OVERTIME_SECONDS;
    state.shotClockRemaining = SHOT_CLOCK_SECONDS;
    state.possessionNeedsSetup = true;
    clearPendingAssist(state);
    state.pendingTransition = null;
    state.pendingPress = null;
    runDeadBallSubstitutions(state, "timeout");
    syncClutchTimeState(state);
    pushEvent(state, {
      type: "overtime_start",
      overtime: overtimeNumber,
    });
    simulateHalf(state, random);
  }

  const boxScore = state.boxScore.teams.map((teamTracker) => ({
    name: teamTracker.name,
    players: teamTracker.players.map((entry) => ({
      ...entry.stats,
      energy: Number(getPlayerEnergy(entry.player).toFixed(1)),
    })),
    teamExtras: { ...teamTracker.teamExtras },
  }));

  return {
    home: {
      name: state.teams[0].name,
      score: state.teams[0].score,
      boxScore: boxScore[0],
    },
    away: {
      name: state.teams[1].name,
      score: state.teams[1].score,
      boxScore: boxScore[1],
    },
    winner:
      state.teams[0].score === state.teams[1].score
        ? null
        : state.teams[0].score > state.teams[1].score
          ? state.teams[0].name
          : state.teams[1].name,
    playByPlay: state.playByPlay,
    boxScore,
  };
}

function createTeam({
  name,
  players,
  lineup,
  formation = OffensiveFormation.MOTION,
  formations = null,
  defenseScheme = DefenseScheme.MAN_TO_MAN,
  tendencies = {},
  timeouts = 4,
  rotation = null,
  pace = PaceProfile.NORMAL,
  coachingStaff = null,
  coaches = null,
  schoolPool = null,
  pipelineStateWeights = null,
}) {
  const defaultSchoolPool =
    Array.isArray(schoolPool) && schoolPool.length > 0
      ? schoolPool
      : typeof name === "string" && name.trim()
        ? [name.trim()]
        : [];
  const normalizedStaff = createCoachingStaff({
    headCoach: coachingStaff?.headCoach || coaches?.[0] || null,
    assistants: coachingStaff?.assistants || (Array.isArray(coaches) ? coaches.slice(1) : []),
    gamePrepAssistantIndex: coachingStaff?.gamePrepAssistantIndex,
    schoolPool: defaultSchoolPool,
    teamName: name,
    defaultPace: normalizePaceProfile(pace),
    defaultOffensiveSet: formation,
    defaultDefensiveSet: defenseScheme,
    pipelineStateWeights: pipelineStateWeights || undefined,
  });

  return {
    name,
    players: players || lineup || [],
    lineup: lineup || players || [],
    formation,
    formations,
    defenseScheme,
    tendencies,
    timeouts,
    rotation,
    pace: normalizePaceProfile(pace),
    coachingStaff: normalizedStaff,
    coaches: normalizedStaff.coaches,
  };
}

module.exports = {
  CHUNK_SECONDS,
  HALF_SECONDS,
  OVERTIME_SECONDS,
  SHOT_CLOCK_SECONDS,
  OffensiveSpot,
  OffensiveFormation,
  DefenseScheme,
  PaceProfile,
  createTeam,
  createInitialGameState,
  resolveInteraction,
  resolveActionChunk,
  simulateHalf,
  simulateGame,
};
