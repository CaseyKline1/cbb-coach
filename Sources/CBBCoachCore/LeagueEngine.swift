import Foundation

public let DEFAULT_TOTAL_REGULAR_SEASON_GAMES = 31
public let LEAGUE_SAVE_FORMAT = "cbb-coach.league-state"
public let LEAGUE_SAVE_VERSION = 1

public struct LeagueState: Codable, Equatable, Sendable {
    public var handle: String

    public init(handle: String) {
        self.handle = handle
    }
}

public struct NonConferenceOption: Codable, Equatable, Sendable {
    public var teamId: String
    public var teamName: String
    public var conferenceId: String?
    public var conferenceName: String
    public var overall: Double?
    public var selected: Bool?
}

public struct CareerTeamOption: Codable, Equatable, Sendable {
    public var teamId: String
    public var teamName: String
    public var conferenceId: String
    public var conferenceName: String
}

public struct UserRosterPlayerSummary: Codable, Equatable, Sendable {
    public var name: String
    public var position: String
    public var year: String
    public var overall: Int
    public var isStarter: Bool
    public var attributes: [String: Int]?
}

public struct PreseasonBoardOption: Codable, Equatable, Sendable {
    public var teamId: String
    public var teamName: String
    public var conferenceId: String?
    public var conferenceName: String
    public var overall: Double?
    public var selected: Bool?
    public var displayIndex: Int?
    public var absoluteIndex: Int?
}

public struct PreseasonSelectedOpponent: Codable, Equatable, Sendable {
    public var teamId: String
    public var teamName: String
    public var conferenceId: String?
    public var conferenceName: String
    public var overall: Double?
}

public struct PreseasonBoard: Codable, Equatable, Sendable {
    public var page: Int
    public var pageSize: Int
    public var totalPages: Int?
    public var search: String?
    public var totalOptions: Int?
    public var requiredCount: Int?
    public var selectedCount: Int?
    public var remainingCount: Int?
    public var selectedOpponents: [PreseasonSelectedOpponent]?
    public var options: [PreseasonBoardOption]
}

public struct UserGameSummary: Codable, Equatable, Sendable {
    public var gameId: String?
    public var day: Int?
    public var type: String?
    public var isHome: Bool?
    public var opponentTeamId: String?
    public var opponentName: String?
    public var completed: Bool?
    public var result: JSONValue?

    public var done: Bool?
    public var message: String?
    public var score: JSONValue?
    public var won: Bool?
    public var record: JSONValue?
}

public struct ConferenceStanding: Codable, Equatable, Sendable {
    public var teamId: String
    public var teamName: String
    public var conferenceId: String
    public var overall: String?
    public var conference: String?
    public var wins: Int
    public var losses: Int
    public var conferenceWins: Int
    public var conferenceLosses: Int
    public var pointsFor: Int?
    public var pointsAgainst: Int?
}

public struct LeagueSummary: Codable, Equatable, Sendable {
    public var status: String
    public var currentDay: Int
    public var totalTeams: Int
    public var totalConferences: Int
    public var userTeamId: String
    public var userTeamName: String
    public var requiredUserNonConferenceGames: Int
    public var userSelectedNonConferenceGames: Int
    public var scheduleGenerated: Bool
    public var totalScheduledGames: Int
}

public struct CreateLeagueOptions: Codable, Equatable, Sendable {
    public var userTeamName: String
    public var userTeamId: String?
    public var seed: String
    public var totalRegularSeasonGames: Int
    public var userHeadCoachSkills: CoachSkills?

    public init(userTeamName: String, seed: String = "default", totalRegularSeasonGames: Int = DEFAULT_TOTAL_REGULAR_SEASON_GAMES) {
        self.userTeamName = userTeamName
        self.userTeamId = nil
        self.seed = seed
        self.totalRegularSeasonGames = totalRegularSeasonGames
        self.userHeadCoachSkills = nil
    }
}

private let leagueEngineModule = "./leagueEngine"

public func createD1League(options: CreateLeagueOptions) throws -> LeagueState {
    let args = [try toJSONValue(options)]
    let handle = try JSRuntime.shared.invokeNew(moduleId: leagueEngineModule, fn: "createD1League", args: args)
    return LeagueState(handle: handle)
}

public func listCareerTeamOptions() -> [CareerTeamOption] {
    do {
        let raw = try JSRuntime.shared.invoke(moduleId: leagueEngineModule, fn: "listCareerTeamOptions", args: [])
        return try fromJSONValue(raw, as: [CareerTeamOption].self)
    } catch {
        fatalError("listCareerTeamOptions failed: \(error)")
    }
}

public func listUserNonConferenceOptions(_ league: LeagueState) -> [NonConferenceOption] {
    do {
        let raw = try JSRuntime.shared.invokeHandle(moduleId: leagueEngineModule, fn: "listUserNonConferenceOptions", handle: league.handle, restArgs: [])
        return try fromJSONValue(raw, as: [NonConferenceOption].self)
    } catch {
        fatalError("listUserNonConferenceOptions failed: \(error)")
    }
}

public func getPreseasonSchedulingBoard(_ league: LeagueState, page: Int = 1, pageSize: Int = 20, query: String? = nil) -> PreseasonBoard {
    do {
        let options = JSONValue.object([
            "page": .number(Double(page)),
            "pageSize": .number(Double(pageSize)),
            "search": .string(query ?? ""),
        ])
        let raw = try JSRuntime.shared.invokeHandle(moduleId: leagueEngineModule, fn: "getPreseasonSchedulingBoard", handle: league.handle, restArgs: [options])
        return try fromJSONValue(raw, as: PreseasonBoard.self)
    } catch {
        fatalError("getPreseasonSchedulingBoard failed: \(error)")
    }
}

public func setUserNonConferenceOpponents(_ league: inout LeagueState, opponentTeamIds: [String]) {
    do {
        _ = try JSRuntime.shared.invokeHandleMutable(moduleId: leagueEngineModule, fn: "setUserNonConferenceOpponents", handle: league.handle, restArgs: [try toJSONValue(opponentTeamIds)])
    } catch {
        fatalError("setUserNonConferenceOpponents failed: \(error)")
    }
}

public func autoFillUserNonConferenceOpponents(_ league: inout LeagueState, seed: String = "autofill") {
    do {
        _ = try JSRuntime.shared.invokeHandleMutable(moduleId: leagueEngineModule, fn: "autoFillUserNonConferenceOpponents", handle: league.handle, restArgs: [JSONValue.object(["seed": .string(seed)])])
    } catch {
        fatalError("autoFillUserNonConferenceOpponents failed: \(error)")
    }
}

public func generateSeasonSchedule(_ league: inout LeagueState) {
    do {
        _ = try JSRuntime.shared.invokeHandleMutable(moduleId: leagueEngineModule, fn: "generateSeasonSchedule", handle: league.handle, restArgs: [])
    } catch {
        fatalError("generateSeasonSchedule failed: \(error)")
    }
}

public func getUserSchedule(_ league: LeagueState) -> [UserGameSummary] {
    do {
        let raw = try JSRuntime.shared.invokeHandle(moduleId: leagueEngineModule, fn: "getUserSchedule", handle: league.handle, restArgs: [])
        return try fromJSONValue(raw, as: [UserGameSummary].self)
    } catch {
        fatalError("getUserSchedule failed: \(error)")
    }
}

public func getUserRoster(_ league: LeagueState) -> [UserRosterPlayerSummary] {
    do {
        let raw = try JSRuntime.shared.invokeHandle(moduleId: leagueEngineModule, fn: "getUserRoster", handle: league.handle, restArgs: [])
        return try fromJSONValue(raw, as: [UserRosterPlayerSummary].self)
    } catch {
        fatalError("getUserRoster failed: \(error)")
    }
}

public func advanceToNextUserGame(_ league: inout LeagueState) -> UserGameSummary? {
    do {
        let result = try JSRuntime.shared.invokeHandleMutable(moduleId: leagueEngineModule, fn: "advanceToNextUserGame", handle: league.handle, restArgs: [])
        return try fromJSONValue(result, as: UserGameSummary.self)
    } catch {
        return nil
    }
}

public func getUserCompletedGames(_ league: LeagueState) -> [UserGameSummary] {
    do {
        let raw = try JSRuntime.shared.invokeHandle(moduleId: leagueEngineModule, fn: "getUserCompletedGames", handle: league.handle, restArgs: [])
        return try fromJSONValue(raw, as: [UserGameSummary].self)
    } catch {
        fatalError("getUserCompletedGames failed: \(error)")
    }
}

public func getConferenceStandings(_ league: LeagueState, conferenceId: String? = nil) -> [ConferenceStanding] {
    do {
        let args: [JSONValue]
        if let conferenceId {
            args = [.string(conferenceId)]
        } else {
            args = []
        }
        let raw = try JSRuntime.shared.invokeHandle(moduleId: leagueEngineModule, fn: "getConferenceStandings", handle: league.handle, restArgs: args)
        if case .array = raw {
            return try fromJSONValue(raw, as: [ConferenceStanding].self)
        }
        return []
    } catch {
        return []
    }
}

public func getLeagueSummary(_ league: LeagueState) -> LeagueSummary {
    do {
        let raw = try JSRuntime.shared.invokeHandle(moduleId: leagueEngineModule, fn: "getLeagueSummary", handle: league.handle, restArgs: [])
        return try fromJSONValue(raw, as: LeagueSummary.self)
    } catch {
        fatalError("getLeagueSummary failed: \(error)")
    }
}

public func saveLeagueState(_ league: LeagueState, destinationPath: String, pretty: Bool = true) throws -> (filePath: String, bytes: Int, format: String, version: Int, savedAt: String) {
    let options = JSONValue.object(["pretty": .bool(pretty)])
    let raw = try JSRuntime.shared.invokeHandle(moduleId: leagueEngineModule, fn: "saveLeagueState", handle: league.handle, restArgs: [.string(destinationPath), options])

    struct SaveResult: Codable {
        let filePath: String
        let bytes: Int
        let format: String
        let version: Int
        let savedAt: String
    }

    let decoded: SaveResult = try fromJSONValue(raw)
    return (decoded.filePath, decoded.bytes, decoded.format, decoded.version, decoded.savedAt)
}

public func loadLeagueState(_ sourcePath: String) throws -> LeagueState {
    let handle = try JSRuntime.shared.invokeNew(moduleId: leagueEngineModule, fn: "loadLeagueState", args: [.string(sourcePath)])
    return LeagueState(handle: handle)
}
