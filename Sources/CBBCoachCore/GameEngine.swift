import Foundation

public struct InteractionResult: Codable, Equatable, Sendable {
    public var offenseScore: Double
    public var defenseScore: Double
    public var edge: Double
    public var offenseWon: Bool

    public init(offenseScore: Double, defenseScore: Double, edge: Double, offenseWon: Bool) {
        self.offenseScore = offenseScore
        self.defenseScore = defenseScore
        self.edge = edge
        self.offenseWon = offenseWon
    }
}

public struct PlayByPlayEvent: Codable, Equatable, Sendable {
    public var half: Int?
    public var elapsedSecondsInHalf: Int?
    public var elapsedGameSeconds: Int?
    public var clockRemaining: Int?
    public var type: String
    public var teamIndex: Int?
    public var offenseTeam: String?
    public var defenseTeam: String?
    public var points: Int?
    public var description: String?
    public var detail: String?
}

public struct PlayerBoxScore: Codable, Equatable, Sendable {
    public var playerName: String
    public var position: String
    public var minutes: Double
    public var points: Int
    public var fgMade: Int
    public var fgAttempts: Int
    public var threeMade: Int
    public var threeAttempts: Int
    public var ftMade: Int
    public var ftAttempts: Int
    public var rebounds: Int
    public var offensiveRebounds: Int
    public var defensiveRebounds: Int
    public var assists: Int
    public var steals: Int
    public var blocks: Int
    public var turnovers: Int
    public var fouls: Int
    public var plusMinus: Int?
    public var energy: Double?
}

public struct TeamBoxScore: Codable, Equatable, Sendable {
    public var name: String
    public var players: [PlayerBoxScore]
    public var teamExtras: [String: Int]?
}

public struct SimulatedTeamResult: Codable, Equatable, Sendable {
    public var name: String
    public var score: Int
    public var boxScore: TeamBoxScore?
}

public struct SimulatedGameResult: Codable, Equatable, Sendable {
    public var home: SimulatedTeamResult
    public var away: SimulatedTeamResult
    public var winner: String?
    public var playByPlay: [PlayByPlayEvent]
    public var boxScore: [TeamBoxScore]?
}

public struct GameState: Codable, Equatable, Sendable {
    public var handle: String

    public init(handle: String) {
        self.handle = handle
    }
}

private let mobilityInteractionRatings: Set<String> = [
    "athleticism.burst",
    "athleticism.speed",
    "athleticism.agility",
    "defense.lateralQuickness",
]

private let clutchRatingImpact = 0.08

private struct NativeGameStateStore {
    struct TeamTracker {
        var team: Team
        var score: Int
    }

    struct StoredState {
        var teams: [TeamTracker]
        var currentHalf: Int
        var gameClockRemaining: Int
        var possessionTeamId: Int
        var playByPlay: [PlayByPlayEvent]
    }

    private static let lock = NSLock()
    private static nonisolated(unsafe) var nextId = 1
    private static nonisolated(unsafe) var states: [String: StoredState] = [:]

    static func create(home: Team, away: Team, random: inout SeededRandom) -> String {
        lock.lock()
        defer { lock.unlock() }
        let handle = "swift_g_\(nextId)"
        nextId += 1

        let initialPossession = random.nextUnit() < 0.5 ? 0 : 1
        states[handle] = StoredState(
            teams: [
                TeamTracker(team: home, score: 0),
                TeamTracker(team: away, score: 0),
            ],
            currentHalf: 1,
            gameClockRemaining: HALF_SECONDS,
            possessionTeamId: initialPossession,
            playByPlay: []
        )
        return handle
    }

    static func withState<T>(_ handle: String, _ body: (inout StoredState) -> T) -> T? {
        lock.lock()
        defer { lock.unlock() }
        guard var state = states[handle] else { return nil }
        let result = body(&state)
        states[handle] = state
        return result
    }

    static func snapshot(_ handle: String) -> StoredState? {
        lock.lock()
        defer { lock.unlock() }
        return states[handle]
    }
}

private struct WeightedSkill: Sendable {
    var score: Double
}

public func createInitialGameState(homeTeam: Team, awayTeam: Team, random: inout SeededRandom) -> GameState {
    let handle = NativeGameStateStore.create(home: homeTeam, away: awayTeam, random: &random)
    return GameState(handle: handle)
}

public func resolveInteraction(
    offensePlayer: Player,
    defensePlayer: Player,
    offenseRatings: [String],
    defenseRatings: [String],
    random: inout SeededRandom
) -> InteractionResult {
    let offense = weightedSkillScore(player: offensePlayer, ratingPaths: offenseRatings, random: &random)
    let defense = weightedSkillScore(player: defensePlayer, ratingPaths: defenseRatings, random: &random)
    let offenseUsesMobility = offenseRatings.contains { mobilityInteractionRatings.contains($0) }
    let defenseUsesMobility = defenseRatings.contains { mobilityInteractionRatings.contains($0) }
    let mobilitySizeEdge = getMobilitySizeEdge(
        offensePlayer: offensePlayer,
        defensePlayer: defensePlayer,
        offenseUsesMobility: offenseUsesMobility,
        defenseUsesMobility: defenseUsesMobility
    )
    let edge = (offense.score - defense.score) / 14 + mobilitySizeEdge
    let successProbability = clamp(logistic(edge), min: 0.03, max: 0.97)
    let offenseWon = random.nextUnit() < successProbability

    return InteractionResult(
        offenseScore: offense.score,
        defenseScore: defense.score,
        edge: edge,
        offenseWon: offenseWon
    )
}

@discardableResult
public func resolveActionChunk(state: inout GameState, random: inout SeededRandom) -> String {
    guard let chunkType = NativeGameStateStore.withState(state.handle, { stored in
        if stored.gameClockRemaining <= 0 {
            return "period_end"
        }

        let offenseTeamId = stored.possessionTeamId
        let defenseTeamId = offenseTeamId == 0 ? 1 : 0

        let offenseStrength = computeTeamOffenseStrength(stored.teams[offenseTeamId].team)
        let defenseStrength = computeTeamDefenseStrength(stored.teams[defenseTeamId].team)
        let edge = (offenseStrength - defenseStrength) / 22 + (random.nextUnit() * 0.2 - 0.1)
        let madeProbability = clamp(0.44 + edge * 0.18, min: 0.18, max: 0.78)
        let isThree = random.nextUnit() < 0.34
        let didScore = random.nextUnit() < madeProbability
        let points = didScore ? (isThree ? 3 : 2) : 0
        if points > 0 {
            stored.teams[offenseTeamId].score += points
        }

        let eventType: String
        if points > 0 {
            eventType = "made_shot"
        } else if random.nextUnit() < 0.11 {
            eventType = "turnover"
        } else {
            eventType = "missed_shot"
        }

        let periodLength = stored.currentHalf <= 2 ? HALF_SECONDS : OVERTIME_SECONDS
        let elapsedInPeriod = periodLength - stored.gameClockRemaining
        let elapsedGameSeconds: Int
        if stored.currentHalf <= 2 {
            elapsedGameSeconds = (stored.currentHalf - 1) * HALF_SECONDS + elapsedInPeriod
        } else {
            elapsedGameSeconds = 2 * HALF_SECONDS + (stored.currentHalf - 3) * OVERTIME_SECONDS + elapsedInPeriod
        }

        stored.playByPlay.append(
            PlayByPlayEvent(
                half: stored.currentHalf,
                elapsedSecondsInHalf: elapsedInPeriod,
                elapsedGameSeconds: elapsedGameSeconds,
                clockRemaining: stored.gameClockRemaining,
                type: eventType,
                teamIndex: offenseTeamId,
                offenseTeam: stored.teams[offenseTeamId].team.name,
                defenseTeam: stored.teams[defenseTeamId].team.name,
                points: points,
                description: nil,
                detail: nil
            )
        )

        stored.gameClockRemaining = max(0, stored.gameClockRemaining - CHUNK_SECONDS)
        stored.possessionTeamId = defenseTeamId
        return eventType
    }) else {
        fatalError("resolveActionChunk failed: unknown game handle \(state.handle)")
    }

    return chunkType
}

public func simulateHalf(state: inout GameState, random: inout SeededRandom) {
    guard NativeGameStateStore.snapshot(state.handle) != nil else {
        fatalError("simulateHalf failed: unknown game handle \(state.handle)")
    }
    while true {
        guard let snapshot = NativeGameStateStore.snapshot(state.handle) else {
            fatalError("simulateHalf failed: missing game state \(state.handle)")
        }
        if snapshot.gameClockRemaining <= 0 {
            break
        }
        _ = resolveActionChunk(state: &state, random: &random)
    }
}

public func simulateGame(homeTeam: Team, awayTeam: Team, random: inout SeededRandom) -> SimulatedGameResult {
    var state = createInitialGameState(homeTeam: homeTeam, awayTeam: awayTeam, random: &random)
    simulateHalf(state: &state, random: &random)

    _ = NativeGameStateStore.withState(state.handle) { stored in
        stored.currentHalf = 2
        stored.gameClockRemaining = HALF_SECONDS
    }
    simulateHalf(state: &state, random: &random)

    var overtimeNumber = 0
    while true {
        guard let snapshot = NativeGameStateStore.snapshot(state.handle) else {
            fatalError("simulateGame failed: missing game state \(state.handle)")
        }
        if snapshot.teams[0].score != snapshot.teams[1].score {
            break
        }
        overtimeNumber += 1
        _ = NativeGameStateStore.withState(state.handle) { stored in
            stored.currentHalf = 2 + overtimeNumber
            stored.gameClockRemaining = OVERTIME_SECONDS
        }
        simulateHalf(state: &state, random: &random)
    }

    guard let final = NativeGameStateStore.snapshot(state.handle) else {
        fatalError("simulateGame failed: missing game state \(state.handle)")
    }

    let homeBox = makeSimpleTeamBoxScore(final.teams[0].team, score: final.teams[0].score, didWin: final.teams[0].score > final.teams[1].score)
    let awayBox = makeSimpleTeamBoxScore(final.teams[1].team, score: final.teams[1].score, didWin: final.teams[1].score > final.teams[0].score)
    let boxScores = [homeBox, awayBox]

    return SimulatedGameResult(
        home: SimulatedTeamResult(name: final.teams[0].team.name, score: final.teams[0].score, boxScore: homeBox),
        away: SimulatedTeamResult(name: final.teams[1].team.name, score: final.teams[1].score, boxScore: awayBox),
        winner: final.teams[0].score == final.teams[1].score ? nil : (final.teams[0].score > final.teams[1].score ? final.teams[0].team.name : final.teams[1].team.name),
        playByPlay: final.playByPlay,
        boxScore: boxScores
    )
}

private func logistic(_ x: Double) -> Double {
    1 / (1 + Foundation.exp(-x))
}

private func average(_ values: [Double]) -> Double {
    guard !values.isEmpty else { return 0 }
    return values.reduce(0, +) / Double(values.count)
}

private func parseLengthToInches(_ value: String?, fallback: Double) -> Double {
    guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
        return fallback
    }

    if let numeric = Double(trimmed), numeric.isFinite {
        return numeric
    }

    if let (feet, inches) = extractFeetInches(trimmed, pattern: #"^\s*(\d+)\s*-\s*(\d+)\s*$"#) {
        return Double(feet * 12 + inches)
    }

    if let (feet, inches) = extractFeetInches(trimmed, pattern: #"^\s*(\d+)\s*'\s*(\d+)"#) {
        return Double(feet * 12 + inches)
    }

    return fallback
}

private func extractFeetInches(_ text: String, pattern: String) -> (Int, Int)? {
    guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
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

private func getHeightInches(_ player: Player) -> Double {
    parseLengthToInches(player.size.height, fallback: 78)
}

private func getWeightPounds(_ player: Player) -> Double {
    if let value = Double(player.size.weight), value.isFinite {
        return value
    }
    return 220
}

private func getRawRating(_ player: Player, path: String) -> Double? {
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

private func getBaseRating(_ player: Player, path: String, fallback: Double = 50) -> Double {
    guard let raw = getRawRating(player, path: path), raw.isFinite else { return fallback }
    if raw <= 1 { return fallback }
    if raw <= 10 { return raw * 10 }
    return raw
}

private func applyClutchModifier(_ player: Player, rating: Double) -> Double {
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

private func getRating(_ player: Player, path: String, fallback: Double = 50) -> Double {
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
    let group = String(path.split(separator: ".").first ?? "")
    let impact: Double
    switch group {
    case "athleticism": impact = 0.3
    case "shooting": impact = 0.18
    case "skills": impact = 0.24
    case "defense": impact = 0.22
    case "rebounding", "postGame": impact = 0.2
    default: impact = 0.2
    }

    let fatigueAdjusted = applyClutchModifier(player, rating: raw * (1 - fatigue * impact))
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

private func weightedSkillScore(player: Player, ratingPaths: [String], random: inout SeededRandom) -> WeightedSkill {
    let ratings = ratingPaths.map { getRating(player, path: $0) }
    let mean = average(ratings)
    let weighted = ratings.map { value -> (value: Double, weight: Double) in
        let excellence = clamp((value - mean) / 50, min: -1, max: 1)
        let baseline = 0.55 + random.nextUnit()
        let strengthBias = 1 + max(0, excellence) * 0.35
        return (value: value, weight: baseline * strengthBias)
    }
    let totalWeight = weighted.reduce(0) { $0 + $1.weight }
    if totalWeight <= 0 {
        return WeightedSkill(score: average(ratings))
    }
    let score = weighted.reduce(0) { $0 + $1.value * $1.weight } / totalWeight
    return WeightedSkill(score: score)
}

private func getMobilitySizePenalty(_ player: Player) -> Double {
    let heightPenalty = (getHeightInches(player) - 76) / 12
    let weightPenalty = (getWeightPounds(player) - 205) / 80
    return clamp(heightPenalty * 0.7 + weightPenalty * 0.9, min: -0.45, max: 1.35)
}

private func getMobilitySizeEdge(
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

private func computeTeamOffenseStrength(_ team: Team) -> Double {
    let lineup = Array(team.lineup.prefix(5))
    guard !lineup.isEmpty else { return 50 }
    let values = lineup.map { player in
        average([
            getBaseRating(player, path: "skills.shotIQ"),
            getBaseRating(player, path: "shooting.threePointShooting"),
            getBaseRating(player, path: "shooting.midrangeShot"),
            getBaseRating(player, path: "shooting.closeShot"),
            getBaseRating(player, path: "skills.ballHandling"),
        ])
    }
    return average(values)
}

private func computeTeamDefenseStrength(_ team: Team) -> Double {
    let lineup = Array(team.lineup.prefix(5))
    guard !lineup.isEmpty else { return 50 }
    let values = lineup.map { player in
        average([
            getBaseRating(player, path: "defense.perimeterDefense"),
            getBaseRating(player, path: "defense.postDefense"),
            getBaseRating(player, path: "defense.shotContest"),
            getBaseRating(player, path: "defense.lateralQuickness"),
            getBaseRating(player, path: "skills.hustle"),
        ])
    }
    return average(values)
}

private func makeSimpleTeamBoxScore(_ team: Team, score: Int, didWin: Bool) -> TeamBoxScore {
    let lineup = Array(team.lineup.prefix(5))
    let players = lineup.enumerated().map { idx, player in
        let minuteBase = 20 + (idx < 2 ? 8 : 4)
        let points = max(0, Int(Double(score) * (idx == 0 ? 0.27 : idx == 1 ? 0.23 : 0.17)))
        let fga = max(1, points / 2 + 4)
        let fgm = max(0, min(fga, points / 2))
        return PlayerBoxScore(
            playerName: player.bio.name.isEmpty ? "Player \(idx + 1)" : player.bio.name,
            position: player.bio.position.rawValue,
            minutes: Double(minuteBase),
            points: points,
            fgMade: fgm,
            fgAttempts: fga,
            threeMade: min(4, max(0, points / 5)),
            threeAttempts: min(9, max(1, points / 3)),
            ftMade: max(0, points / 6),
            ftAttempts: max(0, points / 5),
            rebounds: max(1, 2 + (idx < 3 ? 2 : 1)),
            offensiveRebounds: max(0, 1 + (idx == 3 ? 1 : 0)),
            defensiveRebounds: max(1, 2 + (idx == 4 ? 2 : 0)),
            assists: max(0, idx < 2 ? 4 - idx : 2),
            steals: max(0, idx == 0 ? 2 : 1),
            blocks: max(0, idx >= 3 ? 1 : 0),
            turnovers: max(0, idx < 2 ? 2 : 1),
            fouls: max(0, idx < 4 ? 2 : 3),
            plusMinus: didWin ? 4 : -4,
            energy: player.condition.energy
        )
    }
    return TeamBoxScore(name: team.name, players: players, teamExtras: ["turnovers": max(6, score / 10)])
}
