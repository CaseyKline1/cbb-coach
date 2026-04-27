import Foundation

func pickLineupIndexForBallHandler(
    lineup: [Player],
    lineupBoxIndices: [Int],
    initiatedActionCountByBoxIndex: [Int: Int],
    totalInitiatedActions: Int,
    random: inout SeededRandom
) -> Int {
    guard !lineup.isEmpty else { return 0 }
    let weights = lineup.enumerated().map { idx, player -> Double in
        let base = getBaseRating(player, path: "skills.ballHandling") * 0.32
            + getBaseRating(player, path: "skills.passingVision") * 0.28
            + getBaseRating(player, path: "skills.passingIQ") * 0.2
            + getBaseRating(player, path: "skills.passingAccuracy") * 0.12
            + getBaseRating(player, path: "tendencies.shootVsPass") * 0.16
            + (100 - getBaseRating(player, path: "tendencies.shootVsPass")) * 0.06
            + getBaseRating(player, path: "skills.shotIQ") * 0.02
            + getBaseRating(player, path: "athleticism.burst") * 0.03
            + getBaseRating(player, path: "tendencies.drive") * 0.02
        let stamina = getBaseRating(player, path: "athleticism.stamina")
        let energy = clamp(player.condition.energy, min: 0, max: 100)
        let fatigue = clamp((100 - energy) / 100, min: 0, max: 0.9)
        let staminaProtection = clamp((stamina - 50) / 100, min: -0.2, max: 0.45)
        let fatigueTax = clamp(1 - fatigue * (0.72 - staminaProtection * 0.32), min: 0.32, max: 1)
        let positionMultiplier: Double
        switch player.bio.position {
        case .pg, .cg:
            positionMultiplier = 2.25
        case .sg:
            positionMultiplier = 1.18
        case .sf, .wing, .f:
            positionMultiplier = 0.72
        case .pf, .c, .big:
            positionMultiplier = 0.36
        }
        let skillWeighted = max(1, base * positionMultiplier * fatigueTax)
        let softenedSkill = min(skillWeighted, 95) + max(0, skillWeighted - 95) * 0.35
        let compressed = Foundation.pow(softenedSkill, 0.58)
        let equalTouchFloor = 0.3
        let boxIndex = idx < lineupBoxIndices.count ? lineupBoxIndices[idx] : idx
        let usageMultiplier = ballHandlerUsageMultiplier(
            boxIndex: boxIndex,
            lineupCount: lineup.count,
            initiatedActionCountByBoxIndex: initiatedActionCountByBoxIndex,
            totalInitiatedActions: totalInitiatedActions,
            shareTarget: ballHandlerShareTarget
        )
        let selectionVariance = 0.92 + random.nextUnit() * 0.16
        return max(1, (compressed + equalTouchFloor) * usageMultiplier * selectionVariance)
    }
    return weightedChoiceIndex(weights: weights, random: &random)
}

func isPointGuardLike(_ player: Player) -> Bool {
    switch player.bio.position {
    case .pg: return true
    case .cg: return true
    default: return false
    }
}

func isFourFiveLike(_ player: Player) -> Bool {
    switch player.bio.position {
    case .pf, .c, .big: return true
    default: return false
    }
}

func pickLineupIndexForPickActionBallHandler(
    lineup: [Player],
    lineupBoxIndices: [Int],
    initiatedActionCountByBoxIndex: [Int: Int],
    totalInitiatedActions: Int,
    random: inout SeededRandom
) -> Int {
    guard !lineup.isEmpty else { return 0 }
    let weights = lineup.enumerated().map { idx, player -> Double in
        let base = getBaseRating(player, path: "skills.ballHandling") * 0.34
            + getBaseRating(player, path: "skills.passingVision") * 0.24
            + getBaseRating(player, path: "skills.passingIQ") * 0.2
            + getBaseRating(player, path: "skills.passingAccuracy") * 0.1
            + getBaseRating(player, path: "skills.shotIQ") * 0.05
            + getBaseRating(player, path: "athleticism.burst") * 0.03
            + getBaseRating(player, path: "tendencies.pickAndRoll") * 0.08
            + getBaseRating(player, path: "tendencies.pickAndPop") * 0.06
        let stamina = getBaseRating(player, path: "athleticism.stamina")
        let energy = clamp(player.condition.energy, min: 0, max: 100)
        let fatigue = clamp((100 - energy) / 100, min: 0, max: 0.9)
        let staminaProtection = clamp((stamina - 50) / 100, min: -0.2, max: 0.45)
        let fatigueTax = clamp(1 - fatigue * (0.78 - staminaProtection * 0.32), min: 0.3, max: 1)
        let positionMultiplier: Double
        switch player.bio.position {
        case .pg, .cg:
            positionMultiplier = 2.05
        case .sg:
            positionMultiplier = 0.96
        case .sf, .wing, .f:
            positionMultiplier = 0.7
        case .pf, .c, .big:
            positionMultiplier = 0.4
        }
        let skillWeighted = max(1, base * positionMultiplier * fatigueTax)
        let softenedSkill = min(skillWeighted, 95) + max(0, skillWeighted - 95) * 0.38
        let compressed = Foundation.pow(softenedSkill, 0.56)
        let equalTouchFloor = 0.5
        let boxIndex = idx < lineupBoxIndices.count ? lineupBoxIndices[idx] : idx
        let usageMultiplier = ballHandlerUsageMultiplier(
            boxIndex: boxIndex,
            lineupCount: lineup.count,
            initiatedActionCountByBoxIndex: initiatedActionCountByBoxIndex,
            totalInitiatedActions: totalInitiatedActions,
            shareTarget: 0.38
        )
        let selectionVariance = 0.9 + random.nextUnit() * 0.2
        return max(1, (compressed + equalTouchFloor) * usageMultiplier * selectionVariance)
    }
    return weightedChoiceIndex(weights: weights, random: &random)
}

func ballHandlerUsageMultiplier(
    boxIndex: Int,
    lineupCount: Int,
    initiatedActionCountByBoxIndex: [Int: Int],
    totalInitiatedActions: Int,
    shareTarget: Double
) -> Double {
    guard lineupCount > 0, totalInitiatedActions >= ballHandlerWarmupActions else { return 1.0 }
    let initiatedByPlayer = initiatedActionCountByBoxIndex[boxIndex] ?? 0
    let share = Double(initiatedByPlayer) / Double(max(1, totalInitiatedActions))
    let evenShare = 1.0 / Double(lineupCount)
    let overTarget = max(0, share - shareTarget)
    let overEven = max(0, share - evenShare)
    let underEven = max(0, evenShare - share)

    let capPenalty = clamp(1 - overTarget * 0.26, min: 0.95, max: 1)
    let spreadPenalty = clamp(1 - overEven * 0.04, min: 0.98, max: 1)
    let underuseBoost = clamp(1 + underEven * 0.03, min: 1, max: 1.015)
    return capPenalty * spreadPenalty * underuseBoost
}

func recordActionInitiator(
    stored: inout NativeGameStateStore.StoredState,
    teamId: Int,
    lineupIndex: Int
) {
    guard teamId >= 0, teamId < stored.teams.count else { return }
    guard lineupIndex >= 0, lineupIndex < stored.teams[teamId].activeLineupBoxIndices.count else { return }
    let boxIndex = stored.teams[teamId].activeLineupBoxIndices[lineupIndex]
    stored.teams[teamId].initiatedActionCount += 1
    stored.teams[teamId].initiatedActionCountByBoxIndex[boxIndex, default: 0] += 1
}

func resolveAssistLineupIndex(
    stored: inout NativeGameStateStore.StoredState,
    offenseLineup: [Player],
    defenseLineup: [Player],
    shooterIndex: Int,
    shooterDefenderIndex: Int,
    candidates: [Int],
    creationBias: Double?,
    shotType: ShotType,
    random: inout SeededRandom
) -> Int? {
    let filtered = Array(Set(candidates.filter { $0 != shooterIndex && $0 >= 0 && $0 < offenseLineup.count })).sorted()
    guard !filtered.isEmpty, !defenseLineup.isEmpty else { return nil }

    let shooter = offenseLineup[shooterIndex]
    let shotDefender = defenseLineup[min(max(0, shooterDefenderIndex), defenseLineup.count - 1)]
    var bestIndex: Int?
    var bestScore = -Double.infinity

    for candidateIdx in filtered {
        let passer = offenseLineup[candidateIdx]
        let laneDefender = defenseLineup[min(candidateIdx, defenseLineup.count - 1)]
        let passWindow = resolveInteractionWithTrace(
            stored: &stored,
            label: "assist_pass_window",
            offensePlayer: passer,
            defensePlayer: laneDefender,
            offenseRatings: ["skills.passingVision", "skills.passingIQ", "skills.passingAccuracy", "skills.ballHandling"],
            defenseRatings: ["defense.passPerception", "defense.offballDefense", "defense.lateralQuickness", "skills.hands"],
            random: &random
        )
        let timingWindow = resolveInteractionWithTrace(
            stored: &stored,
            label: "assist_receiver_timing",
            offensePlayer: shooter,
            defensePlayer: shotDefender,
            offenseRatings: ["skills.offballOffense", "skills.shotIQ", "skills.hands", "athleticism.burst"],
            defenseRatings: ["defense.offballDefense", "defense.shotContest", "defense.defensiveControl", "defense.lateralQuickness"],
            random: &random
        )
        let passControl = logistic(passWindow.edge)
        let timingControl = logistic(timingWindow.edge)
        let shotContextBonus: Double = {
            switch shotType {
            case .three:
                return 0.12
            case .midrange, .fadeaway:
                return 0.06
            case .hook:
                return 0.03
            case .layup, .dunk, .close:
                return 0.02
            }
        }()
        let biasBonus = ((creationBias ?? 0.5) - 0.5) * 0.22
        let score = (passControl - 0.5) * 1.05 + (timingControl - 0.5) * 0.9 + shotContextBonus + biasBonus
        if score > bestScore {
            bestScore = score
            bestIndex = candidateIdx
        }
    }

    guard let assistIdx = bestIndex else { return nil }
    return assistIdx
}

enum ReboundZone {
    case paint, leftBlock, rightBlock, leftPerimeter, rightPerimeter, topPerimeter
}

struct ReboundLocationHints {
    var offense: [OffensiveSpot?]
    var defense: [OffensiveSpot?]
}

struct ReboundOutcome {
    var offensive: Bool
    var lineupIndex: Int
}

func reboundZone(for shotType: ShotType, spot: OffensiveSpot) -> ReboundZone {
    switch shotType {
    case .three:
        switch spot {
        case .leftCorner: return .leftPerimeter
        case .rightCorner: return .rightPerimeter
        case .topLeft: return .leftPerimeter
        case .topRight: return .rightPerimeter
        default: return .topPerimeter
        }
    case .midrange, .fadeaway:
        switch spot {
        case .leftElbow, .leftPost: return .leftBlock
        case .rightElbow, .rightPost: return .rightBlock
        default: return .paint
        }
    default:
        switch spot {
        case .leftPost: return .leftBlock
        case .rightPost: return .rightBlock
        default: return .paint
        }
    }
}

func resolveReboundLandingZone(
    stored: inout NativeGameStateStore.StoredState,
    offenseLineup: [Player],
    defenseLineup: [Player],
    shotType: ShotType,
    spot: OffensiveSpot,
    shooterIndex: Int,
    shotDefenderIndex: Int,
    random: inout SeededRandom
) -> ReboundZone {
    let initialZone = reboundZone(for: shotType, spot: spot)
    guard !offenseLineup.isEmpty, !defenseLineup.isEmpty else { return initialZone }
    let shooter = offenseLineup[min(max(0, shooterIndex), offenseLineup.count - 1)]
    let defender = defenseLineup[min(max(0, shotDefenderIndex), defenseLineup.count - 1)]
    let caromControl = resolveInteractionWithTrace(
        stored: &stored,
        label: "rebound_carom_direction",
        offensePlayer: shooter,
        defensePlayer: defender,
        offenseRatings: ["skills.shotIQ", "skills.hands", "shooting.threePointShooting", "shooting.midrangeShot", "shooting.closeShot"],
        defenseRatings: ["defense.shotContest", "defense.shotBlocking", "defense.defensiveControl", "skills.hustle"],
        random: &random
    )
    let offenseCaromControl = logistic(caromControl.edge)

    switch initialZone {
    case .leftPerimeter:
        return offenseCaromControl >= 0.52 ? .leftPerimeter : .leftBlock
    case .rightPerimeter:
        return offenseCaromControl >= 0.52 ? .rightPerimeter : .rightBlock
    case .topPerimeter:
        return offenseCaromControl >= 0.58 ? .topPerimeter : .paint
    case .leftBlock:
        return offenseCaromControl >= 0.5 ? .leftBlock : .paint
    case .rightBlock:
        return offenseCaromControl >= 0.5 ? .rightBlock : .paint
    case .paint:
        return .paint
    }
}

func postSideAffinity(_ player: Player, isLeft: Bool) -> Double {
    switch player.bio.position {
    case .pf:
        return isLeft ? 1.0 : 0.75
    case .c, .big:
        return isLeft ? 0.25 : 1.0
    case .sf, .f, .wing:
        return isLeft ? 0.8 : 0.45
    case .sg, .cg:
        return 0.2
    case .pg:
        return 0.1
    }
}

func zonePresenceAffinity(_ player: Player, zone: ReboundZone) -> Double {
    switch zone {
    case .paint:
        switch player.bio.position {
        case .c, .big:
            return 1.0
        case .pf, .f:
            return 0.85
        case .sf, .wing:
            return 0.45
        case .sg, .cg:
            return 0.18
        case .pg:
            return 0.1
        }
    case .leftBlock:
        return postSideAffinity(player, isLeft: true)
    case .rightBlock:
        return postSideAffinity(player, isLeft: false)
    case .leftPerimeter, .rightPerimeter, .topPerimeter:
        return 0
    }
}

func positionProximity(_ player: Player, zone: ReboundZone) -> Double {
    let positionTag = player.bio.position.rawValue.uppercased()
    let isBig = positionTag.contains("C") || positionTag.contains("PF") || positionTag.contains("F")
    let isGuard = positionTag.contains("PG") || positionTag.contains("SG") || positionTag.contains("G")
    switch zone {
    case .paint:
        return isBig ? 1.25 : (isGuard ? 0.75 : 1.0)
    case .leftBlock, .rightBlock:
        return isBig ? 1.18 : 0.85
    case .leftPerimeter, .rightPerimeter:
        return isGuard ? 1.2 : 0.85
    case .topPerimeter:
        return isGuard ? 1.15 : 0.9
    }
}

func defaultReboundSpot(forLineupIndex index: Int) -> OffensiveSpot {
    switch index % 5 {
    case 0: return .topMiddle
    case 1: return .topLeft
    case 2: return .topRight
    case 3: return .leftPost
    default: return .rightPost
    }
}

func locationProximityToReboundZone(spot: OffensiveSpot, zone: ReboundZone) -> Double {
    switch zone {
    case .paint:
        switch spot {
        case .middlePaint: return 1.36
        case .leftPost, .rightPost: return 1.24
        case .ftLine: return 1.04
        case .leftElbow, .rightElbow: return 0.94
        case .leftSlot, .rightSlot: return 0.82
        case .topMiddle: return 0.74
        case .topLeft, .topRight: return 0.66
        case .leftCorner, .rightCorner: return 0.52
        }
    case .leftBlock:
        switch spot {
        case .leftPost: return 1.36
        case .middlePaint: return 1.22
        case .leftElbow: return 1.04
        case .leftCorner: return 0.92
        case .leftSlot: return 0.9
        case .ftLine: return 0.86
        case .topLeft: return 0.78
        case .topMiddle: return 0.7
        case .rightPost: return 0.64
        case .rightElbow: return 0.58
        case .topRight: return 0.52
        case .rightSlot: return 0.48
        case .rightCorner: return 0.42
        }
    case .rightBlock:
        switch spot {
        case .rightPost: return 1.36
        case .middlePaint: return 1.22
        case .rightElbow: return 1.04
        case .rightCorner: return 0.92
        case .rightSlot: return 0.9
        case .ftLine: return 0.86
        case .topRight: return 0.78
        case .topMiddle: return 0.7
        case .leftPost: return 0.64
        case .leftElbow: return 0.58
        case .topLeft: return 0.52
        case .leftSlot: return 0.48
        case .leftCorner: return 0.42
        }
    case .leftPerimeter:
        switch spot {
        case .leftCorner: return 1.3
        case .topLeft: return 1.2
        case .leftSlot: return 1.1
        case .leftElbow: return 0.92
        case .topMiddle: return 0.84
        case .ftLine: return 0.8
        case .middlePaint: return 0.72
        case .leftPost: return 0.7
        case .rightPost: return 0.54
        case .topRight: return 0.52
        case .rightSlot: return 0.46
        case .rightElbow: return 0.44
        case .rightCorner: return 0.38
        }
    case .rightPerimeter:
        switch spot {
        case .rightCorner: return 1.3
        case .topRight: return 1.2
        case .rightSlot: return 1.1
        case .rightElbow: return 0.92
        case .topMiddle: return 0.84
        case .ftLine: return 0.8
        case .middlePaint: return 0.72
        case .rightPost: return 0.7
        case .leftPost: return 0.54
        case .topLeft: return 0.52
        case .leftSlot: return 0.46
        case .leftElbow: return 0.44
        case .leftCorner: return 0.38
        }
    case .topPerimeter:
        switch spot {
        case .topMiddle: return 1.28
        case .topLeft, .topRight: return 1.12
        case .leftSlot, .rightSlot: return 1.0
        case .ftLine: return 0.86
        case .leftElbow, .rightElbow: return 0.8
        case .middlePaint: return 0.7
        case .leftCorner, .rightCorner: return 0.68
        case .leftPost, .rightPost: return 0.62
        }
    }
}

func reboundNearbyWeight(
    _ player: Player,
    lineupIndex: Int,
    zone: ReboundZone,
    locationHints: [OffensiveSpot?]? = nil
) -> Double {
    let fallbackAffinity = zonePresenceAffinity(player, zone: zone)
    let fallbackProximity = positionProximity(player, zone: zone)
    let fallback = max(0.2, fallbackAffinity * 0.84 + fallbackProximity * 0.5)
    guard let locationHints, lineupIndex >= 0, lineupIndex < locationHints.count, let spot = locationHints[lineupIndex] else {
        return fallback
    }
    let location = locationProximityToReboundZone(spot: spot, zone: zone)
    return max(0.2, location * 0.66 + fallback * 0.52)
}

func teamReboundCrashPreference(crashBoards: Double, fastBreakBias: Double) -> Double {
    let crash = clamp(crashBoards, min: 0, max: 100)
    let leakOut = clamp(fastBreakBias, min: 0, max: 100)
    return clamp(0.5 + (crash - leakOut) / 200, min: 0.05, max: 0.95)
}
