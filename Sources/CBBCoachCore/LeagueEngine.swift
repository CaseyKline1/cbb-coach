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

    public init(
        playerIndex: Int,
        name: String,
        position: String,
        year: String,
        home: String?,
        height: String?,
        weight: String?,
        wingspan: String?,
        overall: Int,
        isStarter: Bool,
        attributes: [String: Int]?
    ) {
        self.playerIndex = playerIndex
        self.name = name
        self.position = position
        self.year = year
        self.home = home
        self.height = height
        self.weight = weight
        self.wingspan = wingspan
        self.overall = overall
        self.isStarter = isStarter
        self.attributes = attributes
    }
}

public struct TeamRosterSummary: Codable, Equatable, Sendable {
    public var teamId: String
    public var teamName: String
    public var players: [UserRosterPlayerSummary]

    public init(teamId: String, teamName: String, players: [UserRosterPlayerSummary]) {
        self.teamId = teamId
        self.teamName = teamName
        self.players = players
    }
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

public struct UserGameAdvanceBatch: Codable, Equatable, Sendable {
    public var results: [UserGameSummary]
    public var seasonCompleted: Bool
    public var boxScoresByGameId: [String: [TeamBoxScore]]

    public init(results: [UserGameSummary], seasonCompleted: Bool, boxScoresByGameId: [String: [TeamBoxScore]] = [:]) {
        self.results = results
        self.seasonCompleted = seasonCompleted
        self.boxScoresByGameId = boxScoresByGameId
    }
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

public struct NationalTournamentTeam: Codable, Equatable, Sendable, Identifiable {
    public var teamId: String
    public var teamName: String
    public var conferenceId: String
    public var overallSeed: Int
    public var seedLine: Int
    public var automaticBid: Bool

    public var id: String { teamId }
}

public struct NationalTournamentGame: Codable, Equatable, Sendable, Identifiable {
    public var gameId: String
    public var roundIndex: Int
    public var gameIndex: Int
    public var topTeam: NationalTournamentTeam?
    public var bottomTeam: NationalTournamentTeam?
    public var winnerTeamId: String?
    public var completed: Bool

    public var id: String { gameId }
}

public struct NationalTournamentBracket: Codable, Equatable, Sendable {
    public var teams: [NationalTournamentTeam]
    public var rounds: [[NationalTournamentGame]]
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
    public var userHeadCoachAlmaMater: String?
    public var userHeadCoachPipelineState: String?

    public init(userTeamName: String, seed: String = "default", totalRegularSeasonGames: Int = DEFAULT_TOTAL_REGULAR_SEASON_GAMES) {
        self.userTeamName = userTeamName
        self.userTeamId = nil
        self.seed = seed
        self.totalRegularSeasonGames = totalRegularSeasonGames
        self.userHeadCoachName = nil
        self.userHeadCoachSkills = nil
        self.userHeadCoachAlmaMater = nil
        self.userHeadCoachPipelineState = nil
    }
}

struct D1Snapshot: Codable, Equatable, Sendable {
    struct Conference: Codable, Equatable, Sendable {
        struct TeamRef: Codable, Equatable, Sendable {
            let id: String
            let name: String
        }

        let id: String
        let name: String
        let teams: [TeamRef]
        let inferredConferenceGames: Int?
    }

    let conferences: [Conference]
}

struct LeagueStore {
    struct ScheduledGame: Codable, Equatable, Sendable {
        var gameId: String
        var day: Int
        var type: String
        var siteType: String
        var neutralSite: Bool
        var homeTeamId: String
        var homeTeamName: String
        var awayTeamId: String
        var awayTeamName: String
        var conferenceId: String?
        var tournamentRound: Int?
        var tournamentGameIndex: Int?
        var completed: Bool
        var result: GameResult?
    }

    struct GameResult: Codable, Equatable, Sendable {
        var homeScore: Int
        var awayScore: Int
        var winnerTeamId: String?
        var wentToOvertime: Bool
        var boxScore: [TeamBoxScore]?
    }

    struct TeamState: Codable, Equatable, Sendable {
        var teamId: String
        var teamName: String
        var conferenceId: String
        var conferenceName: String
        var teamModel: Team
        var prestige: Double
        var lastYearResult: Double

        var wins: Int
        var losses: Int
        var conferenceWins: Int
        var conferenceLosses: Int
        var pointsFor: Int
        var pointsAgainst: Int

        var targetGames: Int
        var targetConferenceGames: Int
        var targetNonConferenceGames: Int
    }

    struct ConferenceTournamentState: Codable, Equatable, Sendable {
        struct ParticipantRef: Codable, Equatable, Sendable {
            var seed: Int?
            var fromRound: Int?
            var fromGame: Int?
        }

        struct Matchup: Codable, Equatable, Sendable {
            var top: ParticipantRef
            var bottom: ParticipantRef
        }

        var conferenceId: String
        var conferenceName: String
        var entrantTeamIds: [String]
        var rounds: [[Matchup]]
        var winnersByRound: [[String?]]
        var scheduledRoundCount: Int
    }

    struct NationalTournamentState: Codable, Equatable, Sendable {
        struct Entrant: Codable, Equatable, Sendable {
            var teamId: String
            var overallSeed: Int
            var seedLine: Int
            var automaticBid: Bool
        }

        struct ParticipantRef: Codable, Equatable, Sendable {
            var overallSeed: Int?
            var fromRound: Int?
            var fromGame: Int?
        }

        struct Matchup: Codable, Equatable, Sendable {
            var top: ParticipantRef
            var bottom: ParticipantRef
        }

        var entrants: [Entrant]
        var rounds: [[Matchup]]
        var winnersByRound: [[String?]]
        var scheduledRoundCount: Int
    }

    struct State: Codable, Equatable, Sendable {
        var optionsSeed: String
        var status: String
        var currentDay: Int
        var totalRegularSeasonGames: Int

        var userTeamId: String
        var userSelectedOpponentIds: [String]
        var requiredUserNonConferenceGames: Int

        var conferences: [D1Snapshot.Conference]
        var teams: [TeamState]
        var schedule: [ScheduledGame]
        var userGameHistory: [UserGameSummary]
        var scheduleGenerated: Bool
        var conferenceTournaments: [ConferenceTournamentState]?
        var nationalTournament: NationalTournamentState?
        var remainingRegularSeasonGames: Int?
    }

    static let lock = NSLock()
    static nonisolated(unsafe) var nextHandle = 1
    static nonisolated(unsafe) var states: [String: State] = [:]

    static func put(_ state: State) -> String {
        lock.lock()
        defer { lock.unlock() }
        let handle = "swift_l_\(nextHandle)"
        nextHandle += 1
        states[handle] = state
        return handle
    }

    static func get(_ handle: String) -> State? {
        lock.lock()
        defer { lock.unlock() }
        return states[handle]
    }

    static func update<T>(_ handle: String, _ body: (inout State) -> T) -> T? {
        lock.lock()
        defer { lock.unlock() }
        guard var state = states[handle] else { return nil }
        let out = body(&state)
        states[handle] = state
        return out
    }

    static func updateOutsideLock<T>(_ handle: String, _ body: (inout State) -> T) -> T? {
        lock.lock()
        guard var state = states[handle] else {
            lock.unlock()
            return nil
        }
        lock.unlock()

        let out = body(&state)

        lock.lock()
        states[handle] = state
        lock.unlock()
        return out
    }
}

struct LoadedD1Data {
    static let sharedResult: Result<D1Snapshot, Error> = Result {
        try loadSnapshot()
    }

    static func get() throws -> D1Snapshot {
        try sharedResult.get()
    }

    private static func loadSnapshot() throws -> D1Snapshot {
        let bundles = [Bundle.module, Bundle.main]
        let resourceName = "d1-conferences.2026"
        let resourceExtension = "json"
        let candidateURL = bundles.compactMap { bundle in
            bundle.url(forResource: resourceName, withExtension: resourceExtension, subdirectory: "js")
            ?? bundle.url(forResource: resourceName, withExtension: resourceExtension)
        }.first

        guard let url = candidateURL else {
            throw NSError(
                domain: "CBBCoachCore",
                code: 1000,
                userInfo: [NSLocalizedDescriptionKey: "Missing bundled D1 conference data."]
            )
        }

        let data = try Data(contentsOf: url)
        let decoded = try JSONDecoder().decode(D1Snapshot.self, from: data)
        return normalizeSnapshot(decoded)
    }

    private static func normalizeSnapshot(_ snapshot: D1Snapshot) -> D1Snapshot {
        D1Snapshot(
            conferences: snapshot.conferences.map { conference in
                D1Snapshot.Conference(
                    id: conference.id,
                    name: decodeHTMLEntities(in: conference.name),
                    teams: conference.teams.map { team in
                        D1Snapshot.Conference.TeamRef(
                            id: team.id,
                            name: decodeHTMLEntities(in: team.name)
                        )
                    },
                    inferredConferenceGames: conference.inferredConferenceGames
                )
            }
        )
    }

    private static func decodeHTMLEntities(in text: String) -> String {
        guard text.contains("&") else { return text }

        var output = ""
        output.reserveCapacity(text.count)

        var index = text.startIndex
        while index < text.endIndex {
            if text[index] == "&", let semicolon = text[index...].firstIndex(of: ";") {
                let entityStart = text.index(after: index)
                let entityBody = String(text[entityStart..<semicolon])
                if let decoded = decodeEntityBody(entityBody) {
                    output.append(decoded)
                    index = text.index(after: semicolon)
                    continue
                }
            }

            output.append(text[index])
            index = text.index(after: index)
        }

        return output
    }

    private static func decodeEntityBody(_ body: String) -> String? {
        switch body {
        case "amp":
            return "&"
        case "apos":
            return "'"
        case "quot":
            return "\""
        case "lt":
            return "<"
        case "gt":
            return ">"
        default:
            break
        }

        if body.hasPrefix("#x") || body.hasPrefix("#X") {
            let hex = String(body.dropFirst(2))
            if let value = UInt32(hex, radix: 16), let scalar = UnicodeScalar(value) {
                return String(scalar)
            }
            return nil
        }

        if body.hasPrefix("#") {
            let decimal = String(body.dropFirst())
            if let value = UInt32(decimal, radix: 10), let scalar = UnicodeScalar(value) {
                return String(scalar)
            }
            return nil
        }

        return nil
    }
}
