import Foundation

private final class LengthParseCacheStorage: @unchecked Sendable {
    let lock = NSLock()
    var parsedInchesByRaw: [String: Double] = [:]
    let hyphenRegex = try! NSRegularExpression(pattern: #"^\s*(\d+)\s*-\s*(\d+)\s*$"#)
    let apostropheRegex = try! NSRegularExpression(pattern: #"^\s*(\d+)\s*'\s*(\d+)"#)
}

private enum LengthParseCache {
    static let shared = LengthParseCacheStorage()
}

public func simulateGameWithQA(homeTeam: Team, awayTeam: Team, random: inout SeededRandom) -> SimulatedGameQAResult {
    var state = createInitialGameState(homeTeam: homeTeam, awayTeam: awayTeam, random: &random)
    defer { _ = NativeGameStateStore.remove(state.handle) }
    _ = NativeGameStateStore.withState(state.handle) { stored in
        stored.traceEnabled = true
    }
    simulateHalf(state: &state, random: &random)

    _ = NativeGameStateStore.withState(state.handle) { stored in
        stored.currentHalf = 2
        stored.gameClockRemaining = HALF_SECONDS
        stored.shotClockRemaining = SHOT_CLOCK_SECONDS
        stored.teamFoulsInHalf = Array(repeating: 0, count: stored.teamFoulsInHalf.count)
        recoverAllPlayersForHalftime(stored: &stored)
    }
    simulateHalf(state: &state, random: &random)

    var overtimeNumber = 0
    while true {
        guard let snapshot = NativeGameStateStore.snapshot(state.handle) else {
            fatalError("simulateGameWithQA failed: missing game state \(state.handle)")
        }
        if snapshot.teams[0].score != snapshot.teams[1].score {
            break
        }
        overtimeNumber += 1
        _ = NativeGameStateStore.withState(state.handle) { stored in
            stored.currentHalf = 2 + overtimeNumber
            stored.gameClockRemaining = OVERTIME_SECONDS
            stored.shotClockRemaining = SHOT_CLOCK_SECONDS
            stored.teamFoulsInHalf = Array(repeating: 0, count: stored.teamFoulsInHalf.count)
            recoverAllPlayersForHalftime(stored: &stored)
        }
        simulateHalf(state: &state, random: &random)
    }

    guard let final = NativeGameStateStore.snapshot(state.handle) else {
        fatalError("simulateGameWithQA failed: missing game state \(state.handle)")
    }

    let homeBox = TeamBoxScore(
        name: final.teams[0].team.name,
        players: final.teams[0].boxPlayers.filter { $0.minutes > 0 || $0.points > 0 || $0.fgAttempts > 0 || $0.ftAttempts > 0 },
        teamExtras: final.teams[0].teamExtras
    )
    let awayBox = TeamBoxScore(
        name: final.teams[1].team.name,
        players: final.teams[1].boxPlayers.filter { $0.minutes > 0 || $0.points > 0 || $0.fgAttempts > 0 || $0.ftAttempts > 0 },
        teamExtras: final.teams[1].teamExtras
    )
    let boxScores = [homeBox, awayBox]
    let game = SimulatedGameResult(
        home: SimulatedTeamResult(name: final.teams[0].team.name, score: final.teams[0].score, boxScore: homeBox),
        away: SimulatedTeamResult(name: final.teams[1].team.name, score: final.teams[1].score, boxScore: awayBox),
        winner: final.teams[0].score == final.teams[1].score ? nil : (final.teams[0].score > final.teams[1].score ? final.teams[0].team.name : final.teams[1].team.name),
        wentToOvertime: overtimeNumber > 0,
        playByPlay: final.playByPlay,
        boxScore: boxScores
    )
    return SimulatedGameQAResult(game: game, actions: final.actionTraces)
}

func logistic(_ x: Double) -> Double {
    1 / (1 + Foundation.exp(-x))
}

func average(_ values: [Double]) -> Double {
    guard !values.isEmpty else { return 0 }
    return values.reduce(0, +) / Double(values.count)
}

func parseLengthToInches(_ value: String?, fallback: Double) -> Double {
    guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else { return fallback }

    let cache = LengthParseCache.shared
    cache.lock.lock()
    if let cached = cache.parsedInchesByRaw[trimmed] {
        cache.lock.unlock()
        return cached
    }
    cache.lock.unlock()

    let parsedValue: Double? = {
        if let numeric = Double(trimmed), numeric.isFinite {
            return numeric
        }
        if let (feet, inches) = extractFeetInches(trimmed, regex: cache.hyphenRegex) {
            return Double(feet * 12 + inches)
        }
        if let (feet, inches) = extractFeetInches(trimmed, regex: cache.apostropheRegex) {
            return Double(feet * 12 + inches)
        }
        return nil
    }()

    guard let parsedValue else { return fallback }

    cache.lock.lock()
    cache.parsedInchesByRaw[trimmed] = parsedValue
    cache.lock.unlock()
    return parsedValue
}

func extractFeetInches(_ text: String, regex: NSRegularExpression) -> (Int, Int)? {
    let nsrange = NSRange(text.startIndex..<text.endIndex, in: text)
    guard let match = regex.firstMatch(in: text, options: [], range: nsrange), match.numberOfRanges >= 3 else {
        return nil
    }
    guard
        let feetRange = Range(match.range(at: 1), in: text),
        let inchesRange = Range(match.range(at: 2), in: text),
        let feet = Int(text[feetRange]),
        let inches = Int(text[inchesRange])
    else {
        return nil
    }
    return (feet, inches)
}

func getHeightInches(_ player: Player) -> Double {
    parseLengthToInches(player.size.height, fallback: 78)
}

func getWingspanInches(_ player: Player) -> Double {
    parseLengthToInches(player.size.wingspan, fallback: getHeightInches(player) + 4)
}

func getWeightPounds(_ player: Player) -> Double {
    if let value = Double(player.size.weight), value.isFinite {
        return value
    }
    return 220
}

func getRawRating(_ player: Player, path: String) -> Double? {
    switch path {
    case "athleticism.speed": return Double(player.athleticism.speed)
    case "athleticism.agility": return Double(player.athleticism.agility)
    case "athleticism.burst": return Double(player.athleticism.burst)
    case "athleticism.strength": return Double(player.athleticism.strength)
    case "athleticism.vertical": return Double(player.athleticism.vertical)
    case "athleticism.stamina": return Double(player.athleticism.stamina)
    case "athleticism.durability": return Double(player.athleticism.durability)
    case "shooting.layups": return Double(player.shooting.layups)
    case "shooting.dunks": return Double(player.shooting.dunks)
    case "shooting.closeShot": return Double(player.shooting.closeShot)
    case "shooting.midrangeShot": return Double(player.shooting.midrangeShot)
    case "shooting.threePointShooting": return Double(player.shooting.threePointShooting)
    case "shooting.cornerThrees": return Double(player.shooting.cornerThrees)
    case "shooting.upTopThrees": return Double(player.shooting.upTopThrees)
    case "shooting.drawFoul": return Double(player.shooting.drawFoul)
    case "shooting.freeThrows": return Double(player.shooting.freeThrows)
    case "postGame.postControl": return Double(player.postGame.postControl)
    case "postGame.postFadeaways": return Double(player.postGame.postFadeaways)
    case "postGame.postHooks": return Double(player.postGame.postHooks)
    case "skills.ballHandling": return Double(player.skills.ballHandling)
    case "skills.ballSafety": return Double(player.skills.ballSafety)
    case "skills.passingAccuracy": return Double(player.skills.passingAccuracy)
    case "skills.passingVision": return Double(player.skills.passingVision)
    case "skills.passingIQ": return Double(player.skills.passingIQ)
    case "skills.shotIQ": return Double(player.skills.shotIQ)
    case "skills.offballOffense": return Double(player.skills.offballOffense)
    case "skills.hands": return Double(player.skills.hands)
    case "skills.hustle": return Double(player.skills.hustle)
    case "skills.clutch": return Double(player.skills.clutch)
    case "defense.perimeterDefense": return Double(player.defense.perimeterDefense)
    case "defense.postDefense": return Double(player.defense.postDefense)
    case "defense.shotBlocking": return Double(player.defense.shotBlocking)
    case "defense.shotContest": return Double(player.defense.shotContest)
    case "defense.steals": return Double(player.defense.steals)
    case "defense.lateralQuickness": return Double(player.defense.lateralQuickness)
    case "defense.offballDefense": return Double(player.defense.offballDefense)
    case "defense.passPerception": return Double(player.defense.passPerception)
    case "defense.defensiveControl": return Double(player.defense.defensiveControl)
    case "rebounding.offensiveRebounding": return Double(player.rebounding.offensiveRebounding)
    case "rebounding.defensiveRebound": return Double(player.rebounding.defensiveRebound)
    case "rebounding.boxouts": return Double(player.rebounding.boxouts)
    case "tendencies.post": return Double(player.tendencies.post)
    case "tendencies.inside": return Double(player.tendencies.inside)
    case "tendencies.midrange": return Double(player.tendencies.midrange)
    case "tendencies.threePoint": return Double(player.tendencies.threePoint)
    case "tendencies.drive": return Double(player.tendencies.drive)
    case "tendencies.pickAndRoll": return Double(player.tendencies.pickAndRoll)
    case "tendencies.pickAndPop": return Double(player.tendencies.pickAndPop)
    case "tendencies.shootVsPass": return Double(player.tendencies.shootVsPass)
    default: return nil
    }
}

func getBaseRating(_ player: Player, path: String, fallback: Double = 50) -> Double {
    guard let raw = getRawRating(player, path: path), raw.isFinite else { return fallback }
    if raw <= 1 { return fallback }
    if raw <= 10 { return raw * 10 }
    return raw
}

func applyClutchModifier(_ player: Player, rating: Double) -> Double {
    let homeCourtMultiplier = player.condition.homeCourtMultiplier
    let baseMultiplier = homeCourtMultiplier.isFinite ? homeCourtMultiplier : 1
    if !player.condition.clutchTime {
        return clamp(rating * baseMultiplier, min: 1, max: 100)
    }
    let clutch = getBaseRating(player, path: "skills.clutch", fallback: 50)
    let clutchEdge = clamp((clutch - 50) / 50, min: -1, max: 1)
    let clutchMultiplier = 1 + clutchEdge * clutchRatingImpact
    return clamp(rating * baseMultiplier * clutchMultiplier, min: 1, max: 100)
}

func getRating(_ player: Player, path: String, fallback: Double = 50) -> Double {
    guard let raw = getRawRating(player, path: path), raw.isFinite else { return fallback }

    if raw <= 1 { return fallback }
    if raw <= 10 { return applyClutchModifier(player, rating: raw * 10) }

    let isAthleticStaminaOrDurability = path == "athleticism.stamina" || path == "athleticism.durability"
    if isAthleticStaminaOrDurability {
        return applyClutchModifier(player, rating: raw)
    }

    let energy = player.condition.energy
    if !energy.isFinite {
        return applyClutchModifier(player, rating: raw)
    }

    let fatigue = clamp((100 - energy) / 100, min: 0, max: 0.85)
    let stamina = getBaseRating(player, path: "athleticism.stamina", fallback: 50)
    let staminaRecovery = clamp((stamina - 50) / 50, min: -1, max: 1)
    let impact: Double
    if path.hasPrefix("athleticism.") {
        impact = 0.33
    } else if path.hasPrefix("shooting.") {
        impact = 0.3
    } else if path.hasPrefix("skills.") {
        impact = 0.39
    } else if path.hasPrefix("defense.") {
        impact = 0.24
    } else {
        impact = 0.22
    }
    let creatorPath: Bool
    switch path {
    case "skills.ballHandling", "skills.ballSafety", "skills.passingIQ", "skills.passingVision",
         "tendencies.drive", "tendencies.pickAndRoll", "tendencies.pickAndPop":
        creatorPath = true
    default:
        creatorPath = false
    }
    let creatorPenalty = creatorPath ? clamp(0.11 + fatigue * 0.22 - staminaRecovery * 0.05, min: 0.05, max: 0.3) : 0
    let effectiveImpact = clamp(impact - staminaRecovery * 0.05 + creatorPenalty, min: 0.16, max: 0.72)

    let fatigueAdjusted = applyClutchModifier(player, rating: raw * (1 - fatigue * effectiveImpact))
    let role = player.condition.possessionRole
    let offensiveModifier = player.condition.offensiveCoachingModifier
    let defensiveModifier = player.condition.defensiveCoachingModifier
    var coachingModifier = 1.0
    if role == "offense", offensiveModifier.isFinite {
        coachingModifier = offensiveModifier
    } else if role == "defense", defensiveModifier.isFinite {
        coachingModifier = defensiveModifier
    }
    return clamp(fatigueAdjusted * coachingModifier, min: 1, max: 100)
}

func weightedSkillScore(player: Player, ratingPaths: [String], random: inout SeededRandom) -> WeightedSkill {
    guard !ratingPaths.isEmpty else {
        return WeightedSkill(score: 50)
    }
    var ratings: [Double] = []
    ratings.reserveCapacity(ratingPaths.count)
    var ratingsSum = 0.0
    for path in ratingPaths {
        let value = getRating(player, path: path)
        ratings.append(value)
        ratingsSum += value
    }
    let mean = ratingsSum / Double(ratings.count)

    var weightedSum = 0.0
    var totalWeight = 0.0
    for value in ratings {
        let excellence = clamp((value - mean) / 50, min: -1, max: 1)
        let baseline = 0.55 + random.nextUnit()
        let strengthBias = 1 + max(0, excellence) * 0.35
        let weight = baseline * strengthBias
        totalWeight += weight
        weightedSum += value * weight
    }
    if totalWeight <= 0 {
        return WeightedSkill(score: mean)
    }
    let score = weightedSum / totalWeight
    return WeightedSkill(score: score)
}

func getMobilitySizePenalty(_ player: Player) -> Double {
    let heightPenalty = (getHeightInches(player) - 76) / 12
    let weightPenalty = (getWeightPounds(player) - 205) / 80
    return clamp(heightPenalty * 0.7 + weightPenalty * 0.9, min: -0.45, max: 1.35)
}

func getMobilitySizeEdge(
    offensePlayer: Player,
    defensePlayer: Player,
    offenseUsesMobility: Bool,
    defenseUsesMobility: Bool
) -> Double {
    if !offenseUsesMobility && !defenseUsesMobility {
        return 0
    }
    let offensePenalty = offenseUsesMobility ? getMobilitySizePenalty(offensePlayer) : 0
    let defensePenalty = defenseUsesMobility ? getMobilitySizePenalty(defensePlayer) : 0
    return clamp((defensePenalty - offensePenalty) / 12, min: -0.16, max: 0.16)
}

// MARK: - Shot type selection and resolution

enum ShotType {
    case close
    case midrange
    case three
    case layup
    case dunk
    case hook
    case fadeaway
}

struct ShotProfile {
    var offenseRatings: [String]
    var defenseRatings: [String]
    var basePoints: Int
}

func shotProfile(for shotType: ShotType) -> ShotProfile {
    switch shotType {
    case .close:
        return ShotProfile(
            offenseRatings: ["shooting.closeShot", "shooting.layups", "athleticism.burst"],
            defenseRatings: ["defense.shotContest", "defense.perimeterDefense", "defense.postDefense"],
            basePoints: 2
        )
    case .midrange:
        return ShotProfile(
            offenseRatings: ["shooting.midrangeShot", "skills.shotIQ", "athleticism.agility"],
            defenseRatings: ["defense.shotContest", "defense.perimeterDefense", "defense.lateralQuickness"],
            basePoints: 2
        )
    case .three:
        return ShotProfile(
            offenseRatings: ["shooting.threePointShooting", "skills.shotIQ"],
            defenseRatings: ["defense.shotContest", "defense.perimeterDefense", "defense.offballDefense"],
            basePoints: 3
        )
    case .layup:
        return ShotProfile(
            offenseRatings: ["shooting.layups", "athleticism.burst", "athleticism.vertical"],
            defenseRatings: ["defense.shotContest", "athleticism.vertical", "defense.shotBlocking"],
            basePoints: 2
        )
    case .dunk:
        return ShotProfile(
            offenseRatings: ["shooting.dunks", "athleticism.vertical", "athleticism.strength"],
            defenseRatings: ["defense.shotContest", "athleticism.vertical", "defense.shotBlocking"],
            basePoints: 2
        )
    case .hook:
        return ShotProfile(
            offenseRatings: ["postGame.postHooks", "postGame.postControl", "athleticism.strength"],
            defenseRatings: ["defense.shotContest", "defense.postDefense", "defense.shotBlocking"],
            basePoints: 2
        )
    case .fadeaway:
        return ShotProfile(
            offenseRatings: ["postGame.postFadeaways", "shooting.midrangeShot"],
            defenseRatings: ["defense.shotContest", "defense.postDefense"],
            basePoints: 2
        )
    }
}

func baseMakeProbability(for shotType: ShotType) -> Double {
    switch shotType {
    case .three: return 0.320
    case .midrange: return 0.388
    case .close: return 0.468
    case .layup: return 0.564
    case .dunk: return 0.728
    case .hook: return 0.431
    case .fadeaway: return 0.395
    }
}

func makeScale(for shotType: ShotType) -> Double {
    switch shotType {
    case .three: return 0.09
    case .midrange: return 0.10
    case .close, .hook, .fadeaway: return 0.11
    case .layup, .dunk: return 0.13
    }
}

func shotTypeEdge(for shotType: ShotType) -> Double {
    switch shotType {
    case .layup: return 0.02
    case .dunk: return 0.03
    case .midrange: return -0.03
    case .fadeaway: return -0.02
    case .three: return -0.038
    case .hook: return 0.0
    case .close: return 0.0
    }
}

func minMakeProbability(for shotType: ShotType) -> Double {
    switch shotType {
    case .three: return 0.256
    case .midrange: return 0.35
    case .close: return 0.42
    case .layup: return 0.52
    case .dunk: return 0.675
    case .hook: return 0.385
    case .fadeaway: return 0.34
    }
}

func maxMakeProbability(for shotType: ShotType) -> Double {
    switch shotType {
    case .three: return 0.496
    case .midrange: return 0.58
    case .close: return 0.66
    case .layup: return 0.79
    case .dunk: return 0.905
    case .hook: return 0.62
    case .fadeaway: return 0.57
    }
}

func isRimShot(_ shotType: ShotType) -> Bool {
    switch shotType {
    case .layup, .dunk, .hook, .close: return true
    default: return false
    }
}

func isPointsInPaintScore(shotType: ShotType, spot: OffensiveSpot) -> Bool {
    switch shotType {
    case .layup, .dunk:
        return true
    case .hook, .fadeaway, .close:
        return spot == .middlePaint || spot == .leftPost || spot == .rightPost
    case .midrange, .three:
        return false
    }
}

func isCornerSpot(_ spot: OffensiveSpot) -> Bool {
    spot == .rightCorner || spot == .leftCorner
}

func pickShooterSpot(player: Player, random: inout SeededRandom) -> OffensiveSpot {
    let cornerWeight = getBaseRating(player, path: "shooting.cornerThrees") * 0.9
    let upTopWeight = getBaseRating(player, path: "shooting.upTopThrees")
    let postTend = getBaseRating(player, path: "tendencies.post")
    let insideTend = getBaseRating(player, path: "tendencies.inside")
    let total = cornerWeight + upTopWeight + postTend + insideTend
    guard total > 0 else { return .topMiddle }
    var pick = random.nextUnit() * total
    pick -= cornerWeight
    if pick <= 0 { return random.nextUnit() < 0.5 ? .rightCorner : .leftCorner }
    pick -= upTopWeight
    if pick <= 0 {
        let picks: [OffensiveSpot] = [.topMiddle, .topRight, .topLeft]
        return picks[random.int(0, picks.count - 1)]
    }
    pick -= postTend
    if pick <= 0 { return random.nextUnit() < 0.5 ? .rightPost : .leftPost }
    return .middlePaint
}

func chooseShotFromTendencies(shooter: Player, spot: OffensiveSpot, random: inout SeededRandom) -> ShotType {
    let shotIQ = getBaseRating(shooter, path: "skills.shotIQ")
    let atRim = spot == .middlePaint || spot == .rightPost || spot == .leftPost

    if atRim {
        let hookW = getBaseRating(shooter, path: "postGame.postHooks") * 1.0
        let fadeW = getBaseRating(shooter, path: "postGame.postFadeaways") * 0.8
        let layupW = getBaseRating(shooter, path: "shooting.layups") * 1.1
        let dunkW = getBaseRating(shooter, path: "shooting.dunks") * 0.9
        let total = hookW + fadeW + layupW + dunkW
        var pick = random.nextUnit() * max(total, 1)
        pick -= hookW; if pick <= 0 { return .hook }
        pick -= fadeW; if pick <= 0 { return .fadeaway }
        pick -= layupW; if pick <= 0 { return .layup }
        return .dunk
    }

    let isThreeSpot = spot == .topMiddle || spot == .topRight || spot == .topLeft || spot == .rightCorner || spot == .leftCorner

    if isThreeSpot {
        let threeUtility = getBaseRating(shooter, path: "shooting.threePointShooting") * 1.5
            + getBaseRating(shooter, path: "tendencies.threePoint") * 0.9
        let midUtility = getBaseRating(shooter, path: "shooting.midrangeShot") * 1.1
            + getBaseRating(shooter, path: "tendencies.midrange") * 0.6
        let closeUtility = getBaseRating(shooter, path: "shooting.closeShot") * 0.6
            + getBaseRating(shooter, path: "tendencies.inside") * 0.5
        if shotIQ >= 70 {
            let items: [(ShotType, Double)] = [(.three, threeUtility), (.midrange, midUtility), (.close, closeUtility)]
            let sorted = items.sorted { $0.1 > $1.1 }
            return random.nextUnit() < 0.82 ? sorted[0].0 : sorted[1].0
        }
        let total = threeUtility + midUtility + closeUtility
        var pick = random.nextUnit() * max(total, 1)
        pick -= threeUtility; if pick <= 0 { return .three }
        pick -= midUtility; if pick <= 0 { return .midrange }
        return .close
    }

    let midW = getBaseRating(shooter, path: "shooting.midrangeShot") * 1.2
        + getBaseRating(shooter, path: "tendencies.midrange") * 0.8
    let closeW = getBaseRating(shooter, path: "shooting.closeShot") * 1.2
        + getBaseRating(shooter, path: "tendencies.inside") * 0.7
    let total = midW + closeW
    var pick = random.nextUnit() * max(total, 1)
    pick -= midW; if pick <= 0 { return .midrange }
    return .close
}
