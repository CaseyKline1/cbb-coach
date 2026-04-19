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
    madeProbability = clamp(
      madeProbability - THREE_POINT_SUCCESS_PROBABILITY_PENALTY,
      0.02,
      THREE_POINT_MAX_MAKE_PROBABILITY,
    );
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

function getExcessWingspanInches(player) {
  return Math.max(0, getWingspanInches(player) - getHeightInches(player) - 2);
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
