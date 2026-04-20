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
        var activeLineup: [Player]
        var activeLineupBoxIndices: [Int]
        var boxPlayers: [PlayerBoxScore]
        var teamExtras: [String: Int]
    }

    struct StoredState {
        var teams: [TeamTracker]
        var currentHalf: Int
        var gameClockRemaining: Int
        var shotClockRemaining: Int
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
                makeTeamTracker(home),
                makeTeamTracker(away),
            ],
            currentHalf: 1,
            gameClockRemaining: HALF_SECONDS,
            shotClockRemaining: SHOT_CLOCK_SECONDS,
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

    private static func makeTeamTracker(_ team: Team) -> TeamTracker {
        let roster = team.players.isEmpty ? team.lineup : team.players
        let starters = Array((team.lineup.isEmpty ? roster : team.lineup).prefix(5))
        var usedRosterIndexes: Set<Int> = []

        func lookupRosterIndex(for player: Player) -> Int {
            if let idx = roster.enumerated().first(where: { element in
                let sameIdentity = element.element.bio.name == player.bio.name && element.element.bio.position == player.bio.position
                return sameIdentity && !usedRosterIndexes.contains(element.offset)
            })?.offset {
                usedRosterIndexes.insert(idx)
                return idx
            }
            if let fallback = roster.indices.first(where: { !usedRosterIndexes.contains($0) }) {
                usedRosterIndexes.insert(fallback)
                return fallback
            }
            return 0
        }

        let boxPlayers = roster.enumerated().map { idx, player in
            PlayerBoxScore(
                playerName: player.bio.name.isEmpty ? "Player \(idx + 1)" : player.bio.name,
                position: player.bio.position.rawValue,
                minutes: 0,
                points: 0,
                fgMade: 0,
                fgAttempts: 0,
                threeMade: 0,
                threeAttempts: 0,
                ftMade: 0,
                ftAttempts: 0,
                rebounds: 0,
                offensiveRebounds: 0,
                defensiveRebounds: 0,
                assists: 0,
                steals: 0,
                blocks: 0,
                turnovers: 0,
                fouls: 0,
                plusMinus: 0,
                energy: player.condition.energy
            )
        }

        let lineupBoxIndices = starters.map { lookupRosterIndex(for: $0) }
        return TeamTracker(
            team: team,
            score: 0,
            activeLineup: starters,
            activeLineupBoxIndices: lineupBoxIndices,
            boxPlayers: boxPlayers,
            teamExtras: ["turnovers": 0]
        )
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
        if stored.teams[offenseTeamId].activeLineup.isEmpty || stored.teams[defenseTeamId].activeLineup.isEmpty {
            return "period_end"
        }

        syncPossessionRoles(stored: &stored)

        let possessionSeconds = possessionDurationSeconds(for: stored.teams[offenseTeamId].team.pace, random: &random)
        applyChunkMinutesAndEnergy(stored: &stored, possessionSeconds: possessionSeconds)

        let offenseStrength = computeTeamOffenseStrength(stored.teams[offenseTeamId].team)
        let defenseStrength = computeTeamDefenseStrength(stored.teams[defenseTeamId].team)
        let teamEdge = (offenseStrength - defenseStrength) / 22 + (random.nextUnit() * 0.2 - 0.1)

        let ballHandlerIdx = pickLineupIndexForBallHandler(lineup: stored.teams[offenseTeamId].activeLineup, random: &random)
        let defenderIdx = min(ballHandlerIdx, stored.teams[defenseTeamId].activeLineup.count - 1)
        let ballHandler = stored.teams[offenseTeamId].activeLineup[ballHandlerIdx]
        let primaryDefender = stored.teams[defenseTeamId].activeLineup[defenderIdx]

        let shotClockPressure = clamp(
            Double(SHOT_CLOCK_SECONDS - stored.shotClockRemaining) / Double(max(1, SHOT_CLOCK_SECONDS - CHUNK_SECONDS)),
            min: 0,
            max: 1
        )
        let paceBias = paceShotBias(for: stored.teams[offenseTeamId].team.pace)
        let shotIQ = getBaseRating(ballHandler, path: "skills.shotIQ")
        let shooterTendency = getBaseRating(ballHandler, path: "tendencies.shootVsPass")
        let attemptShotChance = clamp(
            0.08
                + Foundation.pow(shotClockPressure, 1.4) * 0.56
                + (shotIQ - 55) / 320
                + (shooterTendency - 55) / 320
                + paceBias,
            min: 0.06,
            max: 0.85
        )
        let forcedShot = stored.shotClockRemaining <= CHUNK_SECONDS
        let willAttemptAction = forcedShot || random.nextUnit() < attemptShotChance

        var eventType: String
        var points = 0
        var switchedPossession = false

        if !willAttemptAction {
            if stored.shotClockRemaining <= possessionSeconds {
                addPlayerStat(stored: &stored, teamId: offenseTeamId, lineupIndex: ballHandlerIdx) { $0.turnovers += 1 }
                addTeamExtra(stored: &stored, teamId: offenseTeamId, key: "turnovers", amount: 1)
                eventType = "turnover_shot_clock"
                switchedPossession = true
            } else {
                eventType = "setup"
            }
        } else {
            let turnoverInteraction = resolveInteraction(
                offensePlayer: ballHandler,
                defensePlayer: primaryDefender,
                offenseRatings: ["skills.ballHandling", "skills.ballSafety", "skills.passingIQ"],
                defenseRatings: ["defense.steals", "defense.passPerception", "skills.hands"],
                random: &random
            )
            let turnoverBase = clamp(0.12 - teamEdge * 0.03, min: 0.06, max: 0.18)
            let turnoverBoost = clamp((0.5 - logistic(turnoverInteraction.edge)) * 0.12, min: -0.04, max: 0.08)
            let isTurnover = random.nextUnit() < clamp(turnoverBase + turnoverBoost, min: 0.04, max: 0.24)

            if isTurnover {
                addPlayerStat(stored: &stored, teamId: offenseTeamId, lineupIndex: ballHandlerIdx) { $0.turnovers += 1 }
                addPlayerStat(stored: &stored, teamId: defenseTeamId, lineupIndex: defenderIdx) { $0.steals += 1 }
                addTeamExtra(stored: &stored, teamId: offenseTeamId, key: "turnovers", amount: 1)
                eventType = "turnover"
                switchedPossession = true
            } else {
                let isThree = random.nextUnit() < 0.34
                let shotRatings = isThree
                    ? ["shooting.threePointShooting", "skills.shotIQ", "athleticism.burst"]
                    : ["shooting.closeShot", "shooting.layups", "skills.shotIQ"]
                let shotDefenseRatings = isThree
                    ? ["defense.shotContest", "defense.perimeterDefense", "defense.lateralQuickness"]
                    : ["defense.shotContest", "defense.postDefense", "defense.lateralQuickness"]
                let shotInteraction = resolveInteraction(
                    offensePlayer: ballHandler,
                    defensePlayer: primaryDefender,
                    offenseRatings: shotRatings,
                    defenseRatings: shotDefenseRatings,
                    random: &random
                )

                let shotMakeBase = isThree ? 0.28 : 0.43
                let shotMakeScale = isThree ? 0.09 : 0.11
                let madeProbability = clamp(
                    shotMakeBase + teamEdge * 0.07 + (logistic(shotInteraction.edge) - 0.5) * shotMakeScale,
                    min: isThree ? 0.2 : 0.34,
                    max: isThree ? 0.52 : 0.7
                )
                let made = random.nextUnit() < madeProbability

                addPlayerStat(stored: &stored, teamId: offenseTeamId, lineupIndex: ballHandlerIdx) { line in
                    line.fgAttempts += 1
                    if made { line.fgMade += 1 }
                    if isThree {
                        line.threeAttempts += 1
                        if made { line.threeMade += 1 }
                    }
                }

                if made {
                    points = isThree ? 3 : 2
                    stored.teams[offenseTeamId].score += points
                    applyPlusMinus(stored: &stored, scoringTeamId: offenseTeamId, points: points)
                    addPlayerStat(stored: &stored, teamId: offenseTeamId, lineupIndex: ballHandlerIdx) { $0.points += points }
                    switchedPossession = true

                    if let assistIdx = pickAssistLineupIndex(lineup: stored.teams[offenseTeamId].activeLineup, shooterIndex: ballHandlerIdx, random: &random) {
                        addPlayerStat(stored: &stored, teamId: offenseTeamId, lineupIndex: assistIdx) { $0.assists += 1 }
                    }

                    let andOneChance = clamp(0.05 + max(0, -shotInteraction.edge) * 0.04, min: 0.02, max: 0.14)
                    if random.nextUnit() < andOneChance {
                        addPlayerStat(stored: &stored, teamId: defenseTeamId, lineupIndex: defenderIdx) { $0.fouls += 1 }
                        let ftMade = random.nextUnit() < clamp(getBaseRating(ballHandler, path: "shooting.freeThrows") / 120, min: 0.45, max: 0.92) ? 1 : 0
                        addPlayerStat(stored: &stored, teamId: offenseTeamId, lineupIndex: ballHandlerIdx) { line in
                            line.ftAttempts += 1
                            line.ftMade += ftMade
                            line.points += ftMade
                        }
                        if ftMade > 0 {
                            points += ftMade
                            stored.teams[offenseTeamId].score += ftMade
                            applyPlusMinus(stored: &stored, scoringTeamId: offenseTeamId, points: ftMade)
                        }
                    }
                    eventType = "made_shot"
                } else {
                    let shootingFoulChance = clamp(0.08 + max(0, -shotInteraction.edge) * 0.08, min: 0.04, max: 0.24)
                    if random.nextUnit() < shootingFoulChance {
                        addPlayerStat(stored: &stored, teamId: defenseTeamId, lineupIndex: defenderIdx) { $0.fouls += 1 }
                        let ftAttempts = isThree ? 3 : 2
                        var ftMade = 0
                        for _ in 0..<ftAttempts {
                            if random.nextUnit() < clamp(getBaseRating(ballHandler, path: "shooting.freeThrows") / 120, min: 0.45, max: 0.92) {
                                ftMade += 1
                            }
                        }
                        addPlayerStat(stored: &stored, teamId: offenseTeamId, lineupIndex: ballHandlerIdx) { line in
                            line.ftAttempts += ftAttempts
                            line.ftMade += ftMade
                            line.points += ftMade
                        }
                        if ftMade > 0 {
                            points = ftMade
                            stored.teams[offenseTeamId].score += ftMade
                            applyPlusMinus(stored: &stored, scoringTeamId: offenseTeamId, points: ftMade)
                        }
                        eventType = "foul"
                        switchedPossession = true
                    } else {
                        let offenseReboundChance = clamp(0.27 + teamEdge * 0.04, min: 0.18, max: 0.37)
                        let offenseRebound = random.nextUnit() < offenseReboundChance
                        if offenseRebound {
                            let reboundIdx = pickRebounderIndex(
                                lineup: stored.teams[offenseTeamId].activeLineup,
                                offensive: true,
                                random: &random
                            )
                            addPlayerStat(stored: &stored, teamId: offenseTeamId, lineupIndex: reboundIdx) { line in
                                line.rebounds += 1
                                line.offensiveRebounds += 1
                            }
                            switchedPossession = false
                        } else {
                            let reboundIdx = pickRebounderIndex(
                                lineup: stored.teams[defenseTeamId].activeLineup,
                                offensive: false,
                                random: &random
                            )
                            addPlayerStat(stored: &stored, teamId: defenseTeamId, lineupIndex: reboundIdx) { line in
                                line.rebounds += 1
                                line.defensiveRebounds += 1
                            }
                            switchedPossession = true
                        }
                        eventType = "missed_shot"
                    }
                }
            }
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
                description: eventDescription(
                    eventType: eventType,
                    offenseTeam: stored.teams[offenseTeamId].team.name,
                    defenseTeam: stored.teams[defenseTeamId].team.name,
                    lineup: stored.teams[offenseTeamId].activeLineup,
                    playerIndex: ballHandlerIdx
                ),
                detail: nil
            )
        )

        stored.gameClockRemaining = max(0, stored.gameClockRemaining - possessionSeconds)
        if switchedPossession {
            stored.possessionTeamId = defenseTeamId
            stored.shotClockRemaining = SHOT_CLOCK_SECONDS
        } else {
            stored.shotClockRemaining = max(0, stored.shotClockRemaining - possessionSeconds)
        }
        return eventType
    }) else {
        fatalError("resolveActionChunk failed: unknown game handle \(state.handle)")
    }

    return chunkType
}

private func possessionDurationSeconds(for pace: PaceProfile, random: inout SeededRandom) -> Int {
    _ = pace
    _ = random
    return CHUNK_SECONDS
}

private func paceShotBias(for pace: PaceProfile) -> Double {
    switch pace {
    case .verySlow: return -0.08
    case .slow: return -0.055
    case .slightlySlow: return -0.03
    case .normal: return 0
    case .slightlyFast: return 0.02
    case .fast: return 0.04
    case .veryFast: return 0.06
    }
}

private func syncPossessionRoles(stored: inout NativeGameStateStore.StoredState) {
    let offenseTeamId = stored.possessionTeamId
    let defenseTeamId = offenseTeamId == 0 ? 1 : 0
    for teamId in stored.teams.indices {
        let role = teamId == offenseTeamId ? "offense" : teamId == defenseTeamId ? "defense" : nil
        for idx in stored.teams[teamId].activeLineup.indices {
            stored.teams[teamId].activeLineup[idx].condition.possessionRole = role
        }
    }
}

private func pickLineupIndexForBallHandler(lineup: [Player], random: inout SeededRandom) -> Int {
    guard !lineup.isEmpty else { return 0 }
    return weightedRandomIndex(
        lineup: lineup,
        random: &random
    ) { player in
        getBaseRating(player, path: "skills.ballHandling") * 0.35
            + getBaseRating(player, path: "skills.shotIQ") * 0.2
            + getBaseRating(player, path: "tendencies.shootVsPass") * 0.2
            + getBaseRating(player, path: "athleticism.burst") * 0.15
            + getBaseRating(player, path: "tendencies.threePoint") * 0.1
    }
}

private func pickAssistLineupIndex(lineup: [Player], shooterIndex: Int, random: inout SeededRandom) -> Int? {
    guard lineup.count > 1, random.nextUnit() < 0.62 else { return nil }
    let choices = lineup.enumerated().filter { $0.offset != shooterIndex }
    let weights = choices.map {
        getBaseRating($0.element, path: "skills.passingVision") * 0.45
            + getBaseRating($0.element, path: "skills.passingAccuracy") * 0.35
            + getBaseRating($0.element, path: "skills.passingIQ") * 0.2
    }
    let pick = weightedChoiceIndex(weights: weights, random: &random)
    return choices[pick].offset
}

private func pickRebounderIndex(lineup: [Player], offensive: Bool, random: inout SeededRandom) -> Int {
    guard !lineup.isEmpty else { return 0 }
    return weightedRandomIndex(lineup: lineup, random: &random) { player in
        let reboundRating = offensive
            ? getBaseRating(player, path: "rebounding.offensiveRebounding")
            : getBaseRating(player, path: "rebounding.defensiveRebound")
        return reboundRating * 0.65 + getBaseRating(player, path: "rebounding.boxouts") * 0.35
    }
}

private func weightedRandomIndex(lineup: [Player], random: inout SeededRandom, weight: (Player) -> Double) -> Int {
    let weights = lineup.map { max(0.1, weight($0)) }
    return weightedChoiceIndex(weights: weights, random: &random)
}

private func weightedChoiceIndex(weights: [Double], random: inout SeededRandom) -> Int {
    guard !weights.isEmpty else { return 0 }
    let total = weights.reduce(0, +)
    guard total > 0 else { return 0 }
    var pick = random.nextUnit() * total
    for (idx, value) in weights.enumerated() {
        pick -= value
        if pick <= 0 {
            return idx
        }
    }
    return weights.count - 1
}

private func applyChunkMinutesAndEnergy(stored: inout NativeGameStateStore.StoredState, possessionSeconds: Int) {
    let minuteDelta = Double(possessionSeconds) / 60
    let energyDelta = Double(possessionSeconds) * 0.025
    for teamId in stored.teams.indices {
        for lineupIndex in stored.teams[teamId].activeLineup.indices {
            addPlayerStat(stored: &stored, teamId: teamId, lineupIndex: lineupIndex) { line in
                line.minutes += minuteDelta
                if let energy = line.energy {
                    line.energy = max(0, energy - energyDelta)
                }
            }
        }
    }
}

private func addTeamExtra(stored: inout NativeGameStateStore.StoredState, teamId: Int, key: String, amount: Int) {
    guard teamId >= 0, teamId < stored.teams.count else { return }
    stored.teams[teamId].teamExtras[key, default: 0] += amount
}

private func applyPlusMinus(stored: inout NativeGameStateStore.StoredState, scoringTeamId: Int, points: Int) {
    guard points != 0 else { return }
    let otherTeamId = scoringTeamId == 0 ? 1 : 0
    for lineupIndex in stored.teams[scoringTeamId].activeLineup.indices {
        addPlayerStat(stored: &stored, teamId: scoringTeamId, lineupIndex: lineupIndex) { line in
            let current = line.plusMinus ?? 0
            line.plusMinus = current + points
        }
    }
    for lineupIndex in stored.teams[otherTeamId].activeLineup.indices {
        addPlayerStat(stored: &stored, teamId: otherTeamId, lineupIndex: lineupIndex) { line in
            let current = line.plusMinus ?? 0
            line.plusMinus = current - points
        }
    }
}

private func addPlayerStat(
    stored: inout NativeGameStateStore.StoredState,
    teamId: Int,
    lineupIndex: Int,
    mutate: (inout PlayerBoxScore) -> Void
) {
    guard teamId >= 0, teamId < stored.teams.count else { return }
    guard lineupIndex >= 0, lineupIndex < stored.teams[teamId].activeLineupBoxIndices.count else { return }
    let boxIndex = stored.teams[teamId].activeLineupBoxIndices[lineupIndex]
    guard boxIndex >= 0, boxIndex < stored.teams[teamId].boxPlayers.count else { return }
    mutate(&stored.teams[teamId].boxPlayers[boxIndex])
}

private func eventDescription(eventType: String, offenseTeam: String, defenseTeam: String, lineup: [Player], playerIndex: Int) -> String? {
    let playerName: String
    if playerIndex >= 0, playerIndex < lineup.count {
        playerName = lineup[playerIndex].bio.name
    } else {
        playerName = "Unknown"
    }
    switch eventType {
    case "made_shot":
        return "\(playerName) scores for \(offenseTeam)"
    case "missed_shot":
        return "\(playerName) misses for \(offenseTeam)"
    case "turnover":
        return "\(playerName) turns it over against \(defenseTeam)"
    case "turnover_shot_clock":
        return "\(offenseTeam) shot clock violation"
    case "foul":
        return "\(playerName) draws free throws"
    case "setup":
        return "\(offenseTeam) runs half-court offense"
    default:
        return nil
    }
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
        stored.shotClockRemaining = SHOT_CLOCK_SECONDS
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
            stored.shotClockRemaining = SHOT_CLOCK_SECONDS
        }
        simulateHalf(state: &state, random: &random)
    }

    guard let final = NativeGameStateStore.snapshot(state.handle) else {
        fatalError("simulateGame failed: missing game state \(state.handle)")
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
