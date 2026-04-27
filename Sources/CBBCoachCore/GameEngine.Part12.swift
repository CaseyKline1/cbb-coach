import Foundation

func maybeResolvePress(
    stored: inout NativeGameStateStore.StoredState,
    offenseTeamId: Int,
    defenseTeamId: Int,
    random: inout SeededRandom
) -> (event: String, switchedPossession: Bool, points: Int)? {
    let pressChance = shouldApplyPress(stored: stored, offenseTeamId: offenseTeamId, defenseTeamId: defenseTeamId)
    guard pressChance > 0 else { return nil }

    let offenseLineup = stored.teams[offenseTeamId].activeLineup
    let defenseLineup = stored.teams[defenseTeamId].activeLineup
    guard !offenseLineup.isEmpty, !defenseLineup.isEmpty else { return nil }

    // Pick a "receiver" (likely the team's best ball-handler) and trap defenders.
    let receiverIdx = pickLineupIndexForBallHandler(
        lineup: offenseLineup,
        lineupBoxIndices: stored.teams[offenseTeamId].activeLineupBoxIndices,
        initiatedActionCountByBoxIndex: stored.teams[offenseTeamId].initiatedActionCountByBoxIndex,
        totalInitiatedActions: stored.teams[offenseTeamId].initiatedActionCount,
        random: &random
    )
    let receiver = offenseLineup[receiverIdx]

    var trapCandidates: [(Int, Double)] = []
    trapCandidates.reserveCapacity(defenseLineup.count)
    for (idx, defender) in defenseLineup.enumerated() {
        let trapScore = getRating(defender, path: "defense.steals") * 0.42
            + getRating(defender, path: "skills.hands") * 0.24
            + getRating(defender, path: "defense.lateralQuickness") * 0.2
            + getRating(defender, path: "defense.passPerception") * 0.14
        trapCandidates.append((idx, trapScore))
    }
    trapCandidates.sort { $0.1 > $1.1 }
    let leadTrapIdx = trapCandidates.first?.0 ?? 0
    let supportTrapIdx = trapCandidates.count > 1 ? trapCandidates[1].0 : leadTrapIdx
    let leadTrap = defenseLineup[leadTrapIdx]

    let setupInteraction = resolveInteractionWithTrace(
        stored: &stored,
        label: "press_setup",
        offensePlayer: receiver,
        defensePlayer: leadTrap,
        offenseRatings: ["skills.ballHandling", "skills.ballSafety", "skills.passingIQ", "athleticism.burst"],
        defenseRatings: ["defense.offballDefense", "defense.lateralQuickness", "defense.defensiveControl"],
        random: &random
    )
    let setupDefenseControl = 1 - logistic(setupInteraction.edge)
    let trapTriggerChance = clamp(pressChance * 0.42 + setupDefenseControl * 0.5, min: 0.05, max: 0.9)
    guard random.nextUnit() < trapTriggerChance else { return nil }

    let trapInteraction = resolveInteractionWithTrace(
        stored: &stored,
        label: "trap_ball_security",
        offensePlayer: receiver,
        defensePlayer: leadTrap,
        offenseRatings: ["skills.ballHandling", "skills.ballSafety", "skills.hands", "skills.passingIQ"],
        defenseRatings: ["defense.steals", "skills.hands", "defense.passPerception", "defense.lateralQuickness"],
        random: &random
    )
    let trapDefenseControl = 1 - logistic(trapInteraction.edge)
    let supportPressure = defenseLineup[supportTrapIdx]
    let supportBoost = clamp(
        (
            getRating(supportPressure, path: "defense.steals") * 0.45
                + getRating(supportPressure, path: "skills.hands") * 0.3
                + getRating(supportPressure, path: "defense.passPerception") * 0.25
        ) / 100,
        min: 0.2,
        max: 0.95
    )
    let stealChance = clamp(0.03 + trapDefenseControl * 0.32 + supportBoost * 0.08, min: 0.02, max: 0.28)
    if random.nextUnit() < stealChance {
        let stealerPool = [leadTrapIdx, supportTrapIdx]
        let stealerWeights = stealerPool.map { idx in
            getRating(defenseLineup[idx], path: "defense.steals") * 0.58
                + getRating(defenseLineup[idx], path: "skills.hands") * 0.42
        }
        let stealPick = weightedChoiceIndex(weights: stealerWeights, random: &random)
        let bestDefIdx = stealerPool[stealPick]
        addPlayerStat(stored: &stored, teamId: offenseTeamId, lineupIndex: receiverIdx) { $0.turnovers += 1 }
        addPlayerStat(stored: &stored, teamId: defenseTeamId, lineupIndex: bestDefIdx) { $0.steals += 1 }
        addTeamExtra(stored: &stored, teamId: offenseTeamId, key: "turnovers", amount: 1)
        stored.pendingTransition = NativeGameStateStore.PendingTransition(source: "steal")
        return (event: "turnover", switchedPossession: true, points: 0)
    }

    let breakAdvantage = resolveInteractionWithTrace(
        stored: &stored,
        label: "break_advantage",
        offensePlayer: receiver,
        defensePlayer: leadTrap,
        offenseRatings: ["athleticism.burst", "athleticism.speed", "skills.passingVision", "skills.ballHandling"],
        defenseRatings: ["defense.lateralQuickness", "defense.offballDefense", "defense.passPerception"],
        random: &random
    )
    let attackAfterBreak = stored.teams[offenseTeamId].team.tendencies.pressBreakAttack / 50.0
    let breakChance = clamp(
        0.12 + logistic(breakAdvantage.edge) * 0.48 + (attackAfterBreak - 1) * 0.15,
        min: 0.08,
        max: 0.75
    )
    if random.nextUnit() < breakChance {
        stored.pendingTransition = NativeGameStateStore.PendingTransition(source: "press_break")
    }
    return nil  // Let the normal possession play out.
}

// MARK: - Pass delivery

func resolvePassInterception(
    stored: inout NativeGameStateStore.StoredState,
    passer: Player,
    receiver: Player,
    defenseLineup: [Player],
    riskShift: Double = 0,
    random: inout SeededRandom
) -> Int? {
    guard !defenseLineup.isEmpty else { return nil }
    // Identify likely lane-jumpers, then resolve passer-vs-defender interactions.
    let laneThreats = defenseLineup.enumerated().map { idx, defender in
        (
            idx,
            getRating(defender, path: "defense.passPerception") * 0.42
                + getRating(defender, path: "defense.steals") * 0.28
                + getRating(defender, path: "skills.hands") * 0.18
                + getRating(defender, path: "defense.lateralQuickness") * 0.12
        )
    }
    let candidates = laneThreats.sorted { $0.1 > $1.1 }.prefix(min(3, defenseLineup.count))
    let receiverWindow = getRating(receiver, path: "skills.hands") * 0.58
        + getRating(receiver, path: "skills.shotIQ") * 0.42

    let riskScale = clamp(1 + riskShift, min: 0.55, max: 1.45)
    let safeScale = clamp(2 - riskScale, min: 0.7, max: 1.45)

    var weights: [Double] = []
    var defenderIndices: [Int] = []
    var stealTotal = 0.0
    for (idx, laneThreat) in candidates {
        let defender = defenseLineup[idx]
        let laneInteraction = resolveInteractionWithTrace(
            stored: &stored,
            label: "pass_interception_lane",
            offensePlayer: passer,
            defensePlayer: defender,
            offenseRatings: ["skills.passingAccuracy", "skills.passingIQ", "skills.passingVision"],
            defenseRatings: ["defense.passPerception", "defense.steals", "skills.hands", "defense.lateralQuickness"],
            random: &random
        )
        let secureEdge = laneInteraction.edge + (receiverWindow - 55) / 100
        // Keep lane-jumpers impactful, but tune interception rate lower so picks are rarer.
        let stealSignal = clamp((1 - logistic(secureEdge)) * 0.34, min: 0.006, max: 0.27)
        let laneBoost = clamp((laneThreat - 60) / 320, min: -0.04, max: 0.05)
        let stealWeight = max(0.02, (stealSignal + laneBoost) * riskScale * 4.0)
        weights.append(stealWeight)
        defenderIndices.append(idx)
        stealTotal += stealWeight
    }
    let safePassWeight = max(1.2, (90 - stealTotal * 0.5) * safeScale)
    let pick = weightedChoiceIndex(weights: [safePassWeight] + weights, random: &random)
    if pick == 0 {
        return nil
    }
    return defenderIndices[pick - 1]
}

// MARK: - Fast break / transition

func pickTransitionRunnerIndex(lineup: [Player], random: inout SeededRandom) -> Int {
    weightedRandomIndex(lineup: lineup, random: &random) { player in
        let runScore = getRating(player, path: "athleticism.burst") * 0.28
            + getRating(player, path: "athleticism.speed") * 0.27
            + getRating(player, path: "skills.offballOffense") * 0.2
            + getRating(player, path: "skills.hands") * 0.12
            + getRating(player, path: "skills.shotIQ") * 0.13
        let interiorPenalty = clamp((getWeightPounds(player) - 220) / 60, min: 0, max: 0.3)
        return max(1, runScore * (1 - interiorPenalty))
    }
}

func pickTransitionPointDefenderIndex(lineup: [Player], random: inout SeededRandom) -> Int {
    weightedRandomIndex(lineup: lineup, random: &random) { player in
        let recovery = getRating(player, path: "athleticism.burst") * 0.26
            + getRating(player, path: "athleticism.speed") * 0.26
            + getRating(player, path: "defense.lateralQuickness") * 0.18
            + getRating(player, path: "defense.offballDefense") * 0.18
            + getRating(player, path: "defense.shotContest") * 0.12
        return max(1, recovery)
    }
}

func chooseFastBreakFinish(player: Player, transitionStyle: Double, random: inout SeededRandom) -> ShotType {
    let threeSkill = getRating(player, path: "shooting.threePointShooting") * 0.58
        + getRating(player, path: "shooting.upTopThrees") * 0.26
        + getRating(player, path: "skills.shotIQ") * 0.16
    let pullUpThreeChance = clamp(
        0.02
            + transitionStyle * 0.1
            + max(0, threeSkill - 72) / 320,
        min: 0.02,
        max: 0.16
    )
    if random.nextUnit() < pullUpThreeChance {
        return .three
    }
    let dunkLean = getRating(player, path: "shooting.dunks") * 0.5
        + getRating(player, path: "athleticism.vertical") * 0.3
        + getRating(player, path: "athleticism.strength") * 0.2
    let layupLean = getRating(player, path: "shooting.layups") * 0.62
        + getRating(player, path: "shooting.closeShot") * 0.24
        + getRating(player, path: "skills.shotIQ") * 0.14
    let total = max(1, dunkLean + layupLean)
    return random.nextUnit() * total < layupLean ? .layup : .dunk
}

func maybeResolveFastBreak(
    stored: inout NativeGameStateStore.StoredState,
    offenseTeamId: Int,
    defenseTeamId: Int,
    random: inout SeededRandom
) -> (event: String, switchedPossession: Bool, points: Int)? {
    guard let transition = stored.pendingTransition else { return nil }
    stored.pendingTransition = nil

    let offenseLead = stored.teams[offenseTeamId].score - stored.teams[defenseTeamId].score
    if stored.currentHalf >= 2 && offenseLead >= 20 {
        return nil
    }

    let offenseLineup = stored.teams[offenseTeamId].activeLineup
    let defenseLineup = stored.teams[defenseTeamId].activeLineup
    guard !offenseLineup.isEmpty, !defenseLineup.isEmpty else { return nil }

    let runnerIdx = pickTransitionRunnerIndex(lineup: offenseLineup, random: &random)
    let leadDefIdx = pickTransitionPointDefenderIndex(lineup: defenseLineup, random: &random)
    let runner = offenseLineup[runnerIdx]
    let leadDef = defenseLineup[leadDefIdx]
    let sourceBoost: Double = transition.source == "steal" ? 0.065 : (transition.source == "press_break" ? 0.05 : 0.02)
    let offenseTeam = stored.teams[offenseTeamId].team
    let defenseTeam = stored.teams[defenseTeamId].team
    let transitionStyle = clamp(
        paceTransitionEmphasis(for: offenseTeam.pace) * 0.5
            + clamp(offenseTeam.tendencies.fastBreakOffense / 100, min: 0, max: 1) * 0.34
            + clamp(offenseTeam.tendencies.pressBreakAttack / 100, min: 0, max: 1) * 0.16,
        min: 0.05,
        max: 0.94
    )
    let transitionContain = clamp(
        paceTransitionEmphasis(for: defenseTeam.pace) * 0.24
            + clamp(defenseTeam.tendencies.defendFastBreakOffense / 100, min: 0, max: 1) * 0.52
            + clamp(defenseTeam.tendencies.press / 100, min: 0, max: 1) * 0.24,
        min: 0.12,
        max: 0.95
    )
    let styleBurst = clamp((transitionStyle - 0.68) / 0.26, min: 0, max: 1)

    let pushInteraction = resolveInteractionWithTrace(
        stored: &stored,
        label: "fast_break_push",
        offensePlayer: runner,
        defensePlayer: leadDef,
        offenseRatings: ["athleticism.burst", "athleticism.speed", "skills.ballHandling", "skills.shotIQ"],
        defenseRatings: ["defense.offballDefense", "defense.lateralQuickness", "defense.passPerception"],
        random: &random
    )
    let pushChance = clamp(
        0.06
            + logistic(pushInteraction.edge) * 0.32
            + sourceBoost * 0.18
            + transitionStyle * 0.28
            + styleBurst * 0.05
            - transitionContain * 0.12,
        min: 0.04,
        max: 0.76
    )
    guard random.nextUnit() < pushChance else { return nil }

    let runScore = getRating(runner, path: "athleticism.burst") * 0.38
        + getRating(runner, path: "athleticism.speed") * 0.34
        + getRating(runner, path: "skills.ballHandling") * 0.14
        + getRating(runner, path: "skills.offballOffense") * 0.14
    let recoveryScore = getRating(leadDef, path: "athleticism.burst") * 0.33
        + getRating(leadDef, path: "athleticism.speed") * 0.31
        + getRating(leadDef, path: "defense.lateralQuickness") * 0.2
        + getRating(leadDef, path: "defense.shotContest") * 0.16
    let raceInteraction = resolveInteractionWithTrace(
        stored: &stored,
        label: "fast_break_race",
        offensePlayer: runner,
        defensePlayer: leadDef,
        offenseRatings: ["athleticism.burst", "athleticism.speed", "skills.ballHandling", "skills.offballOffense"],
        defenseRatings: ["athleticism.burst", "athleticism.speed", "defense.lateralQuickness", "defense.shotContest"],
        random: &random
    )
    let raceEdge = (runScore - recoveryScore) / 100
        + sourceBoost
        + raceInteraction.edge * 0.34
        + transitionStyle * 0.14
        - transitionContain * 0.12
    let beatDefenseChance = clamp(
        0.12
            + logistic(raceEdge) * 0.52
            + transitionStyle * 0.17
            + sourceBoost * 0.06
            + styleBurst * 0.04
            - transitionContain * 0.07,
        min: 0.06,
        max: 0.82
    )
    guard random.nextUnit() < beatDefenseChance else { return nil }

    let shotType = chooseFastBreakFinish(player: runner, transitionStyle: transitionStyle, random: &random)
    let profile = shotProfile(for: shotType)
    let shotInteraction = resolveInteractionWithTrace(
        stored: &stored,
        label: "fast_break_finish",
        offensePlayer: runner,
        defensePlayer: leadDef,
        offenseRatings: profile.offenseRatings,
        defenseRatings: profile.defenseRatings,
        random: &random
    )
    let finishQuality = resolveInteractionWithTrace(
        stored: &stored,
        label: "fast_break_finish_quality",
        offensePlayer: runner,
        defensePlayer: leadDef,
        offenseRatings: profile.offenseRatings + ["skills.hands", "skills.shotIQ"],
        defenseRatings: profile.defenseRatings + ["defense.defensiveControl", "defense.shotContest"],
        random: &random
    )
    let madeProb = clamp(
        baseMakeProbability(for: shotType)
            + (logistic(shotInteraction.edge + 0.3) - 0.5) * makeScale(for: shotType) * 0.34
            + (logistic(finishQuality.edge) - 0.5) * 0.22
            + transitionStyle * 0.055
            + sourceBoost * 0.022
            + styleBurst * 0.01
            - transitionContain * 0.03,
        min: minMakeProbability(for: shotType),
        max: maxMakeProbability(for: shotType)
    )
    let made = random.nextUnit() < madeProb

    addPlayerStat(stored: &stored, teamId: offenseTeamId, lineupIndex: runnerIdx) { line in
        line.fgAttempts += 1
        if made { line.fgMade += 1 }
        if shotType == .three {
            line.threeAttempts += 1
            if made { line.threeMade += 1 }
        }
    }

    if made {
        let pts = profile.basePoints
        stored.teams[offenseTeamId].score += pts
        applyPlusMinus(stored: &stored, scoringTeamId: offenseTeamId, points: pts)
        addPlayerStat(stored: &stored, teamId: offenseTeamId, lineupIndex: runnerIdx) { $0.points += pts }
        addTeamExtra(stored: &stored, teamId: offenseTeamId, key: "fastBreakPoints", amount: pts)
        if isPointsInPaintScore(shotType: shotType, spot: .middlePaint) {
            addTeamExtra(stored: &stored, teamId: offenseTeamId, key: "pointsInPaint", amount: pts)
        }
        return (event: "made_shot", switchedPossession: true, points: pts)
    }

    // Missed break finish: still interaction-based, but transition positioning usually favors set defenders.
    let offenseCrashPreference = teamReboundCrashPreference(
        crashBoards: stored.teams[offenseTeamId].team.tendencies.crashBoardsOffense,
        fastBreakBias: stored.teams[offenseTeamId].team.tendencies.defendFastBreakOffense
    )
    let defenseCrashPreference = teamReboundCrashPreference(
        crashBoards: stored.teams[defenseTeamId].team.tendencies.crashBoardsDefense,
        fastBreakBias: stored.teams[defenseTeamId].team.tendencies.attemptFastBreakDefense
    )
    let reboundLocationHints = buildTransitionReboundLocationHints(
        offenseCount: offenseLineup.count,
        defenseCount: defenseLineup.count,
        shooterIdx: runnerIdx,
        shotDefenderIdx: leadDefIdx
    )
    let rebound = resolveReboundOutcome(
        stored: &stored,
        offenseLineup: offenseLineup,
        defenseLineup: defenseLineup,
        shotType: shotType,
        spot: .middlePaint,
        shooterIndex: runnerIdx,
        shotDefenderIndex: leadDefIdx,
        offenseCrashPreference: offenseCrashPreference,
        defenseCrashPreference: defenseCrashPreference,
        offensePositioning: 0.88,
        defensePositioning: 1.12,
        offenseLocationHints: reboundLocationHints.offense,
        defenseLocationHints: reboundLocationHints.defense,
        random: &random
    )
    if rebound.offensive {
        addPlayerStat(stored: &stored, teamId: offenseTeamId, lineupIndex: rebound.lineupIndex) { line in
            line.rebounds += 1
            line.offensiveRebounds += 1
        }
        return (event: "missed_shot", switchedPossession: false, points: 0)
    } else {
        addPlayerStat(stored: &stored, teamId: defenseTeamId, lineupIndex: rebound.lineupIndex) { line in
            line.rebounds += 1
            line.defensiveRebounds += 1
        }
        // Chained transition: defensive rebound seeds another potential break.
        stored.pendingTransition = NativeGameStateStore.PendingTransition(source: "def_rebound")
        return (event: "missed_shot", switchedPossession: true, points: 0)
    }
}
