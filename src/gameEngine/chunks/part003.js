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
