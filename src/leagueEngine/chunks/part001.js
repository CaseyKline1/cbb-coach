const fs = require("fs");
const path = require("path");
const d1Snapshot = require("./data/d1-conferences.2026.json");
const { createPlayer } = require("./player");
const {
  createTeam,
  simulateGame,
  OffensiveFormation,
  DefenseScheme,
  PaceProfile,
} = require("./gameEngine");

const DEFAULT_TOTAL_REGULAR_SEASON_GAMES = 31;
const DEFAULT_NON_CONFERENCE_BUFFER_DAYS = 1;
const DEFAULT_CONFERENCE_BUFFER_DAYS = 2;
const LEAGUE_SAVE_FORMAT = "cbb-coach.league-state";
const LEAGUE_SAVE_VERSION = 1;
const DEFAULT_PRESEASON_BOARD_PAGE_SIZE = 20;

const DEFAULT_COLLEGE_CONFERENCE_IDS = Object.freeze([
  "acc",
  "sec",
  "big-ten",
  "big-12",
  "big-east",
]);

const TEAM_OVR_CONFERENCE_BONUS = Object.freeze({
  acc: 7,
  "big-12": 7,
  "big-ten": 7,
  "big-east": 6,
  sec: 6,
});

const TEAM_PRESTIGE_RECENT_BY_CONFERENCE = Object.freeze({
  acc: 76,
  sec: 76,
  "big-ten": 75,
  "big-12": 77,
  "big-east": 73,
  "american-athletic": 66,
  mwc: 66,
  "atlantic-10": 64,
  "west-coast": 63,
  mvc: 60,
});

const TEAM_PRESTIGE_HISTORICAL_BY_NAME = Object.freeze({
  arizona: 90,
  arkansas: 83,
  baylor: 80,
  cincinnati: 78,
  connecticut: 95,
  creighton: 72,
  dayton: 70,
  duke: 99,
  florida: 86,
  georgetown: 85,
  gonzaga: 84,
  houston: 83,
  illinois: 79,
  indiana: 95,
  iowa: 70,
  iowastate: 73,
  kansas: 99,
  kansasstate: 76,
  kentucky: 99,
  louisville: 91,
  maryland: 83,
  memphis: 80,
  michigan: 88,
  michiganstate: 91,
  ncstate: 83,
  northcarolina: 99,
  notredame: 70,
  ohiostate: 84,
  oklahoma: 76,
  oregon: 72,
  providence: 71,
  purdue: 86,
  saintjohns: 78,
  sandiegostate: 70,
  setonhall: 73,
  syracuse: 88,
  tennessee: 77,
  texas: 84,
  texasam: 74,
  ucla: 99,
  usc: 79,
  villanova: 93,
  virginia: 82,
  wakeforest: 76,
  westvirginia: 77,
  wisconsin: 80,
  xavier: 76,
});

const TEAM_PRESTIGE_RECENT_BY_NAME = Object.freeze({
  alabama: 89,
  arizona: 88,
  auburn: 86,
  baylor: 90,
  creighton: 82,
  duke: 95,
  floridaatlantic: 79,
  gonzaga: 92,
  houston: 96,
  illinois: 83,
  iowastate: 87,
  kansas: 94,
  kentucky: 87,
  marquette: 86,
  michiganstate: 84,
  northcarolina: 92,
  purdue: 95,
  saintmarys: 82,
  sandiegostate: 83,
  tennessee: 89,
  texasam: 80,
  texastech: 82,
  ucla: 78,
  uconn: 96,
  connecticut: 96,
  villanova: 76,
  virginia: 79,
  wisconsin: 78,
});

const POSITION_TEMPLATE = Object.freeze(["PG", "SG", "SF", "PF", "C", "CG", "Wing", "F", "Big", "PG"]);
const ROTATION_SLOTS = Object.freeze(["PG", "SG", "SF", "PF", "C"]);

const POSITION_OFFSETS = Object.freeze({
  PG: { shooting: 1, passing: 10, defendingPerimeter: 5, rebounding: -6, inside: -4 },
  SG: { shooting: 6, passing: 2, defendingPerimeter: 4, rebounding: -3, inside: -2 },
  SF: { shooting: 3, passing: 1, defendingPerimeter: 3, rebounding: 2, inside: 1 },
  PF: { shooting: -1, passing: -2, defendingPerimeter: -1, rebounding: 7, inside: 7 },
  C: { shooting: -4, passing: -5, defendingPerimeter: -5, rebounding: 10, inside: 10 },
  CG: { shooting: 4, passing: 7, defendingPerimeter: 4, rebounding: -4, inside: -2 },
  Wing: { shooting: 5, passing: 1, defendingPerimeter: 5, rebounding: 1, inside: -1 },
  F: { shooting: 0, passing: -1, defendingPerimeter: 1, rebounding: 5, inside: 5 },
  Big: { shooting: -3, passing: -3, defendingPerimeter: -4, rebounding: 9, inside: 9 },
});

const FIRST_NAME_POOL = Object.freeze([
  "Jalen", "Marcus", "Eli", "Noah", "Ty", "Jordan", "Malik", "Darius", "Caleb", "Cameron",
  "Xavier", "Aiden", "Isaiah", "Liam", "Mason", "Jayden", "Trent", "Damon", "Riley", "Kaden",
]);

const LAST_NAME_POOL = Object.freeze([
  "Carter", "Brooks", "Davis", "Coleman", "Thomas", "Hill", "Moore", "Young", "Turner", "Jenkins",
  "Mitchell", "Hayes", "Washington", "Edwards", "Jackson", "Powell", "Bennett", "Foster", "Reed", "Bailey",
]);

function clamp(value, min, max) {
  return Math.max(min, Math.min(max, value));
}

function asNumber(value, fallback = 0) {
  const numeric = Number(value);
  return Number.isFinite(numeric) ? numeric : fallback;
}

function hashString(input) {
  let h = 2166136261;
  for (let i = 0; i < input.length; i += 1) {
    h ^= input.charCodeAt(i);
    h = Math.imul(h, 16777619);
  }
  return h >>> 0;
}

function createSeededRandom(seed) {
  let state = (typeof seed === "number" ? seed : hashString(String(seed))) >>> 0;
  return () => {
    state = (1664525 * state + 1013904223) >>> 0;
    return state / 4294967296;
  };
}

function normalRandom(random = Math.random) {
  let u = 0;
  let v = 0;
  while (u === 0) u = random();
  while (v === 0) v = random();
  return Math.sqrt(-2 * Math.log(u)) * Math.cos(2 * Math.PI * v);
}

function shuffle(values, random = Math.random) {
  const copy = values.slice();
  for (let i = copy.length - 1; i > 0; i -= 1) {
    const j = Math.floor(random() * (i + 1));
    [copy[i], copy[j]] = [copy[j], copy[i]];
  }
  return copy;
}

function unique(values) {
  return [...new Set(values)];
}

function decodeHtmlEntities(value) {
  if (typeof value !== "string") return value;
  return value
    .replace(/&#0*39;/g, "'")
    .replace(/&quot;/g, '"')
    .replace(/&amp;/g, "&")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&nbsp;/g, " ");
}

function slugify(value) {
  return String(value)
    .toLowerCase()
    .replace(/&/g, " and ")
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "");
}

function canonicalName(value) {
  return decodeHtmlEntities(String(value || ""))
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "")
    .trim();
}

function getDeterministicJitter(seedKey, spread) {
  const width = Math.max(0, Math.round(asNumber(spread, 0)));
  if (width <= 0) return 0;
  const bucketCount = width * 2 + 1;
  return (hashString(seedKey) % bucketCount) - width;
}

function estimateHistoricalProgramPrestige(teamName) {
  const key = canonicalName(teamName);
  if (Object.prototype.hasOwnProperty.call(TEAM_PRESTIGE_HISTORICAL_BY_NAME, key)) {
    return TEAM_PRESTIGE_HISTORICAL_BY_NAME[key];
  }
  const baseline = 43;
  return clamp(baseline + getDeterministicJitter(`historical:${key}`, 12), 20, 82);
}

function estimateRecentProgramPrestige(teamName, conferenceId) {
  const key = canonicalName(teamName);
  if (Object.prototype.hasOwnProperty.call(TEAM_PRESTIGE_RECENT_BY_NAME, key)) {
    return TEAM_PRESTIGE_RECENT_BY_NAME[key];
  }
  const conferenceBase = asNumber(TEAM_PRESTIGE_RECENT_BY_CONFERENCE[conferenceId], 60);
  return clamp(conferenceBase + getDeterministicJitter(`recent:${conferenceId}:${key}`, 9), 25, 96);
}

function computeTeamPrestige(teamName, conferenceId) {
  const historical = estimateHistoricalProgramPrestige(teamName);
  const recent = estimateRecentProgramPrestige(teamName, conferenceId);
  return clamp(Math.round(historical * 0.7 + recent * 0.3), 1, 99);
}

function randomInt(min, maxInclusive, random = Math.random) {
  return Math.floor(random() * (maxInclusive - min + 1)) + min;
}

function getDefaultConferenceGamesTarget(teamCount) {
  if (teamCount <= 8) return 14;
  if (teamCount <= 10) return 18;
  return 20;
}

function normalizeConferenceGamesTarget(rawTarget, teamCount, totalGames) {
  const fallback = getDefaultConferenceGamesTarget(teamCount);
  const parsed = Number.isFinite(Number(rawTarget)) ? Math.round(Number(rawTarget)) : fallback;
  const minByConvention = 12;
  const maxByConvention = Math.min(24, Math.max(12, totalGames - 8));
  const maxByOpponentPool = Math.max(1, (teamCount - 1) * 3);
  return clamp(parsed, minByConvention, Math.min(maxByConvention, maxByOpponentPool));
}

function buildConferenceCatalogFromSnapshot(snapshot, totalGames, allowedConferenceIds = DEFAULT_COLLEGE_CONFERENCE_IDS) {
  const allowed = new Set((Array.isArray(allowedConferenceIds) ? allowedConferenceIds : DEFAULT_COLLEGE_CONFERENCE_IDS).map(String));

  const conferences = (snapshot?.conferences || [])
    .filter((conference) => allowed.has(String(conference.id)))
    .map((conference) => {
      const normalizedConferenceName = decodeHtmlEntities(conference.name);
      const teams = (conference.teams || []).map((team) => ({
        id: team.id || slugify(`${normalizedConferenceName}-${team.name}`),
        name: decodeHtmlEntities(team.name),
        teamPrestige: computeTeamPrestige(team.name, conference.id),
      }));

      return {
        id: conference.id || slugify(normalizedConferenceName),
        name: normalizedConferenceName,
        teams,
        conferenceGamesTarget: normalizeConferenceGamesTarget(conference.inferredConferenceGames, teams.length, totalGames),
      };
    });

  return {
    source: snapshot?.source || null,
    conferenceCount: conferences.length,
    teamCount: conferences.reduce((sum, conference) => sum + conference.teams.length, 0),
    conferences,
  };
}

function applyPlayerRatings(player, roleBase, random) {
  const offset = POSITION_OFFSETS[player.bio.position] || POSITION_OFFSETS.SF;
  const ovr = roleBase;

  const paceNoise = () => randomInt(-8, 8, random);
  const tendencyNoise = () => randomInt(-12, 12, random);

  player.athleticism.speed = clamp(ovr + offset.defendingPerimeter + paceNoise(), 40, 95);
  player.athleticism.agility = clamp(ovr + offset.defendingPerimeter + paceNoise(), 40, 95);
  player.athleticism.burst = clamp(ovr + offset.defendingPerimeter + paceNoise(), 40, 95);
  player.athleticism.strength = clamp(ovr + offset.inside + paceNoise(), 40, 95);
  player.athleticism.vertical = clamp(ovr + Math.round(offset.inside / 2) + paceNoise(), 40, 95);
  player.athleticism.stamina = clamp(ovr + 4 + paceNoise(), 45, 98);
  player.athleticism.durability = clamp(ovr + paceNoise(), 45, 98);

  player.shooting.layups = clamp(ovr + Math.round(offset.inside / 2) + paceNoise(), 40, 96);
  player.shooting.dunks = clamp(ovr + offset.inside + paceNoise(), 35, 96);
  player.shooting.closeShot = clamp(ovr + Math.round(offset.inside / 2) + paceNoise(), 38, 96);
  player.shooting.midrangeShot = clamp(ovr + Math.round(offset.shooting / 2) + paceNoise(), 38, 96);
  player.shooting.threePointShooting = clamp(ovr + offset.shooting + paceNoise(), 30, 96);
  player.shooting.cornerThrees = clamp(player.shooting.threePointShooting + randomInt(-4, 6, random), 30, 98);
  player.shooting.upTopThrees = clamp(player.shooting.threePointShooting + randomInt(-6, 5, random), 30, 98);
  player.shooting.drawFoul = clamp(ovr + Math.round(offset.inside / 3) + paceNoise(), 35, 96);
  player.shooting.freeThrows = clamp(ovr + Math.round(offset.shooting / 2) + paceNoise(), 40, 98);

  player.postGame.postControl = clamp(ovr + offset.inside + paceNoise(), 35, 97);
  player.postGame.postFadeaways = clamp(ovr + Math.round(offset.inside / 3) + paceNoise(), 30, 95);
  player.postGame.postHooks = clamp(ovr + offset.inside + paceNoise(), 30, 96);

  player.skills.ballHandling = clamp(ovr + offset.passing + paceNoise(), 35, 97);
  player.skills.ballSafety = clamp(ovr + offset.passing + paceNoise(), 35, 97);
  player.skills.passingAccuracy = clamp(ovr + offset.passing + paceNoise(), 35, 98);
  player.skills.passingVision = clamp(ovr + offset.passing + paceNoise(), 35, 98);
  player.skills.passingIQ = clamp(ovr + offset.passing + paceNoise(), 35, 98);
  player.skills.shotIQ = clamp(ovr + paceNoise(), 35, 98);
  player.skills.offballOffense = clamp(ovr + offset.shooting + paceNoise(), 35, 98);
  player.skills.hands = clamp(ovr + paceNoise(), 35, 99);
  player.skills.hustle = clamp(ovr + 5 + paceNoise(), 40, 99);
  player.skills.clutch = clamp(ovr + randomInt(-12, 12, random), 25, 99);

  player.defense.perimeterDefense = clamp(ovr + offset.defendingPerimeter + paceNoise(), 35, 99);
  player.defense.postDefense = clamp(ovr + offset.inside + paceNoise(), 35, 99);
  player.defense.shotBlocking = clamp(ovr + offset.inside + paceNoise(), 30, 99);
  player.defense.shotContest = clamp(ovr + offset.defendingPerimeter + paceNoise(), 35, 99);
  player.defense.steals = clamp(ovr + offset.defendingPerimeter + paceNoise(), 30, 99);
  player.defense.lateralQuickness = clamp(ovr + offset.defendingPerimeter + paceNoise(), 35, 99);
  player.defense.offballDefense = clamp(ovr + offset.defendingPerimeter + paceNoise(), 35, 99);
  player.defense.passPerception = clamp(ovr + offset.defendingPerimeter + paceNoise(), 35, 99);
  player.defense.defensiveControl = clamp(ovr + paceNoise(), 35, 99);

  player.rebounding.offensiveRebounding = clamp(ovr + offset.rebounding + paceNoise(), 30, 99);
  player.rebounding.defensiveRebound = clamp(ovr + offset.rebounding + paceNoise(), 30, 99);
  player.rebounding.boxouts = clamp(ovr + offset.rebounding + paceNoise(), 30, 99);

  player.tendencies.post = clamp(50 + Math.round(offset.inside * 2) + tendencyNoise(), 5, 95);
  player.tendencies.inside = clamp(50 + Math.round(offset.inside * 1.8) + tendencyNoise(), 5, 95);
  player.tendencies.midrange = clamp(50 + Math.round(offset.shooting * 1.1) + tendencyNoise(), 5, 95);
  player.tendencies.threePoint = clamp(50 + Math.round(offset.shooting * 1.8) + tendencyNoise(), 5, 95);
  player.tendencies.drive = clamp(50 + Math.round(offset.defendingPerimeter * 1.2) + tendencyNoise(), 5, 95);
  player.tendencies.pickAndRoll = clamp(50 + Math.round(offset.passing * 1.3) + tendencyNoise(), 5, 95);
  player.tendencies.pickAndPop = clamp(50 + Math.round(offset.shooting * 1.1) + tendencyNoise(), 5, 95);
  player.tendencies.shootVsPass = clamp(50 + Math.round(offset.shooting - offset.passing * 0.6) + tendencyNoise(), 5, 95);
}

function estimatePlayerOverall(player) {
  const scoring =
    player.shooting.layups +
    player.shooting.midrangeShot +
    player.shooting.threePointShooting +
    player.shooting.freeThrows;
  const skills =
    player.skills.ballHandling +
    player.skills.passingAccuracy +
    player.skills.passingVision +
    player.skills.shotIQ;
  const defense =
    player.defense.perimeterDefense +
    player.defense.postDefense +
    player.defense.shotContest +
    player.defense.lateralQuickness;
  const athleticism =
    player.athleticism.speed + player.athleticism.agility + player.athleticism.strength + player.athleticism.stamina;
  return Math.round((scoring + skills + defense + athleticism) / 16);
}

function estimateTeamOverall(players) {
  if (!players.length) return 50;
  const sorted = players.map(estimatePlayerOverall).sort((a, b) => b - a);
  const topEight = sorted.slice(0, 8);
  const average = topEight.reduce((sum, value) => sum + value, 0) / topEight.length;
  return Math.round(average);
}

function createProgramRoster({ teamName, conferenceId, seed }) {
  const random = createSeededRandom(`${seed}:${teamName}:${conferenceId}`);
  const conferenceBonus = asNumber(TEAM_OVR_CONFERENCE_BONUS[conferenceId], 0);
  const teamBase = clamp(61 + conferenceBonus + randomInt(-8, 8, random), 48, 86);

  const players = POSITION_TEMPLATE.map((position, idx) => {
    const player = createPlayer();
    const firstName = FIRST_NAME_POOL[Math.floor(random() * FIRST_NAME_POOL.length)];
    const lastName = LAST_NAME_POOL[Math.floor(random() * LAST_NAME_POOL.length)];
    player.bio.name = `${firstName} ${lastName}`;
    player.bio.position = position;
    player.bio.year = ["FR", "SO", "JR", "SR"][Math.floor(random() * 4)];
    player.bio.home = "USA";
    player.bio.potential = clamp(teamBase + randomInt(-6, 10, random), 30, 99);

    const roleBoost = idx < 5 ? randomInt(2, 9, random) : randomInt(-5, 4, random);
    const roleBase = clamp(teamBase + roleBoost, 40, 92);
    applyPlayerRatings(player, roleBase, random);
    return player;
  });

  const lineup = players.slice(0, 5);
  const team = createTeam({
    name: teamName,
    players,
    lineup,
    formation: shuffle(Object.values(OffensiveFormation), random)[0],
    defenseScheme: shuffle(Object.values(DefenseScheme), random)[0],
    pace: shuffle(Object.values(PaceProfile), random)[0],
    tendencies: {
      press: clamp(0.7 + random() * 0.8, 0.4, 1.5),
      trapRate: clamp(0.8 + random() * 0.7, 0.5, 1.7),
      drive: clamp(0.7 + random() * 0.8, 0.4, 1.6),
      post: clamp(0.7 + random() * 0.8, 0.4, 1.6),
      ballMovement: clamp(0.7 + random() * 0.8, 0.4, 1.6),
    },
  });

  return {
    team,
    players,
    overall: estimateTeamOverall(players),
  };
}

function gamePairKey(teamAId, teamBId) {
  return [teamAId, teamBId].sort().join("::");
}

function normalizeGameSiteType(game = {}) {
  if (typeof game.siteType === "string" && game.siteType.toLowerCase() === "neutral") return "neutral";
  if (game.neutralSite === true) return "neutral";
  return "home";
}

function isNeutralSiteGame(game = {}) {
  return normalizeGameSiteType(game) === "neutral";
}

function gameHasHomeTeam(game = {}) {
  return !isNeutralSiteGame(game);
}

function ensureDay(context, day) {
  if (!context.busyTeamsByDay.has(day)) {
    context.busyTeamsByDay.set(day, new Set());
    context.gamesByDay.set(day, []);
  }
  if (day > context.maxDay) context.maxDay = day;
}

function addScheduledGame(context, game) {
  ensureDay(context, game.day);
  const busy = context.busyTeamsByDay.get(game.day);
  if (busy.has(game.homeTeamId) || busy.has(game.awayTeamId)) {
    return false;
  }

  busy.add(game.homeTeamId);
  busy.add(game.awayTeamId);
  context.gamesByDay.get(game.day).push(game.id);
  context.games.push(game);
  if (gameHasHomeTeam(game)) {
    context.homeGamesByTeam.set(game.homeTeamId, (context.homeGamesByTeam.get(game.homeTeamId) || 0) + 1);
    context.awayGamesByTeam.set(game.awayTeamId, (context.awayGamesByTeam.get(game.awayTeamId) || 0) + 1);
  }
  return true;
}

function pickHomeAway(context, teamAId, teamBId, random = Math.random) {
  const teamAHome = context.homeGamesByTeam.get(teamAId) || 0;
  const teamAAway = context.awayGamesByTeam.get(teamAId) || 0;
  const teamBHome = context.homeGamesByTeam.get(teamBId) || 0;
  const teamBAway = context.awayGamesByTeam.get(teamBId) || 0;

  const aBalance = teamAHome - teamAAway;
  const bBalance = teamBHome - teamBAway;
  if (aBalance < bBalance) return [teamAId, teamBId];
  if (bBalance < aBalance) return [teamBId, teamAId];
  return random() < 0.5 ? [teamAId, teamBId] : [teamBId, teamAId];
}

function selectDayForMatchup(context, dayPool, teamAId, teamBId) {
  let chosenDay = null;
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

function scheduleNonConferenceGames({
  league,
  seedKey = league.seed,
  context,
  teamStateById,
  nonConferenceTargetByTeam,
  dayPool,
}) {
  const random = createSeededRandom(`${seedKey}:non-conference`);
  const remaining = new Map(Object.entries(nonConferenceTargetByTeam));
  const pairCounts = new Map();

  function canSchedulePair(teamAId, teamBId, maxPairings = 1) {
    if (teamAId === teamBId) return false;
    if (teamStateById[teamAId].conferenceId === teamStateById[teamBId].conferenceId) return false;
    const key = gamePairKey(teamAId, teamBId);
    return (pairCounts.get(key) || 0) < maxPairings;
  }

  function schedulePair(teamAId, teamBId, day) {
    const [homeTeamId, awayTeamId] = pickHomeAway(context, teamAId, teamBId, random);
    const game = {
      id: `g-${context.nextGameId++}`,
      day,
      homeTeamId,
      awayTeamId,
      siteType: "home",
      neutralSite: false,
      type: "non_conference",
      conferenceId: null,
      lockedByUser: false,
      completed: false,
      result: null,
    };

    if (!addScheduledGame(context, game)) return false;

    const key = gamePairKey(teamAId, teamBId);
    pairCounts.set(key, (pairCounts.get(key) || 0) + 1);
    remaining.set(teamAId, (remaining.get(teamAId) || 0) - 1);
    remaining.set(teamBId, (remaining.get(teamBId) || 0) - 1);
    return true;
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

    const used = new Set();
    for (let i = 0; i < available.length; i += 1) {
      const teamAId = available[i];
      if (used.has(teamAId)) continue;

      let bestOpponent = null;
      let bestScore = -Infinity;
      for (let j = i + 1; j < available.length; j += 1) {
        const teamBId = available[j];
        if (used.has(teamBId)) continue;
        if (!canSchedulePair(teamAId, teamBId, 1)) continue;

        const score = (remaining.get(teamBId) || 0) * 3 + random();
        if (score > bestScore) {
          bestScore = score;
          bestOpponent = teamBId;
        }
      }

      if (!bestOpponent) continue;
      if (schedulePair(teamAId, bestOpponent, day)) {
        used.add(teamAId);
        used.add(bestOpponent);
      }
    }
  }

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

      if (schedulePair(teamAId, opponentId, day)) {
        progress = true;
      }
    }

    if (!progress) break;
  }

  const stillUnresolved = allTeamIds.filter((teamId) => (remaining.get(teamId) || 0) > 0);
  if (stillUnresolved.length) {
    throw new Error(`Unable to complete non-conference scheduling for ${stillUnresolved.length} teams.`);
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
    const fallback = conferenceTeamIds.find((teamId) => teamId !== league.userTeamId) || conferenceTeamIds[0];
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
      siteType: "home",
      neutralSite: false,
      type: "conference",
      conferenceId: conference.id,
      lockedByUser: false,
      completed: false,
      result: null,
    };

    if (!addScheduledGame(context, game)) return false;

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
  while (unresolvedTeams().length > 0 && safety < 3000) {
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
        throw new Error(`Could not finish conference schedule for ${conference.name}.`);
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
    const conferenceTarget = league.conferences.byId[teamState.conferenceId].conferenceGamesTarget;
    nonConferenceTargetByTeam[teamId] = Math.max(0, league.settings.totalRegularSeasonGames - conferenceTarget);
  }

  const totalDesiredGames = allTeamIds.reduce((sum) => sum + league.settings.totalRegularSeasonGames, 0);
  if (totalDesiredGames % 2 !== 0) {
    const teamToTrim = allTeamIds.find((teamId) => teamId !== league.userTeamId) || allTeamIds[0];
    nonConferenceTargetByTeam[teamToTrim] = Math.max(0, nonConferenceTargetByTeam[teamToTrim] - 1);
    league.metadata.teamWithReducedSchedule = teamToTrim;
  }

  const initialNonConferenceDayCount = Math.max(...Object.values(nonConferenceTargetByTeam), 0) + DEFAULT_NON_CONFERENCE_BUFFER_DAYS;
  const maxAttempts = 20;
  let context = null;
  let conferenceStartDay = 0;
  let nonConferenceDaysUsed = 0;
  let lastError = null;

  for (let attempt = 0; attempt < maxAttempts; attempt += 1) {
    try {
      const scheduleSeed = `${league.seed}:schedule:${attempt}`;
      const attemptContext = initializeScheduleContext();

      const nonConferenceDayPool = Array.from({ length: initialNonConferenceDayCount }, (_, idx) => idx + 1);
      const nonConferenceResult = scheduleNonConferenceGames({
        league,
        seedKey: scheduleSeed,
        context: attemptContext,
        teamStateById,
        nonConferenceTargetByTeam,
        dayPool: nonConferenceDayPool,
      });

      const attemptConferenceStartDay = nonConferenceResult.nonConferenceDaysUsed + 1;

      for (const conference of league.conferences.list) {
        const conferenceTeamIds = conference.teams.map((team) => team.id);
        const requiredConferenceDays = computeConferenceDayCount(conference.teams.length, conference.conferenceGamesTarget) + DEFAULT_CONFERENCE_BUFFER_DAYS;
        const conferenceDayPool = Array.from({ length: requiredConferenceDays }, (_, idx) => attemptConferenceStartDay + idx);

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

function quickSimGame(homeTeamState, awayTeamState, options = {}, random = Math.random) {
  const homeStrength = homeTeamState.overall;
  const awayStrength = awayTeamState.overall;
  const siteType = options.siteType === "neutral" ? "neutral" : "home";
  const homeCourtEdge = siteType === "neutral" ? 0 : 2.1;

  const homeMean = 68 + (homeStrength - awayStrength) * 0.52 + homeCourtEdge;
  const awayMean = 68 + (awayStrength - homeStrength) * 0.52 - homeCourtEdge;

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
    const isHome = gameHasHomeTeam(game) ? game.homeTeamId === league.userTeamId : null;
    league.userGameHistory.push({
      gameId: game.id,
      day: game.day,
      siteType: normalizeGameSiteType(game),
      neutralSite: isNeutralSiteGame(game),
      homeTeamId: game.homeTeamId,
      awayTeamId: game.awayTeamId,
      opponentTeamId: game.homeTeamId === league.userTeamId ? game.awayTeamId : game.homeTeamId,
      isHome,
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
  const gameSiteType = normalizeGameSiteType(game);

  if (!useDetailedEngine) {
    return quickSimGame(homeTeamState, awayTeamState, { siteType: gameSiteType }, random);
  }

  const homeTeamClone = cloneTeamForSimulation(homeTeamState.teamModel);
  const awayTeamClone = cloneTeamForSimulation(awayTeamState.teamModel);

  const detailedResult = simulateGame(homeTeamClone, awayTeamClone, {
    random,
    gameSiteType,
    neutralSite: gameSiteType === "neutral",
  });
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
    throw new Error("No season schedule found.");
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

function createTeamState({ teamId, teamName, conferenceId, teamModel, overall, teamPrestige }) {
  return {
    id: teamId,
    name: teamName,
    conferenceId,
    teamModel,
    overall,
    teamPrestige: clamp(Math.round(asNumber(teamPrestige, computeTeamPrestige(teamName, conferenceId))), 1, 99),
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

function buildLeagueCatalog(totalGames = DEFAULT_TOTAL_REGULAR_SEASON_GAMES, options = {}) {
  const allowedConferenceIds = Array.isArray(options.allowedConferenceIds) && options.allowedConferenceIds.length
    ? options.allowedConferenceIds
    : DEFAULT_COLLEGE_CONFERENCE_IDS;
  return buildConferenceCatalogFromSnapshot(d1Snapshot, totalGames, allowedConferenceIds);
}

function listCareerTeamOptions(options = {}) {
  const totalRegularSeasonGames =
    Number.isFinite(Number(options.totalRegularSeasonGames)) && Number(options.totalRegularSeasonGames) > 0
      ? Math.round(Number(options.totalRegularSeasonGames))
      : DEFAULT_TOTAL_REGULAR_SEASON_GAMES;

  const catalog = buildLeagueCatalog(totalRegularSeasonGames, options);
  return catalog.conferences
    .slice()
    .sort((a, b) => a.name.localeCompare(b.name))
    .flatMap((conference) => conference.teams
      .slice()
      .sort((a, b) => a.name.localeCompare(b.name))
      .map((team) => ({
        teamId: team.id,
        teamName: team.name,
        teamPrestige: team.teamPrestige,
        conferenceId: conference.id,
        conferenceName: conference.name,
      })));
}

function createD1League(options = {}) {
  const totalRegularSeasonGames =
    Number.isFinite(Number(options.totalRegularSeasonGames)) && Number(options.totalRegularSeasonGames) > 0
      ? Math.round(Number(options.totalRegularSeasonGames))
      : DEFAULT_TOTAL_REGULAR_SEASON_GAMES;

  const catalog = buildLeagueCatalog(totalRegularSeasonGames, options);
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
        teamPrestige: team.teamPrestige,
      });

      teamStateById[team.id] = teamState;
      allTeams.push({
        id: team.id,
        name: team.name,
        conferenceId: conference.id,
        overall: teamState.overall,
        teamPrestige: teamState.teamPrestige,
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
    throw new Error("Unable to determine user team. Pass a valid `userTeamId` or exact `userTeamName`.");
  }

  const requestedUserSkills =
    options.userHeadCoachSkills && typeof options.userHeadCoachSkills === "object" ? options.userHeadCoachSkills : null;
  const requestedUserCoachName =
    typeof options.userHeadCoachName === "string" && options.userHeadCoachName.trim()
      ? options.userHeadCoachName.trim()
      : null;
  if (requestedUserCoachName) {
    const headCoach = teamStateById[userTeamId]?.teamModel?.coachingStaff?.headCoach;
    if (headCoach && typeof headCoach === "object") {
      headCoach.name = requestedUserCoachName;
      if (Array.isArray(teamStateById[userTeamId]?.teamModel?.coaches) && teamStateById[userTeamId].teamModel.coaches[0]) {
        teamStateById[userTeamId].teamModel.coaches[0].name = requestedUserCoachName;
      }
    }
  }
  if (requestedUserSkills) {
    const headCoachSkills = teamStateById[userTeamId]?.teamModel?.coachingStaff?.headCoach?.skills;
    if (headCoachSkills && typeof headCoachSkills === "object") {
      for (const [key, rawValue] of Object.entries(requestedUserSkills)) {
        const numeric = Number(rawValue);
        if (Number.isFinite(numeric) && Object.prototype.hasOwnProperty.call(headCoachSkills, key)) {
          headCoachSkills[key] = clamp(Math.round(numeric), 1, 100);
        }
      }
      if (Array.isArray(teamStateById[userTeamId]?.teamModel?.coaches) && teamStateById[userTeamId].teamModel.coaches[0]) {
        teamStateById[userTeamId].teamModel.coaches[0].skills = { ...headCoachSkills };
      }
    }
  }

  const league = {
    version: 1,
    seed,
    source: catalog.source,
    status: "in_season",
    settings: {
      totalRegularSeasonGames,
      nonConferenceDayCount: Math.max(1, totalRegularSeasonGames - 20),
    },
    metadata: {
      teamWithReducedSchedule: null,
    },
    currentDay: 0,
    userTeamId,
    userPreseason: {
      requiredNonConferenceGames: 0,
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

  buildScheduleForLeague(league);
  return league;
}

function listUserNonConferenceOptions() {
  return [];
}

function setUserNonConferenceOpponents() {
  return {
    selectedCount: 0,
    requiredCount: 0,
    complete: true,
  };
}

function autoFillUserNonConferenceOpponents() {
  return [];
}

function getPreseasonSchedulingBoard(_league, options = {}) {
  const pageSize = clamp(Math.round(asNumber(options.pageSize, DEFAULT_PRESEASON_BOARD_PAGE_SIZE)), 5, 100);
  const page = Math.max(1, Math.round(asNumber(options.page, 1)));
  return {
    page,
    pageSize,
    totalPages: 1,
    search: String(options.search || "").trim().toLowerCase(),
    totalOptions: 0,
    requiredCount: 0,
    selectedCount: 0,
    remainingCount: 0,
    selectedOpponents: [],
    options: [],
  };
}

function generateSeasonSchedule(league) {
  if (!league.schedule || !Array.isArray(league.schedule.games) || league.schedule.games.length === 0) {
    buildScheduleForLeague(league);
  }
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
      const siteType = normalizeGameSiteType(game);
      return {
        gameId: game.id,
        day: game.day,
        type: game.type,
        siteType,
        neutralSite: siteType === "neutral",
        isHome: siteType === "neutral" ? null : game.homeTeamId === userTeamId,
        opponentTeamId,
        opponentName: opponent.name,
        completed: game.completed,
        result: game.result,
      };
    })
    .sort((a, b) => a.day - b.day);
}

function buildPlayerAttributeSummary(player = {}) {
  const rating = (value) => Math.max(1, Math.round(asNumber(value, 1)));
  return {
    potential: rating(player?.bio?.potential),
    speed: rating(player?.athleticism?.speed),
    agility: rating(player?.athleticism?.agility),
    burst: rating(player?.athleticism?.burst),
    strength: rating(player?.athleticism?.strength),
    vertical: rating(player?.athleticism?.vertical),
    stamina: rating(player?.athleticism?.stamina),
    durability: rating(player?.athleticism?.durability),
    layups: rating(player?.shooting?.layups),
    dunks: rating(player?.shooting?.dunks),
    closeShot: rating(player?.shooting?.closeShot),
    midrangeShot: rating(player?.shooting?.midrangeShot),
    threePointShooting: rating(player?.shooting?.threePointShooting),
    cornerThrees: rating(player?.shooting?.cornerThrees),
    upTopThrees: rating(player?.shooting?.upTopThrees),
    drawFoul: rating(player?.shooting?.drawFoul),
    freeThrows: rating(player?.shooting?.freeThrows),
    postControl: rating(player?.postGame?.postControl),
    postFadeaways: rating(player?.postGame?.postFadeaways),
    postHooks: rating(player?.postGame?.postHooks),
    ballHandling: rating(player?.skills?.ballHandling),
    ballSafety: rating(player?.skills?.ballSafety),
    passingAccuracy: rating(player?.skills?.passingAccuracy),
    passingVision: rating(player?.skills?.passingVision),
    passingIQ: rating(player?.skills?.passingIQ),
    shotIQ: rating(player?.skills?.shotIQ),
    offballOffense: rating(player?.skills?.offballOffense),
    hands: rating(player?.skills?.hands),
    hustle: rating(player?.skills?.hustle),
    clutch: rating(player?.skills?.clutch),
    perimeterDefense: rating(player?.defense?.perimeterDefense),
    postDefense: rating(player?.defense?.postDefense),
    shotBlocking: rating(player?.defense?.shotBlocking),
    shotContest: rating(player?.defense?.shotContest),
    steals: rating(player?.defense?.steals),
    lateralQuickness: rating(player?.defense?.lateralQuickness),
    offballDefense: rating(player?.defense?.offballDefense),
    passPerception: rating(player?.defense?.passPerception),
    defensiveControl: rating(player?.defense?.defensiveControl),
    offensiveRebounding: rating(player?.rebounding?.offensiveRebounding),
    defensiveRebound: rating(player?.rebounding?.defensiveRebound),
    boxouts: rating(player?.rebounding?.boxouts),
    tendencyPost: rating(player?.tendencies?.post),
    tendencyInside: rating(player?.tendencies?.inside),
    tendencyMidrange: rating(player?.tendencies?.midrange),
    tendencyThreePoint: rating(player?.tendencies?.threePoint),
    tendencyDrive: rating(player?.tendencies?.drive),
    tendencyPickAndRoll: rating(player?.tendencies?.pickAndRoll),
    tendencyPickAndPop: rating(player?.tendencies?.pickAndPop),
    tendencyShootVsPass: rating(player?.tendencies?.shootVsPass),
  };
}

function normalizeRotationMinutes(value, fallback) {
  const parsed = Number(value);
  if (!Number.isFinite(parsed)) return fallback;
  return clamp(Math.round(parsed * 2) / 2, 0, 40);
}

function findPlayerByIndex(players, index) {
  if (!Array.isArray(players)) return null;
  const parsed = Number(index);
  if (!Number.isFinite(parsed)) return null;
  const rounded = Math.round(parsed);
  if (rounded < 0 || rounded >= players.length) return null;
  return players[rounded] || null;
}

function normalizeStarterPosition(value, fallback = null) {
  const normalized = String(value || "").trim().toUpperCase();
  if (ROTATION_SLOTS.includes(normalized)) return normalized;
  return fallback;
}

function getRotationOrderPlayers(players, lineup, savedOrder = []) {
  const byName = new Map();
  players.forEach((player) => {
    byName.set(player?.bio?.name || "", player);
  });
  const ordered = [];
  const used = new Set();

  if (Array.isArray(savedOrder)) {
    savedOrder.forEach((name) => {
      const player = byName.get(String(name || ""));
      if (player && !used.has(player)) {
        ordered.push(player);
        used.add(player);
      }
    });
  }

  if (Array.isArray(lineup)) {
    lineup.forEach((player) => {
      if (player && !used.has(player)) {
        ordered.push(player);
        used.add(player);
      }
    });
  }

  players.forEach((player) => {
    if (player && !used.has(player)) {
      ordered.push(player);
      used.add(player);
    }
  });

  return ordered;
}

function defaultRotationMinutesForSlot(slotIndex, starterCount) {
  if (slotIndex < starterCount) return 30;
  if (slotIndex < 10) return 10;
  return 0;
}

function normalizeRotationMinuteVector(rawMinutes, targetTotal = 200) {
  const cap = 40;
  const count = Array.isArray(rawMinutes) ? rawMinutes.length : 0;
  if (!count) return [];

  const target = Math.min(targetTotal, count * cap);
  let values = rawMinutes.map((value) => normalizeRotationMinutes(value, 0));
  let sum = values.reduce((total, value) => total + value, 0);

  if (target <= 0) return values.map(() => 0);

  if (sum <= 0) {
    values = values.map(() => 1);
    sum = values.length;
  }

  const scale = target / sum;
  values = values.map((value) => Math.min(cap, Math.max(0, value * scale)));

  let currentTotal = values.reduce((total, value) => total + value, 0);
  let remaining = target - currentTotal;
  let guard = 0;
  while (remaining > 0.001 && guard < 200) {
    guard += 1;
    const eligible = values
      .map((value, index) => ({ value, index }))
      .filter((entry) => entry.value < cap - 0.001);
    if (!eligible.length) break;
    const increment = remaining / eligible.length;
    eligible.forEach(({ index }) => {
      const available = cap - values[index];
      values[index] += Math.min(available, increment);
    });
    currentTotal = values.reduce((total, value) => total + value, 0);
    remaining = target - currentTotal;
  }

  values = values.map((value) => normalizeRotationMinutes(value, 0));
  let roundedTotal = values.reduce((total, value) => total + value, 0);
  let diff = normalizeRotationMinutes(target - roundedTotal, 0);
  let adjustGuard = 0;
  while (Math.abs(diff) >= 0.49 && adjustGuard < 1000) {
    adjustGuard += 1;
    const direction = diff > 0 ? 0.5 : -0.5;
    let adjusted = false;
    for (let i = 0; i < values.length; i += 1) {
      const next = values[i] + direction;
      if (next < 0 || next > cap) continue;
      values[i] = normalizeRotationMinutes(next, values[i]);
      adjusted = true;
      break;
    }
    if (!adjusted) break;
    roundedTotal = values.reduce((total, value) => total + value, 0);
    diff = target - roundedTotal;
  }

  return values.map((value) => normalizeRotationMinutes(value, 0));
}

function inferUserRotationEntries(league) {
  const userTeam = league?.teams?.byId?.[league?.userTeamId];
  const players = Array.isArray(userTeam?.teamModel?.players) ? userTeam.teamModel.players : [];
  if (!players.length) return [];
  const lineup = Array.isArray(userTeam?.teamModel?.lineup) ? userTeam.teamModel.lineup : [];
  const rotation = userTeam?.teamModel?.rotation || {};
  const minuteTargets = rotation.minuteTargets || {};
  const savedOrder = Array.isArray(rotation.order) ? rotation.order : [];
  const orderedPlayers = getRotationOrderPlayers(players, lineup, savedOrder);
  const starterCount = Math.min(ROTATION_SLOTS.length, orderedPlayers.length);
  const savedStarterPositions = Array.isArray(rotation.starterPositions) ? rotation.starterPositions : [];

  const rawMinutes = orderedPlayers.map((player, slotIndex) => {
    const name = player?.bio?.name || "";
    const raw = Number(minuteTargets[name]);
    if (Number.isFinite(raw)) return raw;
    return defaultRotationMinutesForSlot(slotIndex, starterCount);
  });
  const normalizedMinutes = normalizeRotationMinuteVector(rawMinutes, 200);

  return orderedPlayers.map((player, slotIndex) => {
    const playerIndex = players.indexOf(player);
    const fallbackPosition = normalizeStarterPosition(player?.bio?.position, ROTATION_SLOTS[slotIndex] || "SF");
    const starterPosition =
      slotIndex < starterCount
        ? normalizeStarterPosition(savedStarterPositions[slotIndex], fallbackPosition)
        : null;
    return {
      slot: slotIndex + 1,
      playerIndex: playerIndex >= 0 ? playerIndex : null,
      position: starterPosition,
      minutes: normalizedMinutes[slotIndex] || 0,
    };
  });
}

function getUserRotation(league) {
  return inferUserRotationEntries(league);
}

function setUserRotation(league, rawEntries = []) {
  const userTeam = league?.teams?.byId?.[league?.userTeamId];
  if (!userTeam?.teamModel) return [];

  const players = Array.isArray(userTeam.teamModel.players) ? userTeam.teamModel.players : [];
  if (!players.length) return [];

  const current = inferUserRotationEntries(league);
  const requested = Array.isArray(rawEntries) ? rawEntries : [];
  const merged = current.map((entry, index) => {
    const incoming = requested.find((candidate) => Number(candidate?.slot) === entry.slot) || requested[index] || {};
    return {
      slot: entry.slot,
      playerIndex: incoming.playerIndex ?? entry.playerIndex ?? null,
      position: incoming.position ?? entry.position ?? null,
      minutes: incoming.minutes ?? entry.minutes ?? 0,
    };
  });

  const ordered = [];
  const used = new Set();
  merged.forEach((entry) => {
    const player = findPlayerByIndex(players, entry.playerIndex);
    if (player && !used.has(player)) {
      ordered.push({ ...entry, player });
      used.add(player);
    }
  });
  players.forEach((player) => {
    if (!used.has(player)) {
      ordered.push({
        slot: ordered.length + 1,
        playerIndex: players.indexOf(player),
        position: null,
        minutes: 0,
        player,
      });
      used.add(player);
    }
  });

  const starterCount = Math.min(ROTATION_SLOTS.length, ordered.length);
  const rawMinutes = ordered.map((entry, slotIndex) => {
    const requestedValue = Number(entry.minutes);
    if (Number.isFinite(requestedValue)) return requestedValue;
    return defaultRotationMinutesForSlot(slotIndex, starterCount);
  });
  const normalizedMinutes = normalizeRotationMinuteVector(rawMinutes, 200);
  const minuteTargets = {};
  ordered.forEach((entry, index) => {
    const name = entry?.player?.bio?.name || "";
    if (!name) return;
    minuteTargets[name] = normalizedMinutes[index] || 0;
  });

  const starterPositions = [];
  for (let i = 0; i < starterCount; i += 1) {
    const fallbackPosition = normalizeStarterPosition(
      ordered[i]?.player?.bio?.position,
      ROTATION_SLOTS[i] || "SF",
    );
    starterPositions.push(normalizeStarterPosition(ordered[i]?.position, fallbackPosition));
  }

  userTeam.teamModel.lineup = ordered.slice(0, starterCount).map((entry) => entry.player);
  userTeam.teamModel.rotation = {
    ...(userTeam.teamModel.rotation || {}),
    minuteTargets,
    order: ordered.map((entry) => entry?.player?.bio?.name || "").filter((name) => name),
    starterPositions,
  };

  return inferUserRotationEntries(league);
}

function getUserRoster(league) {
  const userTeam = league?.teams?.byId?.[league?.userTeamId];
  const players = Array.isArray(userTeam?.teamModel?.players) ? userTeam.teamModel.players : [];
  const lineup = Array.isArray(userTeam?.teamModel?.lineup) ? userTeam.teamModel.lineup : [];
  const lineupKeys = new Set(lineup.map((player) => `${player?.bio?.name || ""}|${player?.bio?.position || ""}`));

  return players
    .map((player, index) => {
      const key = `${player?.bio?.name || ""}|${player?.bio?.position || ""}`;
      return {
        playerIndex: index,
        name: player?.bio?.name || "Unknown",
        position: player?.bio?.position || "",
        year: player?.bio?.year || "",
        home: player?.bio?.home || "",
        height: player?.size?.height || "",
        weight: player?.size?.weight || "",
        wingspan: player?.size?.wingspan || "",
        overall: estimatePlayerOverall(player),
        isStarter: lineupKeys.has(key),
        attributes: buildPlayerAttributeSummary(player),
      };
    })
    .sort((a, b) => {
      if (a.isStarter !== b.isStarter) return a.isStarter ? -1 : 1;
      if (a.overall !== b.overall) return b.overall - a.overall;
      return a.name.localeCompare(b.name);
    });
}

function normalizeUserCoachingStaff(league) {
  const userTeam = league?.teams?.byId?.[league?.userTeamId];
  const teamModel = userTeam?.teamModel;
  if (!teamModel || typeof teamModel !== "object") {
    return null;
  }

  let staff = teamModel.coachingStaff;
  if (!staff || typeof staff !== "object") {
    const coaches = Array.isArray(teamModel.coaches) ? teamModel.coaches : [];
    const headCoach = coaches[0] || null;
    const assistants = coaches.slice(1);
    if (!headCoach) return null;
    staff = {
      headCoach,
      assistants,
      gamePrepAssistantIndex: null,
    };
  }

  const normalizedAssistants = Array.isArray(staff.assistants)
    ? staff.assistants.map((assistant) => ({
        ...assistant,
        focus: typeof assistant?.focus === "string" && assistant.focus.trim() ? assistant.focus.trim() : "recruiting",
      }))
    : [];

  const numericGamePrepIndex = Number(staff.gamePrepAssistantIndex);
  const focusGamePrepIndex = normalizedAssistants.findIndex((assistant) => assistant.focus === "game_prep");
  const resolvedGamePrepAssistantIndex =
    Number.isInteger(numericGamePrepIndex) && numericGamePrepIndex >= 0 && numericGamePrepIndex < normalizedAssistants.length
      ? numericGamePrepIndex
      : focusGamePrepIndex >= 0
        ? focusGamePrepIndex
        : null;

  const normalized = {
    headCoach: staff.headCoach || null,
    assistants: normalizedAssistants,
    gamePrepAssistantIndex: resolvedGamePrepAssistantIndex,
  };

  if (!normalized.headCoach) return null;

  teamModel.coachingStaff = normalized;
  teamModel.coaches = [normalized.headCoach, ...normalized.assistants];
  return normalized;
}

function getUserCoachingStaff(league) {
  const staff = normalizeUserCoachingStaff(league);
  if (!staff) {
    throw new Error("User team is missing coaching staff.");
  }
  return cloneDeep(staff);
}

function setUserAssistantFocus(league, assistantIndex, focus) {
  const staff = normalizeUserCoachingStaff(league);
  if (!staff) {
    throw new Error("User team is missing coaching staff.");
  }

  const index = Math.round(asNumber(assistantIndex, -1));
  if (index < 0 || index >= staff.assistants.length) {
    throw new Error("Assistant index out of range.");
  }

  const normalizedFocus = String(focus || "").trim().toLowerCase();
  const allowedFocuses = new Set(["recruiting", "development", "game_prep", "scouting"]);
  if (!allowedFocuses.has(normalizedFocus)) {
    throw new Error("Invalid assistant focus.");
  }

  staff.assistants[index] = {
    ...staff.assistants[index],
    focus: normalizedFocus,
  };

  const gamePrepIndex = staff.assistants.findIndex((assistant) => assistant?.focus === "game_prep");
  staff.gamePrepAssistantIndex = gamePrepIndex >= 0 ? gamePrepIndex : null;

  const userTeam = league.teams.byId[league.userTeamId];
  userTeam.teamModel.coachingStaff = staff;
  userTeam.teamModel.coaches = [staff.headCoach, ...staff.assistants];
  return cloneDeep(staff);
}

function advanceToNextUserGame(league, options = {}) {
  generateSeasonSchedule(league);

  const userSchedule = getUserSchedule(league);
  const pending = userSchedule.find((game) => !game.completed);
  if (!pending) {
    return { done: true, message: "Season complete for user team." };
  }

  simulateThroughDay(league, pending.day, options);

  const game = league.schedule.byId[pending.gameId];
  const opponentTeamId = game.homeTeamId === league.userTeamId ? game.awayTeamId : game.homeTeamId;
  const opponent = league.teams.byId[opponentTeamId];
  const gameSiteType = normalizeGameSiteType(game);
  const userIsHome = gameSiteType === "neutral" ? null : game.homeTeamId === league.userTeamId;
  const userIsDesignatedHome = game.homeTeamId === league.userTeamId;

  const userScore = userIsDesignatedHome ? game.result.homeScore : game.result.awayScore;
  const opponentScore = userIsDesignatedHome ? game.result.awayScore : game.result.homeScore;

  return {
    done: false,
    day: game.day,
    gameId: game.id,
    opponentTeamId,
    opponentName: opponent.name,
    siteType: gameSiteType,
    neutralSite: gameSiteType === "neutral",
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
      const userIsDesignatedHome =
        typeof entry.isHome === "boolean"
          ? entry.isHome
          : entry.homeTeamId === league.userTeamId;
      const userScore = userIsDesignatedHome ? entry.result.homeScore : entry.result.awayScore;
      const opponentScore = userIsDesignatedHome ? entry.result.awayScore : entry.result.homeScore;
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

function asRatio(value, fallback = 0.5) {
  const numeric = asNumber(value, fallback);
  if (numeric <= 1) return clamp(numeric, 0, 1);
  return clamp(numeric / 100, 0, 1);
}

function normalizeVector(values, fallback = 0.5) {
  const numeric = values.map((value) => asNumber(value, fallback));
  const min = Math.min(...numeric);
  const max = Math.max(...numeric);
  if (!Number.isFinite(min) || !Number.isFinite(max) || Math.abs(max - min) < 0.000001) {
    return numeric.map(() => fallback);
  }
  return numeric.map((value) => (value - min) / (max - min));
}

function calculateCoachQuality(teamState) {
  const staff = teamState?.teamModel?.coachingStaff;
  if (!staff || typeof staff !== "object") return 50;
  const head = staff.headCoach || {};
  const assistants = Array.isArray(staff.assistants) ? staff.assistants : [];
  const coachList = [head, ...assistants];
  if (!coachList.length) return 50;

  const coachSkillValue = (coach) => {
    const skills = coach?.skills || {};
    const values = [
      asNumber(skills.offensiveCoaching, 50),
      asNumber(skills.defensiveCoaching, 50),
      asNumber(skills.playerDevelopment, 50),
      asNumber(skills.recruiting, 50),
      asNumber(skills.scouting, 50),
      asNumber(skills.potential, 50),
    ];
    return values.reduce((sum, value) => sum + value, 0) / values.length;
  };

  const headQuality = coachSkillValue(head);
  const assistantQuality = assistants.length
    ? assistants.reduce((sum, assistant) => sum + coachSkillValue(assistant), 0) / assistants.length
    : headQuality;

  return clamp(Math.round(headQuality * 0.7 + assistantQuality * 0.3), 1, 100);
}

function derivePrestige(teamState, conferenceId) {
  const explicitPrestige =
    asNumber(teamState?.teamPrestige, NaN) ||
    asNumber(teamState?.prestige, NaN) ||
    asNumber(teamState?.programPrestige, NaN) ||
    asNumber(teamState?.teamModel?.prestige, NaN);
  if (Number.isFinite(explicitPrestige)) {
    return clamp(explicitPrestige, 0, 100);
  }

  const conferencePrestige = {
    acc: 78,
    sec: 76,
    "big-ten": 77,
    "big-12": 79,
    "big-east": 74,
  };
  const conferenceBase = asNumber(conferencePrestige[conferenceId], 65);
  const overall = asNumber(teamState?.overall, 65);
  return clamp(conferenceBase * 0.7 + overall * 0.3, 0, 100);
}

function deriveLastYearResult(teamState, fallbackOverall) {
  const directRatioCandidates = [
    teamState?.lastYearResult,
    teamState?.lastSeasonResult,
    teamState?.previousSeason?.winPct,
    teamState?.lastSeason?.winPct,
    teamState?.history?.lastYearWinPct,
  ];
  for (const candidate of directRatioCandidates) {
    const numeric = Number(candidate);
    if (Number.isFinite(numeric)) {
      return asRatio(numeric, 0.5);
    }
  }

  const recordCandidates = [
    teamState?.previousSeason,
    teamState?.lastSeason,
    teamState?.history?.lastYear,
    { wins: teamState?.lastYearWins, losses: teamState?.lastYearLosses },
    { wins: teamState?.previousSeasonWins, losses: teamState?.previousSeasonLosses },
  ];
  for (const candidate of recordCandidates) {
    const wins = asNumber(candidate?.wins, NaN);
    const losses = asNumber(candidate?.losses, NaN);
    if (Number.isFinite(wins) && Number.isFinite(losses) && wins + losses > 0) {
      return clamp(wins / (wins + losses), 0, 1);
    }
  }

  return clamp(0.35 + asNumber(fallbackOverall, 65) / 200, 0, 1);
}

function computePreseasonFade(gamesPlayed) {
  const games = Math.max(0, Math.round(asNumber(gamesPlayed, 0)));
  const baseline = 0.80;
  const floor = 0.12;
  const decay = Math.exp(-games / 24);
  return clamp(floor + (baseline - floor) * decay, floor, baseline);
}

function getRankings(league, options = {}) {
  const topN = clamp(Math.round(asNumber(options.topN, 25)), 1, 200);
  const teamList = Array.isArray(league?.teams?.list) ? league.teams.list : [];
  const teamById = league?.teams?.byId || {};
  if (!teamList.length) {
    return {
      topN,
      seasonProgress: 0,
      preseasonWeight: 1,
      inSeasonWeight: 0,
      rankings: [],
    };
  }

  const completedGames = Array.isArray(league?.schedule?.games)
    ? league.schedule.games.filter((game) => game?.completed && game?.result)
    : [];

  const gamesByTeam = {};
  completedGames.forEach((game) => {
    if (!gamesByTeam[game.homeTeamId]) gamesByTeam[game.homeTeamId] = [];
    if (!gamesByTeam[game.awayTeamId]) gamesByTeam[game.awayTeamId] = [];
    gamesByTeam[game.homeTeamId].push(game);
    gamesByTeam[game.awayTeamId].push(game);
  });

  const winPctByTeam = {};
  teamList.forEach((team) => {
    const state = teamById[team.id];
    const wins = asNumber(state?.record?.wins, 0);
    const losses = asNumber(state?.record?.losses, 0);
    const games = wins + losses;
    winPctByTeam[team.id] = games > 0 ? wins / games : 0.5;
  });

  const metrics = teamList.map((team) => {
    const state = teamById[team.id] || {};
    const record = state.record || {};
    const wins = asNumber(record.wins, 0);
    const losses = asNumber(record.losses, 0);
    const gamesPlayed = Math.max(0, wins + losses);
    const pointsFor = asNumber(record.pointsFor, 0);
    const pointsAgainst = asNumber(record.pointsAgainst, 0);
    const pointDiffPerGame = gamesPlayed > 0 ? (pointsFor - pointsAgainst) / gamesPlayed : 0;

    const teamGames = gamesByTeam[team.id] || [];
    let sosAccumulator = 0;
    let qualityWins = 0;
    for (const game of teamGames) {
      const opponentId = game.homeTeamId === team.id ? game.awayTeamId : game.homeTeamId;
      const opponentWinPct = asNumber(winPctByTeam[opponentId], 0.5);
      sosAccumulator += opponentWinPct;

      const homeScore = asNumber(game?.result?.homeScore, 0);
      const awayScore = asNumber(game?.result?.awayScore, 0);
      const won = game.homeTeamId === team.id ? homeScore > awayScore : awayScore > homeScore;
      if (won && opponentWinPct >= 0.60) {
        qualityWins += 1;
      }
    }

    const playerSkill = clamp(asNumber(state.overall, asNumber(team.overall, 65)), 1, 100);
    const prestige = derivePrestige(state, state.conferenceId || team.conferenceId);
    const lastYearResult = deriveLastYearResult(state, playerSkill);
    const coachQuality = calculateCoachQuality(state);
    const winPct = gamesPlayed > 0 ? wins / gamesPlayed : 0.5;
    const strengthOfSchedule = teamGames.length > 0 ? sosAccumulator / teamGames.length : 0.5;
    const qualityWinRate = gamesPlayed > 0 ? qualityWins / gamesPlayed : 0;

    return {
      teamId: team.id,
      teamName: state.name || team.name || "Unknown",
      conferenceId: state.conferenceId || team.conferenceId || "",
      wins,
      losses,
      gamesPlayed,
      recordText: `${wins}-${losses}`,
      pointDiffPerGame,
      winPct,
      strengthOfSchedule,
      qualityWinRate,
      playerSkill,
      prestige,
      lastYearResult,
      coachQuality,
    };
  });

  const preseasonPlayer = normalizeVector(metrics.map((team) => team.playerSkill), 0.5);
  const preseasonPrestige = normalizeVector(metrics.map((team) => team.prestige), 0.5);
  const preseasonLastYear = normalizeVector(metrics.map((team) => team.lastYearResult), 0.5);
  const preseasonCoach = normalizeVector(metrics.map((team) => team.coachQuality), 0.5);

  const inSeasonWinPct = normalizeVector(metrics.map((team) => team.winPct), 0.5);
  const inSeasonDiff = normalizeVector(metrics.map((team) => team.pointDiffPerGame), 0.5);
  const inSeasonSos = normalizeVector(metrics.map((team) => team.strengthOfSchedule), 0.5);
  const inSeasonQuality = normalizeVector(metrics.map((team) => team.qualityWinRate), 0.5);

  const maxGamesPlayed = Math.max(...metrics.map((team) => team.gamesPlayed), 0);
  const seasonTarget = Math.max(1, asNumber(league?.settings?.totalRegularSeasonGames, DEFAULT_TOTAL_REGULAR_SEASON_GAMES));
  const seasonProgress = clamp(maxGamesPlayed / seasonTarget, 0, 1);
  const preseasonWeight = computePreseasonFade(maxGamesPlayed);
  const inSeasonWeight = 1 - preseasonWeight;

  const ranked = metrics.map((team, index) => {
    const preseasonScore =
      preseasonPlayer[index] * 0.45 +
      preseasonPrestige[index] * 0.20 +
      preseasonLastYear[index] * 0.20 +
      preseasonCoach[index] * 0.15;

    const inSeasonScore =
      inSeasonWinPct[index] * 0.50 +
      inSeasonDiff[index] * 0.20 +
      inSeasonSos[index] * 0.20 +
      inSeasonQuality[index] * 0.10;

    const compositeScore = preseasonScore * preseasonWeight + inSeasonScore * inSeasonWeight;

    return {
      ...team,
      preseasonScore,
      inSeasonScore,
      compositeScore,
    };
  })
    .sort((a, b) => {
      if (b.compositeScore !== a.compositeScore) return b.compositeScore - a.compositeScore;
      if (b.wins !== a.wins) return b.wins - a.wins;
      if (b.pointDiffPerGame !== a.pointDiffPerGame) return b.pointDiffPerGame - a.pointDiffPerGame;
      return a.teamName.localeCompare(b.teamName);
    })
    .map((entry, index) => ({
      rank: index + 1,
      teamId: entry.teamId,
      teamName: entry.teamName,
      conferenceId: entry.conferenceId,
      record: entry.recordText,
      wins: entry.wins,
      losses: entry.losses,
      gamesPlayed: entry.gamesPlayed,
      pointDifferentialPerGame: entry.pointDiffPerGame,
      strengthOfSchedule: entry.strengthOfSchedule,
      qualityWinRate: entry.qualityWinRate,
      playerSkill: entry.playerSkill,
      prestige: entry.prestige,
      lastYearResult: entry.lastYearResult,
      coachQuality: entry.coachQuality,
      preseasonScore: entry.preseasonScore,
      inSeasonScore: entry.inSeasonScore,
      compositeScore: entry.compositeScore,
    }));

  return {
    topN,
    seasonProgress,
    preseasonWeight,
    inSeasonWeight,
    rankings: ranked.slice(0, topN),
  };
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
    .map((game) => {
      const siteType = normalizeGameSiteType(game);
      return {
        ...game,
        siteType,
        neutralSite: siteType === "neutral",
        day: Math.max(1, Math.round(asNumber(game.day, 1))),
        completed: Boolean(game.completed),
        result: game.result || null,
      };
    })
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
      teamPrestige: clamp(
        Math.round(
          asNumber(
            teamState.teamPrestige,
            computeTeamPrestige(teamState.name || teamId, teamState.conferenceId)
          )
        ),
        1,
        99
      ),
    };
  });
  league.teams.byId = teamStateById;
  league.conferences.list = league.conferences.list.map((conference) => ({
    ...conference,
    teams: Array.isArray(conference.teams)
      ? conference.teams.map((team) => {
          const state = team?.id ? teamStateById[team.id] : null;
          const teamName = state?.name || team?.name || "";
          return {
            ...team,
            name: teamName,
            teamPrestige: clamp(
              Math.round(
                asNumber(
                  team?.teamPrestige,
                  state?.teamPrestige ?? computeTeamPrestige(teamName, conference.id)
                )
              ),
              1,
              99
            ),
          };
        })
      : [],
  }));
  league.conferences.byId = Object.fromEntries(league.conferences.list.map((conference) => [conference.id, conference]));

  const teamList =
    Array.isArray(league.teams.list) && league.teams.list.length
      ? league.teams.list
      : Object.values(teamStateById).map((teamState) => ({
          id: teamState.id,
          name: teamState.name,
          conferenceId: teamState.conferenceId,
          overall: teamState.overall,
          teamPrestige: teamState.teamPrestige,
        }));
  league.teams.list = teamList
    .filter((team) => team && team.id && teamStateById[team.id])
    .map((team) => ({
      id: team.id,
      name: teamStateById[team.id].name,
      conferenceId: teamStateById[team.id].conferenceId,
      overall: teamStateById[team.id].overall,
      teamPrestige: teamStateById[team.id].teamPrestige,
    }));

  league.version = Math.round(asNumber(league.version, 1));
  league.seed = String(league.seed || `${Date.now()}`);
  league.status = typeof league.status === "string" ? league.status : "in_season";
  league.currentDay = Math.max(0, Math.round(asNumber(league.currentDay, 0)));
  league.metadata = typeof league.metadata === "object" && league.metadata ? league.metadata : {};
  if (!Object.prototype.hasOwnProperty.call(league.metadata, "teamWithReducedSchedule")) {
    league.metadata.teamWithReducedSchedule = null;
  }
  league.userGameHistory = Array.isArray(league.userGameHistory) ? league.userGameHistory : [];

  league.settings = {
    totalRegularSeasonGames: Math.max(1, Math.round(asNumber(league.settings?.totalRegularSeasonGames, DEFAULT_TOTAL_REGULAR_SEASON_GAMES))),
    nonConferenceDayCount: Math.max(1, Math.round(asNumber(league.settings?.nonConferenceDayCount, 12))),
  };

  league.userPreseason = {
    requiredNonConferenceGames: 0,
    nonConferenceOpponentIds: [],
  };

  league.schedule = normalizeScheduleState(league.schedule);
  if (!league.schedule) {
    buildScheduleForLeague(league);
  }

  if (league.schedule?.totalDays) {
    league.currentDay = Math.min(league.currentDay, league.schedule.totalDays);
  } else {
    league.currentDay = 0;
  }

  league.status = "in_season";
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
    requiredUserNonConferenceGames: 0,
    userSelectedNonConferenceGames: 0,
    scheduleGenerated: Boolean(league.schedule),
    totalScheduledGames: league.schedule?.games?.length || 0,
  };
}

module.exports = {
  DEFAULT_TOTAL_REGULAR_SEASON_GAMES,
  LEAGUE_SAVE_FORMAT,
  LEAGUE_SAVE_VERSION,
  DEFAULT_COLLEGE_CONFERENCE_IDS,
  buildLeagueCatalog,
  listCareerTeamOptions,
  createD1League,
  listUserNonConferenceOptions,
  getPreseasonSchedulingBoard,
  setUserNonConferenceOpponents,
  autoFillUserNonConferenceOpponents,
  generateSeasonSchedule,
  getUserSchedule,
  getUserRoster,
  getUserCoachingStaff,
  setUserAssistantFocus,
  getUserRotation,
  setUserRotation,
  advanceToNextUserGame,
  getUserCompletedGames,
  getConferenceStandings,
  getRankings,
  getLeagueSummary,
  saveLeagueState,
  loadLeagueState,
};
