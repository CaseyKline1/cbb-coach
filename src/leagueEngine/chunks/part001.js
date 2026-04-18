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
const DEFAULT_NON_CONFERENCE_BUFFER_DAYS = 0;
const DEFAULT_CONFERENCE_BUFFER_DAYS = 2;
const LEAGUE_SAVE_FORMAT = "cbb-coach.league-state";
const LEAGUE_SAVE_VERSION = 1;
const DEFAULT_PRESEASON_BOARD_PAGE_SIZE = 20;

const TEAM_OVR_CONFERENCE_BONUS = Object.freeze({
  acc: 7,
  "big-12": 7,
  "big-ten": 7,
  "big-east": 6,
  sec: 6,
  "atlantic-10": 3,
  american: 2,
  "mountain-west": 3,
  wcc: 3,
  mvc: 2,
  cusa: 1,
  sun_belt: 1,
  "sun-belt": 1,
});

const POSITION_TEMPLATE = Object.freeze(["PG", "SG", "SF", "PF", "C", "CG", "Wing", "F", "Big", "PG"]);

const POSITION_OFFSETS = Object.freeze({
  PG: {
    shooting: 1,
    passing: 10,
    defendingPerimeter: 5,
    rebounding: -6,
    inside: -4,
  },
  SG: {
    shooting: 6,
    passing: 2,
    defendingPerimeter: 4,
    rebounding: -3,
    inside: -2,
  },
  SF: {
    shooting: 3,
    passing: 1,
    defendingPerimeter: 3,
    rebounding: 2,
    inside: 1,
  },
  PF: {
    shooting: -1,
    passing: -2,
    defendingPerimeter: -1,
    rebounding: 7,
    inside: 7,
  },
  C: {
    shooting: -4,
    passing: -5,
    defendingPerimeter: -5,
    rebounding: 10,
    inside: 10,
  },
  CG: {
    shooting: 4,
    passing: 7,
    defendingPerimeter: 4,
    rebounding: -4,
    inside: -2,
  },
  Wing: {
    shooting: 5,
    passing: 1,
    defendingPerimeter: 5,
    rebounding: 1,
    inside: -1,
  },
  F: {
    shooting: 0,
    passing: -1,
    defendingPerimeter: 1,
    rebounding: 5,
    inside: 5,
  },
  Big: {
    shooting: -3,
    passing: -3,
    defendingPerimeter: -4,
    rebounding: 9,
    inside: 9,
  },
});

const FIRST_NAME_POOL = Object.freeze([
  "Jalen",
  "Marcus",
  "Eli",
  "Noah",
  "Ty",
  "Jordan",
  "Malik",
  "Darius",
  "Caleb",
  "Cameron",
  "Xavier",
  "Aiden",
  "Isaiah",
  "Liam",
  "Mason",
  "Jayden",
  "Trent",
  "Damon",
  "Riley",
  "Kaden",
]);

const LAST_NAME_POOL = Object.freeze([
  "Carter",
  "Brooks",
  "Davis",
  "Coleman",
  "Thomas",
  "Hill",
  "Moore",
  "Young",
  "Turner",
  "Jenkins",
  "Mitchell",
  "Hayes",
  "Washington",
  "Edwards",
  "Jackson",
  "Powell",
  "Bennett",
  "Foster",
  "Reed",
  "Bailey",
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

function buildConferenceCatalogFromSnapshot(snapshot, totalGames) {
  const conferences = (snapshot?.conferences || []).map((conference) => {
    const normalizedConferenceName = decodeHtmlEntities(conference.name);
    const teams = (conference.teams || []).map((team) => ({
      id: team.id || slugify(`${normalizedConferenceName}-${team.name}`),
      name: decodeHtmlEntities(team.name),
    }));

    return {
      id: conference.id || slugify(normalizedConferenceName),
      name: normalizedConferenceName,
      teams,
      conferenceGamesTarget: normalizeConferenceGamesTarget(
        conference.inferredConferenceGames,
        teams.length,
        totalGames,
      ),
    };
  });

  return {
    source: snapshot?.source || null,
    conferenceCount: conferences.length,
    teamCount: conferences.reduce((sum, conference) => sum + conference.teams.length, 0),
    conferences,
  };
}

function randomInt(min, maxInclusive, random = Math.random) {
  return Math.floor(random() * (maxInclusive - min + 1)) + min;
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
  context.homeGamesByTeam.set(game.homeTeamId, (context.homeGamesByTeam.get(game.homeTeamId) || 0) + 1);
  context.awayGamesByTeam.set(game.awayTeamId, (context.awayGamesByTeam.get(game.awayTeamId) || 0) + 1);
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
