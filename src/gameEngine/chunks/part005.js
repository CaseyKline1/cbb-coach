
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

function resolvePassDelivery({
  passer,
  receiver,
  defenseContributors,
  zonePenalty = 0,
  maxRelevantDefenders = 1,
  random = Math.random,
}) {
  const relevantDefenders = (defenseContributors || [])
    .filter(Boolean)
    .slice(0, Math.max(1, maxRelevantDefenders));
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
