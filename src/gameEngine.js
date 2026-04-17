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
  const drive = getRating(ballHandler, "tendencies.drive");
  const post = getRating(ballHandler, "tendencies.post");

  const teamDriveBias = offenseTeam?.tendencies?.drive ?? 1;
  const teamPostBias = offenseTeam?.tendencies?.post ?? 1;
  const ballSpot = offenseTeam?.context?.ballHandlerSpot;

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
      ? 0.75
      : 1)
    : 0.2;

  return pickWeighted(
    [
      {
        value: "dribble_drive",
        weight: Math.max(1, drive) * teamDriveBias,
      },
      {
        value: "post_up",
        weight: canPost ? Math.max(1, post) * teamPostBias * postDistancePenalty : 1,
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
  shotQualityEdge = 0,
  contested = true,
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
    midrange: {
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
        "skills.shotIQ",
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

  const profile = shotProfiles[shotType] || shotProfiles.jump;
  const shotResult = resolveInteraction({
    offensePlayer: shooter,
    defensePlayer: defender,
    offenseRatings: profile.offenseRatings,
    defenseRatings: profile.defenseRatings,
    contextEdge: zonePenalty + shotQualityEdge,
    random,
  });

  const drawFoul = getRating(shooter, profile.foulDraw);
  const defensiveControl = getRating(defender, "defense.defensiveControl");
  const foulPressure = (drawFoul - defensiveControl) / 140;
  const baseFoulChance = clamp(0.06 + foulPressure, 0.01, 0.3);
  const isShootingFoul = contested && random() < baseFoulChance;

  let made = shotResult.success;
  if (isShootingFoul) {
    const makePenalty = 0.12 - clamp((drawFoul - 50) / 400, -0.04, 0.07);
    const adjustedProbability = clamp(
      shotResult.successProbability - makePenalty,
      0.02,
      0.9,
    );
    made = random() < adjustedProbability;
  }

  return {
    made,
    points: made ? profile.basePoints : 0,
    shotType,
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

  if (shotIQ >= 70) {
    return layupQuality >= dunkQuality ? "layup" : "dunk";
  }

  return random() < 0.55 ? "layup" : "dunk";
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

function evaluatePassTarget({ passer, receiver, receiverDefender, threatBonus = 0, random = Math.random }) {
  const getOpen = resolveInteraction({
    offensePlayer: receiver,
    defensePlayer: receiverDefender,
    offenseRatings: ["skills.offballOffense", "athleticism.agility", "skills.hands"],
    defenseRatings: ["defense.offballDefense", "defense.lateralQuickness", "defense.perimeterDefense"],
    contextEdge: threatBonus,
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
  const compositeDefender = {
    skills: {},
    defense: {
      passPerception: average(defenseContributors.map((p) => getRating(p, "defense.passPerception"))),
      steals: average(defenseContributors.map((p) => getRating(p, "defense.steals"))),
      offballDefense: average(defenseContributors.map((p) => getRating(p, "defense.offballDefense"))),
    },
    athleticism: {
      lateralQuickness: average(defenseContributors.map((p) => getRating(p, "defense.lateralQuickness"))),
    },
  };

  const interaction = resolveInteraction({
    offensePlayer: {
      skills: {
        passingAccuracy: getRating(passer, "skills.passingAccuracy"),
        passingVision: getRating(passer, "skills.passingVision"),
        passingIQ: getRating(passer, "skills.passingIQ"),
        hands: getRating(receiver, "skills.hands"),
      },
      athleticism: {},
      defense: {},
    },
    defensePlayer: compositeDefender,
    offenseRatings: ["skills.passingAccuracy", "skills.hands", "skills.passingVision", "skills.passingIQ"],
    defenseRatings: ["defense.passPerception", "defense.steals", "defense.offballDefense"],
    contextEdge: zonePenalty,
    random,
  });

  let stealBy = null;
  if (!interaction.success) {
    const defender = pickWeighted(
      defenseContributors.map((d) => ({
        value: d,
        weight: getRating(d, "defense.steals") + getRating(d, "defense.passPerception"),
      })),
      random,
    );
    stealBy = defender?.bio?.name || "Unknown";
  }

  return {
    turnover: !interaction.success,
    stealBy,
    interaction,
  };
}

function resolvePossessionEndAfterShot({
  state,
  offense,
  defense,
  offenseLineup,
  defenseLineup,
  defenseScheme,
  playType,
  shotType,
  shot,
  random = Math.random,
}) {
  if (shot.made) {
    offense.score += shot.points;
    let foulDetail = "";
    if (shot.isShootingFoul) {
      const bonus = resolveFreeThrows(
        shot.shooter || offenseLineup[0],
        shot.madeOnFoul ? 1 : shot.foulShotsAwarded,
        random,
      );
      offense.score += bonus;
      foulDetail = ` + ${bonus} FT`;
    }

    pushEvent(state, {
      type: "made_shot",
      offenseTeam: offense.name,
      points: shot.points,
      playType,
      shotType,
      detail: foulDetail || undefined,
    });
    beginNewPossession(state, nextDefenseTeamId(state.possessionTeamId));
    return { possessionChanged: true, shotClockMode: "hold" };
  }

  if (shot.isShootingFoul) {
    const ftMade = resolveFreeThrows(shot.shooter || offenseLineup[0], shot.foulShotsAwarded, random);
    offense.score += ftMade;
    pushEvent(state, {
      type: "shooting_foul",
      offenseTeam: offense.name,
      playType,
      shotType,
      points: ftMade,
    });
    beginNewPossession(state, nextDefenseTeamId(state.possessionTeamId));
    return { possessionChanged: true, shotClockMode: "hold" };
  }

  const rebound = resolveRebound({
    offenseLineup,
    defenseLineup,
    defenseScheme,
    random,
  });

  if (shot.blockedByDefense) {
    pushEvent(state, {
      type: "blocked_shot",
      offenseTeam: offense.name,
      defenseTeam: defense.name,
      playType,
      shotType,
    });
    beginNewPossession(state, nextDefenseTeamId(state.possessionTeamId));
    return { possessionChanged: true, shotClockMode: "hold" };
  }

  if (rebound.offensiveRebound) {
    state.shotClockRemaining = SHOT_CLOCK_SECONDS;
    pushEvent(state, {
      type: "miss_oreb",
      offenseTeam: offense.name,
      playType,
      shotType,
    });
    return { possessionChanged: false, shotClockMode: "tick" };
  }

  pushEvent(state, {
    type: "miss_dreb",
    offenseTeam: offense.name,
    defenseTeam: defense.name,
    playType,
    shotType,
  });
  beginNewPossession(state, nextDefenseTeamId(state.possessionTeamId));
  return { possessionChanged: true, shotClockMode: "hold" };
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

  offense.context = { ballHandlerSpot };
  const playType = choosePlayType({ offenseTeam: offense, ballHandler, random });
  delete offense.context;

  let possessionChanged = false;
  let shotClockMode = "tick";
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
      contextEdge: zonePenalty,
      random,
    });

    const decisiveOWin = drive.edge >= 0.58;
    const oWin = drive.edge >= 0.1;
    const decisiveDWin = drive.edge <= -0.62;
    const dTieOrSmallWin = !oWin && !decisiveDWin;

    if (decisiveDWin) {
      const stealChance = clamp(
        0.08 + (getRating(onBall.defender, "defense.steals") - getRating(ballHandler, "skills.ballSafety")) / 160,
        0.02,
        0.4,
      );
      if (random() < stealChance) {
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
          detail: "Defense cut off the drive.",
        });
      }
    } else if (dTieOrSmallWin) {
      pushEvent(state, {
        type: "reset",
        offenseTeam: offense.name,
        playType,
        detail: "Drive stalled.",
      });
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
        (55 - shootVsPass) / 100 + (helpArrives ? 0.22 : 0.06),
        0.05,
        decisiveOWin ? 0.84 : 0.74,
      );
      const jumpChance = decisiveOWin ? 0 : clamp((shootVsPass - 55) / 180, 0, 0.25);
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
            threatBonus,
            random,
          });

          return {
            ...target,
            cover,
            evalResult,
            score: evalResult.openLevel * (evalResult.canSeeWindow ? 1.3 : 0.45),
          };
        });

        targetScores.sort((a, b) => b.score - a.score);
        const best = targetScores[0];
        if (!best || !best.evalResult.canSeeWindow) {
          pushEvent(state, {
            type: "reset",
            offenseTeam: offense.name,
            playType,
            detail: "Drive-and-kick read not found.",
          });
        } else {
          const passDelivery = resolvePassDelivery({
            passer: ballHandler,
            receiver: best.player,
            defenseContributors: [onBall.defender, best.cover.defender],
            zonePenalty,
            random,
          });

          if (passDelivery.turnover) {
            pushEvent(state, {
              type: "turnover_pass",
              offenseTeam: offense.name,
              defenderTeam: defense.name,
              playType,
              detail: `Steal by ${passDelivery.stealBy}`,
            });
            beginNewPossession(state, nextDefenseTeamId(state.possessionTeamId));
            possessionChanged = true;
            shotClockMode = "hold";
          } else {
            const shotType = chooseShotFromTendencies(best.player, random);
            const contested = best.evalResult.openLevel < 0.56;
            const shot = resolveShot({
              shooter: best.player,
              defender: best.cover.defender,
              shotType,
              zonePenalty,
              shotQualityEdge: best.evalResult.openLevel * 0.32,
              contested,
              random,
            });
            shot.shooter = best.player;

            const endState = resolvePossessionEndAfterShot({
              state,
              offense,
              defense,
              offenseLineup,
              defenseLineup,
              defenseScheme,
              playType,
              shotType,
              shot,
              random,
            });
            possessionChanged = endState.possessionChanged;
            shotClockMode = endState.shotClockMode;
          }
        }
      } else {
        const shotType = jumpDecision ? chooseShotFromTendencies(ballHandler, random) : chooseDriveFinishType(ballHandler, random);
        const contestWeight = decisiveOWin ? 0.08 : 0.2;
        const shotQualityEdge = decisiveOWin ? 0.32 : 0.1;
        const shot = resolveShot({
          shooter: ballHandler,
          defender: onBall.defender,
          shotType,
          zonePenalty,
          shotQualityEdge: shotQualityEdge - (helpArrives ? contestWeight : 0),
          contested: true,
          random,
        });
        shot.shooter = ballHandler;

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
          offense,
          defense,
          offenseLineup,
          defenseLineup,
          defenseScheme,
          playType,
          shotType,
          shot,
          random,
        });
        possessionChanged = endState.possessionChanged;
        shotClockMode = endState.shotClockMode;
      }
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
      pushEvent(state, {
        type: "reset",
        offenseTeam: offense.name,
        playType,
        detail: "No post touch angle available.",
      });
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
          0.07 + (getRating(onBall.defender, "defense.steals") - getRating(ballHandler, "skills.ballSafety")) / 170,
          0.02,
          0.34,
        );
        if (random() < stealChance) {
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
            detail: "Post entry neutralized.",
          });
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
        const passChance = clamp((52 - shootVsPass) / 100 + threatBonus * 0.65, 0.05, 0.6);
        const giveUpChance = clamp((45 - getRating(ballHandler, "skills.shotIQ")) / 200, 0.03, 0.25);

        if (random() < giveUpChance && postTier !== "dom_win") {
          pushEvent(state, {
            type: "reset",
            offenseTeam: offense.name,
            playType,
            detail: "Post touch kicked back out.",
          });
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
              threatBonus,
              random,
            });

            return {
              ...target,
              cover,
              evalResult,
              score: evalResult.openLevel * (evalResult.canSeeWindow ? 1.25 : 0.5),
            };
          });

          targetScores.sort((a, b) => b.score - a.score);
          const best = targetScores[0];

          if (!best || !best.evalResult.canSeeWindow) {
            pushEvent(state, {
              type: "reset",
              offenseTeam: offense.name,
              playType,
              detail: "Post kick-out window closed.",
            });
          } else {
            const passDelivery = resolvePassDelivery({
              passer: ballHandler,
              receiver: best.player,
              defenseContributors: [onBall.defender, best.cover.defender],
              zonePenalty,
              random,
            });

            if (passDelivery.turnover) {
              pushEvent(state, {
                type: "turnover_pass",
                offenseTeam: offense.name,
                defenderTeam: defense.name,
                playType,
                detail: `Steal by ${passDelivery.stealBy}`,
              });
              beginNewPossession(state, nextDefenseTeamId(state.possessionTeamId));
              possessionChanged = true;
              shotClockMode = "hold";
            } else {
              const shotType = chooseShotFromTendencies(best.player, random);
              const contested = best.evalResult.openLevel < 0.56;
              const shot = resolveShot({
                shooter: best.player,
                defender: best.cover.defender,
                shotType,
                zonePenalty,
                shotQualityEdge: best.evalResult.openLevel * 0.25,
                contested,
                random,
              });
              shot.shooter = best.player;

              const endState = resolvePossessionEndAfterShot({
                state,
                offense,
                defense,
                offenseLineup,
                defenseLineup,
                defenseScheme,
                playType,
                shotType,
                shot,
                random,
              });
              possessionChanged = endState.possessionChanged;
              shotClockMode = endState.shotClockMode;
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

          const shot = resolveShot({
            shooter: ballHandler,
            defender: onBall.defender,
            shotType,
            zonePenalty,
            shotQualityEdge: tierShotEdge,
            contested: shotType !== "fadeaway",
            random,
          });
          shot.shooter = ballHandler;

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
            offense,
            defense,
            offenseLineup,
            defenseLineup,
            defenseScheme,
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
