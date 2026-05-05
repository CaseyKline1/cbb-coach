import Foundation

func zoneDistanceAdvantage(spot: OffensiveSpot, scheme: DefenseScheme) -> Double {
    switch scheme {
    case .manToMan:
        return 0
    case .zone23:
        // 2-3 packs the paint; weak on perimeter, especially corners.
        switch spot {
        case .leftCorner, .rightCorner: return 0.08
        case .topRight, .topLeft, .topMiddle: return 0.04
        case .middlePaint, .rightPost, .leftPost: return -0.06
        default: return 0
        }
    case .zone32:
        // 3-2 covers perimeter; weak on baseline / high post.
        switch spot {
        case .leftCorner, .rightCorner: return -0.03
        case .topMiddle: return -0.06
        case .middlePaint: return 0.05
        case .rightPost, .leftPost: return 0.04
        default: return 0
        }
    case .zone131:
        switch spot {
        case .leftCorner, .rightCorner: return 0.06
        case .middlePaint: return -0.04
        case .rightElbow, .leftElbow: return 0.05
        default: return 0
        }
    case .packLine:
        // Pack-line gives up threes, squeezes inside.
        switch spot {
        case .topRight, .topLeft, .topMiddle, .rightCorner, .leftCorner: return 0.05
        case .middlePaint, .rightPost, .leftPost: return -0.05
        default: return 0
        }
    }
}

func positionMatchedDefenderIndex(shooter: Player, defenseLineup: [Player], fallback: Int) -> Int {
    let target = shooter.bio.position.rawValue
    for (idx, defender) in defenseLineup.enumerated() where defender.bio.position.rawValue == target {
        return idx
    }
    return min(fallback, max(0, defenseLineup.count - 1))
}

func postScore(_ player: Player) -> Double {
    getBaseRating(player, path: "postGame.postControl") * 0.5
        + getBaseRating(player, path: "postGame.postHooks") * 0.3
        + getBaseRating(player, path: "tendencies.post") * 0.2
}

func evaluatePassTarget(
    offenseLineup: [Player],
    defenseLineup: [Player],
    ballHandlerIdx: Int,
    random: inout SeededRandom,
    opennessBonus: Double = 0,
    lineupBoxIndices: [Int]? = nil,
    currentBoxPlayers: [PlayerBoxScore]? = nil
) -> Int {
    var bestIdx = ballHandlerIdx
    var bestScore = -Double.infinity
    for idx in offenseLineup.indices where idx != ballHandlerIdx {
        let player = offenseLineup[idx]
        // Off-ball movement proxy: players with high offballOffense + hustle relocate to openings.
        let movement = getRating(player, path: "skills.offballOffense") * 0.55
            + getRating(player, path: "skills.hustle") * 0.25
            + getRating(player, path: "athleticism.burst") * 0.2
        // Expected shot value: blend of three/mid/close shooting × position tendency.
        let threeRating = getRating(player, path: "shooting.threePointShooting")
        let midRating = getRating(player, path: "shooting.midrangeShot")
        let closeRating = getRating(player, path: "shooting.closeShot")
        let shotEV = 3 * clamp(0.3 + (threeRating - 55) / 260, min: 0.18, max: 0.5)
            + 2 * clamp(0.34 + (midRating - 55) / 260, min: 0.22, max: 0.55)
            + 2 * clamp(0.42 + (closeRating - 55) / 220, min: 0.28, max: 0.65)
        let shotUtility = shotEV / 3
        // Defensive pressure from the matched defender (by lineup slot proximity).
        let defenderIdx = min(idx, defenseLineup.count - 1)
        let defender = defenseLineup[defenderIdx]
        let defensivePressure = getRating(defender, path: "defense.shotContest") * 0.35
            + getRating(defender, path: "defense.perimeterDefense") * 0.25
            + getRating(defender, path: "defense.offballDefense") * 0.4
        let openness = clamp((movement - defensivePressure) / 60 + opennessBonus, min: -0.4, max: 0.92)
        let passRisk = clamp((getRating(defender, path: "defense.passPerception") - 55) / 220, min: 0, max: 0.15)
        let fatigue = clamp((100 - player.condition.energy) / 100, min: 0, max: 0.92)
        let stamina = getBaseRating(player, path: "athleticism.stamina")
        let fatigueTax = fatigue * clamp(8.8 - (stamina - 50) / 14, min: 6.5, max: 11.5)
        let inGameLoadTax: Double = {
            guard let lineupBoxIndices, let currentBoxPlayers, idx < lineupBoxIndices.count else { return 0 }
            let boxIdx = lineupBoxIndices[idx]
            guard boxIdx >= 0, boxIdx < currentBoxPlayers.count else { return 0 }
            let box = currentBoxPlayers[boxIdx]
            let scorerBias = Double(max(0, box.points - 16)) * 0.28 + Double(max(0, box.fgMade - 7)) * 0.22
            let overattemptTax = Double(max(0, box.fgAttempts - 11)) * 1.6
                + Double(max(0, box.points - 28)) * 0.35
            return overattemptTax - scorerBias
        }()
        let score = shotUtility * 12 + openness * 18 - passRisk * 8 - fatigueTax - inGameLoadTax + random.nextUnit() * 2
        if score > bestScore {
            bestScore = score
            bestIdx = idx
        }
    }
    return bestIdx
}

func openShotUtility(_ player: Player) -> Double {
    getBaseRating(player, path: "skills.shotIQ") * 0.25
        + getBaseRating(player, path: "shooting.threePointShooting") * 0.35
        + getBaseRating(player, path: "shooting.midrangeShot") * 0.2
        + getBaseRating(player, path: "skills.offballOffense") * 0.2
}

func pickScreenerIndex(lineup: [Player], excluding: Int, random: inout SeededRandom) -> Int {
    let candidates = lineup.indices.filter { $0 != excluding }
    guard !candidates.isEmpty else { return excluding }

    let weights = candidates.map { idx -> Double in
        let p = lineup[idx]
        let base = getBaseRating(p, path: "athleticism.strength") * 0.58
            + getBaseRating(p, path: "postGame.postControl") * 0.17
            + getBaseRating(p, path: "skills.offballOffense") * 0.14
            + getBaseRating(p, path: "skills.hands") * 0.11
        let positionMultiplier: Double
        if isFourFiveLike(p) {
            positionMultiplier = 2.9
        } else if p.bio.position == .f || p.bio.position == .sf || p.bio.position == .wing {
            positionMultiplier = 0.8
        } else {
            positionMultiplier = 0.18
        }
        return max(0.1, base * positionMultiplier)
    }
    return candidates[weightedChoiceIndex(weights: weights, random: &random)]
}

enum ScreenNavigation {
    case over, under, switchSwitch, ice
}

func chooseScreenNavigation(
    stored: inout NativeGameStateStore.StoredState,
    ballHandler: Player,
    screener: Player,
    onBallDefender: Player,
    screenerDefender: Player,
    screenEdge: Double,
    random: inout SeededRandom
) -> ScreenNavigation {
    let pointInteraction = resolveInteractionWithTrace(
        stored: &stored,
        label: "screen_navigation_point",
        offensePlayer: ballHandler,
        defensePlayer: onBallDefender,
        offenseRatings: ["skills.ballHandling", "athleticism.agility", "skills.shotIQ"],
        defenseRatings: ["defense.perimeterDefense", "defense.lateralQuickness", "skills.shotIQ"],
        random: &random
    )
    let bigInteraction = resolveInteractionWithTrace(
        stored: &stored,
        label: "screen_navigation_big",
        offensePlayer: screener,
        defensePlayer: screenerDefender,
        offenseRatings: ["athleticism.strength", "skills.offballOffense", "skills.hands"],
        defenseRatings: ["defense.defensiveControl", "athleticism.strength", "defense.lateralQuickness"],
        random: &random
    )
    let offenseControl = clamp(logistic(pointInteraction.edge * 0.62 + bigInteraction.edge * 0.38 + screenEdge * 0.4), min: 0.05, max: 0.95)
    let defenseControl = 1 - offenseControl
    let overWeight = max(1, defenseControl * 55 + getBaseRating(onBallDefender, path: "defense.perimeterDefense") * 0.18)
    let underWeight = max(1, defenseControl * 28 + getBaseRating(onBallDefender, path: "skills.shotIQ") * 0.1)
    let switchWeight = max(1, offenseControl * 48 + getBaseRating(screenerDefender, path: "defense.lateralQuickness") * 0.22)
    let iceWeight = max(1, defenseControl * 36 + getBaseRating(onBallDefender, path: "defense.shotContest") * 0.16)
    let total = overWeight + underWeight + switchWeight + iceWeight
    var pick = random.nextUnit() * max(total, 1)
    pick -= overWeight; if pick <= 0 { return .over }
    pick -= underWeight; if pick <= 0 { return .under }
    pick -= switchWeight; if pick <= 0 { return .switchSwitch }
    return .ice
}

func resolvePickAndRollOutcome(
    stored: inout NativeGameStateStore.StoredState,
    offenseLineup: [Player],
    defenseLineup: [Player],
    ballHandlerIdx: Int,
    defenderIdx: Int,
    screenerIdx: Int,
    screenerDefenderIdx: Int,
    screenEdge: Double,
    navigation: ScreenNavigation,
    handlerUsageOverload: Double,
    random: inout SeededRandom
) -> PlayOutcome {
    let ballHandler = offenseLineup[ballHandlerIdx]
    let screener = offenseLineup[screenerIdx]
    let onBallDefender = defenseLineup[defenderIdx]
    let screenerDefender = defenseLineup[screenerDefenderIdx]
    let pnrPassDecisionBias = 0.02 + handlerUsageOverload * 0.05
    let passLean = clamp(
        0.55
            + (50 - getRating(ballHandler, path: "tendencies.shootVsPass")) / 150
            + (getRating(ballHandler, path: "skills.passingVision") - 50) / 300,
        min: 0.4,
        max: 0.82
    )

    switch navigation {
    case .over:
        // Ball handler drives off the screen; roller threat pulls help.
        let rollerSeal = resolveInteractionWithTrace(
            stored: &stored,
            label: "roller_seal",
            offensePlayer: screener,
            defensePlayer: screenerDefender,
            offenseRatings: ["postGame.postControl", "athleticism.strength", "skills.hands"],
            defenseRatings: ["defense.postDefense", "defense.defensiveControl", "athleticism.strength"],
            random: &random
        )
        let handlerRead = resolveInteractionWithTrace(
            stored: &stored,
            label: "pnr_handler_read",
            offensePlayer: ballHandler,
            defensePlayer: onBallDefender,
            offenseRatings: ["skills.passingVision", "skills.passingIQ", "skills.ballHandling"],
            defenseRatings: ["defense.passPerception", "defense.lateralQuickness", "defense.perimeterDefense"],
            random: &random
        )
        // Elite roll-man (postControl) seals harder; elite handler (passingVision)
        // reads the rotation and finds the right read. Defensive bigs / on-ball
        // stoppers symmetrically reduce both.
        let rollerElite = eliteRatingPremium(getRating(screener, path: "postGame.postControl"), maxBoost: 0.45)
        let rollDefElite = eliteRatingPremium(getRating(screenerDefender, path: "defense.postDefense"), maxBoost: 0.40)
        let readerElite = eliteRatingPremium(getRating(ballHandler, path: "skills.passingVision"), maxBoost: 0.35)
        let perimeterElite = eliteRatingPremium(getRating(onBallDefender, path: "defense.perimeterDefense"), maxBoost: 0.30)
        let rollerFinishChance = clamp(
            0.18
                + logistic(rollerSeal.edge + screenEdge * 0.45 + rollerElite - rollDefElite) * 0.46
                + logistic(handlerRead.edge + readerElite - perimeterElite) * 0.12
                + (passLean - 0.55) * 0.16,
            min: 0.2,
            max: 0.82
        )
        if random.nextUnit() < rollerFinishChance {
            let takesDunk = getRating(screener, path: "shooting.dunks") > 65 && random.nextUnit() < 0.45
            return PlayOutcome(
                shooterLineupIndex: screenerIdx,
                defenderLineupIndex: screenerDefenderIdx,
                shotType: takesDunk ? .dunk : .layup,
                spot: .middlePaint,
                edgeBonus: screenEdge * 0.4 + 0.1,
                makeBonus: 0.04,
                foulBonus: 0.03,
                assistCandidateIndices: [ballHandlerIdx],
                assistForceChance: 0.82,
                isDrive: false
            )
        }
        if random.nextUnit() < clamp(0.55 + passLean * 0.34 + pnrPassDecisionBias, min: 0.64 + pnrPassDecisionBias, max: 0.98) {
            let receiverIdx = evaluatePassTarget(
                offenseLineup: offenseLineup,
                defenseLineup: defenseLineup,
                ballHandlerIdx: ballHandlerIdx,
                random: &random
            )
            let shooter = offenseLineup[receiverIdx]
            let receiverDefIdx = min(receiverIdx, defenseLineup.count - 1)
            let selection = chooseInteractionSpotAndShot(
                stored: &stored,
                shooter: shooter,
                defender: defenseLineup[receiverDefIdx],
                random: &random
            )
            let spot = selection.spot
            let shotType = selection.shotType
            return PlayOutcome(
                shooterLineupIndex: receiverIdx,
                defenderLineupIndex: receiverDefIdx,
                shotType: shotType,
                spot: spot,
                edgeBonus: screenEdge * 0.24 + 0.06,
                makeBonus: 0.04,
                foulBonus: 0,
                assistCandidateIndices: [ballHandlerIdx],
                assistForceChance: 0.72,
                isDrive: false
            )
        }
        return PlayOutcome(
            shooterLineupIndex: ballHandlerIdx,
            defenderLineupIndex: defenderIdx,
            shotType: .layup,
            spot: .middlePaint,
            edgeBonus: screenEdge * 0.32,
            makeBonus: -0.02 - handlerUsageOverload * 0.10,
            foulBonus: 0.04,
            assistCandidateIndices: nil,
            assistForceChance: 0.3,
            isDrive: true
        )
    case .under:
        // Defender drops → open pull-up three or midrange for ball handler.
        let threeRating = getRating(ballHandler, path: "shooting.threePointShooting")
        let midRating = getRating(ballHandler, path: "shooting.midrangeShot")
        let shootsThree = threeRating >= midRating - 4
        let shotType: ShotType = shootsThree ? .three : .midrange
        let spot: OffensiveSpot = shootsThree ? .topMiddle : .rightElbow
        if offenseLineup.count > 1 && random.nextUnit() < clamp(0.6 + passLean * 0.3 + pnrPassDecisionBias, min: 0.7 + pnrPassDecisionBias, max: 0.98) {
            let receiverIdx = evaluatePassTarget(
                offenseLineup: offenseLineup,
                defenseLineup: defenseLineup,
                ballHandlerIdx: ballHandlerIdx,
                random: &random
            )
            let shooter = offenseLineup[receiverIdx]
            let receiverDefIdx = min(receiverIdx, defenseLineup.count - 1)
            let selection = chooseInteractionSpotAndShot(
                stored: &stored,
                shooter: shooter,
                defender: defenseLineup[receiverDefIdx],
                random: &random
            )
            let spot = selection.spot
            let shotType = selection.shotType
            return PlayOutcome(
                shooterLineupIndex: receiverIdx,
                defenderLineupIndex: receiverDefIdx,
                shotType: shotType,
                spot: spot,
                edgeBonus: screenEdge * 0.16 + 0.08,
                makeBonus: 0.04,
                foulBonus: 0,
                assistCandidateIndices: [ballHandlerIdx],
                assistForceChance: 0.7
            )
        }
        return PlayOutcome(
            shooterLineupIndex: ballHandlerIdx,
            defenderLineupIndex: defenderIdx,
            shotType: shotType,
            spot: spot,
            edgeBonus: screenEdge * 0.2 + 0.1,
            makeBonus: -0.02 - handlerUsageOverload * 0.09,
            foulBonus: 0,
            assistCandidateIndices: nil,
            assistForceChance: 0.25
        )
    case .switchSwitch:
        // Mismatch: if ball handler is notably quicker than big, attack. Else post the small.
        let handlerBurst = getRating(ballHandler, path: "athleticism.burst")
        let bigBurst = getRating(defenseLineup[min(screenerDefenderIdx, defenseLineup.count - 1)], path: "athleticism.burst")
        if handlerBurst > bigBurst + 8 {
            if offenseLineup.count > 1 && random.nextUnit() < clamp(0.54 + passLean * 0.32 + pnrPassDecisionBias, min: 0.64 + pnrPassDecisionBias, max: 0.97) {
                let receiverIdx = evaluatePassTarget(
                    offenseLineup: offenseLineup,
                    defenseLineup: defenseLineup,
                    ballHandlerIdx: ballHandlerIdx,
                    random: &random
                )
                let shooter = offenseLineup[receiverIdx]
                let receiverDefIdx = min(receiverIdx, defenseLineup.count - 1)
                let selection = chooseInteractionSpotAndShot(
                    stored: &stored,
                    shooter: shooter,
                    defender: defenseLineup[receiverDefIdx],
                    random: &random
                )
                let spot = selection.spot
                let shotType = selection.shotType
                return PlayOutcome(
                    shooterLineupIndex: receiverIdx,
                    defenderLineupIndex: receiverDefIdx,
                    shotType: shotType,
                    spot: spot,
                    edgeBonus: 0.14,
                    makeBonus: 0.04,
                    foulBonus: 0,
                    assistCandidateIndices: [ballHandlerIdx],
                    assistForceChance: 0.68
                )
            }
            return PlayOutcome(
                shooterLineupIndex: ballHandlerIdx,
                defenderLineupIndex: screenerDefenderIdx,
                shotType: .layup,
                spot: .middlePaint,
                edgeBonus: 0.2,
                makeBonus: -0.01 - handlerUsageOverload * 0.09,
                foulBonus: 0.04,
                assistCandidateIndices: nil,
                assistForceChance: 0.3,
                isDrive: true
            )
        } else {
            // Screener posts up the smaller defender.
            let shotType: ShotType = random.nextUnit() < 0.55 ? .hook : .fadeaway
            return PlayOutcome(
                shooterLineupIndex: screenerIdx,
                defenderLineupIndex: defenderIdx,
                shotType: shotType,
                spot: random.nextUnit() < 0.5 ? .leftPost : .rightPost,
                edgeBonus: 0.12,
                makeBonus: 0.03,
                foulBonus: 0.02,
                assistCandidateIndices: [ballHandlerIdx],
                assistForceChance: 0.6
            )
        }
    case .ice:
        // Defense cuts off the middle; ball handler forced sideline → tough midrange or reset to a passer.
        if random.nextUnit() < clamp(0.84 + passLean * 0.14 + pnrPassDecisionBias, min: 0.78 + pnrPassDecisionBias, max: 0.99) {
            // Reset pass to best-open teammate for a shot.
            let receiverIdx = offenseLineup.indices
                .filter { $0 != ballHandlerIdx && $0 != screenerIdx }
                .max { a, b in openShotUtility(offenseLineup[a]) < openShotUtility(offenseLineup[b]) }
                ?? ballHandlerIdx
            let shooter = offenseLineup[receiverIdx]
            let receiverDefIdx = min(receiverIdx, defenseLineup.count - 1)
            let selection = chooseInteractionSpotAndShot(
                stored: &stored,
                shooter: shooter,
                defender: defenseLineup[receiverDefIdx],
                random: &random
            )
            let spot = selection.spot
            let shotType = selection.shotType
            return PlayOutcome(
                shooterLineupIndex: receiverIdx,
                defenderLineupIndex: receiverDefIdx,
                shotType: shotType,
                spot: spot,
                edgeBonus: 0.06,
                makeBonus: 0.03,
                foulBonus: 0,
                assistCandidateIndices: [ballHandlerIdx],
                assistForceChance: 0.6
            )
        }
        return PlayOutcome(
            shooterLineupIndex: ballHandlerIdx,
            defenderLineupIndex: defenderIdx,
            shotType: .midrange,
            spot: random.nextUnit() < 0.5 ? .rightElbow : .leftElbow,
            edgeBonus: -0.08,
            makeBonus: -0.05 - handlerUsageOverload * 0.06,
            foulBonus: 0,
            assistCandidateIndices: nil,
            assistForceChance: 0.2
        )
    }
}

struct PopDestination {
    var shotType: ShotType
    var spot: OffensiveSpot
    var edgeBonus: Double
}

func choosePopDestination(
    stored: inout NativeGameStateStore.StoredState,
    screener: Player,
    closeoutDefender: Player,
    random: inout SeededRandom
) -> PopDestination {
    // Compare expected value: midrange (2 * mid_make_prob) vs three (3 * three_make_prob)
    let popChoiceInteraction = resolveInteractionWithTrace(
        stored: &stored,
        label: "pop_destination",
        offensePlayer: screener,
        defensePlayer: closeoutDefender,
        offenseRatings: ["shooting.threePointShooting", "shooting.midrangeShot", "skills.shotIQ"],
        defenseRatings: ["defense.shotContest", "defense.perimeterDefense", "defense.lateralQuickness"],
        random: &random
    )
    let popControl = logistic(popChoiceInteraction.edge)
    let midRating = getRating(screener, path: "shooting.midrangeShot")
    let threeRating = getRating(screener, path: "shooting.threePointShooting")
    let midEV = 2 * clamp(0.32 + (midRating - 55) / 250 + (0.5 - popControl) * 0.06, min: 0.25, max: 0.58)
    let threeEV = 3 * clamp(0.28 + (threeRating - 55) / 300 + (popControl - 0.5) * 0.07, min: 0.2, max: 0.52)
    if threeEV > midEV + 0.1 {
        let spot: OffensiveSpot = random.nextUnit() < 0.5 ? .topRight : .topLeft
        return PopDestination(shotType: .three, spot: spot, edgeBonus: 0.02)
    } else if midEV > threeEV + 0.05 {
        let spot: OffensiveSpot = random.nextUnit() < 0.5 ? .rightElbow : .leftElbow
        return PopDestination(shotType: .midrange, spot: spot, edgeBonus: 0.03)
    }
    // Toss-up: 50/50
    if random.nextUnit() < 0.5 {
        return PopDestination(shotType: .three, spot: .topMiddle, edgeBonus: 0)
    }
    return PopDestination(shotType: .midrange, spot: .rightElbow, edgeBonus: 0)
}
