  const selected = new Set(league.userPreseason.nonConferenceOpponentIds);
  const options = listUserNonConferenceOptions(league)
    .filter((option) => !selected.has(option.teamId))
    .sort((a, b) => {
      if (a.overall !== b.overall) return b.overall - a.overall;
      return a.teamName.localeCompare(b.teamName);
    });

  for (const option of options) {
    if (selected.size >= required) break;
    selected.add(option.teamId);
  }

  if (selected.size < required) {
    throw new Error(
      `Could not auto-fill enough opponents. Needed ${required} but only found ${selected.size}.`,
    );
  }

  league.userPreseason.nonConferenceOpponentIds = [...selected];
  return league.userPreseason.nonConferenceOpponentIds;
}

function getPreseasonSchedulingBoard(league, options = {}) {
  if (league.status !== "preseason_nonconference") {
    throw new Error("Preseason scheduling board is only available before schedule generation.");
  }

  const pageSize = clamp(Math.round(asNumber(options.pageSize, DEFAULT_PRESEASON_BOARD_PAGE_SIZE)), 5, 100);
  const requestedPage = Math.max(1, Math.round(asNumber(options.page, 1)));
  const search = String(options.search || "")
    .trim()
    .toLowerCase();

  const filteredOptions = listUserNonConferenceOptions(league).filter((option) => {
    if (!search) return true;
    return (
      option.teamName.toLowerCase().includes(search) ||
      option.teamId.toLowerCase().includes(search) ||
      option.conferenceName.toLowerCase().includes(search)
    );
  });

  const totalPages = Math.max(1, Math.ceil(filteredOptions.length / pageSize));
  const page = clamp(requestedPage, 1, totalPages);
  const startIndex = (page - 1) * pageSize;
  const selectedIds = unique(league.userPreseason.nonConferenceOpponentIds);

  const selectedOpponents = selectedIds
    .map((teamId) => {
      const team = league.teams.byId[teamId];
      if (!team) return null;
      const conference = league.conferences.byId[team.conferenceId];
      return {
        teamId: team.id,
        teamName: team.name,
        conferenceId: team.conferenceId,
        conferenceName: conference?.name || "Unknown",
        overall: team.overall,
      };
    })
    .filter(Boolean);

  return {
    page,
    pageSize,
    totalPages,
    search,
    totalOptions: filteredOptions.length,
    requiredCount: league.userPreseason.requiredNonConferenceGames,
    selectedCount: selectedOpponents.length,
    remainingCount: Math.max(0, league.userPreseason.requiredNonConferenceGames - selectedOpponents.length),
    selectedOpponents,
    options: filteredOptions.slice(startIndex, startIndex + pageSize).map((option, index) => ({
      ...option,
      displayIndex: index + 1,
      absoluteIndex: startIndex + index + 1,
    })),
  };
}

function generateSeasonSchedule(league) {
  if (league.status !== "preseason_nonconference") {
    throw new Error("Season schedule already generated.");
  }

  if (league.userPreseason.nonConferenceOpponentIds.length < league.userPreseason.requiredNonConferenceGames) {
    autoFillUserNonConferenceOpponents(league);
  }

  buildScheduleForLeague(league);
  league.status = "in_season";
  return {
    totalGames: league.schedule.games.length,
    totalDays: league.schedule.totalDays,
    conferenceStartDay: league.schedule.conferenceStartDay,
  };
}

function getUserSchedule(league) {
  if (!league.schedule) return [];
  const userTeamId = league.userTeamId;
  return league.schedule.games
    .filter((game) => game.homeTeamId === userTeamId || game.awayTeamId === userTeamId)
    .map((game) => {
      const opponentTeamId = game.homeTeamId === userTeamId ? game.awayTeamId : game.homeTeamId;
      const opponent = league.teams.byId[opponentTeamId];
      return {
        gameId: game.id,
        day: game.day,
        type: game.type,
        isHome: game.homeTeamId === userTeamId,
        opponentTeamId,
        opponentName: opponent.name,
        completed: game.completed,
        result: game.result,
      };
    })
    .sort((a, b) => a.day - b.day);
}

function advanceToNextUserGame(league, options = {}) {
  if (league.status === "preseason_nonconference") {
    generateSeasonSchedule(league);
  }

  const userSchedule = getUserSchedule(league);
  const pending = userSchedule.find((game) => !game.completed);
  if (!pending) {
    return { done: true, message: "Season complete for user team." };
  }

  simulateThroughDay(league, pending.day, options);

  const game = league.schedule.byId[pending.gameId];
  const opponentTeamId = game.homeTeamId === league.userTeamId ? game.awayTeamId : game.homeTeamId;
  const opponent = league.teams.byId[opponentTeamId];
  const userIsHome = game.homeTeamId === league.userTeamId;

  const userScore = userIsHome ? game.result.homeScore : game.result.awayScore;
  const opponentScore = userIsHome ? game.result.awayScore : game.result.homeScore;

  return {
    done: false,
    day: game.day,
    gameId: game.id,
    opponentTeamId,
    opponentName: opponent.name,
    isHome: userIsHome,
    score: {
      user: userScore,
      opponent: opponentScore,
    },
    won: userScore > opponentScore,
    result: game.result,
    record: {
      ...league.teams.byId[league.userTeamId].record,
    },
  };
}

function getUserCompletedGames(league) {
  return league.userGameHistory
    .map((entry) => {
      const opponent = league.teams.byId[entry.opponentTeamId];
      const userScore = entry.isHome ? entry.result.homeScore : entry.result.awayScore;
      const opponentScore = entry.isHome ? entry.result.awayScore : entry.result.homeScore;
      return {
        ...entry,
        opponentName: opponent.name,
        userScore,
        opponentScore,
        won: userScore > opponentScore,
      };
    })
    .sort((a, b) => a.day - b.day);
}

function getConferenceStandings(league, conferenceId) {
  return buildConferenceStandings(league, conferenceId);
}

function sanitizeSelectionForLoadedLeague(league, rawSelection, requiredCount) {
  const selection = unique(Array.isArray(rawSelection) ? rawSelection : []);
  const userTeam = league.teams.byId[league.userTeamId];
  if (!userTeam) return [];

  const filtered = selection.filter((opponentId) => {
    const opponent = league.teams.byId[opponentId];
    if (!opponent) return false;
    if (opponent.id === league.userTeamId) return false;
    return opponent.conferenceId !== userTeam.conferenceId;
  });

  return filtered.slice(0, Math.max(0, Math.round(asNumber(requiredCount, filtered.length))));
}

function deriveRequiredUserNonConferenceGames(league) {
  const userTeam = league?.teams?.byId?.[league?.userTeamId];
  const conference = userTeam ? league?.conferences?.byId?.[userTeam.conferenceId] : null;
  const conferenceTeamCount = Array.isArray(conference?.teams) ? conference.teams.length : 10;

  const conferenceGamesTarget = normalizeConferenceGamesTarget(
    conference?.conferenceGamesTarget,
    conferenceTeamCount,
    asNumber(league?.settings?.totalRegularSeasonGames, DEFAULT_TOTAL_REGULAR_SEASON_GAMES),
  );
  const totalRegularSeasonGames = Math.max(
    conferenceGamesTarget,
    Math.round(asNumber(league?.settings?.totalRegularSeasonGames, conferenceGamesTarget + 11)),
  );
  return Math.max(0, totalRegularSeasonGames - conferenceGamesTarget);
}

function normalizeTeamRecord(rawRecord = {}) {
  return {
    games: Math.max(0, Math.round(asNumber(rawRecord.games, 0))),
    wins: Math.max(0, Math.round(asNumber(rawRecord.wins, 0))),
    losses: Math.max(0, Math.round(asNumber(rawRecord.losses, 0))),
    conferenceWins: Math.max(0, Math.round(asNumber(rawRecord.conferenceWins, 0))),
    conferenceLosses: Math.max(0, Math.round(asNumber(rawRecord.conferenceLosses, 0))),
    pointsFor: Math.max(0, Math.round(asNumber(rawRecord.pointsFor, 0))),
    pointsAgainst: Math.max(0, Math.round(asNumber(rawRecord.pointsAgainst, 0))),
  };
}

function normalizeScheduleState(rawSchedule) {
  if (!rawSchedule || !Array.isArray(rawSchedule.games)) return null;

  const games = rawSchedule.games
    .map((game) => ({
      ...game,
      day: Math.max(1, Math.round(asNumber(game.day, 1))),
      completed: Boolean(game.completed),
      result: game.result || null,
    }))
    .sort((a, b) => {
      if (a.day !== b.day) return a.day - b.day;
      if (a.homeTeamId !== b.homeTeamId) return String(a.homeTeamId).localeCompare(String(b.homeTeamId));
      return String(a.awayTeamId).localeCompare(String(b.awayTeamId));
    });

  const byDay = {};
  let totalDays = 0;
  games.forEach((game) => {
    if (!byDay[game.day]) byDay[game.day] = [];
    byDay[game.day].push(game.id);
    totalDays = Math.max(totalDays, game.day);
  });

  return {
    games,
    byId: Object.fromEntries(games.map((game) => [game.id, game])),
    byDay,
    totalDays: Math.max(totalDays, Math.round(asNumber(rawSchedule.totalDays, totalDays))),
    conferenceStartDay: Math.max(1, Math.round(asNumber(rawSchedule.conferenceStartDay, 1))),
    nonConferenceDays: Math.max(0, Math.round(asNumber(rawSchedule.nonConferenceDays, 0))),
  };
}

function hydrateLoadedLeagueState(rawLeague) {
  const league = cloneDeep(rawLeague);
  if (!league || typeof league !== "object") {
    throw new Error("Loaded state is not a valid league object.");
  }

  if (!league.teams || typeof league.teams !== "object" || !league.teams.byId || typeof league.teams.byId !== "object") {
    throw new Error("Loaded state is missing `teams.byId`.");
  }
  if (
    !league.conferences ||
    typeof league.conferences !== "object" ||
    !league.conferences.byId ||
    typeof league.conferences.byId !== "object"
  ) {
    throw new Error("Loaded state is missing `conferences.byId`.");
  }
  if (!league.userTeamId || !league.teams.byId[league.userTeamId]) {
    throw new Error("Loaded state has an invalid `userTeamId`.");
  }

  const conferenceList =
    Array.isArray(league.conferences.list) && league.conferences.list.length
      ? league.conferences.list
      : Object.values(league.conferences.byId);
  league.conferences.list = conferenceList.map((conference) => ({
    ...conference,
    teams: Array.isArray(conference.teams) ? conference.teams.map((team) => ({ ...team })) : [],
  }));
  league.conferences.byId = Object.fromEntries(league.conferences.list.map((conference) => [conference.id, conference]));

  const teamStateById = {};
  Object.entries(league.teams.byId).forEach(([teamId, teamState]) => {
    if (!teamState || typeof teamState !== "object") return;
    if (!teamState.teamModel || !Array.isArray(teamState.teamModel.players)) {
      throw new Error(`Loaded team ${teamId} is missing a valid team model.`);
    }

    teamStateById[teamId] = {
      ...teamState,
      id: teamState.id || teamId,
      record: normalizeTeamRecord(teamState.record),
      targetGames: Math.max(0, Math.round(asNumber(teamState.targetGames, 0))),
      targetConferenceGames: Math.max(0, Math.round(asNumber(teamState.targetConferenceGames, 0))),
      targetNonConferenceGames: Math.max(0, Math.round(asNumber(teamState.targetNonConferenceGames, 0))),
      overall: Math.round(asNumber(teamState.overall, estimateTeamOverall(teamState.teamModel.players))),
    };
  });
  league.teams.byId = teamStateById;

  const teamList =
    Array.isArray(league.teams.list) && league.teams.list.length
      ? league.teams.list
      : Object.values(teamStateById).map((teamState) => ({
          id: teamState.id,
          name: teamState.name,
          conferenceId: teamState.conferenceId,
          overall: teamState.overall,
        }));
  league.teams.list = teamList
    .filter((team) => team && team.id && teamStateById[team.id])
    .map((team) => ({
      id: team.id,
      name: teamStateById[team.id].name,
      conferenceId: teamStateById[team.id].conferenceId,
      overall: teamStateById[team.id].overall,
    }));

  league.version = Math.round(asNumber(league.version, 1));
  league.seed = String(league.seed || `${Date.now()}`);
  league.status = typeof league.status === "string" ? league.status : "preseason_nonconference";
  league.currentDay = Math.max(0, Math.round(asNumber(league.currentDay, 0)));
  league.metadata = typeof league.metadata === "object" && league.metadata ? league.metadata : {};
  if (!Object.prototype.hasOwnProperty.call(league.metadata, "teamWithReducedSchedule")) {
    league.metadata.teamWithReducedSchedule = null;
  }
  league.userGameHistory = Array.isArray(league.userGameHistory) ? league.userGameHistory : [];

  const requiredNonConferenceGames = deriveRequiredUserNonConferenceGames(league);
  const totalRegularSeasonGames = Math.max(
    requiredNonConferenceGames,
    Math.round(asNumber(league.settings?.totalRegularSeasonGames, requiredNonConferenceGames + 20)),
  );
  league.settings = {
    totalRegularSeasonGames,
    nonConferenceDayCount: Math.max(
      1,
      Math.round(asNumber(league.settings?.nonConferenceDayCount, requiredNonConferenceGames || 1)),
    ),
  };

  const rawSelection = league.userPreseason?.nonConferenceOpponentIds;
  league.userPreseason = {
    requiredNonConferenceGames,
    nonConferenceOpponentIds: sanitizeSelectionForLoadedLeague(league, rawSelection, requiredNonConferenceGames),
  };

  league.schedule = normalizeScheduleState(league.schedule);
  if (league.schedule?.totalDays) {
    league.currentDay = Math.min(league.currentDay, league.schedule.totalDays);
  } else {
    league.currentDay = 0;
  }

  return league;
}

function saveLeagueState(league, destinationPath, options = {}) {
  if (!destinationPath || typeof destinationPath !== "string") {
    throw new Error("A destination path is required when saving league state.");
  }

  const filePath = path.resolve(destinationPath);
  const payload = {
    format: LEAGUE_SAVE_FORMAT,
    version: LEAGUE_SAVE_VERSION,
    savedAt: new Date().toISOString(),
    league: cloneDeep(league),
  };
  const spacing = options.pretty === false ? undefined : 2;
  const serialized = `${JSON.stringify(payload, null, spacing)}\n`;
  fs.mkdirSync(path.dirname(filePath), { recursive: true });
  fs.writeFileSync(filePath, serialized, "utf8");

  return {
    filePath,
    bytes: Buffer.byteLength(serialized, "utf8"),
    format: payload.format,
    version: payload.version,
    savedAt: payload.savedAt,
  };
}

function loadLeagueState(sourcePath) {
  if (!sourcePath || typeof sourcePath !== "string") {
    throw new Error("A source path is required when loading league state.");
  }

  const filePath = path.resolve(sourcePath);
  const rawText = fs.readFileSync(filePath, "utf8");
  let parsed;
  try {
    parsed = JSON.parse(rawText);
  } catch (error) {
    throw new Error(`Failed to parse league state JSON from ${filePath}: ${error.message}`);
  }

  const payload = parsed && parsed.format === LEAGUE_SAVE_FORMAT ? parsed : { league: parsed };
  if (!payload.league) {
    throw new Error(`No league payload found in ${filePath}.`);
  }

  return hydrateLoadedLeagueState(payload.league);
}

function getLeagueSummary(league) {
  return {
    status: league.status,
    currentDay: league.currentDay,
    totalTeams: league.teams.list.length,
    totalConferences: league.conferences.list.length,
    userTeamId: league.userTeamId,
    userTeamName: league.teams.byId[league.userTeamId].name,
    requiredUserNonConferenceGames: league.userPreseason.requiredNonConferenceGames,
    userSelectedNonConferenceGames: league.userPreseason.nonConferenceOpponentIds.length,
    scheduleGenerated: Boolean(league.schedule),
    totalScheduledGames: league.schedule?.games?.length || 0,
  };
}

module.exports = {
  DEFAULT_TOTAL_REGULAR_SEASON_GAMES,
  LEAGUE_SAVE_FORMAT,
  LEAGUE_SAVE_VERSION,
  buildLeagueCatalog,
  createD1League,
  listUserNonConferenceOptions,
  getPreseasonSchedulingBoard,
  setUserNonConferenceOpponents,
  autoFillUserNonConferenceOpponents,
  generateSeasonSchedule,
  getUserSchedule,
  advanceToNextUserGame,
  getUserCompletedGames,
  getConferenceStandings,
  getLeagueSummary,
  saveLeagueState,
  loadLeagueState,
};
