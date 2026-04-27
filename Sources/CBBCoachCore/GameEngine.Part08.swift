import Foundation

func chooseInteractionSpotAndShot(
    stored: inout NativeGameStateStore.StoredState,
    shooter: Player,
    defender: Player,
    random: inout SeededRandom
) -> (spot: OffensiveSpot, shotType: ShotType) {
    let spotInteraction = resolveInteractionWithTrace(
        stored: &stored,
        label: "shot_spot_selection",
        offensePlayer: shooter,
        defensePlayer: defender,
        offenseRatings: ["skills.offballOffense", "skills.shotIQ", "tendencies.threePoint", "tendencies.inside", "tendencies.post"],
        defenseRatings: ["defense.offballDefense", "defense.perimeterDefense", "defense.postDefense", "defense.lateralQuickness"],
        random: &random
    )
    let perimeterControl = logistic(spotInteraction.edge)
    let spot: OffensiveSpot
    if perimeterControl > 0.64 {
        let cornerLean = getBaseRating(shooter, path: "shooting.cornerThrees")
        let topLean = getBaseRating(shooter, path: "shooting.upTopThrees")
        if cornerLean > topLean + 5 {
            spot = random.nextUnit() < 0.5 ? .leftCorner : .rightCorner
        } else {
            let picks: [OffensiveSpot] = [.topLeft, .topMiddle, .topRight]
            spot = picks[random.int(0, picks.count - 1)]
        }
    } else if perimeterControl < 0.36 {
        let postLean = getBaseRating(shooter, path: "tendencies.post")
        if postLean > 58 {
            spot = random.nextUnit() < 0.5 ? .leftPost : .rightPost
        } else {
            spot = .middlePaint
        }
    } else {
        let picks: [OffensiveSpot] = [.leftElbow, .rightElbow, .topMiddle]
        spot = picks[random.int(0, picks.count - 1)]
    }

    let shotInteraction = resolveInteractionWithTrace(
        stored: &stored,
        label: "shot_type_selection",
        offensePlayer: shooter,
        defensePlayer: defender,
        offenseRatings: ["skills.shotIQ", "shooting.threePointShooting", "shooting.midrangeShot", "shooting.closeShot", "shooting.layups"],
        defenseRatings: ["defense.shotContest", "defense.perimeterDefense", "defense.postDefense"],
        random: &random
    )
    let shotControl = logistic(shotInteraction.edge)
    let shotType: ShotType
    if spot == .middlePaint || spot == .leftPost || spot == .rightPost {
        if shotControl > 0.68 {
            shotType = getBaseRating(shooter, path: "shooting.dunks") > getBaseRating(shooter, path: "shooting.layups") + 4 ? .dunk : .layup
        } else if shotControl > 0.44 {
            shotType = getBaseRating(shooter, path: "postGame.postHooks") > getBaseRating(shooter, path: "postGame.postFadeaways") ? .hook : .fadeaway
        } else {
            shotType = .close
        }
    } else if spot == .leftCorner || spot == .rightCorner || spot == .topLeft || spot == .topMiddle || spot == .topRight {
        shotType = shotControl > 0.48 ? .three : .midrange
    } else {
        shotType = shotControl > 0.56 ? .midrange : .close
    }
    return (spot, shotType)
}

// MARK: - Play types

enum PlayType {
    case dribbleDrive, postUp, pickAndRoll, pickAndPop, passAroundForShot
}

struct PlayOutcome {
    var shooterLineupIndex: Int
    var defenderLineupIndex: Int
    var shotType: ShotType
    var spot: OffensiveSpot
    var edgeBonus: Double
    var makeBonus: Double
    var foulBonus: Double
    var assistCandidateIndices: [Int]?
    var assistForceChance: Double?
    var passInterceptionRiskShift: Double = 0
    var isDrive: Bool = false
    var forcedTurnoverStealerLineupIndex: Int? = nil
}

func isPerimeterSpot(_ spot: OffensiveSpot) -> Bool {
    switch spot {
    case .topMiddle, .topLeft, .topRight, .leftCorner, .rightCorner, .leftSlot, .rightSlot:
        return true
    default:
        return false
    }
}

func buildHalfCourtReboundLocationHints(
    play: PlayOutcome,
    ballHandlerIdx: Int,
    offenseCount: Int,
    defenseCount: Int
) -> ReboundLocationHints {
    var offense = (0..<offenseCount).map { Optional(defaultReboundSpot(forLineupIndex: $0)) }
    if ballHandlerIdx >= 0, ballHandlerIdx < offense.count {
        offense[ballHandlerIdx] = play.isDrive ? .middlePaint : .topMiddle
    }
    if let passers = play.assistCandidateIndices {
        for idx in passers where idx >= 0 && idx < offense.count && idx != play.shooterLineupIndex {
            if play.isDrive {
                offense[idx] = .middlePaint
            } else {
                offense[idx] = isPerimeterSpot(play.spot) ? .ftLine : .topMiddle
            }
        }
    }
    if play.shooterLineupIndex >= 0, play.shooterLineupIndex < offense.count {
        offense[play.shooterLineupIndex] = play.spot
    }

    var defense = (0..<defenseCount).map { idx -> OffensiveSpot? in
        idx < offense.count ? offense[idx] : defaultReboundSpot(forLineupIndex: idx)
    }
    if play.defenderLineupIndex >= 0, play.defenderLineupIndex < defense.count {
        defense[play.defenderLineupIndex] = play.spot
    }
    return ReboundLocationHints(offense: offense, defense: defense)
}

func buildTransitionReboundLocationHints(
    offenseCount: Int,
    defenseCount: Int,
    shooterIdx: Int,
    shotDefenderIdx: Int
) -> ReboundLocationHints {
    var offense = (0..<offenseCount).map { Optional(defaultReboundSpot(forLineupIndex: $0)) }
    var defense = (0..<defenseCount).map { Optional(defaultReboundSpot(forLineupIndex: $0)) }
    if shooterIdx >= 0, shooterIdx < offense.count {
        offense[shooterIdx] = .middlePaint
    }
    if shotDefenderIdx >= 0, shotDefenderIdx < defense.count {
        defense[shotDefenderIdx] = .middlePaint
    }
    return ReboundLocationHints(offense: offense, defense: defense)
}

func choosePlayType(
    stored: inout NativeGameStateStore.StoredState,
    offenseTeam: Team,
    ballHandler: Player,
    primaryDefender: Player,
    random: inout SeededRandom
) -> PlayType {
    let drive = getRating(ballHandler, path: "tendencies.drive")
    let post = getRating(ballHandler, path: "tendencies.post")
    let pickAndRoll = getRating(ballHandler, path: "tendencies.pickAndRoll")
    let pickAndPop = getRating(ballHandler, path: "tendencies.pickAndPop")
    let shootVsPass = getRating(ballHandler, path: "tendencies.shootVsPass")
    let passAroundProfile = (
        getRating(ballHandler, path: "skills.passingVision")
        + getRating(ballHandler, path: "skills.passingIQ")
        + getRating(ballHandler, path: "skills.passingAccuracy")
        + getRating(ballHandler, path: "skills.ballHandling")
    ) / 4
    let passAround = clamp((100 - shootVsPass) * 0.55 + passAroundProfile * 0.5, min: 1, max: 115)
    let handlerEnergy = clamp(ballHandler.condition.energy, min: 0, max: 100)
    let handlerFatigue = clamp((100 - handlerEnergy) / 100, min: 0, max: 0.9)
    let handlerStamina = getBaseRating(ballHandler, path: "athleticism.stamina")
    let wearFactor = clamp(handlerFatigue * (1.02 - (handlerStamina - 50) / 170), min: 0, max: 0.85)

    let formation = offenseTeam.formation
    let passAroundFormationBoost = (formation == .motion || formation == .fiveOut) ? 1.1 : 0.96
    let pickFormationBoost = (formation == .motion || formation == .fiveOut || formation == .highLow) ? 1.07 : 0.97

    let weights: [(PlayType, Double)] = [
        (.dribbleDrive, max(1, drive) * 0.22 * clamp(1 - wearFactor * 0.55, min: 0.55, max: 1.05)),
        (.postUp, max(1, post) * 0.28 * clamp(1 - wearFactor * 0.32, min: 0.68, max: 1.03)),
        (.pickAndRoll, max(1, pickAndRoll * 0.62 + drive * 0.22 + (100 - shootVsPass) * 0.16) * pickFormationBoost * 1.1 * clamp(1 - wearFactor * 0.38, min: 0.62, max: 1.04)),
        (.pickAndPop, max(1, pickAndPop * 0.62 + passAroundProfile * 0.2 + (100 - shootVsPass) * 0.18) * pickFormationBoost * 1.05 * clamp(1 - wearFactor * 0.3, min: 0.7, max: 1.04)),
        (.passAroundForShot, max(1, passAround) * passAroundFormationBoost * 5.65 * clamp(1 + wearFactor * 0.85, min: 0.96, max: 1.58)),
    ]
    var adjusted: [(PlayType, Double)] = []
    for (type, baseWeight) in weights {
        let interaction: InteractionResult
        switch type {
        case .dribbleDrive:
            interaction = resolveInteractionWithTrace(
                stored: &stored,
                label: "play_type_drive",
                offensePlayer: ballHandler,
                defensePlayer: primaryDefender,
                offenseRatings: ["tendencies.drive", "athleticism.burst", "skills.ballHandling"],
                defenseRatings: ["defense.perimeterDefense", "defense.lateralQuickness", "defense.defensiveControl"],
                random: &random
            )
        case .postUp:
            interaction = resolveInteractionWithTrace(
                stored: &stored,
                label: "play_type_post",
                offensePlayer: ballHandler,
                defensePlayer: primaryDefender,
                offenseRatings: ["tendencies.post", "postGame.postControl", "athleticism.strength"],
                defenseRatings: ["defense.postDefense", "defense.defensiveControl", "athleticism.strength"],
                random: &random
            )
        case .pickAndRoll:
            interaction = resolveInteractionWithTrace(
                stored: &stored,
                label: "play_type_pnr",
                offensePlayer: ballHandler,
                defensePlayer: primaryDefender,
                offenseRatings: ["tendencies.pickAndRoll", "skills.passingVision", "skills.ballHandling"],
                defenseRatings: ["defense.passPerception", "defense.lateralQuickness", "defense.perimeterDefense"],
                random: &random
            )
        case .pickAndPop:
            interaction = resolveInteractionWithTrace(
                stored: &stored,
                label: "play_type_pnp",
                offensePlayer: ballHandler,
                defensePlayer: primaryDefender,
                offenseRatings: ["tendencies.pickAndPop", "skills.passingIQ", "skills.shotIQ"],
                defenseRatings: ["defense.passPerception", "defense.offballDefense", "defense.perimeterDefense"],
                random: &random
            )
        case .passAroundForShot:
            interaction = resolveInteractionWithTrace(
                stored: &stored,
                label: "play_type_motion",
                offensePlayer: ballHandler,
                defensePlayer: primaryDefender,
                offenseRatings: ["skills.passingVision", "skills.passingIQ", "tendencies.shootVsPass"],
                defenseRatings: ["defense.offballDefense", "defense.passPerception", "defense.lateralQuickness"],
                random: &random
            )
        }
        let boost = clamp((logistic(interaction.edge) - 0.5) * 0.9, min: -0.35, max: 0.45)
        adjusted.append((type, max(1, baseWeight * (1 + boost))))
    }

    let total = adjusted.reduce(0) { $0 + $1.1 }
    var pick = random.nextUnit() * max(total, 1)
    for (type, weight) in adjusted {
        pick -= weight
        if pick <= 0 { return type }
    }
    return .dribbleDrive
}
