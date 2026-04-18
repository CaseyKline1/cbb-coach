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
  const fatigueAdjusted = applyClutchModifier(player, value * (1 - fatigue * impact));
  const role = player?.condition?.possessionRole;
  const offensiveModifier = Number(player?.condition?.offensiveCoachingModifier);
  const defensiveModifier = Number(player?.condition?.defensiveCoachingModifier);
  let coachingModifier = 1;
  if (role === "offense" && Number.isFinite(offensiveModifier)) coachingModifier = offensiveModifier;
  else if (role === "defense" && Number.isFinite(defensiveModifier)) coachingModifier = defensiveModifier;
  return clamp(fatigueAdjusted * coachingModifier, 1, 100);
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
