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
    guard let value, !value.isEmpty else { return fallback }

    if let parsed = fastParseLengthToInches(value) {
        return parsed
    }

    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return fallback }

    if trimmed != value, let parsed = fastParseLengthToInches(trimmed) {
        return parsed
    }

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

func fastParseLengthToInches(_ text: String) -> Double? {
    var feet = 0
    var inches = 0
    var separator: Unicode.Scalar?
    var sawFeetDigit = false
    var sawInchesDigit = false

    for scalar in text.unicodeScalars {
        let value = scalar.value
        if value >= 48, value <= 57 {
            let digit = Int(value - 48)
            if separator != nil {
                sawInchesDigit = true
                inches = inches * 10 + digit
            } else {
                sawFeetDigit = true
                feet = feet * 10 + digit
            }
            continue
        }

        if scalar == "-" || scalar == "'" {
            if separator != nil || !sawFeetDigit { return nil }
            separator = scalar
            continue
        }

        if scalar == "\"" {
            guard separator == "'", sawInchesDigit else { return nil }
            continue
        }

        return nil
    }

    if separator != nil {
        guard sawFeetDigit, sawInchesDigit else { return nil }
        return Double(feet * 12 + inches)
    }
    guard sawFeetDigit else { return nil }
    return Double(feet)
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

enum RatingFatigueCategory {
    case athleticism
    case shooting
    case skills
    case defense
    case other
}

struct RatingLookup {
    var raw: Double
    var category: RatingFatigueCategory
    var ignoresFatigue: Bool
    var isCreatorPath: Bool
}

func ratingLookup(_ player: Player, path: String) -> RatingLookup? {
    switch path {
    case "athleticism.speed": return RatingLookup(raw: Double(player.athleticism.speed), category: .athleticism, ignoresFatigue: false, isCreatorPath: false)
    case "athleticism.agility": return RatingLookup(raw: Double(player.athleticism.agility), category: .athleticism, ignoresFatigue: false, isCreatorPath: false)
    case "athleticism.burst": return RatingLookup(raw: Double(player.athleticism.burst), category: .athleticism, ignoresFatigue: false, isCreatorPath: false)
    case "athleticism.strength": return RatingLookup(raw: Double(player.athleticism.strength), category: .athleticism, ignoresFatigue: false, isCreatorPath: false)
    case "athleticism.vertical": return RatingLookup(raw: Double(player.athleticism.vertical), category: .athleticism, ignoresFatigue: false, isCreatorPath: false)
    case "athleticism.stamina": return RatingLookup(raw: Double(player.athleticism.stamina), category: .athleticism, ignoresFatigue: true, isCreatorPath: false)
    case "athleticism.durability": return RatingLookup(raw: Double(player.athleticism.durability), category: .athleticism, ignoresFatigue: true, isCreatorPath: false)
    case "shooting.layups": return RatingLookup(raw: Double(player.shooting.layups), category: .shooting, ignoresFatigue: false, isCreatorPath: false)
    case "shooting.dunks": return RatingLookup(raw: Double(player.shooting.dunks), category: .shooting, ignoresFatigue: false, isCreatorPath: false)
    case "shooting.closeShot": return RatingLookup(raw: Double(player.shooting.closeShot), category: .shooting, ignoresFatigue: false, isCreatorPath: false)
    case "shooting.midrangeShot": return RatingLookup(raw: Double(player.shooting.midrangeShot), category: .shooting, ignoresFatigue: false, isCreatorPath: false)
    case "shooting.threePointShooting": return RatingLookup(raw: Double(player.shooting.threePointShooting), category: .shooting, ignoresFatigue: false, isCreatorPath: false)
    case "shooting.cornerThrees": return RatingLookup(raw: Double(player.shooting.cornerThrees), category: .shooting, ignoresFatigue: false, isCreatorPath: false)
    case "shooting.upTopThrees": return RatingLookup(raw: Double(player.shooting.upTopThrees), category: .shooting, ignoresFatigue: false, isCreatorPath: false)
    case "shooting.drawFoul": return RatingLookup(raw: Double(player.shooting.drawFoul), category: .shooting, ignoresFatigue: false, isCreatorPath: false)
    case "shooting.freeThrows": return RatingLookup(raw: Double(player.shooting.freeThrows), category: .shooting, ignoresFatigue: false, isCreatorPath: false)
    case "postGame.postControl": return RatingLookup(raw: Double(player.postGame.postControl), category: .other, ignoresFatigue: false, isCreatorPath: false)
    case "postGame.postFadeaways": return RatingLookup(raw: Double(player.postGame.postFadeaways), category: .other, ignoresFatigue: false, isCreatorPath: false)
    case "postGame.postHooks": return RatingLookup(raw: Double(player.postGame.postHooks), category: .other, ignoresFatigue: false, isCreatorPath: false)
    case "skills.ballHandling": return RatingLookup(raw: Double(player.skills.ballHandling), category: .skills, ignoresFatigue: false, isCreatorPath: true)
    case "skills.ballSafety": return RatingLookup(raw: Double(player.skills.ballSafety), category: .skills, ignoresFatigue: false, isCreatorPath: true)
    case "skills.passingAccuracy": return RatingLookup(raw: Double(player.skills.passingAccuracy), category: .skills, ignoresFatigue: false, isCreatorPath: false)
    case "skills.passingVision": return RatingLookup(raw: Double(player.skills.passingVision), category: .skills, ignoresFatigue: false, isCreatorPath: true)
    case "skills.passingIQ": return RatingLookup(raw: Double(player.skills.passingIQ), category: .skills, ignoresFatigue: false, isCreatorPath: true)
    case "skills.shotIQ": return RatingLookup(raw: Double(player.skills.shotIQ), category: .skills, ignoresFatigue: false, isCreatorPath: false)
    case "skills.offballOffense": return RatingLookup(raw: Double(player.skills.offballOffense), category: .skills, ignoresFatigue: false, isCreatorPath: false)
    case "skills.hands": return RatingLookup(raw: Double(player.skills.hands), category: .skills, ignoresFatigue: false, isCreatorPath: false)
    case "skills.hustle": return RatingLookup(raw: Double(player.skills.hustle), category: .skills, ignoresFatigue: false, isCreatorPath: false)
    case "skills.clutch": return RatingLookup(raw: Double(player.skills.clutch), category: .skills, ignoresFatigue: false, isCreatorPath: false)
    case "defense.perimeterDefense": return RatingLookup(raw: Double(player.defense.perimeterDefense), category: .defense, ignoresFatigue: false, isCreatorPath: false)
    case "defense.postDefense": return RatingLookup(raw: Double(player.defense.postDefense), category: .defense, ignoresFatigue: false, isCreatorPath: false)
    case "defense.shotBlocking": return RatingLookup(raw: Double(player.defense.shotBlocking), category: .defense, ignoresFatigue: false, isCreatorPath: false)
    case "defense.shotContest": return RatingLookup(raw: Double(player.defense.shotContest), category: .defense, ignoresFatigue: false, isCreatorPath: false)
    case "defense.steals": return RatingLookup(raw: Double(player.defense.steals), category: .defense, ignoresFatigue: false, isCreatorPath: false)
    case "defense.lateralQuickness": return RatingLookup(raw: Double(player.defense.lateralQuickness), category: .defense, ignoresFatigue: false, isCreatorPath: false)
    case "defense.offballDefense": return RatingLookup(raw: Double(player.defense.offballDefense), category: .defense, ignoresFatigue: false, isCreatorPath: false)
    case "defense.passPerception": return RatingLookup(raw: Double(player.defense.passPerception), category: .defense, ignoresFatigue: false, isCreatorPath: false)
    case "defense.defensiveControl": return RatingLookup(raw: Double(player.defense.defensiveControl), category: .defense, ignoresFatigue: false, isCreatorPath: false)
    case "rebounding.offensiveRebounding": return RatingLookup(raw: Double(player.rebounding.offensiveRebounding), category: .other, ignoresFatigue: false, isCreatorPath: false)
    case "rebounding.defensiveRebound": return RatingLookup(raw: Double(player.rebounding.defensiveRebound), category: .other, ignoresFatigue: false, isCreatorPath: false)
    case "rebounding.boxouts": return RatingLookup(raw: Double(player.rebounding.boxouts), category: .other, ignoresFatigue: false, isCreatorPath: false)
    case "tendencies.post": return RatingLookup(raw: Double(player.tendencies.post), category: .other, ignoresFatigue: false, isCreatorPath: false)
    case "tendencies.inside": return RatingLookup(raw: Double(player.tendencies.inside), category: .other, ignoresFatigue: false, isCreatorPath: false)
    case "tendencies.midrange": return RatingLookup(raw: Double(player.tendencies.midrange), category: .other, ignoresFatigue: false, isCreatorPath: false)
    case "tendencies.threePoint": return RatingLookup(raw: Double(player.tendencies.threePoint), category: .other, ignoresFatigue: false, isCreatorPath: false)
    case "tendencies.drive": return RatingLookup(raw: Double(player.tendencies.drive), category: .other, ignoresFatigue: false, isCreatorPath: true)
    case "tendencies.pickAndRoll": return RatingLookup(raw: Double(player.tendencies.pickAndRoll), category: .other, ignoresFatigue: false, isCreatorPath: true)
    case "tendencies.pickAndPop": return RatingLookup(raw: Double(player.tendencies.pickAndPop), category: .other, ignoresFatigue: false, isCreatorPath: true)
    case "tendencies.shootVsPass": return RatingLookup(raw: Double(player.tendencies.shootVsPass), category: .other, ignoresFatigue: false, isCreatorPath: false)
    default: return nil
    }
}

func normalizedBaseRating(_ raw: Double, fallback: Double) -> Double {
    guard raw.isFinite else { return fallback }
    if raw <= 1 { return fallback }
    if raw <= 10 { return raw * 10 }
    return raw
}

func getRawRating(_ player: Player, path: String) -> Double? {
    ratingLookup(player, path: path)?.raw
}

func getBaseRating(_ player: Player, path: String, fallback: Double = 50) -> Double {
    guard let lookup = ratingLookup(player, path: path) else { return fallback }
    return normalizedBaseRating(lookup.raw, fallback: fallback)
}

func applyClutchModifier(_ player: Player, rating: Double) -> Double {
    let homeCourtMultiplier = player.condition.homeCourtMultiplier
    let baseMultiplier = homeCourtMultiplier.isFinite ? homeCourtMultiplier : 1
    if !player.condition.clutchTime {
        return clamp(rating * baseMultiplier, min: 1, max: 100)
    }
    let clutch = normalizedBaseRating(Double(player.skills.clutch), fallback: 50)
    let clutchEdge = clamp((clutch - 50) / 50, min: -1, max: 1)
    let clutchMultiplier = 1 + clutchEdge * clutchRatingImpact
    return clamp(rating * baseMultiplier * clutchMultiplier, min: 1, max: 100)
}

func getRating(_ player: Player, path: String, fallback: Double = 50) -> Double {
    guard let lookup = ratingLookup(player, path: path), lookup.raw.isFinite else { return fallback }

    if lookup.raw <= 1 { return fallback }
    if lookup.raw <= 10 { return applyClutchModifier(player, rating: lookup.raw * 10) }

    if lookup.ignoresFatigue {
        return applyClutchModifier(player, rating: lookup.raw)
    }

    let energy = player.condition.energy
    if !energy.isFinite {
        return applyClutchModifier(player, rating: lookup.raw)
    }

    let fatigue = clamp((100 - energy) / 100, min: 0, max: 0.85)
    let stamina = normalizedBaseRating(Double(player.athleticism.stamina), fallback: 50)
    let staminaRecovery = clamp((stamina - 50) / 50, min: -1, max: 1)
    let impact: Double
    switch lookup.category {
    case .athleticism:
        impact = 0.33
    case .shooting:
        impact = 0.3
    case .skills:
        impact = 0.39
    case .defense:
        impact = 0.24
    case .other:
        impact = 0.22
    }
    let creatorPenalty = lookup.isCreatorPath ? clamp(0.11 + fatigue * 0.22 - staminaRecovery * 0.05, min: 0.05, max: 0.3) : 0
    let effectiveImpact = clamp(impact - staminaRecovery * 0.05 + creatorPenalty, min: 0.16, max: 0.72)

    let fatigueAdjusted = applyClutchModifier(player, rating: lookup.raw * (1 - fatigue * effectiveImpact))
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

    return withUnsafeTemporaryAllocation(of: Double.self, capacity: ratingPaths.count) { ratings in
        var ratingsSum = 0.0
        for index in ratingPaths.indices {
            let value = getRating(player, path: ratingPaths[index])
            ratings[index] = value
            ratingsSum += value
        }
        let mean = ratingsSum / Double(ratingPaths.count)

        var weightedSum = 0.0
        var totalWeight = 0.0
        for index in ratingPaths.indices {
            let value = ratings[index]
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
    case .three: return 0.250
    case .midrange: return 0.378
    case .close: return 0.456
    case .layup: return 0.548
    case .dunk: return 0.712
    case .hook: return 0.420
    case .fadeaway: return 0.382
    }
}

func makeScale(for shotType: ShotType) -> Double {
    switch shotType {
    case .three: return 0.18
    case .midrange: return 0.14
    case .close: return 0.14
    case .layup: return 0.16
    case .dunk: return 0.14
    case .hook: return 0.13
    case .fadeaway: return 0.13
    }
}

// Direct shooter-rating bonus on top of the matchup logistic. Keep this modest:
// the shot interaction already contains the shooter's rating, so this term is a
// nudge for talent, not a second full make-probability curve.
func primaryShotRatingPath(for shotType: ShotType) -> String {
    switch shotType {
    case .three: return "shooting.threePointShooting"
    case .midrange: return "shooting.midrangeShot"
    case .close: return "shooting.closeShot"
    case .layup: return "shooting.layups"
    case .dunk: return "shooting.dunks"
    case .hook: return "postGame.postHooks"
    case .fadeaway: return "postGame.postFadeaways"
    }
}

/// Quadratic premium that ramps from 0 at `threshold` to `maxBoost` at 99.
/// The shared matchup logistic flattens at the top of the rating scale, so
/// elite ratings (90+) feel the same as merely-good ones (80) without an
/// extra non-linear bump like this. Use this to differentiate elite tiers
/// in any probability-based interaction (shots, blocks, steals, FTs, etc.).
func eliteRatingPremium(_ rating: Double, threshold: Double = 78, maxBoost: Double) -> Double {
    guard rating > threshold else { return 0 }
    let span = max(1, 99 - threshold)
    let normalized = min(1, (rating - threshold) / span)
    return normalized * normalized * maxBoost
}

func shooterTalentBonus(for shotType: ShotType, shooter: Player) -> Double {
    let rating = getRating(shooter, path: primaryShotRatingPath(for: shotType))
    let linear = clamp((rating - 65) / 340, min: -0.12, max: 0.095)
    let eliteCap: Double
    let maxBonus: Double
    switch shotType {
    case .three:
        eliteCap = 0.012
        maxBonus = 0.105
    case .midrange, .fadeaway:
        eliteCap = 0.014
        maxBonus = 0.110
    case .close, .layup, .hook:
        eliteCap = 0.018
        maxBonus = 0.118
    case .dunk:
        eliteCap = 0.020
        maxBonus = 0.125
    }
    let elite = eliteRatingPremium(rating, threshold: 84, maxBoost: eliteCap)
    return clamp(linear + elite, min: -0.14, max: maxBonus)
}

func shotTypeEdge(for shotType: ShotType) -> Double {
    switch shotType {
    case .layup: return 0.02
    case .dunk: return 0.03
    case .midrange: return -0.03
    case .fadeaway: return -0.02
    case .three: return 0.0
    case .hook: return 0.0
    case .close: return 0.0
    }
}

func minMakeProbability(for shotType: ShotType) -> Double {
    switch shotType {
    case .three: return 0.21
    case .midrange: return 0.30
    case .close: return 0.38
    case .layup: return 0.48
    case .dunk: return 0.62
    case .hook: return 0.34
    case .fadeaway: return 0.30
    }
}

func maxMakeProbability(for shotType: ShotType) -> Double {
    switch shotType {
    case .three: return 0.47
    case .midrange: return 0.54
    case .close: return 0.63
    case .layup: return 0.76
    case .dunk: return 0.88
    case .hook: return 0.59
    case .fadeaway: return 0.535
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
