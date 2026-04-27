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
    public var wentToOvertime: Bool
    public var playByPlay: [PlayByPlayEvent]
    public var boxScore: [TeamBoxScore]?
}

public struct QAInteractionTrace: Codable, Equatable, Sendable {
    public var label: String
    public var offensePlayer: String
    public var defensePlayer: String
    public var offenseRatings: [String]
    public var defenseRatings: [String]
    public var offenseRatingValues: [String: Double]
    public var defenseRatingValues: [String: Double]
    public var offenseScore: Double
    public var defenseScore: Double
    public var edge: Double
    public var successProbability: Double
    public var offenseWon: Bool
}

public struct QAStatRecord: Codable, Equatable, Sendable {
    public var entityType: String
    public var teamIndex: Int
    public var teamName: String
    public var playerName: String?
    public var stat: String
    public var before: Double
    public var after: Double
    public var delta: Double
}

public struct QAActionTrace: Codable, Equatable, Sendable {
    public var actionNumber: Int
    public var half: Int
    public var gameClockRemaining: Int
    public var shotClockRemaining: Int
    public var offenseTeam: String
    public var defenseTeam: String
    public var eventType: String
    public var points: Int
    public var playByPlayDescription: String?
    public var interactions: [QAInteractionTrace]
    public var statRecords: [QAStatRecord]
}

public struct SimulatedGameQAResult: Codable, Equatable, Sendable {
    public var game: SimulatedGameResult
    public var actions: [QAActionTrace]
}

public struct GameState: Codable, Equatable, Sendable {
    public var handle: String

    public init(handle: String) {
        self.handle = handle
    }
}

let mobilityInteractionRatings: Set<String> = [
    "athleticism.burst",
    "athleticism.speed",
    "athleticism.agility",
    "defense.lateralQuickness",
]

let clutchRatingImpact = 0.08

let interactionVarianceJitter = 0.17

let ballHandlerShareTarget = 0.96

let ballHandlerWarmupActions = 8

enum BlowoutRotationMode {
    case none
    case bench
    case deepBench
}

struct NativeGameStateStore {
    struct TeamTracker {
        var team: Team
        var score: Int
        var activeLineup: [Player]
        var activeLineupBoxIndices: [Int]
        var boxPlayers: [PlayerBoxScore]
        var teamExtras: [String: Int]
        var initiatedActionCount: Int
        var initiatedActionCountByBoxIndex: [Int: Int]
    }

    struct PendingTransition: Sendable {
        var source: String
    }

    struct StoredState {
        var teams: [TeamTracker]
        var currentHalf: Int
        var gameClockRemaining: Int
        var shotClockRemaining: Int
        var possessionTeamId: Int
        var playByPlayEnabled: Bool
        var playByPlay: [PlayByPlayEvent]
        var teamFoulsInHalf: [Int]
        var formationCycleIndex: [Int]
        var pendingTransition: PendingTransition?
        var lastSubElapsedGameSeconds: [Int]
        var traceEnabled: Bool
        var actionCounter: Int
        var currentActionInteractions: [QAInteractionTrace]
        var currentActionStatRecords: [QAStatRecord]
        var actionTraces: [QAActionTrace]
    }

    private static let lock = NSLock()
    private static nonisolated(unsafe) var nextId = 1
    private static nonisolated(unsafe) var states: [String: StoredState] = [:]

    static func create(home: Team, away: Team, random: inout SeededRandom, includePlayByPlay: Bool) -> String {
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
            playByPlayEnabled: includePlayByPlay,
            playByPlay: [],
            teamFoulsInHalf: [0, 0],
            formationCycleIndex: [0, 0],
            pendingTransition: nil,
            lastSubElapsedGameSeconds: [-9999, -9999],
            traceEnabled: false,
            actionCounter: 0,
            currentActionInteractions: [],
            currentActionStatRecords: [],
            actionTraces: []
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
            teamExtras: [
                "turnovers": 0,
                "fastBreakPoints": 0,
                "pointsInPaint": 0,
            ],
            initiatedActionCount: 0,
            initiatedActionCountByBoxIndex: [:]
        )
    }
}

struct WeightedSkill: Sendable {
    var score: Double
}

public func createInitialGameState(
    homeTeam: Team,
    awayTeam: Team,
    random: inout SeededRandom,
    includePlayByPlay: Bool = true
) -> GameState {
    let handle = NativeGameStateStore.create(
        home: homeTeam,
        away: awayTeam,
        random: &random,
        includePlayByPlay: includePlayByPlay
    )
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
    let interactionJitter = (random.nextUnit() + random.nextUnit() + random.nextUnit() - 1.5) * interactionVarianceJitter
    let edge = (offense.score - defense.score) / 14 + mobilitySizeEdge + interactionJitter
    let successProbability = clamp(logistic(edge), min: 0.03, max: 0.97)
    let offenseWon = random.nextUnit() < successProbability

    return InteractionResult(
        offenseScore: offense.score,
        defenseScore: defense.score,
        edge: edge,
        offenseWon: offenseWon
    )
}

func resolveInteractionWithTrace(
    stored: inout NativeGameStateStore.StoredState,
    label: String,
    offensePlayer: Player,
    defensePlayer: Player,
    offenseRatings: [String],
    defenseRatings: [String],
    random: inout SeededRandom
) -> InteractionResult {
    let result = resolveInteraction(
        offensePlayer: offensePlayer,
        defensePlayer: defensePlayer,
        offenseRatings: offenseRatings,
        defenseRatings: defenseRatings,
        random: &random
    )
    guard stored.traceEnabled else { return result }
    let offenseRatingValues = offenseRatings.reduce(into: [String: Double]()) { values, path in
        values[path] = getRating(offensePlayer, path: path)
    }
    let defenseRatingValues = defenseRatings.reduce(into: [String: Double]()) { values, path in
        values[path] = getRating(defensePlayer, path: path)
    }
    stored.currentActionInteractions.append(
        QAInteractionTrace(
            label: label,
            offensePlayer: offensePlayer.bio.name,
            defensePlayer: defensePlayer.bio.name,
            offenseRatings: offenseRatings,
            defenseRatings: defenseRatings,
            offenseRatingValues: offenseRatingValues,
            defenseRatingValues: defenseRatingValues,
            offenseScore: result.offenseScore,
            defenseScore: result.defenseScore,
            edge: result.edge,
            successProbability: clamp(logistic(result.edge), min: 0.03, max: 0.97),
            offenseWon: result.offenseWon
        )
    )
    return result
}
