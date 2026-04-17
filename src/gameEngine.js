const { createPlayer } = require("./player");

const CHUNK_SECONDS = 5;
const HALF_SECONDS = 20 * 60;
const SHOT_CLOCK_SECONDS = 30;

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

const DefenseScheme = Object.freeze({
  MAN_TO_MAN: "man_to_man",
  ZONE_2_3: "2_3",
  ZONE_3_2: "3_2",
  ZONE_1_3_1: "1_3_1",
  PACK_LINE: "pack_line",
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
  if (value <= 10) return value * 10;
  return value;
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
  const edge = (offense.score - defense.score) / 14 + contextEdge;
  const successProbability = clamp(logistic(edge), 0.03, 0.97);

  return {
    success: random() < successProbability,
    successProbability,
    offense,
    defense,
    edge,
  };
}

function getDefaultLineup(team) {
  if (team?.lineup?.length === 5) return team.lineup;
  if (team?.players?.length >= 5) return team.players.slice(0, 5);
  return new Array(5).fill(null).map(() => createPlayer());
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
    return {
      value: index,
      weight: Math.max(1, ballSkill),
    };
  });

  return pickWeighted(weighted, random);
}

function choosePlayType({ offenseTeam, ballHandler, random = Math.random }) {
  // This is intentionally modular so we can later plug in richer team/player tendency logic.
  const drive = getRating(ballHandler, "tendencies.drive");
  const post = getRating(ballHandler, "tendencies.post");
  const inside = getRating(ballHandler, "tendencies.inside");
  const three = getRating(ballHandler, "tendencies.threePoint");
  const mid = getRating(ballHandler, "tendencies.midrange");
  const shootVsPass = getRating(ballHandler, "tendencies.shootVsPass");

  const teamDriveBias = offenseTeam?.tendencies?.drive ?? 1;
  const teamPostBias = offenseTeam?.tendencies?.post ?? 1;
  const teamMotionBias = offenseTeam?.tendencies?.ballMovement ?? 1;

  return pickWeighted(
    [
      {
        value: "drive_shoot",
        weight: (drive + inside + shootVsPass) * teamDriveBias,
      },
      {
        value: "drive_pass",
        weight: (drive + (100 - shootVsPass) + teamMotionBias * 8) * teamDriveBias,
      },
      {
        value: "drive_reset",
        weight: drive + getRating(ballHandler, "skills.ballSafety") + 10,
      },
      {
        value: "post_shoot",
        weight: (post + inside + shootVsPass) * teamPostBias,
      },
      {
        value: "swing_shot",
        weight: three + mid + teamMotionBias * 10,
      },
    ],
    random,
  );
}

function resolveShot({
  shooter,
  defender,
  shotType,
  zonePenalty = 0,
  random = Math.random,
}) {
  const shotProfiles = {
    rim: {
      offenseRatings: [
        "shooting.layups",
        "shooting.closeShot",
        "athleticism.burst",
        "skills.shotIQ",
      ],
      defenseRatings: [
        "defense.shotContest",
        "defense.perimeterDefense",
        "athleticism.vertical",
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
        "skills.shotIQ",
        "athleticism.agility",
      ],
      defenseRatings: [
        "defense.shotContest",
        "defense.perimeterDefense",
        "athleticism.lateralQuickness",
      ],
      foulDraw: "shooting.drawFoul",
      basePoints: 2,
    },
    three: {
      offenseRatings: [
        "shooting.threePointShooting",
        "shooting.upTopThrees",
        "skills.shotIQ",
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

  const profile = shotProfiles[shotType];
  const shotResult = resolveInteraction({
    offensePlayer: shooter,
    defensePlayer: defender,
    offenseRatings: profile.offenseRatings,
    defenseRatings: profile.defenseRatings,
    contextEdge: zonePenalty,
    random,
  });

  const foulChance = clamp((getRating(shooter, profile.foulDraw) - 45) / 220, 0.02, 0.18);
  const isShootingFoul = !shotResult.success && random() < foulChance;

  return {
    made: shotResult.success,
    points: shotResult.success ? profile.basePoints : 0,
    shotType,
    interaction: shotResult,
    isShootingFoul,
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

function resolveRebound({
  offenseLineup,
  defenseLineup,
  defenseScheme,
  random = Math.random,
}) {
  const offenseScore = average(
    offenseLineup.map((player) =>
      average([
        getRating(player, "rebounding.offensiveRebounding"),
        getRating(player, "rebounding.boxouts"),
        getRating(player, "athleticism.vertical"),
        getRating(player, "skills.hustle"),
      ]),
    ),
  );

  let defenseScore = average(
    defenseLineup.map((player) =>
      average([
        getRating(player, "rebounding.defensiveRebound"),
        getRating(player, "rebounding.boxouts"),
        getRating(player, "athleticism.strength"),
        getRating(player, "skills.hustle"),
      ]),
    ),
  );

  if (defenseScheme !== DefenseScheme.MAN_TO_MAN) {
    const freeReboundersBoost = 2 + random() * 3;
    defenseScore -= freeReboundersBoost;
  }

  const orebProbability = clamp(logistic((offenseScore - defenseScore) / 12), 0.12, 0.48);
  return {
    offensiveRebound: random() < orebProbability,
    orebProbability,
  };
}

function nextDefenseTeamId(currentOffenseTeamId) {
  return currentOffenseTeamId === 0 ? 1 : 0;
}

function createInitialGameState(homeTeam, awayTeam, random = Math.random) {
  const homeLineup = getDefaultLineup(homeTeam);
  const awayLineup = getDefaultLineup(awayTeam);

  return {
    teams: [
      {
        ...homeTeam,
        lineup: homeLineup,
        score: 0,
      },
      {
        ...awayTeam,
        lineup: awayLineup,
        score: 0,
      },
    ],
    possessionTeamId: random() < 0.5 ? 0 : 1,
    gameClockRemaining: HALF_SECONDS,
    currentHalf: 1,
    shotClockRemaining: SHOT_CLOCK_SECONDS,
    possessionNeedsSetup: true,
    playByPlay: [],
  };
}

function beginNewPossession(state, offenseTeamId) {
  state.possessionTeamId = offenseTeamId;
  state.shotClockRemaining = SHOT_CLOCK_SECONDS;
  state.possessionNeedsSetup = true;
}

function pushEvent(state, event) {
  const elapsed = HALF_SECONDS * (state.currentHalf - 1) + (HALF_SECONDS - state.gameClockRemaining);
  state.playByPlay.push({
    half: state.currentHalf,
    elapsedSecondsInHalf: HALF_SECONDS - state.gameClockRemaining,
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

function resolveActionChunk(state, random = Math.random) {
  const offense = state.teams[state.possessionTeamId];
  const defense = state.teams[nextDefenseTeamId(state.possessionTeamId)];

  const offenseLineup = offense.lineup;
  const defenseLineup = defense.lineup;
  const defenseScheme = defense.defenseScheme || DefenseScheme.MAN_TO_MAN;

  if (state.possessionNeedsSetup && !(defense?.tendencies?.press > 1)) {
    state.possessionNeedsSetup = false;
    applyChunkClock(state, "tick");
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
      beginNewPossession(state, nextDefenseTeamId(state.possessionTeamId));
    }

    return;
  }

  const formation = offense.formation || OffensiveFormation.MOTION;
  const offensiveAssignments = assignOffensiveSpots(offenseLineup, formation, random);
  const ballHandlerIndex = pickBallHandler(offensiveAssignments, random);
  const ballHandler = offensiveAssignments[ballHandlerIndex].player;
  const onBall = getOnBallDefender({
    defenseScheme,
    defenseLineup,
    offensiveAssignments,
    ballHandlerIndex,
  });

  const zonePenalty = onBall.isZone
    ? -0.08 + zoneDistanceAdvantage(onBall.defender, onBall.startDistance)
    : 0;

  const playType = choosePlayType({ offenseTeam: offense, ballHandler, random });

  let possessionChanged = false;
  let shotClockMode = "tick";

  if (playType === "drive_reset") {
    const security = resolveBallSecurity({
      offensePlayer: ballHandler,
      defensePlayer: onBall.defender,
      zonePenalty,
      random,
    });

    if (security.turnover) {
      pushEvent(state, {
        type: "turnover_liveball",
        offenseTeam: offense.name,
        defenderTeam: defense.name,
        playType,
      });
      beginNewPossession(state, nextDefenseTeamId(state.possessionTeamId));
      possessionChanged = true;
      shotClockMode = "hold";
    } else {
      pushEvent(state, {
        type: "reset",
        offenseTeam: offense.name,
        playType,
      });
    }
  }

  if (playType === "drive_pass") {
    const pass = resolvePass({
      passer: ballHandler,
      defender: onBall.defender,
      zonePenalty,
      random,
    });

    if (pass.turnover) {
      pushEvent(state, {
        type: "turnover_pass",
        offenseTeam: offense.name,
        defenderTeam: defense.name,
        playType,
      });
      beginNewPossession(state, nextDefenseTeamId(state.possessionTeamId));
      possessionChanged = true;
      shotClockMode = "hold";
    } else {
      const shot = resolveShot({
        shooter: ballHandler,
        defender: onBall.defender,
        shotType: random() < 0.45 ? "three" : "jump",
        zonePenalty,
        random,
      });

      if (shot.made) {
        offense.score += shot.points;
        pushEvent(state, {
          type: "made_shot",
          offenseTeam: offense.name,
          points: shot.points,
          playType,
          shotType: shot.shotType,
        });
        beginNewPossession(state, nextDefenseTeamId(state.possessionTeamId));
        possessionChanged = true;
        shotClockMode = "hold";
      } else {
        const rebound = resolveRebound({
          offenseLineup,
          defenseLineup,
          defenseScheme,
          random,
        });

        if (rebound.offensiveRebound) {
          state.shotClockRemaining = SHOT_CLOCK_SECONDS;
          pushEvent(state, {
            type: "miss_oreb",
            offenseTeam: offense.name,
            playType,
            shotType: shot.shotType,
          });
        } else {
          pushEvent(state, {
            type: "miss_dreb",
            offenseTeam: offense.name,
            defenseTeam: defense.name,
            playType,
            shotType: shot.shotType,
          });
          beginNewPossession(state, nextDefenseTeamId(state.possessionTeamId));
          possessionChanged = true;
          shotClockMode = "hold";
        }
      }
    }
  }

  if (playType === "drive_shoot" || playType === "post_shoot" || playType === "swing_shot") {
    const shotType =
      playType === "post_shoot"
        ? "post"
        : playType === "drive_shoot"
          ? "rim"
          : random() < 0.7
            ? "three"
            : "jump";

    const shot = resolveShot({
      shooter: ballHandler,
      defender: onBall.defender,
      shotType,
      zonePenalty,
      random,
    });

    if (shot.made) {
      offense.score += shot.points;
      pushEvent(state, {
        type: "made_shot",
        offenseTeam: offense.name,
        points: shot.points,
        playType,
        shotType,
      });
      beginNewPossession(state, nextDefenseTeamId(state.possessionTeamId));
      possessionChanged = true;
      shotClockMode = "hold";
    } else {
      const rebound = resolveRebound({
        offenseLineup,
        defenseLineup,
        defenseScheme,
        random,
      });

      if (rebound.offensiveRebound) {
        state.shotClockRemaining = SHOT_CLOCK_SECONDS;
        pushEvent(state, {
          type: "miss_oreb",
          offenseTeam: offense.name,
          playType,
          shotType,
        });
      } else {
        pushEvent(state, {
          type: "miss_dreb",
          offenseTeam: offense.name,
          defenseTeam: defense.name,
          playType,
          shotType,
        });
        beginNewPossession(state, nextDefenseTeamId(state.possessionTeamId));
        possessionChanged = true;
        shotClockMode = "hold";
      }
    }
  }

  applyChunkClock(state, shotClockMode);

  if (!possessionChanged && state.shotClockRemaining <= 0) {
    pushEvent(state, {
      type: "turnover_shot_clock",
      offenseTeam: offense.name,
      playType,
    });
    beginNewPossession(state, nextDefenseTeamId(state.possessionTeamId));
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

  state.currentHalf = 2;
  state.gameClockRemaining = HALF_SECONDS;
  state.shotClockRemaining = SHOT_CLOCK_SECONDS;
  state.possessionNeedsSetup = true;

  simulateHalf(state, random);

  return {
    home: {
      name: state.teams[0].name,
      score: state.teams[0].score,
    },
    away: {
      name: state.teams[1].name,
      score: state.teams[1].score,
    },
    winner:
      state.teams[0].score === state.teams[1].score
        ? null
        : state.teams[0].score > state.teams[1].score
          ? state.teams[0].name
          : state.teams[1].name,
    playByPlay: state.playByPlay,
  };
}

function createTeam({
  name,
  players,
  lineup,
  formation = OffensiveFormation.MOTION,
  defenseScheme = DefenseScheme.MAN_TO_MAN,
  tendencies = {},
}) {
  return {
    name,
    players: players || lineup || [],
    lineup: lineup || players || [],
    formation,
    defenseScheme,
    tendencies,
  };
}

module.exports = {
  CHUNK_SECONDS,
  HALF_SECONDS,
  SHOT_CLOCK_SECONDS,
  OffensiveSpot,
  OffensiveFormation,
  DefenseScheme,
  createTeam,
  createInitialGameState,
  resolveInteraction,
  resolveActionChunk,
  simulateHalf,
  simulateGame,
};
