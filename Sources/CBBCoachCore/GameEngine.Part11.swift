import Foundation

func screenEffectiveness(
    ballHandler: Player,
    screener: Player,
    onBallDefender: Player,
    screenerDefender: Player
) -> Double {
    let offense = getBaseRating(screener, path: "athleticism.strength") * 0.55
        + getBaseRating(ballHandler, path: "skills.ballHandling") * 0.25
        + getBaseRating(ballHandler, path: "athleticism.agility") * 0.2
    let defense = (
        getBaseRating(onBallDefender, path: "defense.lateralQuickness")
        + getBaseRating(onBallDefender, path: "defense.perimeterDefense")
        + getBaseRating(screenerDefender, path: "defense.defensiveControl")
        + getBaseRating(screenerDefender, path: "athleticism.strength")
    ) / 4
    return clamp((offense - defense) / 100, min: -0.5, max: 0.8)
}

// MARK: - Dead balls, timeouts, clutch, formation, fouls

func isDeadBall(eventType: String) -> Bool {
    switch eventType {
    case "made_shot", "foul", "turnover", "turnover_shot_clock", "bonus_foul",
         "charge", "loose_ball_foul", "non_shooting_foul", "technical_foul":
        return true
    default:
        return false
    }
}

func maybeCallTechnicalFoul(stored: inout NativeGameStateStore.StoredState, random: inout SeededRandom) {
    guard stored.teams.count >= 2 else { return }
    let firstLineup = stored.teams[0].activeLineup
    let secondLineup = stored.teams[1].activeLineup
    guard !firstLineup.isEmpty, !secondLineup.isEmpty else { return }

    func candidateForTechnical(teamId: Int, opponentTeamId: Int) -> (lineupIdx: Int, chance: Double)? {
        let lineup = stored.teams[teamId].activeLineup
        let opponentLineup = stored.teams[opponentTeamId].activeLineup
        guard !lineup.isEmpty, !opponentLineup.isEmpty else { return nil }

        var bestIdx = 0
        var bestRisk = -1.0
        for idx in lineup.indices {
            let player = lineup[idx]
            let boxIdx = idx < stored.teams[teamId].activeLineupBoxIndices.count ? stored.teams[teamId].activeLineupBoxIndices[idx] : -1
            let fouls = (boxIdx >= 0 && boxIdx < stored.teams[teamId].boxPlayers.count) ? stored.teams[teamId].boxPlayers[boxIdx].fouls : 0
            let risk = clamp(
                (100 - player.condition.energy) * 0.5
                    + Double(fouls) * 12
                    + (100 - getBaseRating(player, path: "skills.shotIQ")) * 0.25
                    + (100 - getBaseRating(player, path: "skills.clutch")) * 0.2,
                min: 0,
                max: 120
            )
            if risk > bestRisk {
                bestRisk = risk
                bestIdx = idx
            }
        }

        let irritant = opponentLineup[min(bestIdx, opponentLineup.count - 1)]
        let composureInteraction = resolveInteractionWithTrace(
            stored: &stored,
            label: "technical_temper",
            offensePlayer: lineup[bestIdx],
            defensePlayer: irritant,
            offenseRatings: ["skills.shotIQ", "skills.clutch", "skills.ballSafety"],
            defenseRatings: ["defense.defensiveControl", "skills.hustle", "defense.offballDefense"],
            random: &random
        )
        let temperDefenseControl = 1 - logistic(composureInteraction.edge)
        let riskComponent = bestRisk / 120
        let chance = clamp(0.0004 + temperDefenseControl * 0.0026 + riskComponent * 0.0014, min: 0.0002, max: 0.005)
        return (bestIdx, chance)
    }

    guard
        let first = candidateForTechnical(teamId: 0, opponentTeamId: 1),
        let second = candidateForTechnical(teamId: 1, opponentTeamId: 0)
    else { return }

    let offender = first.chance >= second.chance
        ? (teamId: 0, lineupIdx: first.lineupIdx, chance: first.chance)
        : (teamId: 1, lineupIdx: second.lineupIdx, chance: second.chance)
    guard offender.chance >= 0.0025 else { return }
    let offendingTeamId = offender.teamId
    let offendingLineupIdx = offender.lineupIdx
    let benefitingTeamId = offendingTeamId == 0 ? 1 : 0
    guard !stored.teams[benefitingTeamId].activeLineup.isEmpty else { return }
    // Pick best FT shooter on the benefiting team's floor.
    let lineup = stored.teams[benefitingTeamId].activeLineup
    var bestIdx = 0
    var bestFT = -1.0
    for (idx, player) in lineup.enumerated() {
        let ft = getBaseRating(player, path: "shooting.freeThrows")
        if ft > bestFT { bestFT = ft; bestIdx = idx }
    }
    let shooter = lineup[bestIdx]
    let made = random.nextUnit() < freeThrowMakeProbability(
        stored: &stored,
        shooter: shooter,
        defenseTeamId: offendingTeamId,
        label: "free_throw_focus_technical",
        random: &random
    )
    let ftMade = made ? 1 : 0
    addPlayerStat(stored: &stored, teamId: benefitingTeamId, lineupIndex: bestIdx) { line in
        line.ftAttempts += 1
        line.ftMade += ftMade
        line.points += ftMade
    }
    if ftMade > 0 {
        stored.teams[benefitingTeamId].score += ftMade
        applyPlusMinus(stored: &stored, scoringTeamId: benefitingTeamId, points: ftMade)
    }
    // Tag the highest-risk on-floor player as the offender.
    addPlayerStat(stored: &stored, teamId: offendingTeamId, lineupIndex: offendingLineupIdx) { $0.fouls += 1 }
    if offendingTeamId >= 0, offendingTeamId < stored.teamFoulsInHalf.count {
        stored.teamFoulsInHalf[offendingTeamId] += 1
    }
}

func maybeCallTimeout(stored: inout NativeGameStateStore.StoredState, teamId: Int, random: inout SeededRandom) {
    guard teamId >= 0, teamId < stored.teams.count else { return }
    guard stored.teams[teamId].team.timeouts > 0 else { return }
    let oppId = teamId == 0 ? 1 : 0
    let scoreDelta = stored.teams[teamId].score - stored.teams[oppId].score
    // Use timeout when down by a lot late, or when starters are gassed.
    let lateAndTrailing = stored.gameClockRemaining < 240 && scoreDelta < -6
    let starterTired = stored.teams[teamId].activeLineup.contains { ($0.condition.energy) < 45 }
    guard !stored.teams[teamId].activeLineup.isEmpty, !stored.teams[oppId].activeLineup.isEmpty else { return }
    let tiredIdx = stored.teams[teamId].activeLineup.enumerated().min { $0.element.condition.energy < $1.element.condition.energy }?.offset ?? 0
    let pressureIdx = stored.teams[oppId].activeLineup.enumerated().max { lhs, rhs in
        let l = getBaseRating(lhs.element, path: "defense.offballDefense") * 0.4
            + getBaseRating(lhs.element, path: "defense.defensiveControl") * 0.35
            + getBaseRating(lhs.element, path: "skills.hustle") * 0.25
        let r = getBaseRating(rhs.element, path: "defense.offballDefense") * 0.4
            + getBaseRating(rhs.element, path: "defense.defensiveControl") * 0.35
            + getBaseRating(rhs.element, path: "skills.hustle") * 0.25
        return l < r
    }?.offset ?? 0
    let timeoutInteraction = resolveInteractionWithTrace(
        stored: &stored,
        label: "timeout_pressure",
        offensePlayer: stored.teams[teamId].activeLineup[tiredIdx],
        defensePlayer: stored.teams[oppId].activeLineup[pressureIdx],
        offenseRatings: ["skills.shotIQ", "skills.clutch", "skills.ballSafety"],
        defenseRatings: ["defense.offballDefense", "defense.defensiveControl", "skills.hustle"],
        random: &random
    )
    let timeoutNeed = 1 - logistic(timeoutInteraction.edge)
    if lateAndTrailing && timeoutNeed > 0.42 {
        stored.teams[teamId].team.timeouts -= 1
        recoverTeam(stored: &stored, teamId: teamId, amount: 18)
    } else if starterTired && timeoutNeed > 0.62 {
        stored.teams[teamId].team.timeouts -= 1
        recoverTeam(stored: &stored, teamId: teamId, amount: 12)
    }
}

func recoverTeam(stored: inout NativeGameStateStore.StoredState, teamId: Int, amount: Double) {
    for idx in stored.teams[teamId].activeLineup.indices {
        let boxIndex = stored.teams[teamId].activeLineupBoxIndices[idx]
        if boxIndex >= 0, boxIndex < stored.teams[teamId].boxPlayers.count {
            let current = stored.teams[teamId].boxPlayers[boxIndex].energy ?? 100
            let next = min(100, current + amount)
            stored.teams[teamId].boxPlayers[boxIndex].energy = next
            stored.teams[teamId].activeLineup[idx].condition.energy = next
            if boxIndex < stored.teams[teamId].team.players.count {
                stored.teams[teamId].team.players[boxIndex].condition.energy = next
            }
        }
    }
}

func recoverAllPlayersForHalftime(stored: inout NativeGameStateStore.StoredState) {
    for teamId in stored.teams.indices {
        for boxIndex in stored.teams[teamId].boxPlayers.indices {
            let current = stored.teams[teamId].boxPlayers[boxIndex].energy ?? 100
            let next = min(100, current + 26)
            stored.teams[teamId].boxPlayers[boxIndex].energy = next
            if boxIndex < stored.teams[teamId].team.players.count {
                stored.teams[teamId].team.players[boxIndex].condition.energy = next
            }
        }
        for idx in stored.teams[teamId].activeLineup.indices {
            let boxIndex = stored.teams[teamId].activeLineupBoxIndices[idx]
            if boxIndex >= 0, boxIndex < stored.teams[teamId].boxPlayers.count {
                stored.teams[teamId].activeLineup[idx].condition.energy = stored.teams[teamId].boxPlayers[boxIndex].energy ?? 100
            }
        }
    }
}

func syncClutchTime(stored: inout NativeGameStateStore.StoredState) {
    let isLastPeriod = stored.currentHalf >= 2
    let scoreDelta = abs(stored.teams[0].score - stored.teams[1].score)
    let isClutch = isLastPeriod && stored.gameClockRemaining <= 300 && scoreDelta <= 8
    for teamId in stored.teams.indices {
        for idx in stored.teams[teamId].activeLineup.indices {
            stored.teams[teamId].activeLineup[idx].condition.clutchTime = isClutch
        }
    }
}

func advanceOffensiveFormation(stored: inout NativeGameStateStore.StoredState, teamId: Int) {
    guard teamId >= 0, teamId < stored.teams.count else { return }
    guard let formations = stored.teams[teamId].team.formations, !formations.isEmpty else { return }
    let nextIndex = (stored.formationCycleIndex[teamId] + 1) % formations.count
    stored.formationCycleIndex[teamId] = nextIndex
    stored.teams[teamId].team.formation = formations[nextIndex]
}

func registerDefensiveFoul(stored: inout NativeGameStateStore.StoredState, defenseTeamId: Int, lineupIndex: Int, shooting: Bool) {
    addPlayerStat(stored: &stored, teamId: defenseTeamId, lineupIndex: lineupIndex) { $0.fouls += 1 }
    if defenseTeamId >= 0, defenseTeamId < stored.teamFoulsInHalf.count {
        stored.teamFoulsInHalf[defenseTeamId] += 1
    }
}

func freeThrowMakeProbability(
    stored: inout NativeGameStateStore.StoredState,
    shooter: Player,
    defenseTeamId: Int?,
    label: String,
    random: inout SeededRandom
) -> Double {
    let base = clamp(getBaseRating(shooter, path: "shooting.freeThrows") / 120, min: 0.45, max: 0.92)
    guard let defenseTeamId, defenseTeamId >= 0, defenseTeamId < stored.teams.count else {
        return base
    }
    let defenseLineup = stored.teams[defenseTeamId].activeLineup
    guard !defenseLineup.isEmpty else { return base }

    let pressureDefender = defenseLineup.max { lhs, rhs in
        let l = getBaseRating(lhs, path: "defense.defensiveControl") * 0.5
            + getBaseRating(lhs, path: "skills.hustle") * 0.3
            + getBaseRating(lhs, path: "skills.clutch") * 0.2
        let r = getBaseRating(rhs, path: "defense.defensiveControl") * 0.5
            + getBaseRating(rhs, path: "skills.hustle") * 0.3
            + getBaseRating(rhs, path: "skills.clutch") * 0.2
        return l < r
    } ?? defenseLineup[0]

    let interaction = resolveInteractionWithTrace(
        stored: &stored,
        label: label,
        offensePlayer: shooter,
        defensePlayer: pressureDefender,
        offenseRatings: ["shooting.freeThrows", "skills.shotIQ", "skills.clutch"],
        defenseRatings: ["defense.defensiveControl", "skills.hustle", "skills.clutch"],
        random: &random
    )
    let focusBoost = (logistic(interaction.edge) - 0.5) * 0.18
    return clamp(base + focusBoost, min: 0.4, max: 0.95)
}

func teamFoulsForPeriod(_ stored: NativeGameStateStore.StoredState, teamId: Int) -> Int {
    guard teamId >= 0, teamId < stored.teamFoulsInHalf.count else { return 0 }
    return stored.teamFoulsInHalf[teamId]
}

func maybeCallNonShootingFoul(
    stored: inout NativeGameStateStore.StoredState,
    offenseTeamId: Int,
    defenseTeamId: Int,
    ballHandlerIdx: Int,
    defenderIdx: Int,
    willEndPossession: Bool,
    eventType: inout String,
    switchedPossession: inout Bool,
    points: inout Int,
    random: inout SeededRandom
) {
    // Only trigger on setup (no shot taken yet).
    guard eventType == "setup" else { return }
    // Take-foul: defense trailing late intentionally fouls to stop clock and send to FT line.
    let defenseScore = stored.teams[defenseTeamId].score
    let offenseScore = stored.teams[offenseTeamId].score
    let defenseDelta = defenseScore - offenseScore
    let isLastPeriod = stored.currentHalf >= 2
    let clockRemaining = stored.gameClockRemaining
    let takeFoulWindow = isLastPeriod && clockRemaining <= 45 && defenseDelta <= -1 && defenseDelta >= -9
    let defender = stored.teams[defenseTeamId].activeLineup[min(defenderIdx, stored.teams[defenseTeamId].activeLineup.count - 1)]
    let ballHandler = stored.teams[offenseTeamId].activeLineup[min(ballHandlerIdx, stored.teams[offenseTeamId].activeLineup.count - 1)]
    let foulPressure = resolveInteractionWithTrace(
        stored: &stored,
        label: "non_shooting_foul_pressure",
        offensePlayer: ballHandler,
        defensePlayer: defender,
        offenseRatings: ["skills.ballHandling", "skills.ballSafety", "skills.passingIQ", "skills.shotIQ"],
        defenseRatings: ["defense.defensiveControl", "skills.hustle", "defense.offballDefense", "defense.lateralQuickness"],
        random: &random
    )
    let defenseControl = 1 - logistic(foulPressure.edge)
    let discipline = getBaseRating(defender, path: "defense.defensiveControl") * 0.6
        + getBaseRating(defender, path: "skills.shotIQ") * 0.4
    let disciplineRelief = (discipline - 50) / 300
    let baseIntent = takeFoulWindow ? (clockRemaining <= 20 ? 0.52 : 0.3) : 0.008
    let foulChance = clamp(
        baseIntent + defenseControl * 0.06 - disciplineRelief,
        min: takeFoulWindow ? 0.2 : 0.005,
        max: takeFoulWindow ? 0.75 : 0.08
    )
    guard random.nextUnit() < foulChance else { return }
    registerDefensiveFoul(stored: &stored, defenseTeamId: defenseTeamId, lineupIndex: defenderIdx, shooting: false)

    let teamFouls = teamFoulsForPeriod(stored, teamId: defenseTeamId)
    if teamFouls >= 10 {
        // Double bonus: 2 FTs.
        let shooter = stored.teams[offenseTeamId].activeLineup[ballHandlerIdx]
        var ftMade = 0
        for _ in 0..<2 {
            let ftProb = freeThrowMakeProbability(
                stored: &stored,
                shooter: shooter,
                defenseTeamId: defenseTeamId,
                label: "free_throw_focus_bonus",
                random: &random
            )
            if random.nextUnit() < ftProb {
                ftMade += 1
            }
        }
        addPlayerStat(stored: &stored, teamId: offenseTeamId, lineupIndex: ballHandlerIdx) { line in
            line.ftAttempts += 2
            line.ftMade += ftMade
            line.points += ftMade
        }
        if ftMade > 0 {
            points += ftMade
            stored.teams[offenseTeamId].score += ftMade
            applyPlusMinus(stored: &stored, scoringTeamId: offenseTeamId, points: ftMade)
        }
        eventType = "bonus_foul"
        switchedPossession = true
    } else if teamFouls >= 7 {
        // 1-and-1.
        let shooter = stored.teams[offenseTeamId].activeLineup[ballHandlerIdx]
        let firstProb = freeThrowMakeProbability(
            stored: &stored,
            shooter: shooter,
            defenseTeamId: defenseTeamId,
            label: "free_throw_focus_one_and_one",
            random: &random
        )
        let first = random.nextUnit() < firstProb
        var ftAtt = 1
        var ftMade = first ? 1 : 0
        if first {
            ftAtt = 2
            let secondProb = freeThrowMakeProbability(
                stored: &stored,
                shooter: shooter,
                defenseTeamId: defenseTeamId,
                label: "free_throw_focus_one_and_one",
                random: &random
            )
            if random.nextUnit() < secondProb {
                ftMade += 1
            }
        }
        addPlayerStat(stored: &stored, teamId: offenseTeamId, lineupIndex: ballHandlerIdx) { line in
            line.ftAttempts += ftAtt
            line.ftMade += ftMade
            line.points += ftMade
        }
        if ftMade > 0 {
            points += ftMade
            stored.teams[offenseTeamId].score += ftMade
            applyPlusMinus(stored: &stored, scoringTeamId: offenseTeamId, points: ftMade)
        }
        eventType = "bonus_foul"
        switchedPossession = true
    } else {
        // Non-bonus: inbound, no FTs, possession stays (offense retains ball, fresh shot clock).
        eventType = "non_shooting_foul"
        switchedPossession = false
    }
    _ = willEndPossession
}

// MARK: - Press defense

func shouldApplyPress(stored: NativeGameStateStore.StoredState, offenseTeamId: Int, defenseTeamId: Int) -> Double {
    let defense = stored.teams[defenseTeamId].team
    let pressTendency = defense.tendencies.press / 50.0  // 1.0 baseline
    let trailing = stored.teams[defenseTeamId].score - stored.teams[offenseTeamId].score
    let secondsLeft = stored.currentHalf >= 2 ? stored.gameClockRemaining : stored.gameClockRemaining + HALF_SECONDS * (2 - stored.currentHalf)
    let lateTrail = secondsLeft <= 120 && trailing <= -2
    if pressTendency < 1.05 && !lateTrail { return 0 }
    let base = max(0, pressTendency - 1.0) * 0.55
    let urgency = lateTrail ? clamp(Double(-trailing) / 10, min: 0.2, max: 0.8) : 0
    return clamp(base + urgency, min: 0, max: 0.85)
}
