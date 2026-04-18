      const nonConferenceDayPool = Array.from({ length: initialNonConferenceDayCount }, (_, idx) => idx + 1);

      const lockedGames = getUserLockedGames(league, scheduleSeed);
      const nonConferenceResult = scheduleNonConferenceGames({
        league,
        seedKey: scheduleSeed,
        context: attemptContext,
        teamStateById,
        nonConferenceTargetByTeam,
        dayPool: nonConferenceDayPool,
        lockedGames,
      });

      const attemptConferenceStartDay = nonConferenceResult.nonConferenceDaysUsed + 1;

      for (const conference of league.conferences.list) {
        const conferenceTeamIds = conference.teams.map((team) => team.id);
        const requiredConferenceDays =
          computeConferenceDayCount(conference.teams.length, conference.conferenceGamesTarget) + DEFAULT_CONFERENCE_BUFFER_DAYS;

        const conferenceDayPool = Array.from(
          { length: requiredConferenceDays },
          (_, idx) => attemptConferenceStartDay + idx,
        );

        scheduleConferenceGames({
          league,
          seedKey: scheduleSeed,
          context: attemptContext,
          conference,
          conferenceTeamIds,
          conferenceGamesTarget: conference.conferenceGamesTarget,
          dayPool: conferenceDayPool,
        });
      }

      context = attemptContext;
      conferenceStartDay = attemptConferenceStartDay;
      nonConferenceDaysUsed = nonConferenceResult.nonConferenceDaysUsed;
      lastError = null;
      break;
    } catch (error) {
      lastError = error;
    }
  }

  if (!context) {
    const detail = lastError?.message ? ` Last error: ${lastError.message}` : "";
    throw new Error(`Unable to build a valid full-season schedule after ${maxAttempts} attempts.${detail}`);
  }

  context.games.sort((a, b) => {
    if (a.day !== b.day) return a.day - b.day;
    if (a.homeTeamId !== b.homeTeamId) return a.homeTeamId.localeCompare(b.homeTeamId);
    return a.awayTeamId.localeCompare(b.awayTeamId);
  });

  league.schedule = {
    games: context.games,
    byId: Object.fromEntries(context.games.map((game) => [game.id, game])),
    byDay: Object.fromEntries(
      Array.from(context.gamesByDay.entries())
        .sort((a, b) => a[0] - b[0])
        .map(([day, gameIds]) => [day, gameIds]),
    ),
    totalDays: context.maxDay,
    conferenceStartDay,
    nonConferenceDays: nonConferenceDaysUsed,
  };

  // Validate team game totals.
  for (const teamId of allTeamIds) {
    const allGames = context.games.filter((game) => game.homeTeamId === teamId || game.awayTeamId === teamId);
    const conferenceGames = allGames.filter((game) => game.type === "conference");
    const nonConferenceGames = allGames.filter((game) => game.type === "non_conference");

    teamStateById[teamId].targetConferenceGames = conferenceGames.length;
    teamStateById[teamId].targetNonConferenceGames = nonConferenceGames.length;
    teamStateById[teamId].targetGames = allGames.length;
  }
}

function cloneDeep(value) {
  return JSON.parse(JSON.stringify(value));
}

function cloneTeamForSimulation(teamModel) {
  const cloned = cloneDeep(teamModel);
  if (!Array.isArray(cloned.players) || !Array.isArray(cloned.lineup)) {
    return cloned;
  }

  // Preserve player identity across `players` and `lineup` so box score tracking
  // does not treat lineup copies as extra roster members.
  const byIdentity = new Map();
  cloned.players.forEach((player) => {
    const identity = `${player?.bio?.name || "unknown"}|${player?.bio?.position || ""}`;
    if (!byIdentity.has(identity)) byIdentity.set(identity, player);
  });

  cloned.lineup = cloned.lineup.map((lineupPlayer) => {
    const identity = `${lineupPlayer?.bio?.name || "unknown"}|${lineupPlayer?.bio?.position || ""}`;
    return byIdentity.get(identity) || lineupPlayer;
  });

  return cloned;
}

function quickSimGame(homeTeamState, awayTeamState, random = Math.random) {
  const homeStrength = homeTeamState.overall;
  const awayStrength = awayTeamState.overall;

  const homeMean = 68 + (homeStrength - awayStrength) * 0.52 + 2.1;
  const awayMean = 68 + (awayStrength - homeStrength) * 0.52 - 2.1;

  let homeScore = Math.round(homeMean + normalRandom(random) * 10.5);
  let awayScore = Math.round(awayMean + normalRandom(random) * 10.5);
  homeScore = clamp(homeScore, 42, 121);
  awayScore = clamp(awayScore, 42, 121);

  if (homeScore === awayScore) {
    if (random() < 0.5) homeScore += 1;
    else awayScore += 1;
  }

  return {
    homeScore,
    awayScore,
    winnerTeamId: homeScore > awayScore ? homeTeamState.id : awayTeamState.id,
    quickSim: true,
  };
}

function applyCompletedGameResult(league, game, result) {
  game.completed = true;
  game.result = result;

  const homeTeam = league.teams.byId[game.homeTeamId];
  const awayTeam = league.teams.byId[game.awayTeamId];

  const homeWon = result.homeScore > result.awayScore;

  homeTeam.record.games += 1;
  awayTeam.record.games += 1;
  homeTeam.record.pointsFor += result.homeScore;
  homeTeam.record.pointsAgainst += result.awayScore;
  awayTeam.record.pointsFor += result.awayScore;
  awayTeam.record.pointsAgainst += result.homeScore;

  if (homeWon) {
    homeTeam.record.wins += 1;
    awayTeam.record.losses += 1;
  } else {
    awayTeam.record.wins += 1;
    homeTeam.record.losses += 1;
  }

  if (game.type === "conference") {
    if (homeWon) {
      homeTeam.record.conferenceWins += 1;
      awayTeam.record.conferenceLosses += 1;
    } else {
      awayTeam.record.conferenceWins += 1;
      homeTeam.record.conferenceLosses += 1;
    }
  }

  if (game.homeTeamId === league.userTeamId || game.awayTeamId === league.userTeamId) {
    league.userGameHistory.push({
      gameId: game.id,
      day: game.day,
      opponentTeamId: game.homeTeamId === league.userTeamId ? game.awayTeamId : game.homeTeamId,
      isHome: game.homeTeamId === league.userTeamId,
      result,
    });
  }
}

function simulateScheduledGame(league, game, options = {}) {
  const seed = hashString(`${league.seed}:${game.id}`);
  const random = createSeededRandom(seed);

  const homeTeamState = league.teams.byId[game.homeTeamId];
  const awayTeamState = league.teams.byId[game.awayTeamId];
  const userInvolved = game.homeTeamId === league.userTeamId || game.awayTeamId === league.userTeamId;
  const useDetailedEngine = userInvolved || options.simulateCpuWithDetailedEngine === true;

  if (!useDetailedEngine) {
    return quickSimGame(homeTeamState, awayTeamState, random);
  }

  const homeTeamClone = cloneTeamForSimulation(homeTeamState.teamModel);
  const awayTeamClone = cloneTeamForSimulation(awayTeamState.teamModel);

  const detailedResult = simulateGame(homeTeamClone, awayTeamClone, { random });
  const winnerTeamId =
    detailedResult.home.score > detailedResult.away.score
      ? game.homeTeamId
      : detailedResult.away.score > detailedResult.home.score
        ? game.awayTeamId
        : null;

  const includeDetailedArtifacts = userInvolved;

  return {
    homeScore: detailedResult.home.score,
    awayScore: detailedResult.away.score,
    winnerTeamId,
    quickSim: false,
    wentToOvertime: detailedResult.playByPlay.some((event) => event.type === "overtime_start"),
    ...(includeDetailedArtifacts
      ? {
          boxScore: detailedResult.boxScore,
          playByPlay: detailedResult.playByPlay,
        }
      : {}),
  };
}

function simulateThroughDay(league, targetDay, options = {}) {
  if (!league.schedule || !league.schedule.games.length) {
    throw new Error("No season schedule found. Run generateSeasonSchedule(...) first.");
  }

  const gamesToSimulate = league.schedule.games.filter((game) => !game.completed && game.day <= targetDay);
  for (const game of gamesToSimulate) {
    const result = simulateScheduledGame(league, game, options);
    applyCompletedGameResult(league, game, result);
  }

  league.currentDay = Math.max(league.currentDay, targetDay);
}

function buildConferenceStandings(league, conferenceId) {
  const conference = league.conferences.byId[conferenceId];
  if (!conference) return [];

  return conference.teams
    .map((team) => {
      const teamState = league.teams.byId[team.id];
      return {
        teamId: teamState.id,
        teamName: teamState.name,
        conferenceId: teamState.conferenceId,
        overall: `${teamState.record.wins}-${teamState.record.losses}`,
        conference: `${teamState.record.conferenceWins}-${teamState.record.conferenceLosses}`,
        wins: teamState.record.wins,
        losses: teamState.record.losses,
        conferenceWins: teamState.record.conferenceWins,
        conferenceLosses: teamState.record.conferenceLosses,
        pointsFor: teamState.record.pointsFor,
        pointsAgainst: teamState.record.pointsAgainst,
      };
    })
    .sort((a, b) => {
      if (a.conferenceWins !== b.conferenceWins) return b.conferenceWins - a.conferenceWins;
      if (a.conferenceLosses !== b.conferenceLosses) return a.conferenceLosses - b.conferenceLosses;
      const aDiff = a.pointsFor - a.pointsAgainst;
      const bDiff = b.pointsFor - b.pointsAgainst;
      if (aDiff !== bDiff) return bDiff - aDiff;
      return a.teamName.localeCompare(b.teamName);
    });
}

function createTeamState({ teamId, teamName, conferenceId, teamModel, overall }) {
  return {
    id: teamId,
    name: teamName,
    conferenceId,
    teamModel,
    overall,
    record: {
      games: 0,
      wins: 0,
      losses: 0,
      conferenceWins: 0,
      conferenceLosses: 0,
      pointsFor: 0,
      pointsAgainst: 0,
    },
    targetGames: 0,
    targetConferenceGames: 0,
    targetNonConferenceGames: 0,
  };
}

function buildLeagueCatalog(totalGames = DEFAULT_TOTAL_REGULAR_SEASON_GAMES) {
  return buildConferenceCatalogFromSnapshot(d1Snapshot, totalGames);
}

function createD1League(options = {}) {
  const totalRegularSeasonGames =
    Number.isFinite(Number(options.totalRegularSeasonGames)) && Number(options.totalRegularSeasonGames) > 0
      ? Math.round(Number(options.totalRegularSeasonGames))
      : DEFAULT_TOTAL_REGULAR_SEASON_GAMES;

  const catalog = buildLeagueCatalog(totalRegularSeasonGames);
  const seed = options.seed || `${Date.now()}`;

  const conferencesById = {};
  const conferences = catalog.conferences.map((conference) => {
    const normalizedConference = {
      ...conference,
      teams: conference.teams.map((team) => ({ ...team })),
    };
    conferencesById[normalizedConference.id] = normalizedConference;
    return normalizedConference;
  });

  const teamStateById = {};
  const allTeams = [];

  for (const conference of conferences) {
    for (const team of conference.teams) {
      const rosterBundle = createProgramRoster({
        teamName: team.name,
        conferenceId: conference.id,
        seed,
      });

      const teamState = createTeamState({
        teamId: team.id,
        teamName: team.name,
        conferenceId: conference.id,
        teamModel: rosterBundle.team,
        overall: rosterBundle.overall,
      });

      teamStateById[team.id] = teamState;
      allTeams.push({
        id: team.id,
        name: team.name,
        conferenceId: conference.id,
        overall: teamState.overall,
      });
    }
  }

  const userTeamCanonical = canonicalName(options.userTeamName || "");
  const explicitUserTeamId = options.userTeamId || null;

  let userTeamId = explicitUserTeamId;
  if (!userTeamId && userTeamCanonical) {
    const byName = allTeams.find((team) => canonicalName(team.name) === userTeamCanonical);
    if (byName) userTeamId = byName.id;
  }

  if (!userTeamId || !teamStateById[userTeamId]) {
    throw new Error(
      "Unable to determine user team. Pass a valid `userTeamId` or exact `userTeamName` that exists in D1 data.",
    );
  }

  const userTeamState = teamStateById[userTeamId];
  const userConference = conferencesById[userTeamState.conferenceId];
  const userNonConferenceTarget = totalRegularSeasonGames - userConference.conferenceGamesTarget;

  return {
    version: 1,
    seed,
    source: catalog.source,
    status: "preseason_nonconference",
    settings: {
      totalRegularSeasonGames,
      nonConferenceDayCount: userNonConferenceTarget,
    },
    metadata: {
      teamWithReducedSchedule: null,
    },
    currentDay: 0,
    userTeamId,
    userPreseason: {
      requiredNonConferenceGames: userNonConferenceTarget,
      nonConferenceOpponentIds: [],
    },
    conferences: {
      list: conferences,
      byId: conferencesById,
    },
    teams: {
      list: allTeams,
      byId: teamStateById,
    },
    schedule: null,
    userGameHistory: [],
  };
}

function listUserNonConferenceOptions(league) {
  const userTeamState = league.teams.byId[league.userTeamId];
  const selected = new Set(league.userPreseason.nonConferenceOpponentIds);
  return league.teams.list
    .filter((team) => team.id !== league.userTeamId)
    .filter((team) => team.conferenceId !== userTeamState.conferenceId)
    .map((team) => ({
      teamId: team.id,
      teamName: team.name,
      conferenceId: team.conferenceId,
      conferenceName: league.conferences.byId[team.conferenceId].name,
      overall: team.overall,
      selected: selected.has(team.id),
    }))
    .sort((a, b) => {
      if (a.overall !== b.overall) return b.overall - a.overall;
      return a.teamName.localeCompare(b.teamName);
    });
}

function validateUserNonConferenceSelection(league, opponentIds) {
  const uniqueOpponentIds = unique(opponentIds || []);
  const requiredCount = league.userPreseason.requiredNonConferenceGames;
  const userConferenceId = league.teams.byId[league.userTeamId].conferenceId;

  if (uniqueOpponentIds.length > requiredCount) {
    throw new Error(`You selected ${uniqueOpponentIds.length} opponents but only ${requiredCount} are allowed.`);
  }

  for (const opponentId of uniqueOpponentIds) {
    const team = league.teams.byId[opponentId];
    if (!team) throw new Error(`Unknown team id in selection: ${opponentId}`);
    if (team.id === league.userTeamId) throw new Error("User team cannot schedule itself.");
    if (team.conferenceId === userConferenceId) {
      throw new Error(`Opponent ${team.name} is in your conference; choose a non-conference opponent.`);
    }
  }

  return uniqueOpponentIds;
}

function setUserNonConferenceOpponents(league, opponentIds) {
  if (league.status !== "preseason_nonconference") {
    throw new Error("Non-conference selection is only available before schedule generation.");
  }

  const validatedOpponentIds = validateUserNonConferenceSelection(league, opponentIds);
  league.userPreseason.nonConferenceOpponentIds = validatedOpponentIds;

  return {
    selectedCount: validatedOpponentIds.length,
    requiredCount: league.userPreseason.requiredNonConferenceGames,
    complete: validatedOpponentIds.length === league.userPreseason.requiredNonConferenceGames,
  };
}

function autoFillUserNonConferenceOpponents(league) {
  if (league.status !== "preseason_nonconference") {
    throw new Error("Cannot auto-fill opponents after the season starts.");
  }

  const required = league.userPreseason.requiredNonConferenceGames;
