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
    public var raw: JSONValue

    public init(raw: JSONValue) {
        self.raw = raw
    }
}

private let gameEngineModule = "./gameEngine"

public func createInitialGameState(homeTeam: Team, awayTeam: Team, random: inout SeededRandom) -> GameState {
    do {
        let args = [try toJSONValue(homeTeam), try toJSONValue(awayTeam)]
        let response = try JSRuntime.shared.invokeWithRandom(moduleId: gameEngineModule, fn: "createInitialGameState", args: args, random: &random)
        return GameState(raw: response.result)
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
        let args = [
            try toJSONValue(offensePlayer),
            try toJSONValue(defensePlayer),
            try toJSONValue(offenseRatings),
            try toJSONValue(defenseRatings),
        ]
        let response = try JSRuntime.shared.invokeWithRandom(moduleId: gameEngineModule, fn: "resolveInteraction", args: args, random: &random)
        return try fromJSONValue(response.result, as: InteractionResult.self)
    } catch {
        fatalError("resolveInteraction failed: \(error)")
    }
}

@discardableResult
public func resolveActionChunk(state: inout GameState, random: inout SeededRandom) -> String {
    do {
        let response = try JSRuntime.shared.invokeMutableWithRandom(moduleId: gameEngineModule, fn: "resolveActionChunk", state: state.raw, restArgs: [], random: &random)
        state.raw = response.state
        return try fromJSONValue(response.result, as: String.self)
    } catch {
        fatalError("resolveActionChunk failed: \(error)")
    }
}

public func simulateHalf(state: inout GameState, random: inout SeededRandom) {
    do {
        let response = try JSRuntime.shared.invokeMutableWithRandom(moduleId: gameEngineModule, fn: "simulateHalf", state: state.raw, restArgs: [], random: &random)
        state.raw = response.state
    } catch {
        fatalError("simulateHalf failed: \(error)")
    }
}

public func simulateGame(homeTeam: Team, awayTeam: Team, random: inout SeededRandom) -> SimulatedGameResult {
    do {
        let args = [try toJSONValue(homeTeam), try toJSONValue(awayTeam)]
        let response = try JSRuntime.shared.invokeWithRandom(moduleId: gameEngineModule, fn: "simulateGame", args: args, random: &random)
        return try fromJSONValue(response.result, as: SimulatedGameResult.self)
    } catch {
        fatalError("simulateGame failed: \(error)")
    }
}
