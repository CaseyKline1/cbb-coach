  let chosenLoad = Number.POSITIVE_INFINITY;
  for (const day of dayPool) {
    ensureDay(context, day);
    const busy = context.busyTeamsByDay.get(day);
    if (busy.has(teamAId) || busy.has(teamBId)) continue;
    const load = context.gamesByDay.get(day).length;
    if (load < chosenLoad) {
      chosenLoad = load;
      chosenDay = day;
    }
  }
  return chosenDay;
}

function computeConferenceDayCount(conferenceSize, conferenceGamesTarget) {
  if (conferenceSize % 2 === 0) return conferenceGamesTarget;
  return Math.ceil((conferenceGamesTarget * conferenceSize) / (conferenceSize - 1));
}

function getUserLockedGames(league, seedKey = league.seed) {
  const selectedOpponentIds = league.userPreseason.nonConferenceOpponentIds;
  if (!selectedOpponentIds.length) return [];

  const daySlots = spreadEvenly(league.settings.nonConferenceDayCount, selectedOpponentIds.length);
  const random = createSeededRandom(`${seedKey}:locked-nonconf`);

  return selectedOpponentIds.map((opponentTeamId, index) => {
    const [homeTeamId, awayTeamId] = pickHomeAway(
      {
        homeGamesByTeam: new Map(),
        awayGamesByTeam: new Map(),
      },
      league.userTeamId,
      opponentTeamId,
      random,
    );

    return {
      homeTeamId,
      awayTeamId,
      day: daySlots[index],
      lockedByUser: true,
    };
  });
}

function spreadEvenly(maxDay, count) {
  if (count <= 0) return [];
  if (count === 1) return [1];
  const values = [];
  for (let i = 0; i < count; i += 1) {
    const ratio = i / (count - 1);
    values.push(clamp(Math.round(1 + ratio * (maxDay - 1)), 1, maxDay));
  }
  return unique(values);
}

function scheduleNonConferenceGames({
  league,
  seedKey = league.seed,
  context,
  teamStateById,
  nonConferenceTargetByTeam,
  dayPool,
  lockedGames,
}) {
  const random = createSeededRandom(`${seedKey}:non-conference`);
  const remaining = new Map(Object.entries(nonConferenceTargetByTeam));
  const pairCounts = new Map();

  function canSchedulePair(teamAId, teamBId, maxPairings = 1) {
    if (teamAId === teamBId) return false;
    if (teamStateById[teamAId].conferenceId === teamStateById[teamBId].conferenceId) return false;
    const key = gamePairKey(teamAId, teamBId);
    const pairCount = pairCounts.get(key) || 0;
    return pairCount < maxPairings;
  }

  function schedulePair(teamAId, teamBId, day, lockedByUser = false) {
    const [homeTeamId, awayTeamId] = pickHomeAway(context, teamAId, teamBId, random);
    const game = {
      id: `g-${context.nextGameId++}`,
      day,
      homeTeamId,
      awayTeamId,
      type: "non_conference",
      conferenceId: null,
      lockedByUser,
      completed: false,
      result: null,
    };

    const didSchedule = addScheduledGame(context, game);
    if (!didSchedule) return false;

    const key = gamePairKey(teamAId, teamBId);
    pairCounts.set(key, (pairCounts.get(key) || 0) + 1);
    remaining.set(teamAId, (remaining.get(teamAId) || 0) - 1);
    remaining.set(teamBId, (remaining.get(teamBId) || 0) - 1);
    return true;
  }

  for (const lockedGame of lockedGames) {
    if (!remaining.has(lockedGame.homeTeamId) || !remaining.has(lockedGame.awayTeamId)) continue;
    if ((remaining.get(lockedGame.homeTeamId) || 0) <= 0 || (remaining.get(lockedGame.awayTeamId) || 0) <= 0) continue;
    if (!canSchedulePair(lockedGame.homeTeamId, lockedGame.awayTeamId, 1)) continue;

    let scheduledDay = lockedGame.day;
    if (!dayPool.includes(scheduledDay)) {
      scheduledDay = selectDayForMatchup(context, dayPool, lockedGame.homeTeamId, lockedGame.awayTeamId);
    }
    if (!scheduledDay) continue;

    schedulePair(lockedGame.homeTeamId, lockedGame.awayTeamId, scheduledDay, true);
  }

  const allTeamIds = Object.keys(teamStateById);

  for (const day of dayPool) {
    ensureDay(context, day);
    const available = shuffle(
      allTeamIds
        .filter((teamId) => (remaining.get(teamId) || 0) > 0)
        .filter((teamId) => !context.busyTeamsByDay.get(day).has(teamId))
        .sort((a, b) => (remaining.get(b) || 0) - (remaining.get(a) || 0)),
      random,
    );

    const taken = new Set();
    for (let i = 0; i < available.length; i += 1) {
      const teamAId = available[i];
      if (taken.has(teamAId)) continue;

      let bestOpponent = null;
      let bestScore = -Infinity;
      for (let j = i + 1; j < available.length; j += 1) {
        const teamBId = available[j];
        if (taken.has(teamBId)) continue;
        if (!canSchedulePair(teamAId, teamBId, 1)) continue;

        const score = (remaining.get(teamBId) || 0) * 3 + random();
        if (score > bestScore) {
          bestScore = score;
          bestOpponent = teamBId;
        }
      }

      if (!bestOpponent) continue;
      if (schedulePair(teamAId, bestOpponent, day, false)) {
        taken.add(teamAId);
        taken.add(bestOpponent);
      }
    }
  }

  let repairPass = 0;
  while (repairPass < 3) {
    repairPass += 1;
    const unresolved = allTeamIds.filter((teamId) => (remaining.get(teamId) || 0) > 0);
    if (!unresolved.length) break;

    let madeProgress = false;
    const pairCap = repairPass >= 2 ? 2 : 1;
    const ordered = shuffle(
      unresolved.sort((a, b) => (remaining.get(b) || 0) - (remaining.get(a) || 0)),
      random,
    );

    for (const teamAId of ordered) {
      if ((remaining.get(teamAId) || 0) <= 0) continue;

      const opponents = ordered
        .filter((teamBId) => (remaining.get(teamBId) || 0) > 0 && teamBId !== teamAId)
        .filter((teamBId) => canSchedulePair(teamAId, teamBId, pairCap));

      let scheduled = false;
      for (const teamBId of opponents) {
        const day = selectDayForMatchup(context, dayPool, teamAId, teamBId);
        if (!day) continue;
        if (schedulePair(teamAId, teamBId, day, false)) {
          madeProgress = true;
          scheduled = true;
          break;
        }
      }

      if (!scheduled && repairPass === 3) {
        const extraDay = Math.max(...dayPool) + 1;
        dayPool.push(extraDay);
        const teamBId = opponents[0];
        if (teamBId && schedulePair(teamAId, teamBId, extraDay, false)) {
          madeProgress = true;
        }
      }
    }

    if (!madeProgress) break;
  }

  // Final deterministic fallback: keep pairing unresolved teams, expanding the
  // calendar when needed. This avoids rare dead-ends from greedy passes.
  let fallbackGuard = 0;
  while (fallbackGuard < 20000) {
    fallbackGuard += 1;
    const unresolved = allTeamIds
      .filter((teamId) => (remaining.get(teamId) || 0) > 0)
      .sort((a, b) => (remaining.get(b) || 0) - (remaining.get(a) || 0));
    if (!unresolved.length) break;

    let progress = false;
    for (const teamAId of unresolved) {
      if ((remaining.get(teamAId) || 0) <= 0) continue;

      const opponents = unresolved
        .filter((teamBId) => teamBId !== teamAId)
        .filter((teamBId) => (remaining.get(teamBId) || 0) > 0)
        .filter((teamBId) => teamStateById[teamBId].conferenceId !== teamStateById[teamAId].conferenceId)
        .sort((a, b) => {
          const pairDiff = (pairCounts.get(gamePairKey(teamAId, a)) || 0) - (pairCounts.get(gamePairKey(teamAId, b)) || 0);
          if (pairDiff !== 0) return pairDiff;
          return (remaining.get(b) || 0) - (remaining.get(a) || 0);
        });

      const opponentId = opponents[0];
      if (!opponentId) continue;

      let day = selectDayForMatchup(context, dayPool, teamAId, opponentId);
      if (!day) {
        day = Math.max(...dayPool) + 1;
        dayPool.push(day);
      }

      if (schedulePair(teamAId, opponentId, day, false)) {
        progress = true;
      }
    }

    if (!progress) break;
  }

  const stillUnresolved = allTeamIds.filter((teamId) => (remaining.get(teamId) || 0) > 0);
  if (stillUnresolved.length) {
    throw new Error(
      `Unable to complete non-conference scheduling for ${stillUnresolved.length} teams. ` +
        `Try reducing locked games or using a different seed.`,
    );
  }

  return {
    nonConferenceDaysUsed: dayPool.length,
  };
}

function scheduleConferenceGames({
  league,
  seedKey = league.seed,
  context,
  conference,
  conferenceTeamIds,
  conferenceGamesTarget,
  dayPool,
}) {
  const random = createSeededRandom(`${seedKey}:conference:${conference.id}`);
  const remaining = new Map(conferenceTeamIds.map((teamId) => [teamId, conferenceGamesTarget]));
  const pairCounts = new Map();
  const pairCap = Math.max(1, Math.ceil(conferenceGamesTarget / Math.max(1, conferenceTeamIds.length - 1)));

  let degreeSum = conferenceTeamIds.reduce((sum, teamId) => sum + (remaining.get(teamId) || 0), 0);
  if (degreeSum % 2 !== 0) {
    const candidates = conferenceTeamIds.filter((teamId) => teamId !== league.userTeamId);
    const fallback = candidates[0] || conferenceTeamIds[0];
    if (fallback) {
      remaining.set(fallback, Math.max(0, (remaining.get(fallback) || 0) - 1));
      degreeSum -= 1;
    }
  }

  function canPair(teamAId, teamBId, cap = pairCap) {
    if (teamAId === teamBId) return false;
    const key = gamePairKey(teamAId, teamBId);
    return (pairCounts.get(key) || 0) < cap;
  }

  function schedulePair(teamAId, teamBId, day) {
    const [homeTeamId, awayTeamId] = pickHomeAway(context, teamAId, teamBId, random);
    const game = {
      id: `g-${context.nextGameId++}`,
      day,
      homeTeamId,
      awayTeamId,
      type: "conference",
      conferenceId: conference.id,
      lockedByUser: false,
      completed: false,
      result: null,
    };

    const didSchedule = addScheduledGame(context, game);
    if (!didSchedule) return false;

    remaining.set(teamAId, (remaining.get(teamAId) || 0) - 1);
    remaining.set(teamBId, (remaining.get(teamBId) || 0) - 1);
    const key = gamePairKey(teamAId, teamBId);
    pairCounts.set(key, (pairCounts.get(key) || 0) + 1);
    return true;
  }

  function unresolvedTeams() {
    return conferenceTeamIds.filter((teamId) => (remaining.get(teamId) || 0) > 0);
  }

  let safety = 0;
  while (unresolvedTeams().length > 0 && safety < 2500) {
    safety += 1;
    let madeProgress = false;

    for (const day of shuffle(dayPool, random)) {
      ensureDay(context, day);
      const available = shuffle(
        conferenceTeamIds
          .filter((teamId) => (remaining.get(teamId) || 0) > 0)
          .filter((teamId) => !context.busyTeamsByDay.get(day).has(teamId))
          .sort((a, b) => (remaining.get(b) || 0) - (remaining.get(a) || 0)),
        random,
      );

      const used = new Set();
      for (let i = 0; i < available.length; i += 1) {
        const teamAId = available[i];
        if (used.has(teamAId)) continue;

        let bestOpponent = null;
        let bestScore = -Infinity;
        for (let j = i + 1; j < available.length; j += 1) {
          const teamBId = available[j];
          if (used.has(teamBId)) continue;
          if (!canPair(teamAId, teamBId)) continue;

          const key = gamePairKey(teamAId, teamBId);
          const pairCount = pairCounts.get(key) || 0;
          const score = (remaining.get(teamBId) || 0) * 2 + (pairCap - pairCount) * 1.5 + random();
          if (score > bestScore) {
            bestScore = score;
            bestOpponent = teamBId;
          }
        }

        if (!bestOpponent) continue;
        if (schedulePair(teamAId, bestOpponent, day)) {
          used.add(teamAId);
          used.add(bestOpponent);
          madeProgress = true;
        }
      }
    }

    if (!madeProgress) break;
  }

  let repairPass = 0;
  while (unresolvedTeams().length && repairPass < 4) {
    repairPass += 1;
    const cap = pairCap + repairPass;
    const teams = shuffle(unresolvedTeams().sort((a, b) => (remaining.get(b) || 0) - (remaining.get(a) || 0)), random);
    let madeProgress = false;

    for (const teamAId of teams) {
      if ((remaining.get(teamAId) || 0) <= 0) continue;
      const opponents = teams
        .filter((teamBId) => teamBId !== teamAId)
        .filter((teamBId) => (remaining.get(teamBId) || 0) > 0)
        .filter((teamBId) => canPair(teamAId, teamBId, cap));

      let scheduled = false;
      for (const teamBId of opponents) {
        let day = selectDayForMatchup(context, dayPool, teamAId, teamBId);
        if (!day) {
          day = Math.max(...dayPool) + 1;
          dayPool.push(day);
        }
        if (schedulePair(teamAId, teamBId, day)) {
          madeProgress = true;
          scheduled = true;
          break;
        }
      }

      if (!scheduled && repairPass === 4) {
        throw new Error(
          `Could not finish conference schedule for ${conference.name}. Remaining: ${teamAId} (${remaining.get(teamAId)}).`,
        );
      }
    }

    if (!madeProgress) break;
  }

  const unresolved = unresolvedTeams();
  if (unresolved.length) {
    throw new Error(`Conference scheduling incomplete for ${conference.name}: ${unresolved.length} unresolved teams.`);
  }
}

function initializeScheduleContext() {
  return {
    nextGameId: 1,
    maxDay: 0,
    busyTeamsByDay: new Map(),
    gamesByDay: new Map(),
    games: [],
    homeGamesByTeam: new Map(),
    awayGamesByTeam: new Map(),
  };
}

function buildScheduleForLeague(league) {
  const teamStateById = league.teams.byId;
  const allTeamIds = Object.keys(teamStateById);

  const nonConferenceTargetByTeam = {};
  for (const teamId of allTeamIds) {
    const teamState = teamStateById[teamId];
    nonConferenceTargetByTeam[teamId] =
      league.settings.totalRegularSeasonGames - league.conferences.byId[teamState.conferenceId].conferenceGamesTarget;
  }

  const totalDesiredGames = allTeamIds.reduce(
    (sum, teamId) => sum + league.settings.totalRegularSeasonGames,
    0,
  );

  if (totalDesiredGames % 2 !== 0) {
    const trimCandidates = allTeamIds.filter((teamId) => teamId !== league.userTeamId);
    const teamToTrim = trimCandidates[0] || allTeamIds[0];
    nonConferenceTargetByTeam[teamToTrim] = Math.max(0, nonConferenceTargetByTeam[teamToTrim] - 1);
    league.metadata.teamWithReducedSchedule = teamToTrim;
  }

  const initialNonConferenceDayCount =
    Math.max(...Object.values(nonConferenceTargetByTeam), 0) + DEFAULT_NON_CONFERENCE_BUFFER_DAYS;
  const maxAttempts = 20;
  let context = null;
  let conferenceStartDay = 0;
  let nonConferenceDaysUsed = 0;
  let lastError = null;

  for (let attempt = 0; attempt < maxAttempts; attempt += 1) {
    try {
      const scheduleSeed = `${league.seed}:schedule:${attempt}`;
      const attemptContext = initializeScheduleContext();
