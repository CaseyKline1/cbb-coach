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

private let gameEngineModule = "./gameEngine"

public func createInitialGameState(homeTeam: Team, awayTeam: Team, random: inout SeededRandom) -> GameState {
    do {
        let args = [try toJSONValue(homeTeam), try toJSONValue(awayTeam)]
        let response = try JSRuntime.shared.invokeNewWithRandom(moduleId: gameEngineModule, fn: "createInitialGameState", args: args, random: &random)
        return GameState(handle: response.handle)
    } catch {
        fatalError("createInitialGameState failed: \(error)")
    }
}

public func resolveInteraction(
    offensePlayer: Player,
    defensePlayer: Player,
    offenseRatings: [String],
    defenseRatings: [String],
    random: inout SeededRandom
) -> InteractionResult {
    do {
        let payload: JSONValue = .object([
            "offensePlayer": try toJSONValue(offensePlayer),
            "defensePlayer": try toJSONValue(defensePlayer),
            "offenseRatings": try toJSONValue(offenseRatings),
            "defenseRatings": try toJSONValue(defenseRatings),
            "contextEdge": .number(0),
        ])
        let args = [payload]
        let response = try JSRuntime.shared.invokeWithRandom(moduleId: gameEngineModule, fn: "resolveInteraction", args: args, random: &random)
        struct JSResolvedInteraction: Codable {
            struct SkillSummary: Codable { let score: Double }
            let success: Bool
            let offense: SkillSummary
            let defense: SkillSummary
            let edge: Double
        }
        let js = try fromJSONValue(response.result, as: JSResolvedInteraction.self)
        return InteractionResult(offenseScore: js.offense.score, defenseScore: js.defense.score, edge: js.edge, offenseWon: js.success)
    } catch {
        fatalError("resolveInteraction failed: \(error)")
    }
}

@discardableResult
public func resolveActionChunk(state: inout GameState, random: inout SeededRandom) -> String {
    do {
        _ = try JSRuntime.shared.invokeHandleMutableWithRandom(moduleId: gameEngineModule, fn: "resolveActionChunk", handle: state.handle, restArgs: [], random: &random)
        return ""
    } catch {
        fatalError("resolveActionChunk failed: \(error)")
    }
}

public func simulateHalf(state: inout GameState, random: inout SeededRandom) {
    do {
        _ = try JSRuntime.shared.invokeHandleMutableWithRandom(moduleId: gameEngineModule, fn: "simulateHalf", handle: state.handle, restArgs: [], random: &random)
    } catch {
        fatalError("simulateHalf failed: \(error)")
    }
}

public func simulateGame(homeTeam: Team, awayTeam: Team, random: inout SeededRandom) -> SimulatedGameResult {
    do {
        let args = [try toJSONValue(homeTeam), try toJSONValue(awayTeam)]
        let response = try JSRuntime.shared.invokeWithRandomOptions(moduleId: gameEngineModule, fn: "simulateGame", args: args, random: &random)
        return try fromJSONValue(response.result, as: SimulatedGameResult.self)
    } catch {
        fatalError("simulateGame failed: \(error)")
    }
}
