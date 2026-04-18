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
  buildLeagueCatalog,
  createD1League,
  listUserNonConferenceOptions,
  setUserNonConferenceOpponents,
  autoFillUserNonConferenceOpponents,
  generateSeasonSchedule,
  getUserSchedule,
  advanceToNextUserGame,
  getUserCompletedGames,
  getConferenceStandings,
  getLeagueSummary,
};
