const { createPlayer } = require("./player");

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
  return roster
    .filter((player) => !isPlayerFouledOut(state, teamId, player))
    .map((player) => {
      const energy = getPlayerEnergy(player);
      const skill = getPlayerOverallSkill(player);
      const minutesPlayed = getPlayerMinutesPlayed(state, teamId, player);
      const target = targetMinutes.get(player) ?? 0;
      const rotationNeed = clamp(target - minutesPlayed, -12, 20);
      const score = skill * 0.62 + energy * 0.3 + rotationNeed * 1.9;
      return {
        player,
        score,
        energy,
        skill,
        minutesPlayed,
        target,
        rotationNeed,
      };
    })
    .sort((a, b) => b.score - a.score);
}

function runDeadBallSubstitutions(state, reason = "dead_ball") {
  const elapsedGameSeconds = getElapsedGameSeconds(state);

  state.teams.forEach((team, teamId) => {
    if (!Array.isArray(team.lineup) || team.lineup.length !== 5) return;
    if (reason !== "halftime" && reason !== "timeout") {
      const last = Number(team.lastSubElapsedGameSeconds);
      if (Number.isFinite(last) && elapsedGameSeconds - last < 25) {
        return;
      }
    }

    const ranked = rankLineupCandidates(state, teamId);
    const current = [...team.lineup];
    const currentSet = new Set(current);

    if (reason === "halftime") {
      const next = ranked.slice(0, 5).map((entry) => entry.player);
      if (next.length < 5) {
        current.forEach((player) => {
          if (next.length >= 5) return;
          if (!next.includes(player) && !isPlayerFouledOut(state, teamId, player)) {
            next.push(player);
          }
        });
      }
      if (next.length < 5) {
        current.forEach((player) => {
          if (next.length < 5 && !next.includes(player)) next.push(player);
        });
      }
      const changed = next.filter((player) => !currentSet.has(player)).length;
      if (changed > 0) {
        team.lineup = next;
        team.lastSubElapsedGameSeconds = elapsedGameSeconds;
        pushEvent(state, {
          type: "substitution",
          team: team.name,
          reason,
          swaps: changed,
        });
      }
      return;
    }

    const maxSwaps = 2;
    let swaps = 0;
    const next = [...current];
    let bench = ranked.filter((entry) => !next.includes(entry.player));

    // Force out fouled-out players at dead balls if an eligible bench option exists.
    for (let idx = 0; idx < next.length; idx += 1) {
      if (!isPlayerFouledOut(state, teamId, next[idx])) continue;
      const replacement = bench.shift();
      if (!replacement) break;
      next[idx] = replacement.player;
      swaps += 1;
      bench = ranked.filter((entry) => !next.includes(entry.player));
    }

    const scoreByPlayer = new Map(ranked.map((entry) => [entry.player, entry]));

    while (swaps < maxSwaps) {
      const onCourt = next
        .map((player, idx) => ({ idx, player, ...(scoreByPlayer.get(player) || {}) }))
        .sort((a, b) => (a.score ?? -9999) - (b.score ?? -9999));
      if (!bench.length || !onCourt.length) break;

      const outCandidate = onCourt[0];
      const inCandidate = bench[0];
      if (!outCandidate || !inCandidate) break;

      const betterBy = (inCandidate.score ?? 0) - (outCandidate.score ?? 0);
      const fatigueUpgrade =
        (outCandidate.energy ?? getPlayerEnergy(outCandidate.player)) < 42 &&
        inCandidate.energy > (outCandidate.energy ?? getPlayerEnergy(outCandidate.player)) + 8;
      const rotationUpgrade =
        (inCandidate.rotationNeed ?? 0) > 2.5 &&
        ((outCandidate.minutesPlayed ?? 0) - (outCandidate.target ?? 0) > 1.5);

      if (!(betterBy > 6 || fatigueUpgrade || rotationUpgrade)) break;

      next[outCandidate.idx] = inCandidate.player;
      swaps += 1;
      bench = ranked.filter((entry) => !next.includes(entry.player));
    }

    if (swaps > 0) {
      team.lineup = next;
      team.lastSubElapsedGameSeconds = elapsedGameSeconds;
      pushEvent(state, {
        type: "substitution",
        team: team.name,
        reason,
        swaps,
      });
    }
  });
}

function maybeTakeTimeout(state, random = Math.random) {
  const teams = [0, 1];
  for (const teamId of teams) {
    const team = state.teams[teamId];
    team.timeoutsRemaining = Number.isFinite(team.timeoutsRemaining) ? team.timeoutsRemaining : 4;
    if (team.timeoutsRemaining <= 0) continue;

    const avgLineupEnergy = average(team.lineup.map((player) => getPlayerEnergy(player)));
    const urgency = state.shotClockRemaining <= 10 ? 0.03 : 0;
    const fatigueNeed = avgLineupEnergy < 48 ? 0.08 : avgLineupEnergy < 58 ? 0.035 : 0;
    if (random() < urgency + fatigueNeed) {
      team.timeoutsRemaining -= 1;
      recoverAllPlayers(state, TIMEOUT_RECOVERY);
      state.pendingTransition = null;
      state.possessionNeedsSetup = true;
      pushEvent(state, {
        type: "timeout",
        offenseTeam: state.teams[state.possessionTeamId].name,
        calledBy: team.name,
      });
      runDeadBallSubstitutions(state, "timeout");
      return true;
    }
  }
  return false;
}

function applyChunkMinutesAndEnergy(state, involvementByTeam = [new Map(), new Map()]) {
  state.teams.forEach((team, teamId) => {
    const onCourtSet = new Set(team.lineup);
    const involvementMap = involvementByTeam[teamId] || new Map();

    team.lineup.forEach((player) => {
      addPlayerStat(state, teamId, player, "minutes", CHUNK_SECONDS / 60);
      const involvement = involvementMap.get(player) || 0;
      const staminaFactor = getStaminaFactor(player);
      const drain = (BASE_CHUNK_ENERGY_DRAIN + involvement * 0.95) * staminaFactor;
      applyEnergyDelta(player, -drain);
    });

    getTeamRoster(team)
      .filter((player) => !onCourtSet.has(player))
      .forEach((player) => {
        const staminaRecovery = clamp((getRating(player, "athleticism.stamina") - 50) / 120, -0.25, 0.45);
        applyEnergyDelta(player, BASE_CHUNK_BENCH_RECOVERY * (1 + staminaRecovery));
      });
  });
}

function clamp(value, min, max) {
  return Math.max(min, Math.min(max, value));
}

function average(values) {
  if (!values.length) return 0;
  return values.reduce((sum, value) => sum + value, 0) / values.length;
}

function dist(a, b) {
  const dx = a.x - b.x;
  const dy = a.y - b.y;
  return Math.sqrt(dx * dx + dy * dy);
}

function pickWeighted(items, random = Math.random) {
  const total = items.reduce((sum, item) => sum + Math.max(0, item.weight), 0);
  if (total <= 0) return items[0].value;

  let roll = random() * total;
  for (const item of items) {
    roll -= Math.max(0, item.weight);
    if (roll <= 0) return item.value;
  }
  return items[items.length - 1].value;
}

function getRating(player, path, fallback = 50) {
  const [group, key] = path.split(".");
  const raw = player?.[group]?.[key];
  if (raw === undefined || raw === null) return fallback;

  const value = Number(raw);
  if (!Number.isFinite(value)) return fallback;

  // Supports both placeholder defaults (~1) and mature 1-100 ratings.
  if (value <= 1) return fallback;
  if (value <= 10) return applyClutchModifier(player, value * 10);
  if (group === "athleticism" && (key === "stamina" || key === "durability")) {
    return applyClutchModifier(player, value);
  }

  const energy = Number(player?.condition?.energy);
  if (!Number.isFinite(energy)) return applyClutchModifier(player, value);

  const fatigue = clamp((100 - energy) / 100, 0, 0.85);
  let impact = 0.2;
  if (group === "athleticism") impact = 0.3;
  else if (group === "shooting") impact = 0.18;
  else if (group === "skills") impact = 0.24;
  else if (group === "defense") impact = 0.22;
  else if (group === "rebounding" || group === "postGame") impact = 0.2;

  return applyClutchModifier(player, value * (1 - fatigue * impact));
}

function makeStrengthBiasedWeights(ratings, random = Math.random) {
  const values = ratings.map((r) => r.value);
  const mean = average(values);

  return ratings.map((entry) => {
    const excellence = clamp((entry.value - mean) / 50, -1, 1);
    const baseline = 0.55 + random();
    const strengthBias = 1 + Math.max(0, excellence) * 0.35;
    return {
      label: entry.label,
      weight: baseline * strengthBias,
      value: entry.value,
    };
  });
}

function weightedSkillScore(player, ratingPaths, random = Math.random) {
  const ratings = ratingPaths.map((path) => ({
    label: path,
    value: getRating(player, path),
  }));
  const weighted = makeStrengthBiasedWeights(ratings, random);
  const totalWeight = weighted.reduce((sum, entry) => sum + entry.weight, 0);
  if (totalWeight <= 0) {
    return {
      score: average(ratings.map((r) => r.value)),
      weights: weighted,
    };
  }

  const score =
    weighted.reduce((sum, entry) => sum + entry.value * entry.weight, 0) / totalWeight;

  return { score, weights: weighted };
}

function logistic(x) {
  return 1 / (1 + Math.exp(-x));
}

function isMobilityInteraction(ratingPaths = []) {
  return ratingPaths.some((path) => MOBILITY_INTERACTION_RATINGS.has(path));
}

function getMobilitySizePenalty(player) {
  const heightPenalty = (getHeightInches(player) - 76) / 12;
  const weightPenalty = (getWeightPounds(player) - 205) / 80;
  return clamp(heightPenalty * 0.7 + weightPenalty * 0.9, -0.45, 1.35);
}

function getMobilitySizeEdge({
  offensePlayer,
  defensePlayer,
  offenseUsesMobility,
  defenseUsesMobility,
}) {
  if (!offenseUsesMobility && !defenseUsesMobility) return 0;
  const offensePenalty = offenseUsesMobility ? getMobilitySizePenalty(offensePlayer) : 0;
  const defensePenalty = defenseUsesMobility ? getMobilitySizePenalty(defensePlayer) : 0;
  return clamp((defensePenalty - offensePenalty) / 12, -0.16, 0.16);
}

function resolveInteraction({
  offensePlayer,
  defensePlayer,
  offenseRatings,
  defenseRatings,
  contextEdge = 0,
  random = Math.random,
}) {
  const offense = weightedSkillScore(offensePlayer, offenseRatings, random);
  const defense = weightedSkillScore(defensePlayer, defenseRatings, random);
  const offenseUsesMobility = isMobilityInteraction(offenseRatings);
  const defenseUsesMobility = isMobilityInteraction(defenseRatings);
  const mobilitySizeEdge = getMobilitySizeEdge({
    offensePlayer,
    defensePlayer,
    offenseUsesMobility,
    defenseUsesMobility,
  });
  const edge = (offense.score - defense.score) / 14 + contextEdge + mobilitySizeEdge;
  const successProbability = clamp(logistic(edge), 0.03, 0.97);

  return {
    success: random() < successProbability,
    successProbability,
    offense,
    defense,
    edge,
    mobilitySizeEdge,
  };
}

function getDefaultLineup(team) {
  if (team?.lineup?.length === 5) return team.lineup;
  if (team?.players?.length >= 5) return team.players.slice(0, 5);
  return new Array(5).fill(null).map(() => createPlayer());
}

function normalizeFormationCycle(formations, fallbackFormation = OffensiveFormation.MOTION) {
  const source = Array.isArray(formations) && formations.length
    ? formations
    : [fallbackFormation];
  const deduped = [];
  source.forEach((formation) => {
    if (!OFFENSIVE_FORMATION_VALUES.includes(formation)) return;
    if (!deduped.includes(formation)) deduped.push(formation);
  });
  return deduped.length ? deduped : [OffensiveFormation.MOTION];
}

function initializeTeamFormationState(team) {
  const cycle = normalizeFormationCycle(team.formations, team.formation);
  return {
    ...team,
    formations: cycle,
    formationCycleIndex: 0,
    formation: cycle[0],
  };
}

function getCurrentOffensiveFormation(team) {
  if (!team) return OffensiveFormation.MOTION;
  if (Array.isArray(team.formations) && team.formations.length > 0) {
    const index = Number.isInteger(team.formationCycleIndex)
      ? clamp(team.formationCycleIndex, 0, team.formations.length - 1)
      : 0;
    return team.formations[index];
  }
  return team.formation || OffensiveFormation.MOTION;
}

function advanceTeamOffensiveFormation(team) {
  if (!team || !Array.isArray(team.formations) || team.formations.length <= 1) return;
  const index = Number.isInteger(team.formationCycleIndex) ? team.formationCycleIndex : 0;
  const nextIndex = (index + 1) % team.formations.length;
  team.formationCycleIndex = nextIndex;
  team.formation = team.formations[nextIndex];
}

function getFormationSpots(formation) {
  switch (formation) {
    case OffensiveFormation.FIVE_OUT:
      return [
        OffensiveSpot.TOP_MIDDLE,
        OffensiveSpot.TOP_RIGHT,
        OffensiveSpot.TOP_LEFT,
        OffensiveSpot.RIGHT_CORNER,
        OffensiveSpot.LEFT_CORNER,
      ];
    case OffensiveFormation.FOUR_OUT_ONE_POST:
      return [
        OffensiveSpot.TOP_MIDDLE,
        OffensiveSpot.TOP_RIGHT,
        OffensiveSpot.TOP_LEFT,
        OffensiveSpot.RIGHT_CORNER,
        OffensiveSpot.LEFT_POST,
      ];
    case OffensiveFormation.HIGH_LOW:
      return [
        OffensiveSpot.TOP_MIDDLE,
        OffensiveSpot.RIGHT_SLOT,
        OffensiveSpot.LEFT_SLOT,
        OffensiveSpot.FT_LINE,
        OffensiveSpot.RIGHT_POST,
      ];
    case OffensiveFormation.TRIANGLE:
      return [
        OffensiveSpot.TOP_MIDDLE,
        OffensiveSpot.LEFT_SLOT,
        OffensiveSpot.LEFT_CORNER,
        OffensiveSpot.LEFT_POST,
        OffensiveSpot.RIGHT_SLOT,
      ];
    case OffensiveFormation.MOTION:
    default:
      return [
        OffensiveSpot.TOP_MIDDLE,
        OffensiveSpot.TOP_RIGHT,
        OffensiveSpot.LEFT_SLOT,
        OffensiveSpot.RIGHT_CORNER,
        OffensiveSpot.LEFT_POST,
      ];
  }
}

function assignOffensiveSpots(lineup, formation, random = Math.random) {
  const baseSpots = getFormationSpots(formation);
  const spots = [...baseSpots];

  if (formation === OffensiveFormation.MOTION) {
    for (let i = spots.length - 1; i > 0; i -= 1) {
      const j = Math.floor(random() * (i + 1));
      [spots[i], spots[j]] = [spots[j], spots[i]];
    }
  }

  return lineup.map((player, index) => ({
    player,
    spot: spots[index] ?? allSpots[index % allSpots.length],
  }));
}

function getOnBallDefender({
  defenseScheme,
  defenseLineup,
  offensiveAssignments,
  ballHandlerIndex,
}) {
  if (defenseScheme === DefenseScheme.MAN_TO_MAN) {
    return {
      defender: defenseLineup[ballHandlerIndex],
      startDistance: 0.8,
      isZone: false,
    };
  }

  const ballSpot = spotCoords[offensiveAssignments[ballHandlerIndex].spot];
  const anchors = zoneAnchors[defenseScheme] || zoneAnchors[DefenseScheme.ZONE_2_3];

  let bestIndex = 0;
  let bestDistance = Infinity;

  for (let i = 0; i < anchors.length; i += 1) {
    const d = dist(ballSpot, anchors[i]);
    if (d < bestDistance) {
      bestDistance = d;
      bestIndex = i;
    }
  }

  return {
    defender: defenseLineup[bestIndex],
    startDistance: bestDistance,
    isZone: true,
  };
}

function getDefenderCourtPositions({ defenseScheme, defenseLineup, offensiveAssignments }) {
  if (defenseScheme === DefenseScheme.MAN_TO_MAN) {
    const fallbackAnchors = zoneAnchors[DefenseScheme.ZONE_2_3] || [];
    return defenseLineup.map((player, index) => ({
      player,
      coord:
        spotCoords[offensiveAssignments?.[index]?.spot] ||
        fallbackAnchors[index] ||
        fallbackAnchors[fallbackAnchors.length - 1] || { x: 0, y: 2 },
    }));
  }

  const anchors = zoneAnchors[defenseScheme] || zoneAnchors[DefenseScheme.ZONE_2_3] || [];
  return defenseLineup.map((player, index) => ({
    player,
    coord: anchors[index] || anchors[anchors.length - 1] || { x: 0, y: 2 },
  }));
}

function pickNearestDefenderTeammate({
  blocker,
  defenseLineup,
  defenseScheme,
  offensiveAssignments,
}) {
  if (!Array.isArray(defenseLineup) || !defenseLineup.length) return blocker || null;
  if (defenseLineup.length === 1) return defenseLineup[0];

  const positions = getDefenderCourtPositions({
    defenseScheme,
    defenseLineup,
    offensiveAssignments,
  });
  const blockerPos = positions.find((entry) => entry.player === blocker)?.coord;
  const fallback = defenseLineup.find((player) => player !== blocker) || defenseLineup[0];
  if (!blockerPos) return fallback;

  let nearest = null;
  let nearestDistance = Infinity;
  positions.forEach((entry) => {
    if (!entry?.player || entry.player === blocker || !entry.coord) return;
    const teammateDistance = dist(blockerPos, entry.coord);
    if (teammateDistance < nearestDistance) {
      nearestDistance = teammateDistance;
      nearest = entry.player;
    }
  });

  return nearest || fallback;
}

function getOffenderCourtPositions({ offenseLineup, offensiveAssignments }) {
  const assignmentByPlayer = new Map(
    (offensiveAssignments || []).map((entry) => [entry.player, entry]),
  );
  return offenseLineup.map((player, index) => {
    const assignment = assignmentByPlayer.get(player) || offensiveAssignments?.[index];
    return {
      player,
      coord: spotCoords[assignment?.spot] || { x: 0, y: 4.5 },
    };
  });
}

function pickReboundDirection({ shooter, offensiveAssignments, random = Math.random }) {
  const assignmentByPlayer = new Map(
    (offensiveAssignments || []).map((entry) => [entry.player, entry]),
  );
  const shooterSpot = assignmentByPlayer.get(shooter)?.spot;
  const shooterX = spotCoords[shooterSpot]?.x || 0;

  let leftWeight = 1;
  let middleWeight = 1.15;
  let rightWeight = 1;
  if (shooterX < -1) leftWeight += 0.25;
  if (shooterX > 1) rightWeight += 0.25;
  if (Math.abs(shooterX) > 2.5) middleWeight -= 0.1;

  return pickWeighted(
    [
      { value: "left", weight: leftWeight },
      { value: "middle", weight: middleWeight },
      { value: "right", weight: rightWeight },
    ],
    random,
  );
}

function baseLongReboundChance(shotType) {
  if (shotType === "three") return 0.62;
  if (shotType === "midrange" || shotType === "fadeaway") return 0.42;
  if (shotType === "hook") return 0.36;
  return 0.28;
}

function buildReboundLandingSpot({ direction, isLong, random = Math.random }) {
  const directionX = direction === "left" ? -2.9 : direction === "right" ? 2.9 : 0;
  const baseY = isLong ? 6.1 : 2.35;
  const xJitter = (random() - 0.5) * (isLong ? 3.2 : 1.7);
  const yJitter = (random() - 0.5) * (isLong ? 1.8 : 1.2);
  return {
    x: clamp(directionX + xJitter, -4.8, 4.8),
    y: clamp(baseY + yJitter, 0.8, 8.4),
  };
}

function collectReboundBoxoutInteractions({
  offenseLineup,
  defenseLineup,
  offensePositions,
  defensePositions,
  defenseScheme,
}) {
  const interactions = [];
  if (defenseScheme === DefenseScheme.MAN_TO_MAN) {
    const count = Math.min(offenseLineup.length, defenseLineup.length);
    for (let i = 0; i < count; i += 1) {
      interactions.push({
        offense: offenseLineup[i],
        defense: defenseLineup[i],
      });
    }
    return interactions;
  }

  const offenseByPlayer = new Map(offensePositions.map((entry) => [entry.player, entry.coord]));
  const defenseByPlayer = new Map(defensePositions.map((entry) => [entry.player, entry.coord]));
  offenseLineup.forEach((offensePlayer) => {
    const oCoord = offenseByPlayer.get(offensePlayer);
    if (!oCoord) return;
    defenseLineup.forEach((defensePlayer) => {
      const dCoord = defenseByPlayer.get(defensePlayer);
      if (!dCoord) return;
      if (dist(oCoord, dCoord) <= 2.8) {
        interactions.push({ offense: offensePlayer, defense: defensePlayer });
      }
    });
  });
  return interactions;
}

function resolveBoxoutPositioning({
  offenseLineup,
  defenseLineup,
  offensePositions,
  defensePositions,
  defenseScheme,
  random = Math.random,
}) {
  const positioning = new Map();
  offenseLineup.forEach((player) => positioning.set(player, 1));
  defenseLineup.forEach((player) => positioning.set(player, 1));

  const interactions = collectReboundBoxoutInteractions({
    offenseLineup,
    defenseLineup,
    offensePositions,
    defensePositions,
    defenseScheme,
  });

  interactions.forEach(({ offense, defense }) => {
    const boxoutEdge = (getRating(offense, "rebounding.boxouts") - getRating(defense, "rebounding.boxouts")) / 20;
    const strengthEdge = (getRating(offense, "athleticism.strength") - getRating(defense, "athleticism.strength")) / 24;
    const weightEdge = (getWeightPounds(offense) - getWeightPounds(defense)) / 45;
    const edge = boxoutEdge * 0.64 + strengthEdge * 0.24 + weightEdge * 0.12;
    const offenseShare = clamp(logistic(edge + (random() - 0.5) * 0.08), 0.14, 0.86);
    const defenseShare = 1 - offenseShare;
    const offenseBump = 0.78 + offenseShare * 0.88;
    const defenseBump = 0.78 + defenseShare * 0.88;
    positioning.set(offense, clamp((positioning.get(offense) || 1) * offenseBump, 0.5, 2.25));
    positioning.set(defense, clamp((positioning.get(defense) || 1) * defenseBump, 0.5, 2.25));
  });

  return positioning;
}

function collectReboundCandidates({ offensePositions, defensePositions, landingSpot, radius }) {
  const candidates = [];
  offensePositions.forEach(({ player, coord }) => {
    const distance = dist(coord, landingSpot);
    if (distance <= radius) candidates.push({ player, team: "offense", distance });
  });
  defensePositions.forEach(({ player, coord }) => {
    const distance = dist(coord, landingSpot);
    if (distance <= radius) candidates.push({ player, team: "defense", distance });
  });
  return candidates;
}

function zoneDistanceAdvantage(defender, startDistance) {
  if (startDistance <= 1.5) return 0;
  const recoveryRatingPaths = [
    "athleticism.burst",
    "defense.lateralQuickness",
    "defense.perimeterDefense",
    "defense.offballDefense",
  ];

  const recovery = average(recoveryRatingPaths.map((path) => getRating(defender, path)));
  const distancePenalty = (startDistance - 1.5) * 0.2;
  const recoveryRelief = clamp((recovery - 50) / 100, -0.2, 0.25);
  return clamp(distancePenalty - recoveryRelief, 0, 0.45);
}

function pickBallHandler(offensiveAssignments, random = Math.random) {
  const weighted = offensiveAssignments.map(({ player }, index) => {
    const ballSkill = average([
      getRating(player, "skills.ballHandling"),
      getRating(player, "skills.shotIQ"),
      getRating(player, "skills.offballOffense"),
    ]);
    // Add light per-possession noise so the same creator isn't selected every time.
    const varianceFactor = 0.8 + random() * 0.4;
    return {
      value: index,
      weight: Math.max(1, ballSkill * varianceFactor),
    };
  });

  return pickWeighted(weighted, random);
}

function choosePlayType({ offenseTeam, ballHandler, random = Math.random }) {
  const drive = getRating(ballHandler, "tendencies.drive");
  const post = getRating(ballHandler, "tendencies.post");
  const pickAndRoll = getRating(ballHandler, "tendencies.pickAndRoll");
  const pickAndPop = getRating(ballHandler, "tendencies.pickAndPop");
  const shootVsPass = getRating(ballHandler, "tendencies.shootVsPass");
  const passAroundProfile = average([
    getRating(ballHandler, "skills.passingVision"),
    getRating(ballHandler, "skills.passingIQ"),
    getRating(ballHandler, "skills.passingAccuracy"),
    getRating(ballHandler, "skills.ballHandling"),
  ]);
  const passAround = clamp((100 - shootVsPass) * 0.55 + passAroundProfile * 0.5, 1, 115);

  const teamDriveBias = offenseTeam?.tendencies?.drive ?? 1;
  const teamPostBias = offenseTeam?.tendencies?.post ?? 1;
  const teamPassAroundBias = offenseTeam?.tendencies?.passAround ?? 1;
  const teamPickAndRollBias = offenseTeam?.tendencies?.pickAndRoll ?? 1;
  const teamPickAndPopBias = offenseTeam?.tendencies?.pickAndPop ?? 1;
  const ballSpot = offenseTeam?.context?.ballHandlerSpot;
  const formation = offenseTeam?.context?.formation;
  const passAroundFormationBoost =
    formation === OffensiveFormation.MOTION || formation === OffensiveFormation.FIVE_OUT ? 1.1 : 0.96;
  const pickFormationBoost =
    formation === OffensiveFormation.MOTION ||
    formation === OffensiveFormation.FIVE_OUT ||
    formation === OffensiveFormation.HIGH_LOW
      ? 1.07
      : 0.97;

  const postSpots = new Set([
    OffensiveSpot.RIGHT_POST,
    OffensiveSpot.LEFT_POST,
    OffensiveSpot.MIDDLE_PAINT,
    OffensiveSpot.RIGHT_SLOT,
    OffensiveSpot.LEFT_SLOT,
    OffensiveSpot.RIGHT_ELBOW,
    OffensiveSpot.LEFT_ELBOW,
  ]);

  const canPost = postSpots.has(ballSpot);
  const postDistancePenalty = postSpots.has(ballSpot)
    ? (ballSpot === OffensiveSpot.RIGHT_SLOT ||
      ballSpot === OffensiveSpot.LEFT_SLOT ||
      ballSpot === OffensiveSpot.RIGHT_ELBOW ||
      ballSpot === OffensiveSpot.LEFT_ELBOW
      ? 0.82
      : 1)
    : 0.2;

  return pickWeighted(
    [
      {
        value: "dribble_drive",
        weight: Math.max(1, drive) * teamDriveBias * 1.42,
      },
      {
        value: "post_up",
        weight: canPost ? Math.max(1, post) * teamPostBias * postDistancePenalty * 1.12 : 1,
      },
      {
        value: "pick_and_roll",
        weight:
          Math.max(
            1,
            pickAndRoll * 0.62 + drive * 0.22 + (100 - shootVsPass) * 0.16,
          ) *
          teamPickAndRollBias *
          pickFormationBoost *
          0.9,
      },
      {
        value: "pick_and_pop",
        weight:
          Math.max(
            1,
            pickAndPop * 0.62 + passAroundProfile * 0.2 + (100 - shootVsPass) * 0.18,
          ) *
          teamPickAndPopBias *
          pickFormationBoost *
          0.42,
      },
      {
        value: "pass_around_for_shot",
        weight: Math.max(1, passAround) * teamPassAroundBias * passAroundFormationBoost * 0.68,
      },
    ],
    random,
  );
}

function pickScreenerIndex({ offensiveAssignments, ballHandlerIndex, random = Math.random }) {
  const candidates = offensiveAssignments
    .map((assignment, idx) => ({ ...assignment, idx }))
    .filter((entry) => entry.idx !== ballHandlerIndex);

  if (!candidates.length) return ballHandlerIndex;

  return pickWeighted(
    candidates.map((entry) => {
      const heightInches = getHeightInches(entry.player);
      const weightPounds = getWeightPounds(entry.player);
      const screenProfile =
        getRating(entry.player, "athleticism.strength") * 0.56 +
        heightInches * 0.17 +
        weightPounds * 0.14 +
        getRating(entry.player, "skills.offballOffense") * 0.08 +
        getRating(entry.player, "skills.hands") * 0.05;
      return {
        value: entry.idx,
        weight: Math.max(1, screenProfile * (0.85 + random() * 0.3)),
      };
    }),
    random,
  );
}

function choosePopDestination(screener, random = Math.random) {
  const shotIQ = getRating(screener, "skills.shotIQ");
  const elbowUtility =
    getRating(screener, "shooting.midrangeShot") * 1.18 +
    getRating(screener, "tendencies.midrange") * 0.92 +
    getRating(screener, "skills.shotIQ") * 0.45;
  const threeUtility =
    getRating(screener, "shooting.threePointShooting") * 1.28 +
    getRating(screener, "shooting.upTopThrees") * 0.62 +
    getRating(screener, "tendencies.threePoint") * 1.02 +
    getRating(screener, "skills.shotIQ") * 0.35;

  const destinationType =
    shotIQ >= 72
      ? elbowUtility >= threeUtility
        ? "elbow"
        : "three"
      : pickWeighted(
          [
            { value: "elbow", weight: Math.max(1, elbowUtility) },
            { value: "three", weight: Math.max(1, threeUtility) },
          ],
          random,
        );

  if (destinationType === "elbow") {
    const spot = random() < 0.5 ? OffensiveSpot.RIGHT_ELBOW : OffensiveSpot.LEFT_ELBOW;
    return {
      destinationType,
      spot,
      shotType: "midrange",
      expectedShotValue: estimateOpenShotValue(screener, spot),
    };
  }

  const threeSpots = [OffensiveSpot.TOP_MIDDLE, OffensiveSpot.TOP_RIGHT, OffensiveSpot.TOP_LEFT];
  const spot = pickWeighted(
    threeSpots.map((candidate) => ({
      value: candidate,
      weight: Math.max(
        1,
        estimateOpenShotValue(screener, candidate) * 10 + getRating(screener, "shooting.upTopThrees"),
      ),
    })),
    random,
  );
  return {
    destinationType,
    spot,
    shotType: "three",
    expectedShotValue: estimateOpenShotValue(screener, spot),
  };
}

function resolvePickActionDynamics({
  ballHandler,
  screener,
  onBallDefender,
  screenerDefender,
  actionType,
  zonePenalty = 0,
  random = Math.random,
}) {
  const screenProfile =
    getRating(screener, "athleticism.strength") * 0.58 +
    getHeightInches(screener) * 0.16 +
    getWeightPounds(screener) * 0.16 +
    getRating(screener, "skills.offballOffense") * 0.1;
  const ballHandlerAssist =
    getRating(ballHandler, "skills.ballHandling") * 0.42 +
    getRating(ballHandler, "athleticism.agility") * 0.24 +
    getRating(ballHandler, "athleticism.burst") * 0.2 +
    getRating(ballHandler, "athleticism.speed") * 0.14;
  const offenseScreenPower = screenProfile * 0.86 + ballHandlerAssist * 0.14;

  const defenseNavigation = average([
    getRating(onBallDefender, "defense.lateralQuickness"),
    getRating(onBallDefender, "defense.perimeterDefense"),
    getRating(onBallDefender, "athleticism.agility"),
    getRating(screenerDefender, "defense.offballDefense"),
    getRating(screenerDefender, "athleticism.strength"),
    getRating(screenerDefender, "defense.defensiveControl"),
  ]);

  const screenEdge =
    (offenseScreenPower - defenseNavigation) / 18 +
    zonePenalty * 0.4 +
    (random() - 0.5) * 0.24;
  const screenEffectiveness = clamp(logistic(screenEdge), 0.05, 0.97);
  const disruption = clamp(
    screenEffectiveness * 0.88 + clamp(screenEdge, -0.55, 0.9) * 0.24,
    0.04,
    0.98,
  );

  const ballDriveThreat = average([
    getRating(ballHandler, "athleticism.burst"),
    getRating(ballHandler, "athleticism.agility"),
    getRating(ballHandler, "skills.ballHandling"),
    getRating(ballHandler, "tendencies.drive"),
    getRating(ballHandler, "shooting.layups"),
  ]);
  const ballShotThreat = average([
    getRating(ballHandler, "shooting.threePointShooting"),
    getRating(ballHandler, "shooting.midrangeShot"),
    getRating(ballHandler, "skills.shotIQ"),
    getRating(ballHandler, "tendencies.shootVsPass"),
  ]);
  const rollThreat = average([
    getRating(screener, "shooting.closeShot"),
    getRating(screener, "shooting.layups"),
    getRating(screener, "shooting.dunks"),
    getRating(screener, "skills.hands"),
    getRating(screener, "athleticism.strength"),
  ]);
  const popThreat = average([
    getRating(screener, "shooting.midrangeShot"),
    getRating(screener, "shooting.threePointShooting"),
    getRating(screener, "shooting.upTopThrees"),
    getRating(screener, "skills.shotIQ"),
    getRating(screener, "skills.hands"),
  ]);
  const screenerThreat = actionType === "pick_and_roll" ? rollThreat : popThreat;

  const onBallGuardBallShare = clamp(
    0.74 - disruption * 0.5 + (getRating(onBallDefender, "defense.lateralQuickness") - 50) / 190,
    0.14,
    0.94,
  );
  const screenerGuardBallShare = clamp(
    0.28 +
      (ballDriveThreat + ballShotThreat - screenerThreat) / 220 +
      disruption * 0.21 +
      (getRating(screenerDefender, "defense.defensiveControl") - 50) / 220,
    0.08,
    0.9,
  );

  const onBallDriveFocus = clamp(
    0.5 +
      (ballDriveThreat - ballShotThreat) / 210 +
      (getRating(onBallDefender, "defense.perimeterDefense") -
        getRating(onBallDefender, "defense.shotContest")) /
        220,
    0.1,
    0.9,
  );
  const screenerDriveFocus = clamp(
    0.5 +
      (rollThreat - popThreat) / 180 +
      (getRating(screenerDefender, "defense.postDefense") -
        getRating(screenerDefender, "defense.shotContest")) /
        230,
    0.1,
    0.9,
  );

  const ballHandlerPressure = clamp(
    onBallGuardBallShare * (0.5 + 0.5 * (1 - disruption)) + screenerGuardBallShare * 0.52,
    0.04,
    1,
  );
  const screenerPressure = clamp(
    (1 - onBallGuardBallShare) * 0.58 + (1 - screenerGuardBallShare) * 0.88,
    0.04,
    1,
  );

  return {
    screenEffectiveness,
    disruption,
    ballHandlerPressure,
    screenerPressure,
    onBallGuardBallShare,
    screenerGuardBallShare,
    onBallDriveFocus,
    screenerDriveFocus,
  };
}

function resolveShot({
  shooter,
  defender,
  shotType,
  shooterSpot = null,
  zonePenalty = 0,
  shotQualityEdge = 0,
  contested = true,
  random = Math.random,
}) {
  const isThreePointShot = THREE_POINT_SHOT_TYPES.has(shotType);
  const shotProfiles = {
    rim: {
      offenseRatings: [
        "shooting.layups",
        "shooting.closeShot",
        "athleticism.burst",
      ],
      defenseRatings: [
        "defense.shotContest",
        "defense.perimeterDefense",
        "athleticism.vertical",
      ],
      foulDraw: "shooting.drawFoul",
      basePoints: 2,
    },
    layup: {
      offenseRatings: [
        "shooting.layups",
        "shooting.closeShot",
        "athleticism.burst",
        "athleticism.vertical",
      ],
      defenseRatings: [
        "defense.shotContest",
        "athleticism.vertical",
        "defense.shotBlocking",
      ],
      foulDraw: "shooting.drawFoul",
      basePoints: 2,
    },
    dunk: {
      offenseRatings: [
        "shooting.dunks",
        "athleticism.vertical",
        "athleticism.strength",
      ],
      defenseRatings: [
        "defense.shotContest",
        "athleticism.vertical",
        "defense.shotBlocking",
      ],
      foulDraw: "shooting.drawFoul",
      basePoints: 2,
    },
    close: {
      offenseRatings: [
        "shooting.closeShot",
        "athleticism.agility",
      ],
      defenseRatings: [
        "defense.shotContest",
        "defense.perimeterDefense",
        "defense.lateralQuickness",
      ],
      foulDraw: "shooting.drawFoul",
      basePoints: 2,
    },
    midrange: {
      offenseRatings: [
        "shooting.midrangeShot",
        "athleticism.agility",
      ],
      defenseRatings: [
        "defense.shotContest",
        "defense.perimeterDefense",
        "defense.lateralQuickness",
      ],
      foulDraw: "shooting.drawFoul",
      basePoints: 2,
    },
    hook: {
      offenseRatings: [
        "postGame.postHooks",
        "postGame.postControl",
        "athleticism.strength",
      ],
      defenseRatings: [
        "defense.shotContest",
        "defense.postDefense",
        "defense.shotBlocking",
      ],
      foulDraw: "shooting.drawFoul",
      basePoints: 2,
    },
    fadeaway: {
      offenseRatings: [
        "postGame.postFadeaways",
        "shooting.midrangeShot",
      ],
      defenseRatings: [
        "defense.shotContest",
        "defense.postDefense",
      ],
      foulDraw: "shooting.drawFoul",
      basePoints: 2,
    },
    post: {
      offenseRatings: [
        "postGame.postControl",
        "postGame.postHooks",
        "postGame.postFadeaways",
        "athleticism.strength",
      ],
      defenseRatings: [
        "defense.postDefense",
        "defense.shotContest",
        "athleticism.strength",
      ],
      foulDraw: "shooting.drawFoul",
      basePoints: 2,
    },
    jump: {
      offenseRatings: [
        "shooting.midrangeShot",
        "athleticism.agility",
      ],
      defenseRatings: [
        "defense.shotContest",
        "defense.perimeterDefense",
        "defense.lateralQuickness",
      ],
      foulDraw: "shooting.drawFoul",
      basePoints: 2,
    },
    three: {
      offenseRatings: [
        "shooting.threePointShooting",
        "shooting.threePointSpecialty",
      ],
      defenseRatings: [
        "defense.shotContest",
        "defense.perimeterDefense",
        "defense.offballDefense",
      ],
      foulDraw: "shooting.drawFoul",
      basePoints: 3,
    },
  };

  const profile = shotProfiles[shotType] || shotProfiles.jump;
  const offensePlayer = isThreePointShot
    ? {
      ...shooter,
      shooting: {
        ...(shooter?.shooting || {}),
        threePointSpecialty: getThreePointSpecialtyRating(shooter, shooterSpot),
      },
    }
    : shooter;
  let shotTypeEdgeBonus = 0;
  if (shotType === "layup") shotTypeEdgeBonus += LAYUP_MAKE_EDGE_BONUS;
  if (shotType === "dunk") shotTypeEdgeBonus += DUNK_MAKE_EDGE_BONUS;
  if (shotType === "midrange") shotTypeEdgeBonus -= MIDRANGE_MAKE_EDGE_PENALTY;
  if (shotType === "hook") shotTypeEdgeBonus += HOOK_MAKE_EDGE_BONUS;
  if (shotType === "fadeaway") shotTypeEdgeBonus -= FADEAWAY_MAKE_EDGE_PENALTY;

  const contestedEdgePenalty = contested ? THREE_POINT_CONTESTED_EXTRA_PENALTY : 0;
  const shotTypeEdgePenalty = isThreePointShot
    ? THREE_POINT_MAKE_EDGE_PENALTY + contestedEdgePenalty
    : contestedEdgePenalty;
  const shotResult = resolveInteraction({
    offensePlayer,
    defensePlayer: defender,
    offenseRatings: profile.offenseRatings,
    defenseRatings: profile.defenseRatings,
    contextEdge: zonePenalty + shotQualityEdge + shotTypeEdgeBonus - shotTypeEdgePenalty,
    random,
  });

  const drawFoul = getRating(shooter, profile.foulDraw);
  const defensiveControl = getRating(defender, "defense.defensiveControl");
  const foulPressure = (drawFoul - defensiveControl) / 140;
  const baseFoulChance = clamp(CONTESTED_SHOOTING_FOUL_BASE_CHANCE + foulPressure, 0.08, 0.42);
  const isShootingFoul = contested && random() < baseFoulChance;

  let madeProbability = shotResult.successProbability;
  if (isThreePointShot) {
    madeProbability = clamp(madeProbability - THREE_POINT_SUCCESS_PROBABILITY_PENALTY, 0.02, 0.9);
  }
  madeProbability = clamp(madeProbability - GLOBAL_SHOT_MAKE_PROBABILITY_PENALTY, 0.02, 0.9);

  let made = random() < madeProbability;
  if (isShootingFoul) {
    const makePenalty = 0.12 - clamp((drawFoul - 50) / 400, -0.04, 0.07);
    const adjustedProbability = clamp(
      madeProbability - makePenalty,
      0.02,
      0.9,
    );
    made = random() < adjustedProbability;
  }

  return {
    made,
    points: made ? profile.basePoints : 0,
    shotType,
    shooter,
    defender,
    interaction: shotResult,
    isShootingFoul,
    foulShotsAwarded: isShootingFoul ? (profile.basePoints === 3 ? 3 : 2) : 0,
    madeOnFoul: isShootingFoul && made,
  };
}

function resolveBallSecurity({ offensePlayer, defensePlayer, zonePenalty, random = Math.random }) {
  const interaction = resolveInteraction({
    offensePlayer,
    defensePlayer,
    offenseRatings: ["skills.ballHandling", "skills.ballSafety", "athleticism.agility"],
    defenseRatings: ["defense.steals", "defense.passPerception", "defense.lateralQuickness"],
    contextEdge: zonePenalty,
    random,
  });

  return {
    turnover: !interaction.success,
    interaction,
  };
}

function resolvePass({ passer, defender, zonePenalty, random = Math.random }) {
  const interaction = resolveInteraction({
    offensePlayer: passer,
    defensePlayer: defender,
    offenseRatings: [
      "skills.passingAccuracy",
      "skills.passingVision",
      "skills.passingIQ",
      "skills.ballSafety",
    ],
    defenseRatings: ["defense.passPerception", "defense.steals", "defense.offballDefense"],
    contextEdge: zonePenalty,
    random,
  });

  return {
    turnover: !interaction.success,
    interaction,
  };
}

function parseLengthToInches(value, fallback = 78) {
  if (value === undefined || value === null || value === "") return fallback;
  if (typeof value === "number" && Number.isFinite(value)) return value;
  const str = String(value).trim();

  const dash = str.match(/^(\d+)\s*-\s*(\d+)$/);
  if (dash) return Number(dash[1]) * 12 + Number(dash[2]);

  const quote = str.match(/^(\d+)\s*'\s*(\d+)/);
  if (quote) return Number(quote[1]) * 12 + Number(quote[2]);

  const only = Number(str);
  if (Number.isFinite(only)) return only;
  return fallback;
}

function getHeightInches(player) {
  return parseLengthToInches(player?.size?.height, 78);
}

function getWingspanInches(player) {
  return parseLengthToInches(player?.size?.wingspan, getHeightInches(player) + 3);
}

function getPassInterceptionLengthBonus(player) {
  const wingspanEdge = getWingspanInches(player) - getHeightInches(player);
  if (wingspanEdge <= 2) return 0;
  return clamp((wingspanEdge - 2) / 80, 0, 0.06);
}

function getWeightPounds(player) {
  const raw = Number(player?.size?.weight);
  return Number.isFinite(raw) ? raw : 220;
}

function chooseShotFromTendencies(shooter, random = Math.random) {
  const shotIQ = getRating(shooter, "skills.shotIQ");
  const outcomes = [
    {
      type: "three",
      utility:
        getRating(shooter, "shooting.threePointShooting") * 1.5 +
        getRating(shooter, "tendencies.threePoint") * 0.9,
    },
    {
      type: "midrange",
      utility:
        getRating(shooter, "shooting.midrangeShot") * 1.3 +
        getRating(shooter, "tendencies.midrange") * 0.8,
    },
    {
      type: "close",
      utility:
        getRating(shooter, "shooting.closeShot") * 1.4 +
        getRating(shooter, "tendencies.inside") * 0.9,
    },
  ];

  if (shotIQ >= 70) {
    outcomes.sort((a, b) => b.utility - a.utility);
    return random() < 0.82 ? outcomes[0].type : outcomes[1].type;
  }

  return pickWeighted(
    outcomes.map((o) => ({ value: o.type, weight: Math.max(1, o.utility) })),
    random,
  );
}

function chooseDriveFinishType(shooter, random = Math.random) {
  const shotIQ = getRating(shooter, "skills.shotIQ");
  const layupQuality =
    getRating(shooter, "shooting.layups") +
    getRating(shooter, "shooting.closeShot") * 0.5;
  const dunkQuality =
    getRating(shooter, "shooting.dunks") +
    getRating(shooter, "athleticism.vertical") * 0.5;

  if (shotIQ >= 50) {
    return layupQuality >= dunkQuality ? "layup" : "dunk";
  }

  return random() < 0.55 ? "layup" : "dunk";
}

function isThreePointSpot(spot) {
  return (
    spot === OffensiveSpot.TOP_MIDDLE ||
    spot === OffensiveSpot.TOP_RIGHT ||
    spot === OffensiveSpot.TOP_LEFT ||
    spot === OffensiveSpot.RIGHT_CORNER ||
    spot === OffensiveSpot.LEFT_CORNER
  );
}

function isCornerThreeSpot(spot) {
  return spot === OffensiveSpot.RIGHT_CORNER || spot === OffensiveSpot.LEFT_CORNER;
}

function getThreePointSpecialtyRating(player, spot = null) {
  if (isCornerThreeSpot(spot)) {
    return getRating(player, "shooting.cornerThrees");
  }
  if (isThreePointSpot(spot)) {
    return getRating(player, "shooting.upTopThrees");
  }
  return average([
    getRating(player, "shooting.cornerThrees"),
    getRating(player, "shooting.upTopThrees"),
  ]);
}

function estimateOpenShotValue(receiver, spot) {
  if (isThreePointSpot(spot)) {
    const threeCore = getRating(receiver, "shooting.threePointShooting");
    const threeSpecialty = getThreePointSpecialtyRating(receiver, spot);
    const threeMake = clamp((threeCore * 0.7 + threeSpecialty * 0.3) / 100, 0.2, 0.75);
    return threeMake * 1.5;
  }

  const midrangeSpots = new Set([
    OffensiveSpot.RIGHT_SLOT,
    OffensiveSpot.LEFT_SLOT,
    OffensiveSpot.RIGHT_ELBOW,
    OffensiveSpot.LEFT_ELBOW,
    OffensiveSpot.FT_LINE,
  ]);
  if (midrangeSpots.has(spot)) {
    const twoMake = clamp(getRating(receiver, "shooting.midrangeShot") / 100, 0.22, 0.72);
    return twoMake;
  }

  const closeMake = clamp(
    (getRating(receiver, "shooting.closeShot") * 0.6 +
      getRating(receiver, "shooting.layups") * 0.4) /
      100,
    0.25,
    0.78,
  );
  return closeMake;
}

function resolveFreeThrows(shooter, attempts, random = Math.random) {
  const ftRating = getRating(shooter, "shooting.freeThrows");
  const makeChance = clamp(0.42 + (ftRating - 50) / 85, 0.35, 0.94);
  let made = 0;
  for (let i = 0; i < attempts; i += 1) {
    if (random() < makeChance) made += 1;
  }
  return made;
}

function getDefenderForOffensiveIndex({
  defenseScheme,
  defenseLineup,
  offensiveAssignments,
  offenseIndex,
}) {
  if (defenseScheme === DefenseScheme.MAN_TO_MAN) {
    return {
      defender: defenseLineup[offenseIndex],
      distance: 1,
    };
  }

  const spot = offensiveAssignments[offenseIndex].spot;
  const target = spotCoords[spot];
  const anchors = zoneAnchors[defenseScheme] || zoneAnchors[DefenseScheme.ZONE_2_3];
  let bestIndex = 0;
  let bestDistance = Infinity;
  for (let i = 0; i < anchors.length; i += 1) {
    const d = dist(target, anchors[i]);
    if (d < bestDistance) {
      bestDistance = d;
      bestIndex = i;
    }
  }

  return {
    defender: defenseLineup[bestIndex],
    distance: bestDistance,
  };
}

function isPaintSpot(spot) {
  return (
    spot === OffensiveSpot.MIDDLE_PAINT ||
    spot === OffensiveSpot.RIGHT_POST ||
    spot === OffensiveSpot.LEFT_POST
  );
}

function getOffballOpenLocationEdge(spot) {
  if (isThreePointSpot(spot)) return 0.11;
  if (spot === OffensiveSpot.RIGHT_SLOT || spot === OffensiveSpot.LEFT_SLOT) return 0.04;
  if (isPaintSpot(spot)) return -0.1;
  if (spot === OffensiveSpot.RIGHT_ELBOW || spot === OffensiveSpot.LEFT_ELBOW || spot === OffensiveSpot.FT_LINE) {
    return -0.04;
  }
  return 0;
}

function getNearbySpots(spot, maxDistance = 3.75) {
  const origin = spotCoords[spot];
  if (!origin) return [];
  return allSpots.filter((candidate) => {
    if (candidate === spot) return false;
    const coord = spotCoords[candidate];
    if (!coord) return false;
    return dist(origin, coord) <= maxDistance;
  });
}

function maybeRelocateOffBallPlayers({ offensiveAssignments, ballHandlerIndex, random = Math.random }) {
  const occupiedSpots = new Set(offensiveAssignments.map((assignment) => assignment.spot));

  offensiveAssignments.forEach((assignment, idx) => {
    if (idx === ballHandlerIndex) return;

    const player = assignment.player;
    const moveSkill = average([
      getRating(player, "skills.offballOffense"),
      getRating(player, "athleticism.agility"),
      getRating(player, "athleticism.speed"),
    ]);
    const moveChance = clamp(0.24 + (moveSkill - 50) / 115, 0.18, 0.76);
    if (random() >= moveChance) return;

    const nearby = getNearbySpots(assignment.spot).filter((spot) => !occupiedSpots.has(spot));
    if (!nearby.length) return;

    const currentCoord = spotCoords[assignment.spot];
    const threeBias = clamp((getRating(player, "tendencies.threePoint") - 45) / 45, -0.4, 1.2);
    const destination = pickWeighted(
      nearby.map((spot) => {
        const coord = spotCoords[spot];
        const travelEase = clamp(1.3 - dist(currentCoord, coord) / 4.5, 0.35, 1.2);
        const perimeterBoost = isThreePointSpot(spot) ? 0.45 * (1 + threeBias) : 0;
        const paintBoost = isPaintSpot(spot) ? 0.18 * Math.max(0, -threeBias) : 0;
        const offballEdge = getOffballOpenLocationEdge(spot) + 0.14;
        return {
          value: spot,
          weight: Math.max(1, 1 + travelEase + perimeterBoost + paintBoost + offballEdge),
        };
      }),
      random,
    );

    occupiedSpots.delete(assignment.spot);
    assignment.spot = destination;
    occupiedSpots.add(destination);
  });
}

function getNearbyPassDefenders({
  defenseScheme,
  defenseLineup,
  offensiveAssignments,
  ballHandlerDefender,
  receiverDefender,
  receiverSpot,
}) {
  const contributors = [];
  if (ballHandlerDefender) contributors.push(ballHandlerDefender);
  if (receiverDefender && receiverDefender !== ballHandlerDefender) contributors.push(receiverDefender);

  const receiverCoord = spotCoords[receiverSpot];
  if (!receiverCoord) return contributors.length ? contributors : defenseLineup.slice(0, 2);

  const defensePositions = getDefenderCourtPositions({
    defenseScheme,
    defenseLineup,
    offensiveAssignments,
  });

  defensePositions.forEach(({ player, coord }) => {
    if (!player || !coord) return;
    if (dist(coord, receiverCoord) > 2.8) return;
    if (!contributors.includes(player)) contributors.push(player);
  });

  if (!contributors.length) return defenseLineup.slice(0, 2);
  return contributors;
}

function resolveLooseBallRecovery({
  offenseLineup,
  defenseLineup,
  offenseTeamId,
  defenseTeamId,
  offensiveAssignments,
  defenseScheme,
  receiverSpot,
  random = Math.random,
}) {
  const receiverCoord = spotCoords[receiverSpot] || { x: 0, y: 4 };
  const radius = 2.8;
  const offensePositions = getOffenderCourtPositions({ offenseLineup, offensiveAssignments });
  const defensePositions = getDefenderCourtPositions({
    defenseScheme,
    defenseLineup,
    offensiveAssignments,
  });

  let candidates = [
    ...offensePositions.map(({ player, coord }) => ({
      player,
      coord,
      team: "offense",
      teamId: offenseTeamId,
      distance: dist(coord, receiverCoord),
    })),
    ...defensePositions.map(({ player, coord }) => ({
      player,
      coord,
      team: "defense",
      teamId: defenseTeamId,
      distance: dist(coord, receiverCoord),
    })),
  ].filter((entry) => entry.player && entry.distance <= radius);

  if (!candidates.length) {
    candidates = [
      ...offensePositions.map(({ player, coord }) => ({
        player,
        coord,
        team: "offense",
        teamId: offenseTeamId,
        distance: dist(coord, receiverCoord),
      })),
      ...defensePositions.map(({ player, coord }) => ({
        player,
        coord,
        team: "defense",
        teamId: defenseTeamId,
        distance: dist(coord, receiverCoord),
      })),
    ]
      .filter((entry) => entry.player)
      .sort((a, b) => a.distance - b.distance)
      .slice(0, 6);
  }

  const averageHustle = average(candidates.map((entry) => getRating(entry.player, "skills.hustle")));
  const averageBurst = average(candidates.map((entry) => getRating(entry.player, "athleticism.burst")));
  const averageHands = average(candidates.map((entry) => getRating(entry.player, "skills.hands")));
  const recoveredBy = pickWeighted(
    candidates.map((entry) => {
      const hustle = getRating(entry.player, "skills.hustle");
      const burst = getRating(entry.player, "athleticism.burst");
      const hands = getRating(entry.player, "skills.hands");
      const hustleEdge = (hustle - averageHustle) / 22;
      const burstEdge = (burst - averageBurst) / 24;
      const handsEdge = (hands - averageHands) / 28;
      const hustleMultiplier = clamp(1 + hustleEdge * 1.85, 0.25, 3.8);
      const burstMultiplier = clamp(1 + burstEdge * 0.42, 0.75, 1.35);
      const handsMultiplier = clamp(1 + handsEdge * 0.28, 0.8, 1.22);
      const proximityMultiplier = clamp(1.45 - entry.distance / (radius + 0.35), 0.25, 1.3);
      return {
        value: entry,
        weight: Math.max(
          0.15,
          proximityMultiplier * hustleMultiplier * burstMultiplier * handsMultiplier,
        ),
      };
    }),
    random,
  );

  return {
    recoveredByTeam: recoveredBy.team,
    recoveredByTeamId: recoveredBy.teamId,
    recoveredByPlayer: recoveredBy.player,
  };
}

function evaluatePassTarget({
  passer,
  receiver,
  receiverDefender,
  receiverSpot = null,
  threatBonus = 0,
  random = Math.random,
}) {
  const locationEdge = getOffballOpenLocationEdge(receiverSpot);
  const getOpen = resolveInteraction({
    offensePlayer: receiver,
    defensePlayer: receiverDefender,
    offenseRatings: ["skills.offballOffense", "athleticism.agility", "skills.hands"],
    defenseRatings: ["defense.offballDefense", "defense.lateralQuickness", "defense.perimeterDefense"],
    contextEdge: threatBonus + locationEdge,
    random,
  });

  const vision = resolveInteraction({
    offensePlayer: passer,
    defensePlayer: receiverDefender,
    offenseRatings: ["skills.passingVision", "skills.passingIQ"],
    defenseRatings: ["defense.offballDefense", "defense.passPerception"],
    contextEdge: threatBonus,
    random,
  });

  const openLevel = clamp((getOpen.edge + 0.8) / 1.6, 0, 1);

  return {
    openLevel,
    canSeeWindow: vision.success,
    getOpen,
    vision,
  };
}

function resolvePassDelivery({ passer, receiver, defenseContributors, zonePenalty = 0, random = Math.random }) {
  const relevantDefenders = (defenseContributors || []).filter(Boolean).slice(0, 1);
  const interceptionLengthBonus = average(relevantDefenders.map(getPassInterceptionLengthBonus));
  const passerSecurity = average([
    getRating(passer, "skills.ballHandling"),
    getRating(passer, "skills.ballSafety"),
    getRating(passer, "skills.passingIQ"),
  ]);
  const receiverSecurity = average([
    getRating(receiver, "skills.hands"),
    getRating(receiver, "skills.offballOffense"),
  ]);
  const passSecurityEdge = clamp((passerSecurity + receiverSecurity - 120) / 280, 0, 0.35);
  const compositeDefender = {
    skills: {},
    defense: {
      passPerception: average(relevantDefenders.map((p) => getRating(p, "defense.passPerception"))) * 0.85,
      steals: average(relevantDefenders.map((p) => getRating(p, "defense.steals"))) * 0.5,
      offballDefense: average(relevantDefenders.map((p) => getRating(p, "defense.offballDefense"))) * 0.7,
    },
    athleticism: {
      lateralQuickness: average(relevantDefenders.map((p) => getRating(p, "defense.lateralQuickness"))),
    },
  };

  const interaction = resolveInteraction({
    offensePlayer: {
      skills: {
        passingAccuracy: getRating(passer, "skills.passingAccuracy"),
        passingVision: getRating(passer, "skills.passingVision"),
        passingIQ: getRating(passer, "skills.passingIQ"),
        ballHandling: getRating(passer, "skills.ballHandling"),
        ballSafety: getRating(passer, "skills.ballSafety"),
        hands: getRating(receiver, "skills.hands"),
      },
      athleticism: {},
      defense: {},
    },
    defensePlayer: compositeDefender,
    offenseRatings: [
      "skills.passingAccuracy",
      "skills.hands",
      "skills.passingVision",
      "skills.passingIQ",
      "skills.ballHandling",
      "skills.ballSafety",
    ],
    defenseRatings: ["defense.passPerception", "defense.steals", "defense.offballDefense"],
    contextEdge: zonePenalty + PASS_DELIVERY_COMPLETION_EDGE_BONUS + passSecurityEdge - interceptionLengthBonus,
    random,
  });

  let stealBy = null;
  let stealByPlayer = null;
  let looseBall = false;
  if (!interaction.success) {
    const ballhawkPressure = average(
      relevantDefenders.map((d) =>
        getRating(d, "defense.steals") * 1.1 + getRating(d, "defense.passPerception") * 0.9,
      ),
    );
    const offensiveControl = average([
      getRating(passer, "skills.passingAccuracy"),
      getRating(passer, "skills.ballSafety"),
      getRating(receiver, "skills.hands"),
    ]);
    const failureSeverity = clamp((0.62 - interaction.successProbability) / 0.62, 0, 1);
    const stealOnFailureChance = clamp(
      0.8 + failureSeverity * 0.14 + (ballhawkPressure - offensiveControl) / 340 + interceptionLengthBonus * 0.45,
      0.7,
      0.95,
    );

    if (random() < stealOnFailureChance) {
      const defendersForSteal = (defenseContributors || []).filter(Boolean);
      const defender = defendersForSteal.length
        ? pickWeighted(
          defendersForSteal.map((d) => ({
            value: d,
            weight:
              (getRating(d, "defense.steals") + getRating(d, "defense.passPerception")) *
              (1 + getPassInterceptionLengthBonus(d) * 4),
          })),
          random,
        )
        : null;
      stealByPlayer = defender;
      stealBy = defender?.bio?.name || "Unknown";
    } else {
      looseBall = true;
    }
  }

  return {
    turnover: !interaction.success && !looseBall,
    looseBall,
    stealBy,
    stealByPlayer,
    interaction,
  };
}

function resolvePossessionEndAfterShot({
  state,
  offenseTeamId,
  defenseTeamId,
  offense,
  defense,
  offenseLineup,
  defenseLineup,
  defenseScheme,
  offensiveAssignments,
  playType,
  shotType,
  shot,
  transitionReboundMode = null,
  random = Math.random,
}) {
  const shooter = shot.shooter || offenseLineup[0];
  const primaryDefender = shot.defender || defenseLineup[0];
  applyPendingAssistIfEligible(state, offenseTeamId, shooter, shot);
  clearPendingAssist(state);

  recordFieldGoalAttempt(state, offenseTeamId, shooter, shotType, shot.made);

  if (shot.made) {
    offense.score += shot.points;
    addPlayerStat(state, offenseTeamId, shooter, "points", shot.points);
    if (shot.assister) {
      const contestedPenalty = shot.contested ? 0.52 : 1;
      const creationPenalty =
        playType === "dribble_drive" || playType === "post_up" ? 0.9 : 1;
      const assistCreditChance = clamp(0.9 * contestedPenalty * creationPenalty, 0.28, 0.92);
      if (random() < assistCreditChance) {
        addPlayerStat(state, offenseTeamId, shot.assister, "assists", 1);
      }
    }
    let foulDetail = "";
    if (shot.isShootingFoul) {
      addPlayerStat(state, defenseTeamId, primaryDefender, "fouls", 1);
      const attempts = shot.madeOnFoul ? 1 : shot.foulShotsAwarded;
      const bonus = resolveFreeThrows(
        shooter,
        attempts,
        random,
      );
      recordFreeThrows(state, offenseTeamId, shooter, attempts, bonus);
      addPlayerStat(state, offenseTeamId, shooter, "points", bonus);
      offense.score += bonus;
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
    offense.score += ftMade;
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

function createInitialGameState(homeTeam, awayTeam, random = Math.random) {
  const homeLineup = getDefaultLineup(homeTeam);
  const awayLineup = getDefaultLineup(awayTeam);
  const teams = [
    initializeTeamFormationState({
      ...homeTeam,
      players: homeTeam.players?.length ? homeTeam.players : homeLineup,
      lineup: homeLineup,
      score: 0,
      timeoutsRemaining: Number.isFinite(homeTeam.timeouts) ? homeTeam.timeouts : 4,
    }),
    initializeTeamFormationState({
      ...awayTeam,
      players: awayTeam.players?.length ? awayTeam.players : awayLineup,
      lineup: awayLineup,
      score: 0,
      timeoutsRemaining: Number.isFinite(awayTeam.timeouts) ? awayTeam.timeouts : 4,
    }),
  ];

  teams.forEach((team) => {
    getTeamRoster(team).forEach((player) => ensurePlayerCondition(player));
  });

  const state = {
    teams,
    boxScore: initializeBoxScoreTracker(teams),
    possessionTeamId: random() < 0.5 ? 0 : 1,
    gameClockRemaining: HALF_SECONDS,
    currentHalf: 1,
    shotClockRemaining: SHOT_CLOCK_SECONDS,
    possessionNeedsSetup: true,
    pendingAssist: null,
    pendingTransition: null,
    playByPlay: [],
  };
  syncClutchTimeState(state);
  return state;
}

function beginNewPossession(state, offenseTeamId, deadBallReason = null, options = null) {
  clearPendingAssist(state);
  state.possessionTeamId = offenseTeamId;
  advanceTeamOffensiveFormation(state.teams[offenseTeamId]);
  state.shotClockRemaining = SHOT_CLOCK_SECONDS;
  state.possessionNeedsSetup = true;
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

function getLateGamePaceShotBias(state, offenseTeamId) {
  const offense = state.teams?.[offenseTeamId];
  const defense = state.teams?.[nextDefenseTeamId(offenseTeamId)];
  if (!offense || !defense) return 0;

  const secondsLeftInGame =
    state.currentHalf === 1
      ? HALF_SECONDS + state.gameClockRemaining
      : state.currentHalf === 2
        ? state.gameClockRemaining
        : 0;
  if (secondsLeftInGame > 120) return 0;

  const scoreDiff = (offense.score || 0) - (defense.score || 0);
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
        weight: Math.max(1, score * shooterPenalty * (0.85 + random() * 0.3)),
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
        weight: Math.max(1, score * (0.85 + random() * 0.3)),
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
  const sourceBoost = sourceType === "steal" ? 0.12 : 0.03;
  const pushIntent = getTeamFastBreakIntent(offense, "fastBreakOffense");
  const defenseRecoveryIntent = getTeamFastBreakIntent(defense, "defendFastBreakOffense");
  const headStart = transition.defenseHeadStart || 0;

  if (phase === 1) {
    const pushChance = clamp(
      0.08 + (sourceType === "steal" ? 0.12 : 0) + pushIntent * 0.9 + headStart * 0.35,
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

function shouldTakeShotThisAction({
  state,
  shooter,
  shotQuality = 0,
  random = Math.random,
  forceShotThresholdSeconds = 5,
}) {
  if (state.shotClockRemaining <= forceShotThresholdSeconds) return true;

  const shotIQ = getRating(shooter, "skills.shotIQ");
  const shootVsPass = getRating(shooter, "tendencies.shootVsPass");
  const elapsedClock = SHOT_CLOCK_SECONDS - state.shotClockRemaining;
  const pressureSpan = SHOT_CLOCK_SECONDS - forceShotThresholdSeconds;
  const clockPressure = pressureSpan <= 0 ? 1 : clamp(elapsedClock / pressureSpan, 0, 1);
  const paceShotBias = getPaceShotBias(state, state.possessionTeamId);
  const earlyClockRestraint = Math.pow(1 - clockPressure, 1.35) * 0.095;
  // Shot quality matters less as the clock winds down — late in the clock, any look goes up.
  const qualityWeight = 1 - 0.75 * clockPressure;
  const qualityBoost = clamp(shotQuality, 0, 1.2) * 0.23 * qualityWeight;
  const shotChance = clamp(
    0.23 +
      EARLY_CLOCK_SHOT_ATTEMPT_BONUS +
      Math.pow(clockPressure, 1.35) * 0.73 +
      (shotIQ - 60) / 300 +
      (shootVsPass - 55) / 300 +
      paceShotBias +
      qualityBoost,
    0.1,
    0.98,
  );

  return random() < clamp(shotChance - earlyClockRestraint, 0.08, 0.98);
}

function resolveActionChunk(state, random = Math.random) {
  syncClutchTimeState(state);
  const offenseTeamId = state.possessionTeamId;
  const defenseTeamId = nextDefenseTeamId(state.possessionTeamId);
  const offense = state.teams[offenseTeamId];
  const defense = state.teams[defenseTeamId];
  const involvementByTeam = [new Map(), new Map()];
  const markInvolvement = (teamId, player, amount = 1) => {
    if (!player) return;
    const map = involvementByTeam[teamId];
    map.set(player, (map.get(player) || 0) + amount);
  };

  if (maybeTakeTimeout(state, random)) {
    return;
  }

  const offenseLineup = offense.lineup;
  const defenseLineup = defense.lineup;
  const defenseScheme = defense.defenseScheme || DefenseScheme.MAN_TO_MAN;

  if (state.possessionNeedsSetup && state.pendingTransition) {
    const transitionResult = resolveFastBreakWindow({
      state,
      offenseTeamId,
      defenseTeamId,
      offense,
      defense,
      offenseLineup,
      defenseLineup,
      defenseScheme,
      markInvolvement,
      random,
    });

    if (transitionResult.handled) {
      applyChunkClock(state, transitionResult.shotClockMode || "tick");
      applyChunkMinutesAndEnergy(state, involvementByTeam);

      if (!transitionResult.possessionChanged && state.shotClockRemaining <= 0) {
        pushEvent(state, {
          type: "turnover_shot_clock",
          offenseTeam: offense.name,
          playType: transitionResult.playType || "fast_break",
        });
        addTeamExtra(state, offenseTeamId, "turnovers", 1);
        beginNewPossession(state, nextDefenseTeamId(state.possessionTeamId), "out_of_bounds");
      }
      return;
    }
  }

  if (state.possessionNeedsSetup && !(defense?.tendencies?.press > 1)) {
    state.possessionNeedsSetup = false;
    applyChunkClock(state, "tick");
    offenseLineup.forEach((player) => markInvolvement(offenseTeamId, player, 0.15));
    defenseLineup.forEach((player) => markInvolvement(defenseTeamId, player, 0.15));
    applyChunkMinutesAndEnergy(state, involvementByTeam);
    pushEvent(state, {
      type: "setup",
      offenseTeam: offense.name,
      defenseTeam: defense.name,
      detail: "Ball advanced into half-court set.",
    });

    if (state.shotClockRemaining <= 0) {
      pushEvent(state, {
        type: "turnover_shot_clock",
        offenseTeam: offense.name,
      });
      addTeamExtra(state, offenseTeamId, "turnovers", 1);
      beginNewPossession(state, nextDefenseTeamId(state.possessionTeamId), "out_of_bounds");
    }

    return;
  }

  const formation = getCurrentOffensiveFormation(offense);
  const offensiveAssignments = assignOffensiveSpots(offenseLineup, formation, random);
  const ballHandlerIndex = pickBallHandler(offensiveAssignments, random);
  const ballHandler = offensiveAssignments[ballHandlerIndex].player;
  const ballHandlerSpot = offensiveAssignments[ballHandlerIndex].spot;
  const onBall = getOnBallDefender({
    defenseScheme,
    defenseLineup,
    offensiveAssignments,
    ballHandlerIndex,
  });

  const zonePenalty = onBall.isZone
    ? -0.08 + zoneDistanceAdvantage(onBall.defender, onBall.startDistance)
    : 0;
  if (state.pendingAssist) {
    const pending = state.pendingAssist;
    if (
      pending.teamId !== offenseTeamId ||
      pending.receiver !== ballHandler ||
      !pending.validForNextAction
    ) {
      clearPendingAssist(state);
    } else {
      pending.validForNextAction = false;
    }
  }
  markInvolvement(offenseTeamId, ballHandler, 1);
  markInvolvement(defenseTeamId, onBall.defender, 0.9);

  offense.context = { ballHandlerSpot, formation };
  const playType = choosePlayType({ offenseTeam: offense, ballHandler, random });
  delete offense.context;

  let possessionChanged = false;
  let shotClockMode = "tick";
  const resolveLateClockBailout = ({
    shooter,
    defender,
    shooterSpot = null,
    sourceDetail,
    shotQualityEdge = -0.2,
  }) => {
    if (state.shotClockRemaining > 5) return false;

    const forcedShotType = chooseShotFromTendencies(shooter, random);
    const forcedShot = resolveShot({
      shooter,
      defender,
      shotType: forcedShotType,
      shooterSpot,
      zonePenalty,
      shotQualityEdge,
      contested: true,
      random,
    });
    forcedShot.shooter = shooter;
    markInvolvement(offenseTeamId, shooter, 1);
    markInvolvement(defenseTeamId, defender, 0.9);

    pushEvent(state, {
      type: "forced_shot_clock",
      offenseTeam: offense.name,
      playType,
      shotType: forcedShotType,
      shooter: shooter?.bio?.name,
      detail: sourceDetail,
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
      offensiveAssignments,
      playType,
      shotType: forcedShotType,
      shot: forcedShot,
      random,
    });
    possessionChanged = endState.possessionChanged;
    shotClockMode = endState.shotClockMode;
    return true;
  };

  if (playType === "dribble_drive") {
    const drive = resolveInteraction({
      offensePlayer: ballHandler,
      defensePlayer: onBall.defender,
      offenseRatings: [
        "athleticism.agility",
        "athleticism.burst",
        "skills.ballHandling",
        "athleticism.speed",
      ],
      defenseRatings: [
        "defense.lateralQuickness",
        "defense.perimeterDefense",
        "athleticism.agility",
      ],
      contextEdge: zonePenalty - 0.04,
      random,
    });

    const decisiveOWin = drive.edge >= 0.64;
    const oWin = drive.edge >= 0.14;
    const decisiveDWin = drive.edge <= -0.6;
    const dTieOrSmallWin = !oWin && !decisiveDWin;

    if (decisiveDWin) {
      const stealChance = clamp(
        0.04 + (getRating(onBall.defender, "defense.steals") - getRating(ballHandler, "skills.ballSafety")) / 220,
        0.01,
        0.26,
      );
      if (random() < stealChance) {
        recordTurnover(state, offenseTeamId, ballHandler, defenseTeamId, onBall.defender);
        pushEvent(state, {
          type: "turnover_liveball",
          offenseTeam: offense.name,
          defenderTeam: defense.name,
          playType,
          defender: onBall.defender?.bio?.name,
        });
        beginNewPossession(state, nextDefenseTeamId(state.possessionTeamId), null, {
          transition: {
            sourceType: "steal",
            initiator: onBall.defender,
          },
        });
        possessionChanged = true;
        shotClockMode = "hold";
      } else {
        if (!resolveLateClockBailout({
          shooter: ballHandler,
          defender: onBall.defender,
          shooterSpot: ballHandlerSpot,
          sourceDetail: "Defense cut off the drive; late-clock bailout shot.",
        })) {
          pushEvent(state, {
            type: "reset",
            offenseTeam: offense.name,
            playType,
            detail: "Defense cut off the drive.",
          });
        }
      }
    } else if (dTieOrSmallWin) {
      if (!resolveLateClockBailout({
        shooter: ballHandler,
        defender: onBall.defender,
        shooterSpot: ballHandlerSpot,
        sourceDetail: "Drive stalled; late-clock bailout shot.",
      })) {
        pushEvent(state, {
          type: "reset",
          offenseTeam: offense.name,
          playType,
          detail: "Drive stalled.",
        });
      }
    } else {
      const helpCandidates = defenseLineup.filter((_, idx) => idx !== ballHandlerIndex);
      const helpQuality = average(
        helpCandidates.map((d) =>
          average([
            getRating(d, "defense.offballDefense"),
            getRating(d, "defense.perimeterDefense"),
            getRating(d, "athleticism.burst"),
          ]),
        ),
      );
      const helpChance = clamp(0.2 + (helpQuality - 50) / 130, 0.06, 0.72);
      const helpArrives = random() < helpChance;

      const shootVsPass = getRating(ballHandler, "tendencies.shootVsPass");
      const passChance = clamp(
        (54 - shootVsPass) / 100 + (helpArrives ? 0.22 : 0.08),
        0.06,
        decisiveOWin ? 0.82 : 0.72,
      );
      const jumpChance = decisiveOWin ? 0 : clamp((shootVsPass - 58) / 220, 0, 0.16);
      const passDecision = random() < passChance;
      const jumpDecision = !passDecision && random() < jumpChance;

      if (passDecision) {
        const targets = offensiveAssignments
          .map((assignment, idx) => ({ ...assignment, idx }))
          .filter((entry) => entry.idx !== ballHandlerIndex);

        const targetScores = targets.map((target) => {
          const cover = getDefenderForOffensiveIndex({
            defenseScheme,
            defenseLineup,
            offensiveAssignments,
            offenseIndex: target.idx,
          });

          const threatBonus = decisiveOWin && helpArrives ? 0.22 : 0.04;
          const evalResult = evaluatePassTarget({
            passer: ballHandler,
            receiver: target.player,
            receiverDefender: cover.defender,
            receiverSpot: target.spot,
            threatBonus,
            random,
          });

          return {
            ...target,
            cover,
            evalResult,
            score:
              evalResult.openLevel *
              estimateOpenShotValue(target.player, target.spot) *
              (evalResult.canSeeWindow ? 1.3 : 0.45),
          };
        });

        targetScores.sort((a, b) => b.score - a.score);
        const best = targetScores[0];
        if (!best || !best.evalResult.canSeeWindow) {
          if (!resolveLateClockBailout({
            shooter: ballHandler,
            defender: onBall.defender,
            shooterSpot: ballHandlerSpot,
            sourceDetail: "Drive-and-kick read not found; late-clock bailout shot.",
          })) {
            pushEvent(state, {
              type: "reset",
              offenseTeam: offense.name,
              playType,
              detail: "Drive-and-kick read not found.",
            });
          }
        } else {
          const passDelivery = resolvePassDelivery({
            passer: ballHandler,
            receiver: best.player,
            defenseContributors: [onBall.defender, best.cover.defender],
            zonePenalty,
            random,
          });
          markInvolvement(offenseTeamId, ballHandler, 0.55);
          markInvolvement(offenseTeamId, best.player, 0.7);
          markInvolvement(defenseTeamId, onBall.defender, 0.35);
          markInvolvement(defenseTeamId, best.cover.defender, 0.45);

          if (passDelivery.turnover) {
            recordTurnover(
              state,
              offenseTeamId,
              ballHandler,
              defenseTeamId,
              passDelivery.stealByPlayer,
            );
            pushEvent(state, {
              type: "turnover_pass",
              offenseTeam: offense.name,
              defenderTeam: defense.name,
              playType,
              detail: `Steal by ${passDelivery.stealBy}`,
            });
            beginNewPossession(state, nextDefenseTeamId(state.possessionTeamId), null, {
              transition: {
                sourceType: "steal",
                initiator: passDelivery.stealByPlayer,
              },
            });
            possessionChanged = true;
            shotClockMode = "hold";
          } else if (passDelivery.looseBall) {
            clearPendingAssist(state);
            const looseBall = resolveLooseBallRecovery({
              offenseLineup,
              defenseLineup,
              offenseTeamId,
              defenseTeamId,
              offensiveAssignments,
              defenseScheme,
              receiverSpot: best.spot,
              random,
            });

            if (looseBall.recoveredByTeam === "defense") {
              addPlayerStat(state, offenseTeamId, ballHandler, "turnovers", 1);
              pushEvent(state, {
                type: "loose_ball_recovery",
                offenseTeam: offense.name,
                defenderTeam: defense.name,
                playType,
                detail: `Loose ball recovered by ${looseBall.recoveredByPlayer?.bio?.name || "Unknown"}.`,
              });
              beginNewPossession(state, nextDefenseTeamId(state.possessionTeamId));
              possessionChanged = true;
              shotClockMode = "hold";
            } else {
              pushEvent(state, {
                type: "loose_ball_recovery",
                offenseTeam: offense.name,
                playType,
                detail: `Loose ball recovered by ${looseBall.recoveredByPlayer?.bio?.name || "Unknown"} (${offense.name}).`,
              });
            }
          } else {
            setPendingAssist(state, offenseTeamId, ballHandler, best.player);
            if (!shouldTakeShotThisAction({
              state,
              shooter: best.player,
              shotQuality: best.evalResult.openLevel,
              random,
            })) {
                if (!resolveLateClockBailout({
                  shooter: best.player,
                  defender: best.cover.defender,
                  shooterSpot: best.spot,
                  sourceDetail: "Kick-out caught; late-clock catch-and-shoot bailout.",
                  shotQualityEdge: best.evalResult.openLevel * 0.15 - 0.08,
                })) {
                pushEvent(state, {
                  type: "reset",
                  offenseTeam: offense.name,
                  playType,
                  detail: "Kick-out caught, offense reset for a later shot.",
                });
              }
            } else {
              const shotType = chooseShotFromTendencies(best.player, random);
              const contested = best.evalResult.openLevel < 0.56;
              const shot = resolveShot({
                shooter: best.player,
                defender: best.cover.defender,
                shotType,
                shooterSpot: best.spot,
                zonePenalty,
                shotQualityEdge: best.evalResult.openLevel * 0.32,
                contested,
                random,
              });
              shot.shooter = best.player;
              shot.assister = ballHandler;
              markInvolvement(offenseTeamId, best.player, 0.9);
              markInvolvement(offenseTeamId, ballHandler, 0.35);
              markInvolvement(defenseTeamId, best.cover.defender, 0.75);

              const endState = resolvePossessionEndAfterShot({
                state,
                offenseTeamId,
                defenseTeamId,
                offense,
                defense,
                offenseLineup,
                defenseLineup,
                defenseScheme,
                offensiveAssignments,
                playType,
                shotType,
                shot,
                random,
              });
              possessionChanged = endState.possessionChanged;
              shotClockMode = endState.shotClockMode;
            }
          }
        }
      } else {
        if (!shouldTakeShotThisAction({
          state,
          shooter: ballHandler,
          shotQuality: decisiveOWin ? 0.8 : (helpArrives ? 0.35 : 0.55),
          random,
        })) {
          if (!resolveLateClockBailout({
            shooter: ballHandler,
            defender: onBall.defender,
            shooterSpot: ballHandlerSpot,
            sourceDetail: "Drive advantage faded; late-clock bailout shot.",
          })) {
            pushEvent(state, {
              type: "reset",
              offenseTeam: offense.name,
              playType,
              detail: "Drive advantage wasn't enough, offense reset.",
            });
          }
        } else {
          const shotType = jumpDecision ? chooseShotFromTendencies(ballHandler, random) : chooseDriveFinishType(ballHandler, random);
          const contestWeight = decisiveOWin ? 0.08 : 0.2;
          const shotQualityEdge = decisiveOWin ? 0.32 : 0.1;
          const shot = resolveShot({
            shooter: ballHandler,
            defender: onBall.defender,
            shotType,
            shooterSpot: ballHandlerSpot,
            zonePenalty,
            shotQualityEdge: shotQualityEdge - (helpArrives ? contestWeight : 0),
            contested: true,
            random,
          });
          shot.shooter = ballHandler;
          markInvolvement(offenseTeamId, ballHandler, 1);
          markInvolvement(defenseTeamId, onBall.defender, 0.85);

          if (!shot.made && (shotType === "layup" || shotType === "dunk")) {
            const oLength =
              (getHeightInches(ballHandler) + getWingspanInches(ballHandler)) / 2;
            const dLength =
              (getHeightInches(onBall.defender) + getWingspanInches(onBall.defender)) / 2;
            const blockRating = getRating(onBall.defender, "defense.shotBlocking");
            const blockChance = clamp(
              0.02 +
                (dLength - oLength) / 180 +
                (blockRating - 50) / 220 +
                (decisiveOWin ? -0.02 : 0.04),
              0.01,
              0.26,
            );
            if (random() < blockChance) {
              shot.blockedByDefense = true;
            }
          }

          const endState = resolvePossessionEndAfterShot({
            state,
            offenseTeamId,
            defenseTeamId,
            offense,
            defense,
            offenseLineup,
            defenseLineup,
            defenseScheme,
            offensiveAssignments,
            playType,
            shotType,
            shot,
            random,
          });
          possessionChanged = endState.possessionChanged;
          shotClockMode = endState.shotClockMode;
        }
      }
    }
  } else if (playType === "pick_and_roll" || playType === "pick_and_pop") {
    const screenerIndex = pickScreenerIndex({
      offensiveAssignments,
      ballHandlerIndex,
      random,
    });
    const screenerEntry = offensiveAssignments[screenerIndex];
    const screener = screenerEntry?.player;
    const screenerSpot = screenerEntry?.spot || OffensiveSpot.FT_LINE;

    if (!screener || screener === ballHandler) {
      if (!resolveLateClockBailout({
        shooter: ballHandler,
        defender: onBall.defender,
        shooterSpot: ballHandlerSpot,
        sourceDetail: "Screen action had no screener outlet; late-clock bailout shot.",
      })) {
        pushEvent(state, {
          type: "reset",
          offenseTeam: offense.name,
          playType,
          detail: "Screen action dissolved before contact.",
        });
      }
    } else {
      const screenerCover = getDefenderForOffensiveIndex({
        defenseScheme,
        defenseLineup,
        offensiveAssignments,
        offenseIndex: screenerIndex,
      });
      const screenerDefender = screenerCover?.defender || onBall.defender;
      const screenerZonePenalty = defenseScheme === DefenseScheme.MAN_TO_MAN
        ? 0
        : -0.08 + zoneDistanceAdvantage(screenerDefender, screenerCover?.distance || 1.6);

      const dynamics = resolvePickActionDynamics({
        ballHandler,
        screener,
        onBallDefender: onBall.defender,
        screenerDefender,
        actionType: playType,
        zonePenalty: zonePenalty + screenerZonePenalty * 0.45,
        random,
      });

      const ballHandlerOpen = clamp(
        1 - dynamics.ballHandlerPressure + dynamics.disruption * 0.18,
        0,
        1,
      );
      const screenerOpen = clamp(
        1 - dynamics.screenerPressure + dynamics.disruption * 0.22,
        0,
        1,
      );
      const screenReadGap = Math.abs(ballHandlerOpen - screenerOpen);
      const passIQ = getRating(ballHandler, "skills.passingIQ");
      const readBestOptionChance = clamp(
        0.45 + (passIQ - 50) / 95 + screenReadGap * 0.4,
        0.08,
        0.96,
      );
      const betterOption = screenerOpen > ballHandlerOpen ? "screener" : "ball_handler";
      let primaryDecision;
      if (random() < readBestOptionChance) {
        primaryDecision = betterOption;
      } else {
        const shootVsPass = getRating(ballHandler, "tendencies.shootVsPass");
        const ballChance = clamp(
          0.35 + (shootVsPass - 50) / 120 + (ballHandlerOpen - screenerOpen) * 0.35,
          0.08,
          0.92,
        );
        primaryDecision = random() < ballChance ? "ball_handler" : "screener";
      }

      markInvolvement(offenseTeamId, screener, 0.82);
      markInvolvement(defenseTeamId, screenerDefender, 0.78);

      if (primaryDecision === "screener") {
        const passDelivery = resolvePassDelivery({
          passer: ballHandler,
          receiver: screener,
          defenseContributors: [onBall.defender, screenerDefender],
          zonePenalty: zonePenalty + screenerZonePenalty + dynamics.disruption * 0.12,
          random,
        });

        markInvolvement(offenseTeamId, ballHandler, 0.48);
        markInvolvement(offenseTeamId, screener, 0.62);
        markInvolvement(defenseTeamId, onBall.defender, 0.38);
        markInvolvement(defenseTeamId, screenerDefender, 0.45);

        if (passDelivery.turnover) {
          recordTurnover(
            state,
            offenseTeamId,
            ballHandler,
            defenseTeamId,
            passDelivery.stealByPlayer,
          );
          pushEvent(state, {
            type: "turnover_pass",
            offenseTeam: offense.name,
            defenderTeam: defense.name,
            playType,
            detail: `Screen pass picked off by ${passDelivery.stealBy}.`,
          });
          beginNewPossession(state, nextDefenseTeamId(state.possessionTeamId), null, {
            transition: {
              sourceType: "steal",
              initiator: passDelivery.stealByPlayer,
            },
          });
          possessionChanged = true;
          shotClockMode = "hold";
        } else if (passDelivery.looseBall) {
          clearPendingAssist(state);
          const looseBall = resolveLooseBallRecovery({
            offenseLineup,
            defenseLineup,
            offenseTeamId,
            defenseTeamId,
            offensiveAssignments,
            defenseScheme,
            receiverSpot: screenerSpot,
            random,
          });
          if (looseBall.recoveredByTeam === "defense") {
            addPlayerStat(state, offenseTeamId, ballHandler, "turnovers", 1);
            pushEvent(state, {
              type: "loose_ball_recovery",
              offenseTeam: offense.name,
              defenderTeam: defense.name,
              playType,
              detail: `Loose ball recovered by ${looseBall.recoveredByPlayer?.bio?.name || "Unknown"}.`,
            });
            beginNewPossession(state, nextDefenseTeamId(state.possessionTeamId));
            possessionChanged = true;
            shotClockMode = "hold";
          } else {
            pushEvent(state, {
              type: "loose_ball_recovery",
              offenseTeam: offense.name,
              playType,
              detail: `Loose ball recovered by ${looseBall.recoveredByPlayer?.bio?.name || "Unknown"} (${offense.name}).`,
            });
          }
        } else if (playType === "pick_and_roll") {
          setPendingAssist(state, offenseTeamId, ballHandler, screener);

          const onBallRollStopShare = (1 - dynamics.onBallGuardBallShare) * dynamics.onBallDriveFocus;
          const screenerRollStopShare = (1 - dynamics.screenerGuardBallShare) * dynamics.screenerDriveFocus;
          const rollDefender =
            onBallRollStopShare >= screenerRollStopShare ? onBall.defender : screenerDefender;
          const rollStopPressure = Math.max(onBallRollStopShare, screenerRollStopShare);
          const rollQuality = clamp(
            screenerOpen * 0.58 + dynamics.disruption * 0.34 + (1 - rollStopPressure) * 0.2,
            0.08,
            1.08,
          );
          const rollShotType = chooseDriveFinishType(screener, random);
          const shot = resolveShot({
            shooter: screener,
            defender: rollDefender,
            shotType: rollShotType,
            shooterSpot: OffensiveSpot.MIDDLE_PAINT,
            zonePenalty: Math.max(zonePenalty, screenerZonePenalty),
            shotQualityEdge: rollQuality * 0.34 - rollStopPressure * 0.22,
            contested: rollQuality < 0.62,
            random,
          });
          shot.shooter = screener;
          shot.assister = ballHandler;
          markInvolvement(offenseTeamId, screener, 0.95);
          markInvolvement(offenseTeamId, ballHandler, 0.36);
          markInvolvement(defenseTeamId, rollDefender, 0.86);

          const endState = resolvePossessionEndAfterShot({
            state,
            offenseTeamId,
            defenseTeamId,
            offense,
            defense,
            offenseLineup,
            defenseLineup,
            defenseScheme,
            offensiveAssignments,
            playType,
            shotType: rollShotType,
            shot,
            random,
          });
          possessionChanged = endState.possessionChanged;
          shotClockMode = endState.shotClockMode;
        } else {
          const popDestination = choosePopDestination(screener, random);
          const popShotRating = popDestination.shotType === "three"
            ? getRating(screener, "shooting.threePointShooting")
            : getRating(screener, "shooting.midrangeShot");
          const onBallPopStopShare =
            (1 - dynamics.onBallGuardBallShare) * (1 - dynamics.onBallDriveFocus);
          const screenerPopStopShare =
            (1 - dynamics.screenerGuardBallShare) * (1 - dynamics.screenerDriveFocus);
          const popDefender =
            onBallPopStopShare >= screenerPopStopShare ? onBall.defender : screenerDefender;
          const popStopPressure = Math.max(onBallPopStopShare, screenerPopStopShare);
          const popOpenLevel = clamp(
            screenerOpen * 0.7 + dynamics.disruption * 0.2 + (1 - popStopPressure) * 0.18,
            0,
            1,
          );
          const avoidBadShot = popShotRating < 58 && getRating(screener, "skills.shotIQ") < 60;

          if (
            avoidBadShot ||
            !shouldTakeShotThisAction({
              state,
              shooter: screener,
              shotQuality: popOpenLevel * 0.95,
              random,
            })
          ) {
            if (!resolveLateClockBailout({
              shooter: ballHandler,
              defender: onBall.defender,
              shooterSpot: ballHandlerSpot,
              sourceDetail: "Pop target wasn't open enough; late-clock bailout shot.",
              shotQualityEdge: popOpenLevel * 0.08 - 0.08,
            })) {
              pushEvent(state, {
                type: "reset",
                offenseTeam: offense.name,
                playType,
                detail:
                  avoidBadShot
                    ? "Pop target declined the look and reset the action."
                    : "Pop window closed before a clean shot.",
              });
            }
          } else {
            setPendingAssist(state, offenseTeamId, ballHandler, screener);
            const shot = resolveShot({
              shooter: screener,
              defender: popDefender,
              shotType: popDestination.shotType,
              shooterSpot: popDestination.spot,
              zonePenalty: Math.max(zonePenalty, screenerZonePenalty),
              shotQualityEdge:
                popOpenLevel * 0.31 +
                dynamics.screenEffectiveness * 0.14 -
                popStopPressure * 0.18 +
                popDestination.expectedShotValue * 0.03,
              contested: popOpenLevel < 0.6,
              random,
            });
            shot.shooter = screener;
            shot.assister = ballHandler;
            markInvolvement(offenseTeamId, screener, 0.94);
            markInvolvement(offenseTeamId, ballHandler, 0.34);
            markInvolvement(defenseTeamId, popDefender, 0.82);

            const endState = resolvePossessionEndAfterShot({
              state,
              offenseTeamId,
              defenseTeamId,
              offense,
              defense,
              offenseLineup,
              defenseLineup,
              defenseScheme,
              offensiveAssignments,
              playType,
              shotType: popDestination.shotType,
              shot,
              random,
            });
            possessionChanged = endState.possessionChanged;
            shotClockMode = endState.shotClockMode;
          }
        }
      } else {
        const totalDriveDefense =
          dynamics.onBallGuardBallShare * dynamics.onBallDriveFocus +
          dynamics.screenerGuardBallShare * dynamics.screenerDriveFocus;
        const totalShotDefense =
          dynamics.onBallGuardBallShare * (1 - dynamics.onBallDriveFocus) +
          dynamics.screenerGuardBallShare * (1 - dynamics.screenerDriveFocus);
        const driveIntent = clamp(
          0.45 +
            (getRating(ballHandler, "tendencies.drive") - 50) / 120 +
            (totalShotDefense - totalDriveDefense) * 0.5,
          0.1,
          0.9,
        );
        const attackDrive = random() < driveIntent;
        const attackerDefender = attackDrive
          ? dynamics.onBallGuardBallShare * dynamics.onBallDriveFocus >=
            dynamics.screenerGuardBallShare * dynamics.screenerDriveFocus
            ? onBall.defender
            : screenerDefender
          : dynamics.onBallGuardBallShare * (1 - dynamics.onBallDriveFocus) >=
            dynamics.screenerGuardBallShare * (1 - dynamics.screenerDriveFocus)
            ? onBall.defender
            : screenerDefender;

        if (
          !shouldTakeShotThisAction({
            state,
            shooter: ballHandler,
            shotQuality: attackDrive ? 0.58 + dynamics.disruption * 0.28 : 0.45 + ballHandlerOpen * 0.42,
            random,
          })
        ) {
          if (!resolveLateClockBailout({
            shooter: ballHandler,
            defender: attackerDefender,
            shooterSpot: ballHandlerSpot,
            sourceDetail: "Ball-handler read favored patience; late-clock bailout shot.",
            shotQualityEdge: dynamics.disruption * 0.14 - 0.1,
          })) {
            pushEvent(state, {
              type: "reset",
              offenseTeam: offense.name,
              playType,
              detail: "Screen created a read, but ball-handler reset the possession.",
            });
          }
        } else {
          const shotType = attackDrive ? chooseDriveFinishType(ballHandler, random) : chooseShotFromTendencies(ballHandler, random);
          const defensePressure = attackDrive ? totalDriveDefense : totalShotDefense;
          const shot = resolveShot({
            shooter: ballHandler,
            defender: attackerDefender,
            shotType,
            shooterSpot: ballHandlerSpot,
            zonePenalty,
            shotQualityEdge:
              dynamics.disruption * 0.2 +
              (1 - defensePressure) * (attackDrive ? 0.3 : 0.24) -
              defensePressure * 0.2,
            contested: defensePressure > 0.42,
            random,
          });
          shot.shooter = ballHandler;
          markInvolvement(offenseTeamId, ballHandler, 1);
          markInvolvement(offenseTeamId, screener, 0.52);
          markInvolvement(defenseTeamId, attackerDefender, 0.86);
          markInvolvement(defenseTeamId, onBall.defender, 0.28);
          markInvolvement(defenseTeamId, screenerDefender, 0.28);

          const endState = resolvePossessionEndAfterShot({
            state,
            offenseTeamId,
            defenseTeamId,
            offense,
            defense,
            offenseLineup,
            defenseLineup,
            defenseScheme,
            offensiveAssignments,
            playType,
            shotType,
            shot,
            random,
          });
          possessionChanged = endState.possessionChanged;
          shotClockMode = endState.shotClockMode;
        }
      }
    }
  } else if (playType === "pass_around_for_shot") {
    const pgStarterIndex = offensiveAssignments.findIndex(
      (assignment) => assignment.player?.bio?.position === "PG",
    );
    const starterIndex = pgStarterIndex >= 0 ? pgStarterIndex : ballHandlerIndex;
    const starterOnBall = getOnBallDefender({
      defenseScheme,
      defenseLineup,
      offensiveAssignments,
      ballHandlerIndex: starterIndex,
    });

    let currentHandlerIndex = starterIndex;
    let currentHandler = offensiveAssignments[currentHandlerIndex].player;
    let currentHandlerSpot = offensiveAssignments[currentHandlerIndex].spot;
    let currentDefender = starterOnBall.defender;
    let currentZonePenalty = starterOnBall.isZone
      ? -0.08 + zoneDistanceAdvantage(starterOnBall.defender, starterOnBall.startDistance)
      : 0;
    let openBeforeCatch = clamp(starterOnBall.isZone ? 0.34 + starterOnBall.startDistance * 0.03 : 0.3, 0.2, 0.6);
    let passesCompleted = 0;
    let scrambleBonus = 0;
    let scrambleFresh = false;
    const maxPasses = 4;
    let actionDone = false;
    markInvolvement(offenseTeamId, currentHandler, 0.55);
    markInvolvement(defenseTeamId, currentDefender, 0.45);

    while (!actionDone && !possessionChanged) {
      const canStillPass = passesCompleted < maxPasses;
      const hasCompletedRequiredPass = passesCompleted > 0;
      const activeScrambleBonus = scrambleBonus;
      const shotQuality = clamp(openBeforeCatch * 0.85 + activeScrambleBonus * 0.4, 0.1, 1.05);
      const shouldShoot = hasCompletedRequiredPass && shouldTakeShotThisAction({
        state,
        shooter: currentHandler,
        shotQuality,
        random,
      });

      if (shouldShoot || !canStillPass) {
        if (!shouldShoot && !resolveLateClockBailout({
          shooter: currentHandler,
          defender: currentDefender,
          shooterSpot: currentHandlerSpot,
          sourceDetail: "Pass limit reached; offense resets without a shot.",
          shotQualityEdge: openBeforeCatch * 0.12 - 0.06,
        })) {
          pushEvent(state, {
            type: "reset",
            offenseTeam: offense.name,
            playType,
            detail: "Pass-around hit max passes and reset to neutral offense.",
          });
          actionDone = true;
          break;
        }
        if (!shouldShoot) {
          actionDone = true;
          break;
        }

        const shotType = chooseShotFromTendencies(currentHandler, random);
        const contested = openBeforeCatch < 0.62;
        const shot = resolveShot({
          shooter: currentHandler,
          defender: currentDefender,
          shotType,
          shooterSpot: currentHandlerSpot,
          zonePenalty: currentZonePenalty,
          shotQualityEdge: openBeforeCatch * 0.28 + scrambleBonus * 0.1,
          contested,
          random,
        });
        shot.shooter = currentHandler;
        markInvolvement(offenseTeamId, currentHandler, 0.95);
        markInvolvement(defenseTeamId, currentDefender, 0.8);

        const endState = resolvePossessionEndAfterShot({
          state,
          offenseTeamId,
          defenseTeamId,
          offense,
          defense,
          offenseLineup,
          defenseLineup,
          defenseScheme,
          offensiveAssignments,
          playType,
          shotType,
          shot,
          random,
        });
        possessionChanged = endState.possessionChanged;
        shotClockMode = endState.shotClockMode;
        actionDone = true;
        break;
      }

      maybeRelocateOffBallPlayers({
        offensiveAssignments,
        ballHandlerIndex: currentHandlerIndex,
        random,
      });

      const targets = offensiveAssignments
        .map((assignment, idx) => ({ ...assignment, idx }))
        .filter((entry) => entry.idx !== currentHandlerIndex);
      const threatBonus =
        clamp((getRating(currentHandler, "skills.passingVision") - 55) / 180, -0.05, 0.2) +
        activeScrambleBonus;

      const targetScores = targets.map((target) => {
        const cover = getDefenderForOffensiveIndex({
          defenseScheme,
          defenseLineup,
          offensiveAssignments,
          offenseIndex: target.idx,
        });

        const evalResult = evaluatePassTarget({
          passer: currentHandler,
          receiver: target.player,
          receiverDefender: cover.defender,
          receiverSpot: target.spot,
          threatBonus,
          random,
        });

        markInvolvement(offenseTeamId, target.player, 0.16);
        markInvolvement(defenseTeamId, cover.defender, 0.12);

        const getsOpen = evalResult.getOpen.success;
        return {
          ...target,
          cover,
          evalResult,
          getsOpen,
          score:
            evalResult.openLevel *
            estimateOpenShotValue(target.player, target.spot) *
            (getsOpen ? 1.25 : 0.25) *
            (evalResult.canSeeWindow ? 1.25 : 0.35),
        };
      });

      targetScores.sort((a, b) => b.score - a.score);
      const best = targetScores.find((candidate) => candidate.getsOpen && candidate.evalResult.canSeeWindow);
      if (activeScrambleBonus > 0) {
        if (scrambleFresh) scrambleFresh = false;
        else scrambleBonus *= 0.28;
      }
      if (!best) {
        const canLateClockBailout = hasCompletedRequiredPass && resolveLateClockBailout({
          shooter: currentHandler,
          defender: currentDefender,
          shooterSpot: currentHandlerSpot,
          sourceDetail: "No passing window opened in action; neutral reset.",
          shotQualityEdge: openBeforeCatch * 0.11 - 0.07,
        });
        if (!canLateClockBailout) {
          pushEvent(state, {
            type: "reset",
            offenseTeam: offense.name,
            playType,
            detail: "Pass-around found no clean option and reset to neutral offense.",
          });
          actionDone = true;
          break;
        }
        actionDone = true;
        break;
      }

      const defenseContributors = getNearbyPassDefenders({
        defenseScheme,
        defenseLineup,
        offensiveAssignments,
        ballHandlerDefender: currentDefender,
        receiverDefender: best.cover.defender,
        receiverSpot: best.spot,
      });
      const passDelivery = resolvePassDelivery({
        passer: currentHandler,
        receiver: best.player,
        defenseContributors,
        zonePenalty: currentZonePenalty,
        random,
      });

      markInvolvement(offenseTeamId, currentHandler, 0.52);
      markInvolvement(offenseTeamId, best.player, 0.7);
      defenseContributors.forEach((defender) => markInvolvement(defenseTeamId, defender, 0.18));

      if (passDelivery.turnover) {
        recordTurnover(
          state,
          offenseTeamId,
          currentHandler,
          defenseTeamId,
          passDelivery.stealByPlayer,
        );
        pushEvent(state, {
          type: "turnover_pass",
          offenseTeam: offense.name,
          defenderTeam: defense.name,
          playType,
          detail: `Steal by ${passDelivery.stealBy}`,
        });
        beginNewPossession(state, nextDefenseTeamId(state.possessionTeamId), null, {
          transition: {
            sourceType: "steal",
            initiator: passDelivery.stealByPlayer,
          },
        });
        possessionChanged = true;
        shotClockMode = "hold";
        actionDone = true;
        break;
      } else if (passDelivery.looseBall) {
        clearPendingAssist(state);
        const looseBall = resolveLooseBallRecovery({
          offenseLineup,
          defenseLineup,
          offenseTeamId,
          defenseTeamId,
          offensiveAssignments,
          defenseScheme,
          receiverSpot: best.spot,
          random,
        });

        if (looseBall.recoveredByTeam === "defense") {
          addPlayerStat(state, offenseTeamId, currentHandler, "turnovers", 1);
          pushEvent(state, {
            type: "loose_ball_recovery",
            offenseTeam: offense.name,
            defenderTeam: defense.name,
            playType,
            detail: `Loose ball recovered by ${looseBall.recoveredByPlayer?.bio?.name || "Unknown"}.`,
          });
          beginNewPossession(state, nextDefenseTeamId(state.possessionTeamId));
          possessionChanged = true;
          shotClockMode = "hold";
        } else {
          pushEvent(state, {
            type: "loose_ball_recovery",
            offenseTeam: offense.name,
            playType,
            detail: `Loose ball recovered by ${looseBall.recoveredByPlayer?.bio?.name || "Unknown"} (${offense.name}).`,
          });
        }
        actionDone = true;
        break;
      }

      setPendingAssist(state, offenseTeamId, currentHandler, best.player);
      passesCompleted += 1;
      openBeforeCatch = best.evalResult.openLevel;
      scrambleBonus = clamp(
        Math.max(scrambleBonus * 0.3, (best.evalResult.openLevel - 0.34) * 0.5),
        0,
        0.4,
      );
      scrambleFresh = true;
      currentHandlerIndex = best.idx;
      currentHandler = best.player;
      currentHandlerSpot = best.spot;
      currentDefender = best.cover.defender;
      currentZonePenalty = defenseScheme === DefenseScheme.MAN_TO_MAN
        ? 0
        : -0.08 + zoneDistanceAdvantage(best.cover.defender, best.cover.distance);
    }

    if (!actionDone && !possessionChanged) {
      pushEvent(state, {
        type: "reset",
        offenseTeam: offense.name,
        playType,
        detail: "Pass-around action timed out and reset to neutral offense.",
      });
    }
  } else if (playType === "post_up") {
    const postEligibleSpots = new Set([
      OffensiveSpot.RIGHT_POST,
      OffensiveSpot.LEFT_POST,
      OffensiveSpot.MIDDLE_PAINT,
      OffensiveSpot.RIGHT_SLOT,
      OffensiveSpot.LEFT_SLOT,
      OffensiveSpot.RIGHT_ELBOW,
      OffensiveSpot.LEFT_ELBOW,
    ]);

    if (!postEligibleSpots.has(ballHandlerSpot)) {
      if (!resolveLateClockBailout({
        shooter: ballHandler,
        defender: onBall.defender,
        shooterSpot: ballHandlerSpot,
        sourceDetail: "No post angle; late-clock bailout shot.",
      })) {
        pushEvent(state, {
          type: "reset",
          offenseTeam: offense.name,
          playType,
          detail: "No post touch angle available.",
        });
      }
    } else {
      const weightEdge = (getWeightPounds(ballHandler) - getWeightPounds(onBall.defender)) / 220;
      const postBattle = resolveInteraction({
        offensePlayer: ballHandler,
        defensePlayer: onBall.defender,
        offenseRatings: [
          "postGame.postControl",
          "athleticism.strength",
          "skills.ballHandling",
        ],
        defenseRatings: [
          "defense.postDefense",
          "athleticism.strength",
          "defense.defensiveControl",
        ],
        contextEdge: weightEdge,
        random,
      });

      let postTier = "tie";
      if (postBattle.edge >= 0.7) postTier = "dom_win";
      else if (postBattle.edge >= 0.18) postTier = "win";
      else if (postBattle.edge <= -0.72) postTier = "dom_loss";
      else if (postBattle.edge <= -0.2) postTier = "loss";

      if (postTier === "dom_loss") {
        const stealChance = clamp(
          0.035 + (getRating(onBall.defender, "defense.steals") - getRating(ballHandler, "skills.ballSafety")) / 240,
          0.01,
          0.24,
        );
        if (random() < stealChance) {
          recordTurnover(state, offenseTeamId, ballHandler, defenseTeamId, onBall.defender);
          pushEvent(state, {
            type: "turnover_liveball",
            offenseTeam: offense.name,
            defenderTeam: defense.name,
            playType,
            defender: onBall.defender?.bio?.name,
          });
          beginNewPossession(state, nextDefenseTeamId(state.possessionTeamId), null, {
            transition: {
              sourceType: "steal",
              initiator: onBall.defender,
            },
          });
          possessionChanged = true;
          shotClockMode = "hold";
        } else {
          if (!resolveLateClockBailout({
            shooter: ballHandler,
            defender: onBall.defender,
            shooterSpot: ballHandlerSpot,
            sourceDetail: "Post entry neutralized; late-clock bailout shot.",
          })) {
            pushEvent(state, {
              type: "reset",
              offenseTeam: offense.name,
              playType,
              detail: "Post entry neutralized.",
            });
          }
        }
      } else {
        const shootVsPass = getRating(ballHandler, "tendencies.shootVsPass");
        const scoringThreat = average([
          getRating(ballHandler, "postGame.postControl"),
          getRating(ballHandler, "postGame.postHooks"),
          getRating(ballHandler, "postGame.postFadeaways"),
          getRating(ballHandler, "shooting.closeShot"),
        ]);
        const threatBonus = clamp((scoringThreat - 60) / 120, 0, 0.24);
        const passChance = clamp((48 - shootVsPass) / 110 + threatBonus * 0.45, 0.03, 0.5);
        const giveUpChance = clamp((45 - getRating(ballHandler, "skills.shotIQ")) / 200, 0.03, 0.25);

        if (random() < giveUpChance && postTier !== "dom_win") {
          if (!resolveLateClockBailout({
            shooter: ballHandler,
            defender: onBall.defender,
            shooterSpot: ballHandlerSpot,
            sourceDetail: "Post touch kicked out; late-clock bailout shot.",
          })) {
            pushEvent(state, {
              type: "reset",
              offenseTeam: offense.name,
              playType,
              detail: "Post touch kicked back out.",
            });
          }
        } else if (random() < passChance) {
          const targets = offensiveAssignments
            .map((assignment, idx) => ({ ...assignment, idx }))
            .filter((entry) => entry.idx !== ballHandlerIndex);

          const targetScores = targets.map((target) => {
            const cover = getDefenderForOffensiveIndex({
              defenseScheme,
              defenseLineup,
              offensiveAssignments,
              offenseIndex: target.idx,
            });
            const evalResult = evaluatePassTarget({
              passer: ballHandler,
              receiver: target.player,
              receiverDefender: cover.defender,
              receiverSpot: target.spot,
              threatBonus,
              random,
            });

            return {
              ...target,
              cover,
              evalResult,
              score:
                evalResult.openLevel *
                estimateOpenShotValue(target.player, target.spot) *
                (evalResult.canSeeWindow ? 1.25 : 0.5),
            };
          });

          targetScores.sort((a, b) => b.score - a.score);
          const best = targetScores[0];

          if (!best || !best.evalResult.canSeeWindow) {
            if (!resolveLateClockBailout({
              shooter: ballHandler,
              defender: onBall.defender,
              shooterSpot: ballHandlerSpot,
              sourceDetail: "Post kick-out window closed; late-clock bailout shot.",
            })) {
              pushEvent(state, {
                type: "reset",
                offenseTeam: offense.name,
                playType,
                detail: "Post kick-out window closed.",
              });
            }
          } else {
            const passDelivery = resolvePassDelivery({
              passer: ballHandler,
              receiver: best.player,
              defenseContributors: [onBall.defender, best.cover.defender],
              zonePenalty,
              random,
            });
            markInvolvement(offenseTeamId, ballHandler, 0.55);
            markInvolvement(offenseTeamId, best.player, 0.7);
            markInvolvement(defenseTeamId, onBall.defender, 0.35);
            markInvolvement(defenseTeamId, best.cover.defender, 0.45);

            if (passDelivery.turnover) {
              recordTurnover(
                state,
                offenseTeamId,
                ballHandler,
                defenseTeamId,
                passDelivery.stealByPlayer,
              );
              pushEvent(state, {
                type: "turnover_pass",
                offenseTeam: offense.name,
                defenderTeam: defense.name,
                playType,
                detail: `Steal by ${passDelivery.stealBy}`,
              });
              beginNewPossession(state, nextDefenseTeamId(state.possessionTeamId), null, {
                transition: {
                  sourceType: "steal",
                  initiator: passDelivery.stealByPlayer,
                },
              });
              possessionChanged = true;
              shotClockMode = "hold";
            } else if (passDelivery.looseBall) {
              clearPendingAssist(state);
              const looseBall = resolveLooseBallRecovery({
                offenseLineup,
                defenseLineup,
                offenseTeamId,
                defenseTeamId,
                offensiveAssignments,
                defenseScheme,
                receiverSpot: best.spot,
                random,
              });

              if (looseBall.recoveredByTeam === "defense") {
                addPlayerStat(state, offenseTeamId, ballHandler, "turnovers", 1);
                pushEvent(state, {
                  type: "loose_ball_recovery",
                  offenseTeam: offense.name,
                  defenderTeam: defense.name,
                  playType,
                  detail: `Loose ball recovered by ${looseBall.recoveredByPlayer?.bio?.name || "Unknown"}.`,
                });
                beginNewPossession(state, nextDefenseTeamId(state.possessionTeamId));
                possessionChanged = true;
                shotClockMode = "hold";
              } else {
                pushEvent(state, {
                  type: "loose_ball_recovery",
                  offenseTeam: offense.name,
                  playType,
                  detail: `Loose ball recovered by ${looseBall.recoveredByPlayer?.bio?.name || "Unknown"} (${offense.name}).`,
                });
              }
            } else {
              setPendingAssist(state, offenseTeamId, ballHandler, best.player);
              if (!shouldTakeShotThisAction({
                state,
                shooter: best.player,
                shotQuality: best.evalResult.openLevel,
                random,
              })) {
                if (!resolveLateClockBailout({
                  shooter: best.player,
                  defender: best.cover.defender,
                  shooterSpot: best.spot,
                  sourceDetail: "Kick-out window there; late-clock catch-and-shoot bailout.",
                  shotQualityEdge: best.evalResult.openLevel * 0.14 - 0.08,
                })) {
                  pushEvent(state, {
                    type: "reset",
                    offenseTeam: offense.name,
                    playType,
                    detail: "Kick-out was there, but offense waited for late clock.",
                  });
                }
              } else {
                const shotType = chooseShotFromTendencies(best.player, random);
                const contested = best.evalResult.openLevel < 0.56;
                const shot = resolveShot({
                  shooter: best.player,
                  defender: best.cover.defender,
                  shotType,
                  shooterSpot: best.spot,
                  zonePenalty,
                  shotQualityEdge: best.evalResult.openLevel * 0.25,
                  contested,
                  random,
                });
                shot.shooter = best.player;
                shot.assister = ballHandler;
                markInvolvement(offenseTeamId, best.player, 0.9);
                markInvolvement(offenseTeamId, ballHandler, 0.35);
                markInvolvement(defenseTeamId, best.cover.defender, 0.75);

                const endState = resolvePossessionEndAfterShot({
                  state,
                  offenseTeamId,
                  defenseTeamId,
                  offense,
                  defense,
                  offenseLineup,
                  defenseLineup,
                  defenseScheme,
                  offensiveAssignments,
                  playType,
                  shotType,
                  shot,
                  random,
                });
                possessionChanged = endState.possessionChanged;
                shotClockMode = endState.shotClockMode;
              }
            }
          }
        } else {
          const tierShotEdgeByTier = {
            dom_win: 0.5,
            win: 0.22,
            tie: 0.02,
            loss: -0.22,
          };
          const tierShotEdge = tierShotEdgeByTier[postTier] ?? 0;

          const hookWeight = getRating(ballHandler, "postGame.postHooks");
          const fadeWeight = getRating(ballHandler, "postGame.postFadeaways") * 0.9;
          const layWeight = getRating(ballHandler, "shooting.layups") * (postTier === "dom_win" ? 1.5 : 0.6);
          const dunkWeight = getRating(ballHandler, "shooting.dunks") * (postTier === "dom_win" ? 1.4 : 0.55);
          const shotType = pickWeighted(
            [
              { value: "hook", weight: hookWeight },
              { value: "fadeaway", weight: fadeWeight },
              { value: "layup", weight: layWeight },
              { value: "dunk", weight: dunkWeight },
            ],
            random,
          );

          if (!shouldTakeShotThisAction({
            state,
            shooter: ballHandler,
            shotQuality: postTier === "dom_win" ? 0.9 : postTier === "win" ? 0.65 : 0.35,
            random,
          })) {
            if (!resolveLateClockBailout({
              shooter: ballHandler,
              defender: onBall.defender,
              shooterSpot: ballHandlerSpot,
              sourceDetail: "Post touch hesitated; late-clock bailout shot.",
            })) {
              pushEvent(state, {
                type: "reset",
                offenseTeam: offense.name,
                playType,
                detail: "Post touch didn't force a shot; offense reset.",
              });
            }
          } else {
            const shot = resolveShot({
              shooter: ballHandler,
              defender: onBall.defender,
              shotType,
              shooterSpot: ballHandlerSpot,
              zonePenalty,
              shotQualityEdge: tierShotEdge,
              contested: shotType !== "fadeaway",
              random,
            });
            shot.shooter = ballHandler;
            markInvolvement(offenseTeamId, ballHandler, 1);
            markInvolvement(defenseTeamId, onBall.defender, 0.85);

            if (!shot.made && (shotType === "hook" || shotType === "layup" || shotType === "dunk")) {
              const blockChance = clamp(
                0.015 +
                  (getRating(onBall.defender, "defense.shotBlocking") - 50) / 250 +
                  (postTier === "loss" ? 0.06 : 0) +
                  (postTier === "tie" ? 0.02 : 0),
                0.01,
                0.28,
              );
              if (random() < blockChance) {
                shot.blockedByDefense = true;
              }
            }

            const endState = resolvePossessionEndAfterShot({
              state,
              offenseTeamId,
              defenseTeamId,
              offense,
              defense,
              offenseLineup,
              defenseLineup,
              defenseScheme,
              offensiveAssignments,
              playType,
              shotType,
              shot,
              random,
            });
            possessionChanged = endState.possessionChanged;
            shotClockMode = endState.shotClockMode;
          }
        }
      }
    }
  }

  applyChunkClock(state, shotClockMode);
  applyChunkMinutesAndEnergy(state, involvementByTeam);

  if (!possessionChanged && state.shotClockRemaining <= 0) {
    pushEvent(state, {
      type: "turnover_shot_clock",
      offenseTeam: offense.name,
      playType,
    });
    addTeamExtra(state, offenseTeamId, "turnovers", 1);
    beginNewPossession(state, nextDefenseTeamId(state.possessionTeamId), "out_of_bounds");
  }
}

function simulateHalf(state, random = Math.random) {
  while (state.gameClockRemaining > 0) {
    resolveActionChunk(state, random);
  }
}

function simulateGame(homeTeam, awayTeam, options = {}) {
  const random = options.random || Math.random;
  const state = createInitialGameState(homeTeam, awayTeam, random);

  simulateHalf(state, random);

  recoverAllPlayers(state, HALFTIME_RECOVERY);
  runDeadBallSubstitutions(state, "halftime");
  state.currentHalf = 2;
  state.gameClockRemaining = HALF_SECONDS;
  state.shotClockRemaining = SHOT_CLOCK_SECONDS;
  state.possessionNeedsSetup = true;
  state.pendingTransition = null;
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
}) {
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
