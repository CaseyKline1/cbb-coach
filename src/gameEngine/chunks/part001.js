const { createPlayer } = require("./player");
const { createCoachingStaff } = require("./coach");

const CHUNK_SECONDS = 5;
const HALF_SECONDS = 20 * 60;
const OVERTIME_SECONDS = 5 * 60;
const SHOT_CLOCK_SECONDS = 30;
const REGULATION_HALVES = 2;
const CLUTCH_TIME_SECONDS = 2 * 60;
const CLOSE_GAME_MARGIN = 6;
const CLUTCH_RATING_IMPACT = 0.08;
const EARLY_CLOCK_SHOT_ATTEMPT_BONUS = 0;
const CONTESTED_SHOOTING_FOUL_BASE_CHANCE = 0.15;
const PASS_DELIVERY_COMPLETION_EDGE_BONUS = 0.52;
const LAYUP_MAKE_EDGE_BONUS = 0.22;
const DUNK_MAKE_EDGE_BONUS = 0.31;
const MIDRANGE_MAKE_EDGE_PENALTY = 0.4;
const HOOK_MAKE_EDGE_BONUS = 0.08;
const FADEAWAY_MAKE_EDGE_PENALTY = 0.06;
const THREE_POINT_MAKE_EDGE_PENALTY = 0.42;
const THREE_POINT_CONTESTED_EXTRA_PENALTY = 0.12;
const THREE_POINT_SUCCESS_PROBABILITY_PENALTY = 0.125;
const GLOBAL_SHOT_MAKE_PROBABILITY_PENALTY = 0.04;
const PRESS_BASE_TRIGGER_CHANCE = 0.06;
const PRESS_HIGH_TENDENCY_TRIGGER_BONUS = 0.4;
const PRESS_LATE_GAME_TRAIL_BONUS = 0.38;
const PRESS_TRAP_BASE_CHANCE = 0.62;
const PRESS_ATTACK_AFTER_BREAK_BASE_CHANCE = 0.48;
const COACHING_EDGE_MAX_MULTIPLIER = 0.055;
const HEAD_COACH_GAME_IMPACT_WEIGHT = 0.72;
const GAME_PREP_ASSISTANT_GAME_IMPACT_WEIGHT = 0.28;

const OffensiveSpot = Object.freeze({
  MIDDLE_PAINT: "middle_paint",
  RIGHT_POST: "right_post",
  LEFT_POST: "left_post",
  RIGHT_SLOT: "right_slot",
  LEFT_SLOT: "left_slot",
  RIGHT_ELBOW: "right_elbow",
  LEFT_ELBOW: "left_elbow",
  FT_LINE: "ft_line",
  TOP_MIDDLE: "top_middle",
  TOP_RIGHT: "top_right",
  TOP_LEFT: "top_left",
  RIGHT_CORNER: "right_corner",
  LEFT_CORNER: "left_corner",
});

const OffensiveFormation = Object.freeze({
  FIVE_OUT: "5_out",
  FOUR_OUT_ONE_POST: "4_out_1_post",
  HIGH_LOW: "high_low",
  TRIANGLE: "triangle",
  MOTION: "motion",
});
const OFFENSIVE_FORMATION_VALUES = Object.values(OffensiveFormation);

const DefenseScheme = Object.freeze({
  MAN_TO_MAN: "man_to_man",
  ZONE_2_3: "2_3",
  ZONE_3_2: "3_2",
  ZONE_1_3_1: "1_3_1",
  PACK_LINE: "pack_line",
});

const PaceProfile = Object.freeze({
  VERY_SLOW: "very_slow",
  SLOW: "slow",
  SLIGHTLY_SLOW: "slightly_slow",
  NORMAL: "normal",
  SLIGHTLY_FAST: "slightly_fast",
  FAST: "fast",
  VERY_FAST: "very_fast",
});

const PACE_TO_SHOT_BIAS = Object.freeze({
  [PaceProfile.VERY_SLOW]: -0.1,
  [PaceProfile.SLOW]: -0.07,
  [PaceProfile.SLIGHTLY_SLOW]: -0.035,
  [PaceProfile.NORMAL]: 0,
  [PaceProfile.SLIGHTLY_FAST]: 0.03,
  [PaceProfile.FAST]: 0.06,
  [PaceProfile.VERY_FAST]: 0.09,
});

const PACE_TO_FASTBREAK_BIAS = Object.freeze({
  [PaceProfile.VERY_SLOW]: -0.16,
  [PaceProfile.SLOW]: -0.1,
  [PaceProfile.SLIGHTLY_SLOW]: -0.05,
  [PaceProfile.NORMAL]: 0,
  [PaceProfile.SLIGHTLY_FAST]: 0.06,
  [PaceProfile.FAST]: 0.12,
  [PaceProfile.VERY_FAST]: 0.18,
});

const spotCoords = {
  [OffensiveSpot.MIDDLE_PAINT]: { x: 0, y: 2 },
  [OffensiveSpot.RIGHT_POST]: { x: 2, y: 2 },
  [OffensiveSpot.LEFT_POST]: { x: -2, y: 2 },
  [OffensiveSpot.RIGHT_SLOT]: { x: 3, y: 5 },
  [OffensiveSpot.LEFT_SLOT]: { x: -3, y: 5 },
  [OffensiveSpot.RIGHT_ELBOW]: { x: 2, y: 4 },
  [OffensiveSpot.LEFT_ELBOW]: { x: -2, y: 4 },
  [OffensiveSpot.FT_LINE]: { x: 0, y: 4 },
  [OffensiveSpot.TOP_MIDDLE]: { x: 0, y: 7 },
  [OffensiveSpot.TOP_RIGHT]: { x: 2.5, y: 7 },
  [OffensiveSpot.TOP_LEFT]: { x: -2.5, y: 7 },
  [OffensiveSpot.RIGHT_CORNER]: { x: 4.5, y: 1.5 },
  [OffensiveSpot.LEFT_CORNER]: { x: -4.5, y: 1.5 },
};

const zoneAnchors = {
  [DefenseScheme.ZONE_2_3]: [
    { x: -2, y: 4 },
    { x: 2, y: 4 },
    { x: -3, y: 2 },
    { x: 3, y: 2 },
    { x: 0, y: 2 },
  ],
  [DefenseScheme.ZONE_3_2]: [
    { x: 0, y: 7 },
    { x: 2, y: 4 },
    { x: -2, y: 4 },
    { x: 2, y: 2 },
    { x: -2, y: 2 },
  ],
  [DefenseScheme.ZONE_1_3_1]: [
    { x: 0, y: 7 },
    { x: 0, y: 4 },
    { x: 4.5, y: 1.5 },
    { x: -4.5, y: 1.5 },
    { x: 0, y: 2 },
  ],
  [DefenseScheme.PACK_LINE]: [
    { x: 0, y: 2 },
    { x: 1.2, y: 2.2 },
    { x: -1.2, y: 2.2 },
    { x: 0.8, y: 1.2 },
    { x: -0.8, y: 1.2 },
  ],
};

const allSpots = Object.values(OffensiveSpot);
const THREE_POINT_SHOT_TYPES = new Set(["three"]);
const BASE_CHUNK_ENERGY_DRAIN = 1.2;
const BASE_CHUNK_BENCH_RECOVERY = 1.65;
const FREE_THROW_BREAK_RECOVERY = 5.5;
const TIMEOUT_RECOVERY = 7.5;
const HALFTIME_RECOVERY = 18;
const FOUL_OUT_LIMIT = 5;
const MOBILITY_INTERACTION_RATINGS = new Set([
  "athleticism.burst",
  "athleticism.speed",
  "athleticism.agility",
  "defense.lateralQuickness",
]);

function ensurePlayerCondition(player) {
  if (!player.condition) player.condition = {};
  if (!Number.isFinite(Number(player.condition.energy))) {
    player.condition.energy = 100;
  }
  player.condition.energy = clamp(Number(player.condition.energy), 0, 100);
}

function getTeamRoster(team) {
  const byRef = new Set();
  const roster = [];
  const candidates = [];
  if (Array.isArray(team?.players)) candidates.push(...team.players);
  if (Array.isArray(team?.lineup)) candidates.push(...team.lineup);

  candidates.forEach((player) => {
    if (player && !byRef.has(player)) {
      byRef.add(player);
      roster.push(player);
    }
  });
  return roster;
}

function getCurrentPeriodLengthSeconds(state) {
  return state.currentHalf <= REGULATION_HALVES ? HALF_SECONDS : OVERTIME_SECONDS;
}

function getElapsedSecondsInCurrentPeriod(state) {
  return getCurrentPeriodLengthSeconds(state) - state.gameClockRemaining;
}

function getElapsedGameSeconds(state) {
  const completedSeconds =
    state.currentHalf <= REGULATION_HALVES
      ? (state.currentHalf - 1) * HALF_SECONDS
      : REGULATION_HALVES * HALF_SECONDS + (state.currentHalf - (REGULATION_HALVES + 1)) * OVERTIME_SECONDS;
  return completedSeconds + getElapsedSecondsInCurrentPeriod(state);
}

function isInOvertime(state) {
  return state.currentHalf > REGULATION_HALVES;
}

function getScoreMargin(state) {
  return Math.abs((state.teams?.[0]?.score || 0) - (state.teams?.[1]?.score || 0));
}

function isClutchTimeActive(state) {
  if (isInOvertime(state)) return true;
  return (
    state.currentHalf === REGULATION_HALVES &&
    state.gameClockRemaining <= CLUTCH_TIME_SECONDS &&
    getScoreMargin(state) <= CLOSE_GAME_MARGIN
  );
}

function syncClutchTimeState(state) {
  const clutchActive = isClutchTimeActive(state);
  state.teams.forEach((team) => {
    getTeamRoster(team).forEach((player) => {
      ensurePlayerCondition(player);
      player.condition.clutchTime = clutchActive;
    });
  });
}

function applyClutchModifier(player, rating) {
  if (!player?.condition?.clutchTime) return rating;
  const clutch = getBaseRating(player, "skills.clutch", 50);
  const clutchEdge = clamp((clutch - 50) / 50, -1, 1);
  const multiplier = 1 + clutchEdge * CLUTCH_RATING_IMPACT;
  return clamp(rating * multiplier, 1, 100);
}

function createEmptyPlayerBoxScore(player) {
  return {
    playerName: player?.bio?.name || "Unknown",
    position: player?.bio?.position || "",
    minutes: 0,
    points: 0,
    fgMade: 0,
    fgAttempts: 0,
    threeMade: 0,
    threeAttempts: 0,
    ftMade: 0,
    ftAttempts: 0,
    rebounds: 0,
    offensiveRebounds: 0,
    defensiveRebounds: 0,
    assists: 0,
    steals: 0,
    blocks: 0,
    turnovers: 0,
    fouls: 0,
  };
}

function initializeBoxScoreTracker(teams) {
  return {
    teams: teams.map((team) => ({
      name: team.name,
      players: getTeamRoster(team).map((player) => ({
        player,
        stats: createEmptyPlayerBoxScore(player),
      })),
      playerIndexByRef: new Map(getTeamRoster(team).map((player, index) => [player, index])),
      teamExtras: {
        turnovers: 0,
      },
    })),
  };
}

function getPlayerStatsLine(state, teamId, player) {
  if (teamId === undefined || teamId === null || !player) return null;
  const tracker = state.boxScore?.teams?.[teamId];
  if (!tracker) return null;
  const playerIndex = tracker.playerIndexByRef.get(player);
  if (playerIndex === undefined) return null;
  return tracker.players[playerIndex].stats;
}

function addPlayerStat(state, teamId, player, stat, amount = 1) {
  const line = getPlayerStatsLine(state, teamId, player);
  if (!line || !Object.prototype.hasOwnProperty.call(line, stat)) return;
  line[stat] += amount;
}

function getPlayerFouls(state, teamId, player) {
  const line = getPlayerStatsLine(state, teamId, player);
  const fouls = Number(line?.fouls);
  return Number.isFinite(fouls) ? fouls : 0;
}

function isPlayerFouledOut(state, teamId, player) {
  return getPlayerFouls(state, teamId, player) >= FOUL_OUT_LIMIT;
}

function addTeamExtra(state, teamId, stat, amount = 1) {
  const tracker = state.boxScore?.teams?.[teamId];
  if (!tracker?.teamExtras || !Object.prototype.hasOwnProperty.call(tracker.teamExtras, stat)) return;
  tracker.teamExtras[stat] += amount;
}

function recordTurnover(state, offenseTeamId, ballHandler, defenseTeamId, defender) {
  addPlayerStat(state, offenseTeamId, ballHandler, "turnovers", 1);
  addPlayerStat(state, defenseTeamId, defender, "steals", 1);
}

function recordFieldGoalAttempt(state, teamId, shooter, shotType, made) {
  addPlayerStat(state, teamId, shooter, "fgAttempts", 1);
  if (made) addPlayerStat(state, teamId, shooter, "fgMade", 1);

  if (THREE_POINT_SHOT_TYPES.has(shotType)) {
    addPlayerStat(state, teamId, shooter, "threeAttempts", 1);
    if (made) addPlayerStat(state, teamId, shooter, "threeMade", 1);
  }
}

function recordFreeThrows(state, teamId, shooter, attempts, made) {
  addPlayerStat(state, teamId, shooter, "ftAttempts", attempts);
  addPlayerStat(state, teamId, shooter, "ftMade", made);
}

function recordRebound(state, teamId, rebounder, isOffensive) {
  addPlayerStat(state, teamId, rebounder, "rebounds", 1);
  if (isOffensive) addPlayerStat(state, teamId, rebounder, "offensiveRebounds", 1);
  else addPlayerStat(state, teamId, rebounder, "defensiveRebounds", 1);
}

function getPlayerEnergy(player) {
  ensurePlayerCondition(player);
  return player.condition.energy;
}

function setPlayerEnergy(player, value) {
  ensurePlayerCondition(player);
  player.condition.energy = clamp(value, 0, 100);
}

function getStaminaFactor(player) {
  const stamina = getRating(player, "athleticism.stamina");
  return clamp(1.15 - (stamina - 50) / 130, 0.72, 1.45);
}

function applyEnergyDelta(player, delta) {
  setPlayerEnergy(player, getPlayerEnergy(player) + delta);
}

function recoverAllPlayers(state, amount) {
  state.teams.forEach((team) => {
    getTeamRoster(team).forEach((player) => {
      const staminaBonus = clamp((getRating(player, "athleticism.stamina") - 50) / 160, -0.2, 0.35);
      applyEnergyDelta(player, amount * (1 + staminaBonus));
    });
  });
}

function getBaseRating(player, path, fallback = 50) {
  const [group, key] = path.split(".");
  const raw = player?.[group]?.[key];
  if (raw === undefined || raw === null) return fallback;
  const value = Number(raw);
  if (!Number.isFinite(value)) return fallback;
  if (value <= 1) return fallback;
  if (value <= 10) return value * 10;
  return value;
}

function getPlayerOverallSkill(player) {
  return average([
    getBaseRating(player, "skills.shotIQ"),
    getBaseRating(player, "skills.ballHandling"),
    getBaseRating(player, "skills.passingIQ"),
    getBaseRating(player, "shooting.threePointShooting"),
    getBaseRating(player, "shooting.midrangeShot"),
    getBaseRating(player, "shooting.closeShot"),
    getBaseRating(player, "defense.perimeterDefense"),
    getBaseRating(player, "defense.postDefense"),
    getBaseRating(player, "rebounding.defensiveRebound"),
    getBaseRating(player, "athleticism.speed"),
    getBaseRating(player, "athleticism.agility"),
  ]);
}

function getPlayerMinutesPlayed(state, teamId, player) {
  const line = getPlayerStatsLine(state, teamId, player);
  return line?.minutes || 0;
}

function getTargetMinutesMap(state, teamId) {
  const team = state.teams[teamId];
  const roster = getTeamRoster(team);
  const totalTeamMinutes = 200;
  const namedTargets = team.rotation?.minuteTargets;

  if (namedTargets && typeof namedTargets === "object") {
    const map = new Map();
    roster.forEach((player) => {
      const name = player?.bio?.name || "";
      const raw = Number(namedTargets[name]);
      if (Number.isFinite(raw) && raw >= 0) map.set(player, raw);
    });
    if (map.size) {
      const sum = [...map.values()].reduce((a, b) => a + b, 0);
      if (sum > 0) {
        const scale = totalTeamMinutes / sum;
        [...map.keys()].forEach((p) => map.set(p, clamp(map.get(p) * scale, 0, 40)));
      }
      roster.forEach((player) => {
        if (!map.has(player)) map.set(player, 0);
      });
      return map;
    }
  }

  const floor = roster.length > 5 ? 4 : 0;
  const remaining = Math.max(0, totalTeamMinutes - floor * roster.length);
  const weights = roster.map((player) => ({
    player,
    weight: Math.max(1, getPlayerOverallSkill(player)),
  }));
  const totalWeight = weights.reduce((sum, item) => sum + item.weight, 0);
  const map = new Map();
  weights.forEach((item) => {
    const share = totalWeight > 0 ? remaining * (item.weight / totalWeight) : remaining / weights.length;
    map.set(item.player, clamp(floor + share, 0, 40));
  });
  return map;
}

function rankLineupCandidates(state, teamId) {
  const team = state.teams[teamId];
  const roster = getTeamRoster(team);
  const targetMinutes = getTargetMinutesMap(state, teamId);
  const regulationSeconds = HALF_SECONDS * REGULATION_HALVES;
  const elapsedGameSeconds = getElapsedGameSeconds(state);
  const progress = clamp(elapsedGameSeconds / regulationSeconds, 0, 1.5);
  const closingWindow = isClutchTimeActive(state) || progress >= 0.92;
  const rotationWeight = closingWindow ? 1.85 : progress < 0.7 ? 4.35 : progress < 0.9 ? 3.6 : 2.4;

  return roster
    .filter((player) => !isPlayerFouledOut(state, teamId, player))
    .map((player) => {
      const energy = getPlayerEnergy(player);
      const skill = getPlayerOverallSkill(player);
      const minutesPlayed = getPlayerMinutesPlayed(state, teamId, player);
      const target = targetMinutes.get(player) ?? 0;
      const rotationNeed = clamp(target - minutesPlayed, -14, 24);
      // Push minute-target catch-up strongly before late-game closing lineups.
      const score = skill * 0.56 + energy * 0.27 + rotationNeed * rotationWeight;
      return {
        player,
        score,
        energy,
        skill,
        minutesPlayed,
        target,
        rotationNeed,
