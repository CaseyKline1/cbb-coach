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
    public var playerIndex: Int
    public var name: String
    public var position: String
    public var year: String
    public var home: String?
    public var height: String?
    public var weight: String?
    public var wingspan: String?
    public var overall: Int
    public var isStarter: Bool
    public var attributes: [String: Int]?
}

public struct UserRotationSlot: Codable, Equatable, Sendable, Identifiable {
    public var slot: Int
    public var playerIndex: Int?
    public var position: String?
    public var minutes: Double

    public init(slot: Int, playerIndex: Int?, position: String?, minutes: Double) {
        self.slot = slot
        self.playerIndex = playerIndex
        self.position = position
        self.minutes = minutes
    }

    public var id: Int { slot }
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
    public var siteType: String?
    public var neutralSite: Bool?
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

public struct LeagueGameSummary: Codable, Equatable, Sendable {
    public var gameId: String?
    public var day: Int?
    public var type: String?
    public var siteType: String?
    public var neutralSite: Bool?
    public var homeTeamId: String?
    public var homeTeamName: String?
    public var awayTeamId: String?
    public var awayTeamName: String?
    public var completed: Bool?
    public var result: JSONValue?
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

public struct LeagueRankingTeam: Codable, Equatable, Sendable, Identifiable {
    public var rank: Int
    public var teamId: String
    public var teamName: String
    public var conferenceId: String
    public var record: String
    public var wins: Int
    public var losses: Int
    public var gamesPlayed: Int
    public var pointDifferentialPerGame: Double
    public var strengthOfSchedule: Double
    public var qualityWinRate: Double
    public var playerSkill: Double
    public var prestige: Double
    public var lastYearResult: Double
    public var coachQuality: Double
    public var preseasonScore: Double
    public var inSeasonScore: Double
    public var compositeScore: Double

    public var id: String { teamId }
}

public struct LeagueRankings: Codable, Equatable, Sendable {
    public var topN: Int
    public var seasonProgress: Double
    public var preseasonWeight: Double
    public var inSeasonWeight: Double
    public var rankings: [LeagueRankingTeam]
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

public struct UserCoachingStaffSummary: Codable, Equatable, Sendable {
    public var headCoach: Coach
    public var assistants: [Coach]
    public var gamePrepAssistantIndex: Int?
}

public struct CreateLeagueOptions: Codable, Equatable, Sendable {
    public var userTeamName: String
    public var userTeamId: String?
    public var seed: String
    public var totalRegularSeasonGames: Int
    public var userHeadCoachName: String?
    public var userHeadCoachSkills: CoachSkills?

    public init(userTeamName: String, seed: String = "default", totalRegularSeasonGames: Int = DEFAULT_TOTAL_REGULAR_SEASON_GAMES) {
        self.userTeamName = userTeamName
        self.userTeamId = nil
        self.seed = seed
        self.totalRegularSeasonGames = totalRegularSeasonGames
        self.userHeadCoachName = nil
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

public func getUserRotation(_ league: LeagueState) -> [UserRotationSlot] {
    do {
        let raw = try JSRuntime.shared.invokeHandle(moduleId: leagueEngineModule, fn: "getUserRotation", handle: league.handle, restArgs: [])
        return try fromJSONValue(raw, as: [UserRotationSlot].self)
    } catch {
        fatalError("getUserRotation failed: \(error)")
    }
}

public func setUserRotation(_ league: inout LeagueState, slots: [UserRotationSlot]) -> [UserRotationSlot] {
    do {
        let raw = try JSRuntime.shared.invokeHandleMutable(moduleId: leagueEngineModule, fn: "setUserRotation", handle: league.handle, restArgs: [try toJSONValue(slots)])
        return try fromJSONValue(raw, as: [UserRotationSlot].self)
    } catch {
        fatalError("setUserRotation failed: \(error)")
    }
}

public func getUserCoachingStaff(_ league: LeagueState) -> UserCoachingStaffSummary {
    do {
        let raw = try JSRuntime.shared.invokeHandle(moduleId: leagueEngineModule, fn: "getUserCoachingStaff", handle: league.handle, restArgs: [])
        return try fromJSONValue(raw, as: UserCoachingStaffSummary.self)
    } catch {
        fatalError("getUserCoachingStaff failed: \(error)")
    }
}

public func setUserAssistantFocus(_ league: inout LeagueState, assistantIndex: Int, focus: AssistantFocus) {
    do {
        _ = try JSRuntime.shared.invokeHandleMutable(
            moduleId: leagueEngineModule,
            fn: "setUserAssistantFocus",
            handle: league.handle,
            restArgs: [.number(Double(assistantIndex)), .string(focus.rawValue)]
        )
    } catch {
        fatalError("setUserAssistantFocus failed: \(error)")
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

public func getCompletedLeagueGames(_ league: LeagueState) -> [LeagueGameSummary] {
    do {
        let raw = try JSRuntime.shared.invokeHandle(moduleId: leagueEngineModule, fn: "getCompletedLeagueGames", handle: league.handle, restArgs: [])
        return try fromJSONValue(raw, as: [LeagueGameSummary].self)
    } catch {
        fatalError("getCompletedLeagueGames failed: \(error)")
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

public func getRankings(_ league: LeagueState, topN: Int = 25) -> LeagueRankings {
    do {
        let options: JSONValue = .object([
            "topN": .number(Double(topN))
        ])
        let raw = try JSRuntime.shared.invokeHandle(moduleId: leagueEngineModule, fn: "getRankings", handle: league.handle, restArgs: [options])
        return try fromJSONValue(raw, as: LeagueRankings.self)
    } catch {
        fatalError("getRankings failed: \(error)")
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
