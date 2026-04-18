  const targets = lineup.filter((player) => player && player !== ballHandler);
  if (!targets.length) return ballHandler;
  return pickWeighted(
    targets.map((player) => {
      const utility =
        getRating(player, "skills.hands") * 0.28 +
        getRating(player, "skills.offballOffense") * 0.23 +
        getRating(player, "athleticism.speed") * 0.2 +
        getRating(player, "athleticism.burst") * 0.16 +
        getRating(player, "skills.ballHandling") * 0.13;
      return {
        value: player,
        weight: Math.max(1, utility * (0.86 + random() * 0.28)),
      };
    }),
    random,
  );
}

function pickPressTrappers(defenseLineup, random = Math.random) {
  if (!defenseLineup.length) return [];
  const sorted = defenseLineup
    .map((player) => {
      const pressure =
        getRating(player, "defense.steals") * 0.32 +
        getRating(player, "defense.passPerception") * 0.28 +
        getRating(player, "athleticism.burst") * 0.21 +
        getRating(player, "athleticism.agility") * 0.18 +
        getRating(player, "defense.offballDefense") * 0.16 +
        getRating(player, "defense.lateralQuickness") * 0.08 +
        getRating(player, "athleticism.speed") * 0.11 +
        getExcessWingspanInches(player) * 5.5;
      return {
        player,
        weight: Math.max(1, pressure * (0.86 + random() * 0.26)),
      };
    })
    .sort((a, b) => b.weight - a.weight);
  const primary = sorted[0]?.player;
  const secondaryCandidates = sorted.filter((entry) => entry.player !== primary);
  const secondary = secondaryCandidates.length
    ? pickWeighted(
      secondaryCandidates.map((entry) => ({ value: entry.player, weight: entry.weight })),
      random,
    )
    : null;
  return [primary, secondary].filter(Boolean);
}

function pickPressStealer(defenders, random = Math.random) {
  const candidates = (defenders || []).filter(Boolean);
  if (!candidates.length) return null;
  return pickWeighted(
    candidates.map((player) => ({
      value: player,
      weight: Math.max(
        1,
        getRating(player, "defense.steals") +
          getRating(player, "defense.passPerception") +
          getExcessWingspanInches(player) * 4.5,
      ),
    })),
    random,
  );
}

function resolveBackcourtLooseBallRecovery({ offenseLineup, defenseLineup, random = Math.random }) {
  const candidates = [
    ...offenseLineup.map((player) => ({ player, team: "offense" })),
    ...defenseLineup.map((player) => ({ player, team: "defense" })),
  ].filter((entry) => entry.player);

  const recoveredBy = pickWeighted(
    candidates.map((entry) => {
      const player = entry.player;
      const weight =
        getRating(player, "skills.hustle") * 0.42 +
        getRating(player, "athleticism.burst") * 0.26 +
        getRating(player, "skills.hands") * 0.22 +
        getRating(player, "athleticism.speed") * 0.1;
      return {
        value: entry,
        weight: Math.max(1, weight * (0.85 + random() * 0.32)),
      };
    }),
    random,
  );

  return recoveredBy;
}

function resolvePressTrapInteraction({
  ballHandler,
  trapDefenders,
  pressTendency,
  random = Math.random,
}) {
  const defenders = (trapDefenders || []).filter(Boolean);
  const avgExcessWingspan = average(defenders.map(getExcessWingspanInches));
  const pressAthleticPressure = average(
    defenders.map((player) =>
      getRating(player, "athleticism.burst") * 0.35 +
      getRating(player, "athleticism.agility") * 0.28 +
      getRating(player, "defense.offballDefense") * 0.27 +
      getRating(player, "defense.lateralQuickness") * 0.1,
    ),
  );
  const handlerRead =
    average([
      getRating(ballHandler, "skills.passingIQ"),
      getRating(ballHandler, "skills.passingVision"),
    ]) - 55;
  const contextEdge = clamp(
    -0.08 -
      Math.max(0, pressTendency - 1) * 0.18 -
      avgExcessWingspan * 0.028 -
      (pressAthleticPressure - 60) / 360 +
      handlerRead / 520,
    -0.38,
    0.14,
  );
  const compositeDefender = {
    defense: {
      steals: average(defenders.map((player) => getRating(player, "defense.steals"))),
      passPerception: average(defenders.map((player) => getRating(player, "defense.passPerception"))),
      lateralQuickness: average(defenders.map((player) => getRating(player, "defense.lateralQuickness"))),
      offballDefense: average(defenders.map((player) => getRating(player, "defense.offballDefense"))),
    },
    athleticism: {
      burst: average(defenders.map((player) => getRating(player, "athleticism.burst"))),
      agility: average(defenders.map((player) => getRating(player, "athleticism.agility"))),
    },
    skills: {},
  };
  const interaction = resolveInteraction({
    offensePlayer: ballHandler,
    defensePlayer: compositeDefender,
    offenseRatings: [
      "skills.ballHandling",
      "skills.ballSafety",
      "skills.passingIQ",
      "skills.passingVision",
      "athleticism.agility",
    ],
    defenseRatings: [
      "defense.steals",
      "defense.passPerception",
      "defense.lateralQuickness",
      "defense.offballDefense",
      "athleticism.burst",
      "athleticism.agility",
    ],
    contextEdge,
    random,
  });

  return {
    interaction,
    avgExcessWingspan,
  };
}

function resolvePressBreakWindow({
  state,
  offenseTeamId,
  defenseTeamId,
  offense,
  defense,
  offenseLineup,
  defenseLineup,
  markInvolvement,
  random = Math.random,
}) {
  if (!state.possessionNeedsSetup) return { handled: false };

  let pending = state.pendingPress;
  if (!pending) {
    const shouldPress = shouldApplyPressThisPossession({
      state,
      offense,
      defense,
      random,
    });
    if (!shouldPress) return { handled: false };
    pending = {
      chunksInBackcourt: 0,
      progress: 0,
      ballHandler: pickPressBallHandler(offenseLineup, random),
    };
    state.pendingPress = pending;
    pushEvent(state, {
      type: "press_start",
      offenseTeam: offense.name,
      defenseTeam: defense.name,
      detail: `${defense.name} showed full-court pressure.`,
    });
  }

  const ballHandler = pending.ballHandler || pickPressBallHandler(offenseLineup, random);
  const pressTendency = getTeamTendencyMultiplier(defense, "press", 1);
  const trapRate = getTeamTendencyMultiplier(defense, "trapRate", pressTendency);
  const teamPressAthleticProfile = average(
    defenseLineup.map((player) =>
      getRating(player, "athleticism.burst") * 0.33 +
      getRating(player, "athleticism.agility") * 0.28 +
      getRating(player, "defense.offballDefense") * 0.29 +
      getRating(player, "defense.lateralQuickness") * 0.1,
    ),
  );
  const trapChance = clamp(
    PRESS_TRAP_BASE_CHANCE +
      Math.max(0, trapRate - 1) * 0.24 +
      Math.max(0, pressTendency - 1) * 0.12 +
      (teamPressAthleticProfile - 60) / 280 +
      pending.chunksInBackcourt * 0.04,
    0.5,
    0.93,
  );
  const trapOnBall = random() < trapChance;
  const trapDefenders = trapOnBall
    ? pickPressTrappers(defenseLineup, random)
    : [pickTransitionPointDefender(defenseLineup, random)];
  const primaryDefender = trapDefenders[0];

  markInvolvement(offenseTeamId, ballHandler, 1.05);
  trapDefenders.forEach((player, idx) => markInvolvement(defenseTeamId, player, idx === 0 ? 1.02 : 0.88));
  offenseLineup.forEach((player) => {
    if (player !== ballHandler) markInvolvement(offenseTeamId, player, 0.26);
  });
  defenseLineup.forEach((player) => {
    if (!trapDefenders.includes(player)) markInvolvement(defenseTeamId, player, 0.34);
  });

  const pressBreakPass = getTeamTendencyMultiplier(offense, "pressBreakPass", 1);
  const passingControl =
    average([
      getRating(ballHandler, "skills.passingVision"),
      getRating(ballHandler, "skills.passingIQ"),
      getRating(ballHandler, "skills.passingAccuracy"),
    ]) - 60;
  const dribbleControl =
    average([
      getRating(ballHandler, "skills.ballHandling"),
      getRating(ballHandler, "skills.ballSafety"),
      getRating(ballHandler, "athleticism.speed"),
    ]) - 60;
  const passChance = clamp(
    0.44 + passingControl / 180 - dribbleControl / 320 + (pressBreakPass - 1) * 0.18 + (trapOnBall ? 0.08 : -0.04),
    0.18,
    0.84,
  );
  const actionType = random() < passChance ? "pass" : "dribble";

  if (trapOnBall) {
    const trap = resolvePressTrapInteraction({
      ballHandler,
      trapDefenders,
      pressTendency,
      random,
    });
    if (!trap.interaction.success) {
      const stealChance = clamp(
        0.56 +
          (0.58 - trap.interaction.successProbability) * 0.68 +
          trap.avgExcessWingspan * 0.034 +
          (actionType === "pass" ? 0.06 : 0),
        0.5,
        0.96,
      );
      if (random() < stealChance) {
        const stealer = pickPressStealer(trapDefenders, random);
        recordTurnover(state, offenseTeamId, ballHandler, defenseTeamId, stealer);
        pushEvent(state, {
          type: "turnover_press_trap",
          offenseTeam: offense.name,
          defenderTeam: defense.name,
          playType: "press_break",
          defender: stealer?.bio?.name || "Unknown",
          detail: "Trap forced a live-ball turnover in the backcourt.",
        });
        beginNewPossession(state, defenseTeamId, null, {
          transition: {
            sourceType: "steal",
            initiator: stealer,
          },
        });
        return {
          handled: true,
          playType: "press_break",
          possessionChanged: true,
          shotClockMode: "hold",
        };
      }

      const looseBall = resolveBackcourtLooseBallRecovery({
        offenseLineup,
        defenseLineup,
        random,
      });
      if (looseBall.team === "defense") {
        addPlayerStat(state, offenseTeamId, ballHandler, "turnovers", 1);
        addTeamExtra(state, offenseTeamId, "turnovers", 1);
        pushEvent(state, {
          type: "loose_ball_recovery",
          offenseTeam: offense.name,
          defenderTeam: defense.name,
          playType: "press_break",
          detail: `Loose ball won by ${looseBall.player?.bio?.name || "Unknown"} (${defense.name}).`,
        });
        beginNewPossession(state, defenseTeamId);
        return {
          handled: true,
          playType: "press_break",
          possessionChanged: true,
          shotClockMode: "hold",
        };
      }

      pending.ballHandler = looseBall.player || ballHandler;
      pushEvent(state, {
        type: "loose_ball_recovery",
        offenseTeam: offense.name,
        playType: "press_break",
        detail: `Offense survived the trap and recovered the ball (${pending.ballHandler?.bio?.name || "Unknown"}).`,
      });
    }
  }

  if (actionType === "pass") {
    const receiver = pickPressReceiver(offenseLineup, ballHandler, random);
    const passDelivery = resolvePassDelivery({
      passer: ballHandler,
      receiver,
      defenseContributors: trapDefenders,
      zonePenalty: trapOnBall ? -0.08 : -0.02,
      maxRelevantDefenders: trapOnBall ? 2 : 1,
      random,
    });
    markInvolvement(offenseTeamId, receiver, 0.78);

    if (passDelivery.turnover) {
      recordTurnover(state, offenseTeamId, ballHandler, defenseTeamId, passDelivery.stealByPlayer);
      pushEvent(state, {
        type: "turnover_pass",
        offenseTeam: offense.name,
        defenderTeam: defense.name,
        playType: "press_break",
        detail: `Press-break pass intercepted by ${passDelivery.stealBy}.`,
      });
      beginNewPossession(state, defenseTeamId, null, {
        transition: {
          sourceType: "steal",
          initiator: passDelivery.stealByPlayer,
        },
      });
      return {
        handled: true,
        playType: "press_break",
        possessionChanged: true,
        shotClockMode: "hold",
      };
    }
    if (passDelivery.looseBall) {
      const looseBall = resolveBackcourtLooseBallRecovery({
        offenseLineup,
        defenseLineup,
        random,
      });
      if (looseBall.team === "defense") {
        addPlayerStat(state, offenseTeamId, ballHandler, "turnovers", 1);
        addTeamExtra(state, offenseTeamId, "turnovers", 1);
        pushEvent(state, {
          type: "loose_ball_recovery",
          offenseTeam: offense.name,
          defenderTeam: defense.name,
          playType: "press_break",
          detail: `Loose pass recovered by ${looseBall.player?.bio?.name || "Unknown"} (${defense.name}).`,
        });
        beginNewPossession(state, defenseTeamId);
        return {
          handled: true,
          playType: "press_break",
          possessionChanged: true,
          shotClockMode: "hold",
        };
      }
      pending.ballHandler = looseBall.player || ballHandler;
      pushEvent(state, {
        type: "loose_ball_recovery",
        offenseTeam: offense.name,
        playType: "press_break",
        detail: `Press-break pass bobbled but offense recovered (${pending.ballHandler?.bio?.name || "Unknown"}).`,
      });
    } else {
      const passAdvanceScore =
        getRating(ballHandler, "skills.passingVision") * 0.34 +
        getRating(ballHandler, "skills.passingIQ") * 0.32 +
        getRating(receiver, "athleticism.speed") * 0.2 +
        getRating(receiver, "skills.hands") * 0.14;
      const trapRecovery = average(
        trapDefenders.map((player) =>
          average([
            getRating(player, "athleticism.speed"),
            getRating(player, "defense.lateralQuickness"),
            getRating(player, "defense.offballDefense"),
          ]),
        ),
      );
      const burstEdge = (passAdvanceScore - trapRecovery) / 120;
      const fullAdvanceChance = clamp(0.14 + burstEdge + (trapOnBall ? 0.1 : 0.03), 0.05, 0.76);
      const progressGain = random() < fullAdvanceChance ? 2 : 1;
      pending.progress = Math.min(2, pending.progress + progressGain);
      pending.ballHandler = receiver;
      pushEvent(state, {
        type: "press_break_pass",
        offenseTeam: offense.name,
        defenseTeam: defense.name,
        playType: "press_break",
        detail:
          progressGain >= 2
            ? "Quick passing beat the press into frontcourt."
            : "Pass completed to relieve pressure.",
      });
    }
  } else {
    const dribblePressure = resolveInteraction({
      offensePlayer: ballHandler,
      defensePlayer: primaryDefender,
      offenseRatings: [
        "skills.ballHandling",
        "skills.ballSafety",
        "athleticism.agility",
        "athleticism.speed",
        "skills.passingIQ",
      ],
      defenseRatings: [
        "defense.lateralQuickness",
        "defense.perimeterDefense",
        "defense.steals",
        "defense.passPerception",
      ],
      contextEdge: trapOnBall ? -0.13 : -0.03,
      random,
    });
    if (!dribblePressure.success) {
      const stealChance = clamp(
        0.24 + (0.62 - dribblePressure.successProbability) * 0.55 + (trapOnBall ? 0.12 : 0),
        0.12,
        0.88,
      );
