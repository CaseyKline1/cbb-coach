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

private struct D1Snapshot: Codable, Equatable, Sendable {
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

private struct LeagueStore {
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
}

private struct LoadedD1Data {
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

public func createD1League(options: CreateLeagueOptions) throws -> LeagueState {
    let dataset = try LoadedD1Data.get()
    let allTeams = dataset.conferences.flatMap { conference in
        conference.teams.map { (conference, $0) }
    }

    guard !allTeams.isEmpty else {
        throw NSError(domain: "CBBCoachCore", code: 1001, userInfo: [NSLocalizedDescriptionKey: "No teams available in D1 dataset"]) 
    }

    let requestedName = options.userTeamName.trimmingCharacters(in: .whitespacesAndNewlines)
    let userTuple = allTeams.first(where: { _, team in
        if let userTeamId = options.userTeamId, !userTeamId.isEmpty {
            return team.id == userTeamId
        }
        return team.name.caseInsensitiveCompare(requestedName) == .orderedSame
    }) ?? allTeams.first!

    let userConference = userTuple.0
    let userTeamRef = userTuple.1

    var random = SeededRandom(seed: hashString(options.seed))
    let totalRegularSeasonGames = max(1, options.totalRegularSeasonGames)

    var teams: [LeagueStore.TeamState] = []
    teams.reserveCapacity(allTeams.count)

    for (conference, teamRef) in allTeams {
        let isUser = teamRef.id == userTeamRef.id
        let teamPrestige = prestigeForTeam(teamId: teamRef.id, conferenceId: conference.id)
        let teamLastYearResult = lastYearResultForTeam(teamId: teamRef.id, conferenceId: conference.id)
        // Keep using the shared league RNG so each team's roster draw is unique.
        let roster = buildTeamRoster(teamName: teamRef.name, prestige: teamPrestige, random: &random)

        var createTeamOptions = CreateTeamOptions(name: teamRef.name, players: roster)
        createTeamOptions.formation = random.choose(OffensiveFormation.allCases) ?? .motion
        createTeamOptions.defenseScheme = random.choose(DefenseScheme.allCases) ?? .manToMan
        createTeamOptions.pace = random.choose(PaceProfile.allCases) ?? .normal

        if isUser {
            var staffOptions = CreateCoachingStaffOptions()
            var head = CreateCoachOptions()
            head.role = .headCoach
            head.name = options.userHeadCoachName
            head.skills = options.userHeadCoachSkills
            head.almaMater = options.userHeadCoachAlmaMater
            head.pipelineState = options.userHeadCoachPipelineState
            staffOptions.headCoach = head
            staffOptions.teamName = teamRef.name
            createTeamOptions.coachingStaff = createCoachingStaff(options: staffOptions, random: &random)
        }

        let model = createTeam(options: createTeamOptions, random: &random)
        let confGames = max(0, min(conference.inferredConferenceGames ?? 18, totalRegularSeasonGames))
        let nonConfGames = max(0, totalRegularSeasonGames - confGames)

        teams.append(
            LeagueStore.TeamState(
                teamId: teamRef.id,
                teamName: teamRef.name,
                conferenceId: conference.id,
                conferenceName: conference.name,
                teamModel: model,
                prestige: teamPrestige,
                lastYearResult: teamLastYearResult,
                wins: 0,
                losses: 0,
                conferenceWins: 0,
                conferenceLosses: 0,
                pointsFor: 0,
                pointsAgainst: 0,
                targetGames: totalRegularSeasonGames,
                targetConferenceGames: confGames,
                targetNonConferenceGames: nonConfGames
            )
        )
    }

    let requiredUserNonConferenceGames = max(0, totalRegularSeasonGames - max(0, min(userConference.inferredConferenceGames ?? 18, totalRegularSeasonGames)))

    var state = LeagueStore.State(
        optionsSeed: options.seed,
        status: "in_progress",
        currentDay: 0,
        totalRegularSeasonGames: totalRegularSeasonGames,
        userTeamId: userTeamRef.id,
        userSelectedOpponentIds: [],
        requiredUserNonConferenceGames: requiredUserNonConferenceGames,
        conferences: dataset.conferences,
        teams: teams,
        schedule: [],
        userGameHistory: [],
        scheduleGenerated: false,
        conferenceTournaments: nil
    )

    autoFillUserNonConferenceOpponentsInState(&state, seed: "create:\(options.seed)")
    generateSeasonScheduleInState(&state)

    let handle = LeagueStore.put(state)
    return LeagueState(handle: handle)
}

public func listCareerTeamOptions() -> [CareerTeamOption] {
    guard let dataset = try? LoadedD1Data.get() else {
        return []
    }
    return dataset.conferences
        .flatMap { conference in
            conference.teams.map {
                CareerTeamOption(teamId: $0.id, teamName: $0.name, conferenceId: conference.id, conferenceName: conference.name)
            }
        }
        .sorted { lhs, rhs in
            if lhs.conferenceName != rhs.conferenceName { return lhs.conferenceName < rhs.conferenceName }
            return lhs.teamName < rhs.teamName
        }
}

public func listUserNonConferenceOptions(_ league: LeagueState) -> [NonConferenceOption] {
    guard let state = LeagueStore.get(league.handle), let user = state.teams.first(where: { $0.teamId == state.userTeamId }) else {
        return []
    }

    return state.teams
        .filter { $0.teamId != user.teamId && $0.conferenceId != user.conferenceId }
        .sorted { $0.teamName < $1.teamName }
        .map { team in
            NonConferenceOption(
                teamId: team.teamId,
                teamName: team.teamName,
                conferenceId: team.conferenceId,
                conferenceName: team.conferenceName,
                overall: teamOverall(team.teamModel),
                selected: state.userSelectedOpponentIds.contains(team.teamId)
            )
        }
}

public func getPreseasonSchedulingBoard(_ league: LeagueState, page: Int = 1, pageSize: Int = 20, query: String? = nil) -> PreseasonBoard {
    let trimmedQuery = (query ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    let all = listUserNonConferenceOptions(league)
        .filter { option in
            guard !trimmedQuery.isEmpty else { return true }
            return option.teamName.localizedCaseInsensitiveContains(trimmedQuery) || option.conferenceName.localizedCaseInsensitiveContains(trimmedQuery)
        }

    let pageSizeSafe = max(1, pageSize)
    let totalPages = max(1, Int(ceil(Double(all.count) / Double(pageSizeSafe))))
    let pageSafe = clamp(page, min: 1, max: totalPages)
    let start = (pageSafe - 1) * pageSizeSafe
    let end = min(all.count, start + pageSizeSafe)
    let slice = start < end ? Array(all[start..<end]) : []

    let options = slice.enumerated().map { idx, item in
        PreseasonBoardOption(
            teamId: item.teamId,
            teamName: item.teamName,
            conferenceId: item.conferenceId,
            conferenceName: item.conferenceName,
            overall: item.overall,
            selected: item.selected,
            displayIndex: idx,
            absoluteIndex: start + idx
        )
    }

    let selectedOpponents = all
        .filter { $0.selected == true }
        .map {
            PreseasonSelectedOpponent(teamId: $0.teamId, teamName: $0.teamName, conferenceId: $0.conferenceId, conferenceName: $0.conferenceName, overall: $0.overall)
        }

    let selectedCount = selectedOpponents.count
    let requiredCount = LeagueStore.get(league.handle)?.requiredUserNonConferenceGames ?? 0

    return PreseasonBoard(
        page: pageSafe,
        pageSize: pageSizeSafe,
        totalPages: totalPages,
        search: trimmedQuery,
        totalOptions: all.count,
        requiredCount: requiredCount,
        selectedCount: selectedCount,
        remainingCount: max(0, requiredCount - selectedCount),
        selectedOpponents: selectedOpponents,
        options: options
    )
}

public func setUserNonConferenceOpponents(_ league: inout LeagueState, opponentTeamIds: [String]) {
    _ = LeagueStore.update(league.handle) { state in
        guard let user = state.teams.first(where: { $0.teamId == state.userTeamId }) else { return }
        let valid = Set(
            state.teams
                .filter { $0.teamId != user.teamId && $0.conferenceId != user.conferenceId }
                .map(\.teamId)
        )
        let deduped = Array(NSOrderedSet(array: opponentTeamIds.filter { valid.contains($0) })) as? [String] ?? []
        state.userSelectedOpponentIds = Array(deduped.prefix(state.requiredUserNonConferenceGames))
        state.scheduleGenerated = false
        state.schedule.removeAll()
        state.userGameHistory.removeAll()
        state.conferenceTournaments = nil
        resetTeamRecords(&state)
    }
}

public func autoFillUserNonConferenceOpponents(_ league: inout LeagueState, seed: String = "autofill") {
    _ = LeagueStore.update(league.handle) { state in
        autoFillUserNonConferenceOpponentsInState(&state, seed: seed)
        state.scheduleGenerated = false
        state.schedule.removeAll()
        state.userGameHistory.removeAll()
        state.conferenceTournaments = nil
        resetTeamRecords(&state)
    }
}

public func generateSeasonSchedule(_ league: inout LeagueState) {
    _ = LeagueStore.update(league.handle) { state in
        generateSeasonScheduleInState(&state)
    }
}

public func getUserSchedule(_ league: LeagueState) -> [UserGameSummary] {
    guard let state = LeagueStore.get(league.handle), let user = state.teams.first(where: { $0.teamId == state.userTeamId }) else {
        return []
    }

    return state.schedule
        .filter { $0.homeTeamId == user.teamId || $0.awayTeamId == user.teamId }
        .sorted {
            if $0.day != $1.day { return $0.day < $1.day }
            return $0.gameId < $1.gameId
        }
        .map { userSummaryFromGame($0, userTeamId: user.teamId) }
}

public func getUserRoster(_ league: LeagueState) -> [UserRosterPlayerSummary] {
    guard let state = LeagueStore.get(league.handle), let user = state.teams.first(where: { $0.teamId == state.userTeamId }) else {
        return []
    }

    let lineupNames = Set(user.teamModel.lineup.map(\.bio.name))
    return rosterSummaryPlayers(from: user.teamModel, lineupNames: lineupNames)
}

public func getTeamRosters(_ league: LeagueState) -> [TeamRosterSummary] {
    guard let state = LeagueStore.get(league.handle) else {
        return []
    }

    return state.teams.map { team in
        let lineupNames = Set(team.teamModel.lineup.map(\.bio.name))
        return TeamRosterSummary(
            teamId: team.teamId,
            teamName: team.teamModel.name,
            players: rosterSummaryPlayers(from: team.teamModel, lineupNames: lineupNames)
        )
    }
}

private func rosterSummaryPlayers(from team: Team, lineupNames: Set<String>) -> [UserRosterPlayerSummary] {
    team.players.enumerated().map { idx, player in
        UserRosterPlayerSummary(
            playerIndex: idx,
            name: player.bio.name,
            position: player.bio.position.rawValue,
            year: player.bio.year.rawValue,
            home: player.bio.home,
            height: player.size.height,
            weight: player.size.weight,
            wingspan: player.size.wingspan,
            overall: playerOverall(player),
            isStarter: lineupNames.contains(player.bio.name),
            attributes: [
                "potential": player.bio.potential,

                "speed": player.athleticism.speed,
                "agility": player.athleticism.agility,
                "burst": player.athleticism.burst,
                "strength": player.athleticism.strength,
                "vertical": player.athleticism.vertical,
                "stamina": player.athleticism.stamina,
                "durability": player.athleticism.durability,

                "layups": player.shooting.layups,
                "dunks": player.shooting.dunks,
                "closeShot": player.shooting.closeShot,
                "midrangeShot": player.shooting.midrangeShot,
                "threePointShooting": player.shooting.threePointShooting,
                "cornerThrees": player.shooting.cornerThrees,
                "upTopThrees": player.shooting.upTopThrees,
                "drawFoul": player.shooting.drawFoul,
                "freeThrows": player.shooting.freeThrows,

                "postControl": player.postGame.postControl,
                "postFadeaways": player.postGame.postFadeaways,
                "postHooks": player.postGame.postHooks,

                "ballHandling": player.skills.ballHandling,
                "ballSafety": player.skills.ballSafety,
                "passingAccuracy": player.skills.passingAccuracy,
                "passingVision": player.skills.passingVision,
                "passingIQ": player.skills.passingIQ,
                "shotIQ": player.skills.shotIQ,
                "offballOffense": player.skills.offballOffense,
                "hands": player.skills.hands,
                "hustle": player.skills.hustle,
                "clutch": player.skills.clutch,

                "perimeterDefense": player.defense.perimeterDefense,
                "postDefense": player.defense.postDefense,
                "shotBlocking": player.defense.shotBlocking,
                "shotContest": player.defense.shotContest,
                "steals": player.defense.steals,
                "lateralQuickness": player.defense.lateralQuickness,
                "offballDefense": player.defense.offballDefense,
                "passPerception": player.defense.passPerception,
                "defensiveControl": player.defense.defensiveControl,

                "offensiveRebounding": player.rebounding.offensiveRebounding,
                "defensiveRebound": player.rebounding.defensiveRebound,
                "boxouts": player.rebounding.boxouts,

                "tendencyPost": player.tendencies.post,
                "tendencyInside": player.tendencies.inside,
                "tendencyMidrange": player.tendencies.midrange,
                "tendencyThreePoint": player.tendencies.threePoint,
                "tendencyDrive": player.tendencies.drive,
                "tendencyPickAndRoll": player.tendencies.pickAndRoll,
                "tendencyPickAndPop": player.tendencies.pickAndPop,
                "tendencyShootVsPass": player.tendencies.shootVsPass,
            ]
        )
    }
}

public func getUserRotation(_ league: LeagueState) -> [UserRotationSlot] {
    guard let state = LeagueStore.get(league.handle), let user = state.teams.first(where: { $0.teamId == state.userTeamId }) else {
        return []
    }

    let defaultSlots = defaultRotationSlots(for: user.teamModel)
    guard let targets = user.teamModel.rotation?.minuteTargets, !targets.isEmpty else {
        return defaultSlots
    }

    return defaultSlots.map { slot in
        guard let playerIndex = slot.playerIndex, playerIndex < user.teamModel.players.count else { return slot }
        let player = user.teamModel.players[playerIndex]
        let mapped = targets[player.bio.name] ?? slot.minutes
        return UserRotationSlot(slot: slot.slot, playerIndex: slot.playerIndex, position: slot.position, minutes: mapped)
    }
}

public func setUserRotation(_ league: inout LeagueState, slots: [UserRotationSlot]) -> [UserRotationSlot] {
    LeagueStore.update(league.handle) { state in
        guard let userIndex = state.teams.firstIndex(where: { $0.teamId == state.userTeamId }) else {
            return []
        }

        let team = state.teams[userIndex].teamModel
        var targets: [String: Double] = [:]
        for slot in slots {
            guard let playerIndex = slot.playerIndex, playerIndex >= 0, playerIndex < team.players.count else { continue }
            let playerName = team.players[playerIndex].bio.name
            targets[playerName] = clamp(slot.minutes, min: 0, max: 40)
        }

        var updatedTeam = team
        updatedTeam.rotation = TeamRotation(minuteTargets: targets)

        let lineupIndexes = slots
            .sorted { $0.minutes > $1.minutes }
            .compactMap(\.playerIndex)
            .filter { $0 >= 0 && $0 < updatedTeam.players.count }

        if lineupIndexes.count >= 5 {
            updatedTeam.lineup = Array(lineupIndexes.prefix(5)).map { updatedTeam.players[$0] }
        }

        state.teams[userIndex].teamModel = updatedTeam

        let defaultSlots = defaultRotationSlots(for: updatedTeam)
        guard let minuteTargets = updatedTeam.rotation?.minuteTargets, !minuteTargets.isEmpty else {
            return defaultSlots
        }
        return defaultSlots.map { slot in
            guard let playerIndex = slot.playerIndex, playerIndex < updatedTeam.players.count else { return slot }
            let player = updatedTeam.players[playerIndex]
            let mapped = minuteTargets[player.bio.name] ?? slot.minutes
            return UserRotationSlot(slot: slot.slot, playerIndex: slot.playerIndex, position: slot.position, minutes: mapped)
        }
    } ?? []
}

public func getUserCoachingStaff(_ league: LeagueState) -> UserCoachingStaffSummary {
    guard let state = LeagueStore.get(league.handle), let user = state.teams.first(where: { $0.teamId == state.userTeamId }) else {
        fatalError("User team is missing coaching staff.")
    }

    return UserCoachingStaffSummary(
        headCoach: user.teamModel.coachingStaff.headCoach,
        assistants: user.teamModel.coachingStaff.assistants,
        gamePrepAssistantIndex: user.teamModel.coachingStaff.gamePrepAssistantIndex
    )
}

public func setUserAssistantFocus(_ league: inout LeagueState, assistantIndex: Int, focus: AssistantFocus) {
    _ = LeagueStore.update(league.handle) { state in
        guard let userIndex = state.teams.firstIndex(where: { $0.teamId == state.userTeamId }) else { return }
        guard assistantIndex >= 0, assistantIndex < state.teams[userIndex].teamModel.coachingStaff.assistants.count else { return }

        state.teams[userIndex].teamModel.coachingStaff.assistants[assistantIndex].focus = focus
        if focus == .gamePrep {
            state.teams[userIndex].teamModel.coachingStaff.gamePrepAssistantIndex = assistantIndex
        } else if state.teams[userIndex].teamModel.coachingStaff.gamePrepAssistantIndex == assistantIndex {
            state.teams[userIndex].teamModel.coachingStaff.gamePrepAssistantIndex = nil
        }
    }
}

public func advanceToNextUserGame(_ league: inout LeagueState) -> UserGameSummary? {
    LeagueStore.update(league.handle) { state in
        if !state.scheduleGenerated || state.schedule.isEmpty {
            generateSeasonScheduleInState(&state)
        }
        prepareConferenceTournamentsIfNeeded(&state)

        let userTeamId = state.userTeamId
        func nextPendingUserGame(_ state: LeagueStore.State, userTeamId: String) -> (offset: Int, element: LeagueStore.ScheduledGame)? {
            state.schedule
                .enumerated()
                .filter { _, game in !game.completed && (game.homeTeamId == userTeamId || game.awayTeamId == userTeamId) }
                .min { lhs, rhs in
                    if lhs.element.day != rhs.element.day { return lhs.element.day < rhs.element.day }
                    return lhs.element.gameId < rhs.element.gameId
                }
        }

        var pending = nextPendingUserGame(state, userTeamId: userTeamId)
        while pending == nil {
            guard let nextDay = state.schedule.filter({ !$0.completed }).map(\.day).min() else {
                state.status = "completed"
                return UserGameSummary(
                    gameId: nil,
                    day: state.currentDay,
                    type: nil,
                    siteType: nil,
                    neutralSite: nil,
                    isHome: nil,
                    opponentTeamId: nil,
                    opponentName: nil,
                    completed: true,
                    result: nil,
                    done: true,
                    message: "Season complete",
                    score: nil,
                    won: nil,
                    record: nil
                )
            }

            state.currentDay = nextDay
            let dayIndexes = state.schedule.enumerated().filter { _, game in !game.completed && game.day == nextDay }.map(\.offset)
            for idx in dayIndexes {
                simulateScheduledGameInState(&state, scheduleIndex: idx)
            }
            prepareConferenceTournamentsIfNeeded(&state)
            pending = nextPendingUserGame(state, userTeamId: userTeamId)
        }

        guard let pending else {
            state.status = "completed"
            return UserGameSummary(
                gameId: nil,
                day: state.currentDay,
                type: nil,
                siteType: nil,
                neutralSite: nil,
                isHome: nil,
                opponentTeamId: nil,
                opponentName: nil,
                completed: true,
                result: nil,
                done: true,
                message: "Season complete",
                score: nil,
                won: nil,
                record: nil
            )
        }

        let simDay = pending.element.day
        let targetGameId = pending.element.gameId

        var nextDayToSim = state.schedule.filter { !$0.completed && $0.day <= simDay }.map(\.day).min()
        while let day = nextDayToSim {
            state.currentDay = day
            let dayIndexes = state.schedule.enumerated().filter { _, game in !game.completed && game.day == day }.map(\.offset)
            for idx in dayIndexes {
                simulateScheduledGameInState(&state, scheduleIndex: idx)
            }
            prepareConferenceTournamentsIfNeeded(&state)
            nextDayToSim = state.schedule.filter { !$0.completed && $0.day <= simDay }.map(\.day).min()
        }

        guard let completedUserGame = state.schedule.first(where: { $0.gameId == targetGameId }) else {
            state.status = "completed"
            return UserGameSummary(
                gameId: nil,
                day: state.currentDay,
                type: nil,
                siteType: nil,
                neutralSite: nil,
                isHome: nil,
                opponentTeamId: nil,
                opponentName: nil,
                completed: true,
                result: nil,
                done: true,
                message: "Season complete",
                score: nil,
                won: nil,
                record: nil
            )
        }
        let summary = userSummaryFromGame(completedUserGame, userTeamId: userTeamId)
        state.userGameHistory.append(summary)

        let user = state.teams.first(where: { $0.teamId == userTeamId })
        let wins = user?.wins ?? 0
        let losses = user?.losses ?? 0

        var out = summary
        out.done = false
        out.message = "Game complete"
        if let result = completedUserGame.result {
            let userScore = completedUserGame.homeTeamId == userTeamId ? result.homeScore : result.awayScore
            let oppScore = completedUserGame.homeTeamId == userTeamId ? result.awayScore : result.homeScore
            out.score = .object([
                "user": .number(Double(userScore)),
                "opponent": .number(Double(oppScore)),
            ])
            out.won = userScore > oppScore
        }
        out.record = .object([
            "wins": .number(Double(wins)),
            "losses": .number(Double(losses)),
        ])
        return out
    }
}

public func getUserCompletedGames(_ league: LeagueState) -> [UserGameSummary] {
    guard let state = LeagueStore.get(league.handle) else { return [] }
    let fromSchedule = getUserSchedule(league).filter { $0.completed == true }
    if !fromSchedule.isEmpty { return fromSchedule }
    return state.userGameHistory
}

public func getCompletedLeagueGames(_ league: LeagueState) -> [LeagueGameSummary] {
    guard let state = LeagueStore.get(league.handle) else { return [] }
    return state.schedule
        .filter(\ .completed)
        .sorted { lhs, rhs in
            if lhs.day != rhs.day { return lhs.day < rhs.day }
            return lhs.gameId < rhs.gameId
        }
        .map(leagueSummaryFromGame)
}

public func getConferenceStandings(_ league: LeagueState, conferenceId: String? = nil) -> [ConferenceStanding] {
    guard let state = LeagueStore.get(league.handle) else { return [] }

    let rows = state.teams
        .filter { team in
            if let conferenceId { return team.conferenceId == conferenceId }
            return true
        }
        .map { team in
            ConferenceStanding(
                teamId: team.teamId,
                teamName: team.teamName,
                conferenceId: team.conferenceId,
                overall: "\(team.wins)-\(team.losses)",
                conference: "\(team.conferenceWins)-\(team.conferenceLosses)",
                wins: team.wins,
                losses: team.losses,
                conferenceWins: team.conferenceWins,
                conferenceLosses: team.conferenceLosses,
                pointsFor: team.pointsFor,
                pointsAgainst: team.pointsAgainst
            )
        }
        .sorted { lhs, rhs in
            if lhs.conferenceWins != rhs.conferenceWins { return lhs.conferenceWins > rhs.conferenceWins }
            if lhs.conferenceLosses != rhs.conferenceLosses { return lhs.conferenceLosses < rhs.conferenceLosses }
            if lhs.wins != rhs.wins { return lhs.wins > rhs.wins }
            if lhs.losses != rhs.losses { return lhs.losses < rhs.losses }
            return lhs.teamName < rhs.teamName
        }

    return rows
}

public func getRankings(_ league: LeagueState, topN: Int = 25) -> LeagueRankings {
    guard let state = LeagueStore.get(league.handle) else {
        return LeagueRankings(topN: topN, seasonProgress: 0, preseasonWeight: 1, inSeasonWeight: 0, rankings: [])
    }

    let maxGamesPlayed = state.teams.map { $0.wins + $0.losses }.max() ?? 0
    let seasonTarget = max(1, state.totalRegularSeasonGames)
    let seasonProgress = clamp(Double(maxGamesPlayed) / Double(seasonTarget), min: 0, max: 1)
    let preseasonWeight = clamp(1 - seasonProgress * 0.9, min: 0.1, max: 1)
    let inSeasonWeight = 1 - preseasonWeight

    var ranked = state.teams.map { team -> LeagueRankingTeam in
        let games = team.wins + team.losses
        let pointDiffPerGame = games > 0 ? Double(team.pointsFor - team.pointsAgainst) / Double(games) : 0
        let winRate = games > 0 ? Double(team.wins) / Double(games) : 0
        let qualityWinRate = clamp(winRate * 0.8 + team.prestige * 0.2, min: 0, max: 1)
        let playerSkill = teamOverall(team.teamModel) / 100
        let coachQuality = coachingQuality(team.teamModel.coachingStaff)
        let strengthOfSchedule = clamp(0.45 + Double(team.targetConferenceGames) / Double(max(1, team.targetGames)) * 0.35, min: 0, max: 1)

        let preseasonScore = playerSkill * 0.45 + coachQuality * 0.25 + team.prestige * 0.2 + team.lastYearResult * 0.1
        let inSeasonScore = winRate * 0.52 + qualityWinRate * 0.2 + clamp((pointDiffPerGame + 20) / 40, min: 0, max: 1) * 0.18 + strengthOfSchedule * 0.1
        let composite = preseasonScore * preseasonWeight + inSeasonScore * inSeasonWeight

        return LeagueRankingTeam(
            rank: 0,
            teamId: team.teamId,
            teamName: team.teamName,
            conferenceId: team.conferenceId,
            record: "\(team.wins)-\(team.losses)",
            wins: team.wins,
            losses: team.losses,
            gamesPlayed: games,
            pointDifferentialPerGame: pointDiffPerGame,
            strengthOfSchedule: strengthOfSchedule,
            qualityWinRate: qualityWinRate,
            playerSkill: playerSkill,
            prestige: team.prestige,
            lastYearResult: team.lastYearResult,
            coachQuality: coachQuality,
            preseasonScore: preseasonScore,
            inSeasonScore: inSeasonScore,
            compositeScore: composite
        )
    }

    ranked.sort { lhs, rhs in
        if lhs.compositeScore != rhs.compositeScore { return lhs.compositeScore > rhs.compositeScore }
        if lhs.wins != rhs.wins { return lhs.wins > rhs.wins }
        if lhs.losses != rhs.losses { return lhs.losses < rhs.losses }
        return lhs.teamName < rhs.teamName
    }

    for idx in ranked.indices {
        ranked[idx].rank = idx + 1
    }

    let top = Array(ranked.prefix(max(1, topN)))
    return LeagueRankings(topN: max(1, topN), seasonProgress: seasonProgress, preseasonWeight: preseasonWeight, inSeasonWeight: inSeasonWeight, rankings: top)
}

public func getLeagueSummary(_ league: LeagueState) -> LeagueSummary {
    guard let state = LeagueStore.get(league.handle), let user = state.teams.first(where: { $0.teamId == state.userTeamId }) else {
        fatalError("getLeagueSummary failed: Unknown league state")
    }

    return LeagueSummary(
        status: state.status,
        currentDay: state.currentDay,
        totalTeams: state.teams.count,
        totalConferences: state.conferences.count,
        userTeamId: state.userTeamId,
        userTeamName: user.teamName,
        requiredUserNonConferenceGames: state.requiredUserNonConferenceGames,
        userSelectedNonConferenceGames: state.userSelectedOpponentIds.count,
        scheduleGenerated: state.scheduleGenerated,
        totalScheduledGames: state.schedule.count
    )
}

public func saveLeagueState(_ league: LeagueState, destinationPath: String, pretty: Bool = true) throws -> (filePath: String, bytes: Int, format: String, version: Int, savedAt: String) {
    guard let state = LeagueStore.get(league.handle) else {
        throw NSError(domain: "CBBCoachCore", code: 1002, userInfo: [NSLocalizedDescriptionKey: "Unknown league handle"])
    }

    struct SavePayload: Codable {
        let format: String
        let version: Int
        let savedAt: String
        let state: LeagueStore.State
    }

    let savedAt = ISO8601DateFormatter().string(from: Date())
    let payload = SavePayload(format: LEAGUE_SAVE_FORMAT, version: LEAGUE_SAVE_VERSION, savedAt: savedAt, state: state)

    let encoder = JSONEncoder()
    if pretty {
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }
    let data = try encoder.encode(payload)

    let url = URL(fileURLWithPath: destinationPath)
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try data.write(to: url)

    return (url.path, data.count, LEAGUE_SAVE_FORMAT, LEAGUE_SAVE_VERSION, savedAt)
}

public func loadLeagueState(_ sourcePath: String) throws -> LeagueState {
    struct SavePayload: Codable {
        let format: String
        let version: Int
        let savedAt: String
        let state: LeagueStore.State
    }

    let url = URL(fileURLWithPath: sourcePath)
    let data = try Data(contentsOf: url)
    let payload = try JSONDecoder().decode(SavePayload.self, from: data)
    guard payload.format == LEAGUE_SAVE_FORMAT else {
        throw NSError(domain: "CBBCoachCore", code: 1003, userInfo: [NSLocalizedDescriptionKey: "Unexpected league save format"])
    }

    let handle = LeagueStore.put(payload.state)
    return LeagueState(handle: handle)
}

private func userSummaryFromGame(_ game: LeagueStore.ScheduledGame, userTeamId: String) -> UserGameSummary {
    let isHome = game.homeTeamId == userTeamId
    let opponentTeamId = isHome ? game.awayTeamId : game.homeTeamId
    let opponentName = isHome ? game.awayTeamName : game.homeTeamName
    let resultValue: JSONValue?
    if let result = game.result {
        var resultObject: [String: JSONValue] = [
            "homeScore": .number(Double(result.homeScore)),
            "awayScore": .number(Double(result.awayScore)),
            "winnerTeamId": result.winnerTeamId.map(JSONValue.string) ?? .null,
            "wentToOvertime": .bool(result.wentToOvertime),
        ]
        if let box = result.boxScore {
            resultObject["boxScore"] = boxScoreJSONValue(box)
        }
        resultValue = .object(resultObject)
    } else {
        resultValue = nil
    }

    return UserGameSummary(
        gameId: game.gameId,
        day: game.day,
        type: game.type,
        siteType: game.siteType,
        neutralSite: game.neutralSite,
        isHome: isHome,
        opponentTeamId: opponentTeamId,
        opponentName: opponentName,
        completed: game.completed,
        result: resultValue,
        done: nil,
        message: nil,
        score: nil,
        won: nil,
        record: nil
    )
}

private func leagueSummaryFromGame(_ game: LeagueStore.ScheduledGame) -> LeagueGameSummary {
    let resultValue: JSONValue?
    if let result = game.result {
        var resultObject: [String: JSONValue] = [
            "homeScore": .number(Double(result.homeScore)),
            "awayScore": .number(Double(result.awayScore)),
            "winnerTeamId": result.winnerTeamId.map(JSONValue.string) ?? .null,
            "wentToOvertime": .bool(result.wentToOvertime),
        ]
        if let box = result.boxScore {
            resultObject["boxScore"] = boxScoreJSONValue(box)
        }
        resultValue = .object(resultObject)
    } else {
        resultValue = nil
    }

    return LeagueGameSummary(
        gameId: game.gameId,
        day: game.day,
        type: game.type,
        siteType: game.siteType,
        neutralSite: game.neutralSite,
        homeTeamId: game.homeTeamId,
        homeTeamName: game.homeTeamName,
        awayTeamId: game.awayTeamId,
        awayTeamName: game.awayTeamName,
        completed: game.completed,
        result: resultValue
    )
}

private func boxScoreJSONValue(_ boxScore: [TeamBoxScore]) -> JSONValue {
    .array(boxScore.map(teamBoxScoreJSONValue))
}

private func teamBoxScoreJSONValue(_ team: TeamBoxScore) -> JSONValue {
    var object: [String: JSONValue] = [
        "name": .string(team.name),
        "players": .array(team.players.map(playerBoxScoreJSONValue)),
    ]
    if let teamExtras = team.teamExtras {
        object["teamExtras"] = .object(teamExtras.mapValues { .number(Double($0)) })
    }
    return .object(object)
}

private func playerBoxScoreJSONValue(_ player: PlayerBoxScore) -> JSONValue {
    .object([
        "playerName": .string(player.playerName),
        "position": .string(player.position),
        "minutes": .number(player.minutes),
        "points": .number(Double(player.points)),
        "fgMade": .number(Double(player.fgMade)),
        "fgAttempts": .number(Double(player.fgAttempts)),
        "threeMade": .number(Double(player.threeMade)),
        "threeAttempts": .number(Double(player.threeAttempts)),
        "ftMade": .number(Double(player.ftMade)),
        "ftAttempts": .number(Double(player.ftAttempts)),
        "rebounds": .number(Double(player.rebounds)),
        "offensiveRebounds": .number(Double(player.offensiveRebounds)),
        "defensiveRebounds": .number(Double(player.defensiveRebounds)),
        "assists": .number(Double(player.assists)),
        "steals": .number(Double(player.steals)),
        "blocks": .number(Double(player.blocks)),
        "turnovers": .number(Double(player.turnovers)),
        "fouls": .number(Double(player.fouls)),
        "plusMinus": player.plusMinus.map { .number(Double($0)) } ?? .null,
        "energy": player.energy.map(JSONValue.number) ?? .null,
    ])
}

private func conferenceTournamentEntrantCount(for teamCount: Int) -> Int {
    for size in [16, 12, 8, 4] where size <= teamCount {
        return size
    }
    return 0
}

private func conferenceTournamentTemplate(entrantCount: Int) -> [[LeagueStore.ConferenceTournamentState.Matchup]] {
    typealias Ref = LeagueStore.ConferenceTournamentState.ParticipantRef
    typealias Matchup = LeagueStore.ConferenceTournamentState.Matchup

    func seed(_ value: Int) -> Ref {
        Ref(seed: value, fromRound: nil, fromGame: nil)
    }

    func winner(_ round: Int, _ game: Int) -> Ref {
        Ref(seed: nil, fromRound: round, fromGame: game)
    }

    switch entrantCount {
    case 4:
        return [
            [Matchup(top: seed(1), bottom: seed(4)), Matchup(top: seed(2), bottom: seed(3))],
            [Matchup(top: winner(0, 0), bottom: winner(0, 1))],
        ]
    case 8:
        return [
            [
                Matchup(top: seed(1), bottom: seed(8)),
                Matchup(top: seed(4), bottom: seed(5)),
                Matchup(top: seed(2), bottom: seed(7)),
                Matchup(top: seed(3), bottom: seed(6)),
            ],
            [Matchup(top: winner(0, 0), bottom: winner(0, 1)), Matchup(top: winner(0, 2), bottom: winner(0, 3))],
            [Matchup(top: winner(1, 0), bottom: winner(1, 1))],
        ]
    case 12:
        return [
            [
                Matchup(top: seed(5), bottom: seed(12)),
                Matchup(top: seed(8), bottom: seed(9)),
                Matchup(top: seed(6), bottom: seed(11)),
                Matchup(top: seed(7), bottom: seed(10)),
            ],
            [
                Matchup(top: seed(1), bottom: winner(0, 1)),
                Matchup(top: seed(4), bottom: winner(0, 0)),
                Matchup(top: seed(2), bottom: winner(0, 3)),
                Matchup(top: seed(3), bottom: winner(0, 2)),
            ],
            [Matchup(top: winner(1, 0), bottom: winner(1, 1)), Matchup(top: winner(1, 2), bottom: winner(1, 3))],
            [Matchup(top: winner(2, 0), bottom: winner(2, 1))],
        ]
    case 16:
        return [
            [
                Matchup(top: seed(1), bottom: seed(16)),
                Matchup(top: seed(8), bottom: seed(9)),
                Matchup(top: seed(5), bottom: seed(12)),
                Matchup(top: seed(4), bottom: seed(13)),
                Matchup(top: seed(6), bottom: seed(11)),
                Matchup(top: seed(3), bottom: seed(14)),
                Matchup(top: seed(7), bottom: seed(10)),
                Matchup(top: seed(2), bottom: seed(15)),
            ],
            [
                Matchup(top: winner(0, 0), bottom: winner(0, 1)),
                Matchup(top: winner(0, 2), bottom: winner(0, 3)),
                Matchup(top: winner(0, 4), bottom: winner(0, 5)),
                Matchup(top: winner(0, 6), bottom: winner(0, 7)),
            ],
            [Matchup(top: winner(1, 0), bottom: winner(1, 1)), Matchup(top: winner(1, 2), bottom: winner(1, 3))],
            [Matchup(top: winner(2, 0), bottom: winner(2, 1))],
        ]
    default:
        return []
    }
}

private func sortedConferenceTeamIdsForSeeding(_ state: LeagueStore.State, conferenceId: String) -> [String] {
    state.teams
        .filter { $0.conferenceId == conferenceId }
        .sorted { lhs, rhs in
            if lhs.conferenceWins != rhs.conferenceWins { return lhs.conferenceWins > rhs.conferenceWins }
            if lhs.conferenceLosses != rhs.conferenceLosses { return lhs.conferenceLosses < rhs.conferenceLosses }
            if lhs.wins != rhs.wins { return lhs.wins > rhs.wins }
            if lhs.losses != rhs.losses { return lhs.losses < rhs.losses }
            return lhs.teamName < rhs.teamName
        }
        .map(\.teamId)
}

private func isRegularSeasonComplete(_ state: LeagueStore.State) -> Bool {
    let regularGames = state.schedule.filter { $0.type == "regular_season" }
    guard !regularGames.isEmpty else { return false }
    return regularGames.allSatisfy(\.completed)
}

private func prepareConferenceTournamentsIfNeeded(_ state: inout LeagueStore.State) {
    guard isRegularSeasonComplete(state) else { return }

    if state.conferenceTournaments == nil {
        state.conferenceTournaments = state.conferences.compactMap { conference in
            let sortedIds = sortedConferenceTeamIdsForSeeding(state, conferenceId: conference.id)
            let entrantCount = conferenceTournamentEntrantCount(for: sortedIds.count)
            guard entrantCount >= 4 else { return nil }

            let entrants = Array(sortedIds.prefix(entrantCount))
            let rounds = conferenceTournamentTemplate(entrantCount: entrantCount)
            guard !rounds.isEmpty else { return nil }

            return LeagueStore.ConferenceTournamentState(
                conferenceId: conference.id,
                conferenceName: conference.name,
                entrantTeamIds: entrants,
                rounds: rounds,
                winnersByRound: rounds.map { Array(repeating: nil, count: $0.count) },
                scheduledRoundCount: 0
            )
        }
    }

    appendReadyConferenceTournamentRoundsInState(&state)
}

private func appendReadyConferenceTournamentRoundsInState(_ state: inout LeagueStore.State) {
    guard var tournaments = state.conferenceTournaments, !tournaments.isEmpty else { return }

    let teamById = Dictionary(uniqueKeysWithValues: state.teams.map { ($0.teamId, $0) })
    var appendedAnyGames = false

    for tournamentIndex in tournaments.indices {
        let roundIndex = tournaments[tournamentIndex].scheduledRoundCount
        guard roundIndex < tournaments[tournamentIndex].rounds.count else { continue }

        let round = tournaments[tournamentIndex].rounds[roundIndex]
        var resolved: [(homeId: String, awayId: String, gameIndex: Int)] = []
        resolved.reserveCapacity(round.count)

        for gameIndex in round.indices {
            let matchup = round[gameIndex]
            guard
                let topTeamId = resolveConferenceTournamentParticipantTeamId(
                    tournament: tournaments[tournamentIndex],
                    participant: matchup.top
                ),
                let bottomTeamId = resolveConferenceTournamentParticipantTeamId(
                    tournament: tournaments[tournamentIndex],
                    participant: matchup.bottom
                )
            else {
                resolved.removeAll(keepingCapacity: false)
                break
            }
            resolved.append((homeId: topTeamId, awayId: bottomTeamId, gameIndex: gameIndex))
        }

        guard resolved.count == round.count else { continue }

        let day = state.totalRegularSeasonGames + 1 + roundIndex
        for game in resolved {
            guard let homeTeam = teamById[game.homeId], let awayTeam = teamById[game.awayId] else { continue }

            state.schedule.append(
                LeagueStore.ScheduledGame(
                    gameId: "ct_\(tournaments[tournamentIndex].conferenceId)_r\(roundIndex + 1)_g\(game.gameIndex + 1)",
                    day: day,
                    type: "conference_tournament",
                    siteType: "neutral",
                    neutralSite: true,
                    homeTeamId: homeTeam.teamId,
                    homeTeamName: homeTeam.teamName,
                    awayTeamId: awayTeam.teamId,
                    awayTeamName: awayTeam.teamName,
                    conferenceId: tournaments[tournamentIndex].conferenceId,
                    tournamentRound: roundIndex,
                    tournamentGameIndex: game.gameIndex,
                    completed: false,
                    result: nil
                )
            )
            appendedAnyGames = true
        }

        tournaments[tournamentIndex].scheduledRoundCount += 1
    }

    if appendedAnyGames {
        state.schedule.sort {
            if $0.day != $1.day { return $0.day < $1.day }
            return $0.gameId < $1.gameId
        }
    }
    state.conferenceTournaments = tournaments
}

private func resolveConferenceTournamentParticipantTeamId(
    tournament: LeagueStore.ConferenceTournamentState,
    participant: LeagueStore.ConferenceTournamentState.ParticipantRef
) -> String? {
    if let seed = participant.seed, seed > 0, seed <= tournament.entrantTeamIds.count {
        return tournament.entrantTeamIds[seed - 1]
    }

    guard
        let fromRound = participant.fromRound,
        let fromGame = participant.fromGame,
        fromRound >= 0,
        fromRound < tournament.winnersByRound.count,
        fromGame >= 0,
        fromGame < tournament.winnersByRound[fromRound].count
    else {
        return nil
    }

    return tournament.winnersByRound[fromRound][fromGame]
}

private func recordConferenceTournamentWinner(
    _ state: inout LeagueStore.State,
    conferenceId: String,
    roundIndex: Int,
    gameIndex: Int,
    winnerTeamId: String?
) {
    guard let winnerTeamId else { return }
    guard var tournaments = state.conferenceTournaments else { return }
    guard let tournamentIndex = tournaments.firstIndex(where: { $0.conferenceId == conferenceId }) else { return }
    guard roundIndex >= 0, roundIndex < tournaments[tournamentIndex].winnersByRound.count else { return }
    guard gameIndex >= 0, gameIndex < tournaments[tournamentIndex].winnersByRound[roundIndex].count else { return }

    tournaments[tournamentIndex].winnersByRound[roundIndex][gameIndex] = winnerTeamId
    state.conferenceTournaments = tournaments
}

private func autoFillUserNonConferenceOpponentsInState(_ state: inout LeagueStore.State, seed: String) {
    guard let user = state.teams.first(where: { $0.teamId == state.userTeamId }) else { return }
    var random = SeededRandom(seed: hashString("\(state.optionsSeed):\(seed):\(state.userTeamId)"))
    let pool = state.teams
        .filter { $0.teamId != user.teamId && $0.conferenceId != user.conferenceId }
        .map(\ .teamId)

    var selected: [String] = []
    var mutablePool = pool
    while selected.count < state.requiredUserNonConferenceGames, !mutablePool.isEmpty {
        let idx = random.int(0, mutablePool.count - 1)
        selected.append(mutablePool.remove(at: idx))
    }

    state.userSelectedOpponentIds = selected
}

private func generateSeasonScheduleInState(_ state: inout LeagueStore.State) {
    state.schedule.removeAll(keepingCapacity: true)
    state.userGameHistory.removeAll(keepingCapacity: true)
    state.conferenceTournaments = nil
    resetTeamRecords(&state)

    guard let user = state.teams.first(where: { $0.teamId == state.userTeamId }) else {
        state.scheduleGenerated = false
        return
    }

    let confOpponents = state.teams
        .filter { $0.conferenceId == user.conferenceId && $0.teamId != user.teamId }
        .map(\ .teamId)

    var random = SeededRandom(seed: hashString("schedule:\(state.optionsSeed):\(user.teamId)"))
    var userOpponents: [String] = []

    var nonConf = state.userSelectedOpponentIds
    if nonConf.count < state.requiredUserNonConferenceGames {
        let remainingPool = state.teams
            .filter { $0.teamId != user.teamId && $0.conferenceId != user.conferenceId && !nonConf.contains($0.teamId) }
            .map(\ .teamId)
        var pool = remainingPool
        while nonConf.count < state.requiredUserNonConferenceGames, !pool.isEmpty {
            let idx = random.int(0, pool.count - 1)
            nonConf.append(pool.remove(at: idx))
        }
    }

    // Play non-conference games first, then conference games.
    userOpponents.append(contentsOf: nonConf.prefix(max(0, state.totalRegularSeasonGames - userOpponents.count)))

    let confGames = min(user.targetConferenceGames, state.totalRegularSeasonGames)
    if !confOpponents.isEmpty {
        var i = 0
        while userOpponents.count < state.totalRegularSeasonGames, i < confGames {
            userOpponents.append(confOpponents[i % confOpponents.count])
            i += 1
        }
    }

    let fillerPool = state.teams.filter { $0.teamId != user.teamId }.map(\ .teamId)
    var fillerIndex = 0
    while userOpponents.count < state.totalRegularSeasonGames, !fillerPool.isEmpty {
        userOpponents.append(fillerPool[fillerIndex % fillerPool.count])
        fillerIndex += 1
    }

    let teamById = Dictionary(uniqueKeysWithValues: state.teams.map { ($0.teamId, $0) })

    for (index, opponentId) in userOpponents.enumerated() {
        guard let opp = teamById[opponentId] else { continue }
        let day = index + 1
        let userHome = random.nextUnit() < 0.52
        let homeId = userHome ? user.teamId : opp.teamId
        let awayId = userHome ? opp.teamId : user.teamId
        let homeName = userHome ? user.teamName : opp.teamName
        let awayName = userHome ? opp.teamName : user.teamName
        state.schedule.append(
            LeagueStore.ScheduledGame(
                gameId: "g_\(day)_user",
                day: day,
                type: "regular_season",
                siteType: userHome ? "home" : "away",
                neutralSite: false,
                homeTeamId: homeId,
                homeTeamName: homeName,
                awayTeamId: awayId,
                awayTeamName: awayName,
                conferenceId: nil,
                tournamentRound: nil,
                tournamentGameIndex: nil,
                completed: false,
                result: nil
            )
        )

        var availableCPUIds = state.teams
            .map(\.teamId)
            .filter { $0 != user.teamId && $0 != opp.teamId }

        if availableCPUIds.count >= 2 {
            var dayRandom = SeededRandom(seed: hashString("schedule:\(state.optionsSeed):day:\(day)"))
            for idx in stride(from: availableCPUIds.count - 1, through: 1, by: -1) {
                let swapIdx = dayRandom.int(0, idx)
                if swapIdx != idx {
                    availableCPUIds.swapAt(idx, swapIdx)
                }
            }

            var gameNumber = 1
            var pairIndex = 0
            while pairIndex + 1 < availableCPUIds.count {
                let teamAId = availableCPUIds[pairIndex]
                let teamBId = availableCPUIds[pairIndex + 1]
                pairIndex += 2

                guard
                    let teamA = teamById[teamAId],
                    let teamB = teamById[teamBId]
                else {
                    continue
                }

                let teamAHome = dayRandom.nextUnit() < 0.5
                let homeTeam = teamAHome ? teamA : teamB
                let awayTeam = teamAHome ? teamB : teamA

                state.schedule.append(
                    LeagueStore.ScheduledGame(
                        gameId: "g_\(day)_cpu_\(gameNumber)",
                        day: day,
                        type: "regular_season",
                        siteType: "home",
                        neutralSite: false,
                        homeTeamId: homeTeam.teamId,
                        homeTeamName: homeTeam.teamName,
                        awayTeamId: awayTeam.teamId,
                        awayTeamName: awayTeam.teamName,
                        conferenceId: nil,
                        tournamentRound: nil,
                        tournamentGameIndex: nil,
                        completed: false,
                        result: nil
                    )
                )
                gameNumber += 1
            }
        }
    }

    state.schedule.sort {
        if $0.day != $1.day { return $0.day < $1.day }
        return $0.gameId < $1.gameId
    }
    state.scheduleGenerated = true
    state.currentDay = 0
    state.status = "in_progress"
}

private func simulateScheduledGameInState(_ state: inout LeagueStore.State, scheduleIndex: Int) {
    guard scheduleIndex >= 0, scheduleIndex < state.schedule.count else { return }
    guard !state.schedule[scheduleIndex].completed else { return }

    let game = state.schedule[scheduleIndex]
    guard
        let homeIndex = state.teams.firstIndex(where: { $0.teamId == game.homeTeamId }),
        let awayIndex = state.teams.firstIndex(where: { $0.teamId == game.awayTeamId })
    else {
        return
    }

    var random = SeededRandom(seed: hashString("sim:\(state.optionsSeed):\(game.gameId)"))
    var homeTeam = state.teams[homeIndex].teamModel
    var awayTeam = state.teams[awayIndex].teamModel
    applyPreGameModifiers(team: &homeTeam, isHome: !game.neutralSite)
    applyPreGameModifiers(team: &awayTeam, isHome: false)
    let result = simulateGame(
        homeTeam: homeTeam,
        awayTeam: awayTeam,
        random: &random,
        includePlayByPlay: false
    )

    var homeScore = result.home.score
    var awayScore = result.away.score
    if game.type == "conference_tournament", homeScore == awayScore {
        if random.nextUnit() < 0.5 {
            homeScore += 1
        } else {
            awayScore += 1
        }
    }
    let winnerTeamId: String?
    if homeScore == awayScore {
        winnerTeamId = nil
    } else {
        winnerTeamId = homeScore > awayScore ? game.homeTeamId : game.awayTeamId
    }

    state.schedule[scheduleIndex].completed = true
    state.schedule[scheduleIndex].result = LeagueStore.GameResult(
        homeScore: homeScore,
        awayScore: awayScore,
        winnerTeamId: winnerTeamId,
        wentToOvertime: result.wentToOvertime,
        boxScore: result.boxScore
    )

    state.teams[homeIndex].pointsFor += homeScore
    state.teams[homeIndex].pointsAgainst += awayScore
    state.teams[awayIndex].pointsFor += awayScore
    state.teams[awayIndex].pointsAgainst += homeScore

    let isConference = state.teams[homeIndex].conferenceId == state.teams[awayIndex].conferenceId
    let updatesConferenceStandings = isConference && game.type == "regular_season"

    if homeScore > awayScore {
        state.teams[homeIndex].wins += 1
        state.teams[awayIndex].losses += 1
        if updatesConferenceStandings {
            state.teams[homeIndex].conferenceWins += 1
            state.teams[awayIndex].conferenceLosses += 1
        }
    } else if awayScore > homeScore {
        state.teams[awayIndex].wins += 1
        state.teams[homeIndex].losses += 1
        if updatesConferenceStandings {
            state.teams[awayIndex].conferenceWins += 1
            state.teams[homeIndex].conferenceLosses += 1
        }
    }

    if game.type == "conference_tournament",
       let conferenceId = game.conferenceId,
       let roundIndex = game.tournamentRound,
       let gameIndex = game.tournamentGameIndex {
        recordConferenceTournamentWinner(
            &state,
            conferenceId: conferenceId,
            roundIndex: roundIndex,
            gameIndex: gameIndex,
            winnerTeamId: winnerTeamId
        )
    }
}

private func resetTeamRecords(_ state: inout LeagueStore.State) {
    for idx in state.teams.indices {
        state.teams[idx].wins = 0
        state.teams[idx].losses = 0
        state.teams[idx].conferenceWins = 0
        state.teams[idx].conferenceLosses = 0
        state.teams[idx].pointsFor = 0
        state.teams[idx].pointsAgainst = 0
    }
}

private func prestigeForTeam(teamId: String, conferenceId: String) -> Double {
    let historical = historicalPrestigeByTeamId[teamId]
        ?? clamp(historicalConferenceBaseline(for: conferenceId) + deterministicSpread(teamId: teamId, salt: "hist", amplitude: 0.12), min: 0.22, max: 0.85)
    let recent = recentSuccessByTeamId[teamId]
        ?? clamp(recentConferenceBaseline(for: conferenceId) + deterministicSpread(teamId: teamId, salt: "recent", amplitude: 0.18), min: 0.18, max: 0.9)
    return clamp(historical * 0.7 + recent * 0.3, min: 0.2, max: 0.98)
}

private func lastYearResultForTeam(teamId: String, conferenceId: String) -> Double {
    let recent = recentSuccessByTeamId[teamId]
        ?? clamp(recentConferenceBaseline(for: conferenceId) + deterministicSpread(teamId: teamId, salt: "recent", amplitude: 0.18), min: 0.18, max: 0.9)
    let yearToYearForm = deterministicSpread(teamId: teamId, salt: "last-year", amplitude: 0.12)
    return clamp(recent * 0.9 + yearToYearForm, min: 0.12, max: 0.98)
}

private func historicalConferenceBaseline(for conferenceId: String) -> Double {
    switch conferenceId {
    case "acc", "big-12", "big-east", "big-ten", "sec":
        return 0.58
    case "atlantic-10", "american", "mountain-west", "mvc", "wcc":
        return 0.47
    case "america-east", "asun", "big-sky", "big-south", "big-west", "caa", "cusa", "horizon", "ivy-league", "maac", "mac", "meac", "nec", "ovc", "patriot", "socon", "southland", "summit-league", "sun-belt", "swac", "wac":
        return 0.36
    default:
        return 0.36
    }
}

private func recentConferenceBaseline(for conferenceId: String) -> Double {
    switch conferenceId {
    case "acc", "big-12", "big-east", "big-ten", "sec":
        return 0.56
    case "atlantic-10", "american", "mountain-west", "mvc", "wcc":
        return 0.48
    case "america-east", "asun", "big-sky", "big-south", "big-west", "caa", "cusa", "horizon", "ivy-league", "maac", "mac", "meac", "nec", "ovc", "patriot", "socon", "southland", "summit-league", "sun-belt", "swac", "wac":
        return 0.39
    default:
        return 0.39
    }
}

private func deterministicSpread(teamId: String, salt: String, amplitude: Double) -> Double {
    var random = SeededRandom(seed: hashString("\(salt):\(teamId)"))
    let centered = random.nextUnit() - 0.5
    return centered * amplitude
}

private let historicalPrestigeByTeamId: [String: Double] = [
    "big-12-kansas": 0.99,
    "sec-kentucky": 0.99,
    "acc-duke": 0.98,
    "acc-north-carolina": 0.98,
    "big-ten-ucla": 0.98,
    "big-ten-indiana": 0.95,
    "big-east-uconn": 0.95,
    "big-east-villanova": 0.92,
    "acc-louisville": 0.91,
    "acc-syracuse": 0.9,
    "big-12-arizona": 0.9,
    "big-ten-michigan-st": 0.9,
    "big-ten-purdue": 0.88,
    "acc-virginia": 0.88,
    "sec-florida": 0.87,
    "big-ten-michigan": 0.87,
    "big-east-georgetown": 0.86,
    "sec-arkansas": 0.85,
    "sec-tennessee": 0.85,
    "sec-alabama": 0.84,
    "big-east-st-john-and-039-s-ny": 0.84,
    "big-12-baylor": 0.84,
    "sec-lsu": 0.84,
    "acc-notre-dame": 0.83,
    "big-east-xavier": 0.83,
    "big-east-providence": 0.82,
    "big-east-seton-hall": 0.81,
    "big-east-marquette": 0.81,
    "big-east-creighton": 0.8,
    "big-12-houston": 0.8,
    "wcc-gonzaga": 0.8,
    "sec-texas": 0.8,
    "sec-texas-a-and-amp-m": 0.8,
    "acc-nc-state": 0.79,
    "big-ten-ohio-st": 0.79,
    "acc-florida-st": 0.78,
    "sec-auburn": 0.78,
    "acc-pittsburgh": 0.77,
    "sec-oklahoma": 0.77,
    "big-12-west-virginia": 0.77,
    "big-12-texas-tech": 0.77,
    "big-12-kansas-st": 0.76,
    "big-12-iowa-st": 0.76,
    "big-ten-illinois": 0.76,
    "big-ten-wisconsin": 0.76,
    "big-ten-maryland": 0.75,
    "sec-mississippi-st": 0.74,
    "sec-ole-miss": 0.73,
    "american-memphis": 0.73,
    "mountain-west-san-diego-st": 0.73,
    "atlantic-10-dayton": 0.72,
    "atlantic-10-vcu": 0.71,
    "mountain-west-utah-st": 0.7,
    "mountain-west-boise-st": 0.7,
    "mountain-west-new-mexico": 0.7,
    "wcc-san-francisco": 0.69,
    "big-east-butler": 0.69,
    "big-12-byu": 0.69,
    "big-12-tcu": 0.68,
    "big-12-utah": 0.66,
]

private let recentSuccessByTeamId: [String: Double] = [
    "big-east-uconn": 0.98,
    "big-12-houston": 0.95,
    "sec-alabama": 0.93,
    "big-12-baylor": 0.92,
    "big-12-kansas": 0.92,
    "sec-auburn": 0.91,
    "big-ten-purdue": 0.91,
    "sec-tennessee": 0.9,
    "wcc-gonzaga": 0.9,
    "big-east-marquette": 0.89,
    "big-east-creighton": 0.88,
    "big-12-arizona": 0.88,
    "big-12-iowa-st": 0.88,
    "big-ten-illinois": 0.87,
    "acc-duke": 0.87,
    "acc-north-carolina": 0.87,
    "sec-kentucky": 0.86,
    "sec-florida": 0.86,
    "sec-arkansas": 0.85,
    "big-ten-michigan-st": 0.85,
    "big-ten-ucla": 0.84,
    "big-ten-wisconsin": 0.84,
    "big-12-texas-tech": 0.84,
    "big-12-byu": 0.83,
    "sec-texas-a-and-amp-m": 0.83,
    "acc-clemson": 0.83,
    "acc-louisville": 0.82,
    "acc-virginia": 0.82,
    "acc-miami-fl": 0.82,
    "sec-mississippi-st": 0.82,
    "sec-ole-miss": 0.81,
    "sec-missouri": 0.8,
    "sec-oklahoma": 0.79,
    "sec-texas": 0.79,
    "big-ten-maryland": 0.78,
    "big-ten-oregon": 0.78,
    "big-ten-southern-california": 0.77,
    "big-12-tcu": 0.77,
    "big-12-kansas-st": 0.77,
    "big-12-west-virginia": 0.76,
    "big-east-st-john-and-039-s-ny": 0.76,
    "big-east-xavier": 0.75,
    "big-east-providence": 0.74,
    "big-east-villanova": 0.74,
    "american-memphis": 0.74,
    "american-fla-atlantic": 0.73,
    "mountain-west-san-diego-st": 0.73,
    "mountain-west-utah-st": 0.72,
    "mountain-west-new-mexico": 0.72,
    "mountain-west-boise-st": 0.71,
    "mountain-west-nevada": 0.7,
    "atlantic-10-dayton": 0.7,
    "atlantic-10-vcu": 0.69,
    "atlantic-10-loyola-chicago": 0.67,
    "mvc-drake": 0.67,
    "southland-mcneese": 0.66,
    "mountain-west-grand-canyon": 0.66,
]

private let rosterFirstNames: [String] = [
    "Jalen", "Marcus", "Eli", "Noah", "Ty", "Jordan", "Malik", "Darius", "Caleb", "Cameron",
    "Anthony", "Isaiah", "Trey", "Xavier", "Devin", "Brandon", "Tyler", "Kyle", "Jaden", "Amir",
    "Tariq", "Zion", "Khalil", "Keenan", "Jace", "Tristan", "Evan", "Gabe", "Micah", "Elijah",
    "Julian", "Omar", "Rashid", "Desmond", "Terrance", "DeAndre", "Bryce", "Chase", "Grant", "Hunter",
    "Jaxon", "Kai", "Luka", "Mason", "Nate", "Parker", "Quincy", "Reggie", "Silas", "Tobias",
    "Victor", "Wyatt", "Andre", "Bo", "Chris", "Dante", "Emmett", "Finn", "Garrett", "Hakeem",
    "Ivan", "Jamal", "Kendrick", "Lamar", "Miles", "Nico", "Owen", "Preston", "Raheem", "Solomon"
]

private let rosterLastNames: [String] = [
    "Carter", "Brooks", "Davis", "Coleman", "Thomas", "Hill", "Moore", "Young", "Turner", "Jenkins",
    "Washington", "Johnson", "Williams", "Jackson", "Harris", "Martin", "Thompson", "Robinson", "Clark", "Lewis",
    "Walker", "Hall", "Allen", "Wright", "Scott", "Green", "Baker", "Adams", "Nelson", "Hill",
    "Mitchell", "Campbell", "Roberts", "Phillips", "Evans", "Parker", "Edwards", "Collins", "Stewart", "Morris",
    "Rogers", "Reed", "Cook", "Bell", "Bailey", "Rivera", "Cooper", "Richardson", "Cox", "Howard",
    "Ward", "Torres", "Peterson", "Gray", "Ramirez", "James", "Watson", "Kim", "Price", "Bennett",
    "Wood", "Barnes", "Ross", "Henderson", "Coleman", "Jenkins", "Perry", "Powell", "Long", "Patterson"
]

private func buildTeamRoster(teamName: String, prestige: Double, random: inout SeededRandom) -> [Player] {
    let positionCycle: [PlayerPosition] = [.pg, .sg, .sf, .pf, .c, .cg, .wing, .f, .big, .pg, .sg, .sf, .pf]
    let yearCycle: [PlayerYear] = [.fr, .so, .jr, .sr]
    let normalizedPrestige = clamp(prestige, min: 0, max: 1)
    let teamQualityBaseline = Int((56 + normalizedPrestige * 14).rounded())
    let lowPrestigeLift = Int(((1 - normalizedPrestige) * 2).rounded())
    let teamVariance = random.int(-5, 5)

    var usedNames = Set<String>()
    return (0..<13).map { idx in
        var player = createPlayer()
        var name = ""
        repeat {
            let first = rosterFirstNames[random.int(0, rosterFirstNames.count - 1)]
            let last = rosterLastNames[random.int(0, rosterLastNames.count - 1)]
            name = "\(first) \(last)"
        } while usedNames.contains(name)
        usedNames.insert(name)
        player.bio.name = name
        player.bio.position = positionCycle[idx % positionCycle.count]
        player.bio.year = yearCycle[idx % yearCycle.count]
        player.bio.home = ["CA", "TX", "FL", "NY", "NC", "IL", "GA", "PA"][idx % 8]
        player.bio.redshirtUsed = false

        let tierAdjustment: Int
        switch idx {
        case 0...2: tierAdjustment = random.int(2, 14)
        case 3...7: tierAdjustment = random.int(-6, 8)
        default: tierAdjustment = random.int(-14, 6)
        }
        let base = clamp(teamQualityBaseline + lowPrestigeLift + teamVariance + tierAdjustment + random.int(-14, 14), min: 42, max: 93)
        player.bio.potential = clamp(base + random.int(-7, 15), min: 30, max: 99)
        applyRatings(&player, base: base, random: &random)

        let height = sampleHeightInches(for: player.bio.position, random: &random)
        player.size.height = formatHeight(inches: height)
        player.size.weight = "\(sampleWeightPounds(for: player.bio.position, heightInches: height, random: &random))"
        let wingspan = height + sampleWingspanDelta(for: player.bio.position, random: &random)
        player.size.wingspan = formatHeight(inches: wingspan)

        player.condition.energy = 100
        player.condition.clutchTime = false
        player.condition.fouledOut = false
        player.condition.homeCourtMultiplier = 1
        player.condition.possessionRole = nil
        player.condition.offensiveCoachingModifier = 1
        player.condition.defensiveCoachingModifier = 1
        return player
    }
}

private struct HeightBucket {
    let inches: Int
    let weight: Int
}

private func sampleHeightInches(for position: PlayerPosition, random: inout SeededRandom) -> Int {
    let minHeight: Int
    let maxHeight: Int
    let buckets: [HeightBucket]

    switch position {
    case .pg:
        minHeight = 69; maxHeight = 77
        buckets = [.init(inches: 71, weight: 2), .init(inches: 72, weight: 4), .init(inches: 73, weight: 4), .init(inches: 74, weight: 3), .init(inches: 75, weight: 1)]
    case .sg:
        minHeight = 70; maxHeight = 79
        buckets = [.init(inches: 72, weight: 2), .init(inches: 73, weight: 3), .init(inches: 74, weight: 4), .init(inches: 75, weight: 3), .init(inches: 76, weight: 2)]
    case .cg:
        minHeight = 70; maxHeight = 78
        buckets = [.init(inches: 72, weight: 2), .init(inches: 73, weight: 4), .init(inches: 74, weight: 4), .init(inches: 75, weight: 3), .init(inches: 76, weight: 1)]
    case .sf, .wing:
        minHeight = 72; maxHeight = 81
        buckets = [.init(inches: 74, weight: 2), .init(inches: 75, weight: 3), .init(inches: 76, weight: 4), .init(inches: 77, weight: 3), .init(inches: 78, weight: 2)]
    case .f:
        minHeight = 74; maxHeight = 82
        buckets = [.init(inches: 76, weight: 2), .init(inches: 77, weight: 3), .init(inches: 78, weight: 4), .init(inches: 79, weight: 3), .init(inches: 80, weight: 1)]
    case .pf:
        minHeight = 75; maxHeight = 84
        buckets = [.init(inches: 77, weight: 2), .init(inches: 78, weight: 3), .init(inches: 79, weight: 4), .init(inches: 80, weight: 3), .init(inches: 81, weight: 1)]
    case .c, .big:
        minHeight = 77; maxHeight = 85
        buckets = [.init(inches: 79, weight: 2), .init(inches: 80, weight: 4), .init(inches: 81, weight: 4), .init(inches: 82, weight: 3), .init(inches: 83, weight: 1)]
    }

    let sampled = sampleWeightedHeight(buckets, random: &random) + random.int(-1, 1)
    return clamp(sampled, min: minHeight, max: maxHeight)
}

private func sampleWeightedHeight(_ buckets: [HeightBucket], random: inout SeededRandom) -> Int {
    let total = buckets.reduce(0) { $0 + max(1, $1.weight) }
    guard total > 0 else { return 76 }
    var pick = random.int(1, total)
    for bucket in buckets {
        pick -= max(1, bucket.weight)
        if pick <= 0 { return bucket.inches }
    }
    return buckets.last?.inches ?? 76
}

private func sampleWeightPounds(for position: PlayerPosition, heightInches: Int, random: inout SeededRandom) -> Int {
    let weight: Int
    switch position {
    case .pg, .cg:
        weight = 170 + (heightInches - 72) * 8 + random.int(-10, 12)
        return clamp(weight, min: 155, max: 220)
    case .sg:
        weight = 180 + (heightInches - 74) * 9 + random.int(-10, 14)
        return clamp(weight, min: 165, max: 230)
    case .sf, .wing:
        weight = 195 + (heightInches - 76) * 10 + random.int(-12, 14)
        return clamp(weight, min: 180, max: 245)
    case .f, .pf:
        weight = 212 + (heightInches - 78) * 11 + random.int(-12, 16)
        return clamp(weight, min: 195, max: 265)
    case .c, .big:
        weight = 228 + (heightInches - 80) * 12 + random.int(-14, 18)
        return clamp(weight, min: 215, max: 290)
    }
}

private func sampleWingspanDelta(for position: PlayerPosition, random: inout SeededRandom) -> Int {
    switch position {
    case .pg, .sg, .cg:
        return random.int(2, 6)
    case .sf, .wing, .f:
        return random.int(3, 7)
    case .pf, .c, .big:
        return random.int(4, 9)
    }
}

private func formatHeight(inches: Int) -> String {
    "\(inches / 12)-\(inches % 12)"
}

private func applyRatings(_ player: inout Player, base: Int, random: inout SeededRandom) {
    func r(_ delta: Int = 0) -> Int { clamp(base + delta + random.int(-11, 11), min: 25, max: 99) }

    player.athleticism.speed = r(2)
    player.athleticism.agility = r(1)
    player.athleticism.burst = r(1)
    player.athleticism.strength = r(-1)
    player.athleticism.vertical = r(0)
    player.athleticism.stamina = r(4)
    player.athleticism.durability = r(3)

    player.shooting.layups = r(3)
    player.shooting.dunks = r(-1)
    player.shooting.closeShot = r(2)
    player.shooting.midrangeShot = r(1)
    player.shooting.threePointShooting = r(0)
    player.shooting.cornerThrees = r(1)
    player.shooting.upTopThrees = r(0)
    player.shooting.drawFoul = r(-1)
    player.shooting.freeThrows = r(2)

    player.postGame.postControl = r(-1)
    player.postGame.postFadeaways = r(-2)
    player.postGame.postHooks = r(-2)

    player.skills.ballHandling = r(1)
    player.skills.ballSafety = r(0)
    player.skills.passingAccuracy = r(1)
    player.skills.passingVision = r(0)
    player.skills.passingIQ = r(1)
    player.skills.shotIQ = r(2)
    player.skills.offballOffense = r(1)
    player.skills.hands = r(0)
    player.skills.hustle = r(2)
    player.skills.clutch = r(0)

    player.defense.perimeterDefense = r(1)
    player.defense.postDefense = r(0)
    player.defense.shotBlocking = r(-2)
    player.defense.shotContest = r(0)
    player.defense.steals = r(0)
    player.defense.lateralQuickness = r(1)
    player.defense.offballDefense = r(1)
    player.defense.passPerception = r(1)
    player.defense.defensiveControl = r(1)

    player.rebounding.offensiveRebounding = r(-1)
    player.rebounding.defensiveRebound = r(0)
    player.rebounding.boxouts = r(0)

    player.tendencies.post = r(-2)
    player.tendencies.inside = r(2)
    player.tendencies.midrange = r(0)
    player.tendencies.threePoint = r(0)
    player.tendencies.drive = r(1)
    player.tendencies.pickAndRoll = r(1)
    player.tendencies.pickAndPop = r(0)
    let shootVsPassBase: Int
    switch player.bio.position {
    case .pg:
        shootVsPassBase = 43
    case .cg:
        shootVsPassBase = 47
    case .sg:
        shootVsPassBase = 50
    case .sf, .wing:
        shootVsPassBase = 52
    case .f, .pf:
        shootVsPassBase = 54
    case .c, .big:
        shootVsPassBase = 56
    }
    player.tendencies.shootVsPass = clamp(shootVsPassBase + random.int(-8, 8), min: 25, max: 99)
}

private func playerOverall(_ player: Player) -> Int {
    let values = [
        player.skills.shotIQ,
        player.skills.ballHandling,
        player.skills.passingIQ,
        player.shooting.threePointShooting,
        player.shooting.midrangeShot,
        player.shooting.closeShot,
        player.defense.perimeterDefense,
        player.defense.postDefense,
        player.rebounding.defensiveRebound,
        player.athleticism.speed,
        player.athleticism.agility,
    ]
    let avg = Double(values.reduce(0, +)) / Double(values.count)
    return clamp(Int(avg.rounded()), min: 1, max: 99)
}

private func teamOverall(_ team: Team) -> Double {
    guard !team.players.isEmpty else { return 50 }
    let avg = team.players.map(playerOverall).reduce(0, +) / team.players.count
    return Double(avg)
}

private func coachingQuality(_ staff: CoachingStaff) -> Double {
    func coachSkill(_ coach: Coach) -> Double {
        let values = [
            coach.skills.playerDevelopment,
            coach.skills.guardDevelopment,
            coach.skills.wingDevelopment,
            coach.skills.bigDevelopment,
            coach.skills.offensiveCoaching,
            coach.skills.defensiveCoaching,
            coach.skills.scouting,
            coach.skills.recruiting,
        ]
        return Double(values.reduce(0, +)) / Double(values.count)
    }

    let head = coachSkill(staff.headCoach)
    let assistantAvg = staff.assistants.isEmpty ? head : staff.assistants.map(coachSkill).reduce(0, +) / Double(staff.assistants.count)
    return clamp((head * 0.68 + assistantAvg * 0.32) / 100, min: 0, max: 1)
}

private func defaultRotationSlots(for team: Team) -> [UserRotationSlot] {
    let starters = team.lineup
    let lineupNames = Set(starters.map { $0.bio.name })

    let starterSlots = starters.enumerated().map { idx, player in
        let playerIndex = team.players.firstIndex(where: { $0.bio.name == player.bio.name })
        return UserRotationSlot(slot: idx, playerIndex: playerIndex, position: player.bio.position.rawValue, minutes: 28)
    }

    let benchPlayers = team.players.enumerated().filter { !lineupNames.contains($0.element.bio.name) }
    let benchSlots = benchPlayers.prefix(5).enumerated().map { benchIdx, pair in
        UserRotationSlot(slot: benchIdx + 5, playerIndex: pair.offset, position: pair.element.bio.position.rawValue, minutes: 12)
    }

    return starterSlots + benchSlots
}

private let homeCourtBoost = 1.03
private let coachingEdgeMaxMultiplier = 0.055
private let headCoachGameImpactWeight = 0.72
private let gamePrepAssistantGameImpactWeight = 0.28

func applyPreGameModifiers(team: inout Team, isHome: Bool) {
    let staff = team.coachingStaff
    let head = staff.headCoach
    let prepIdx = staff.gamePrepAssistantIndex
    let prep: Coach? = {
        if let idx = prepIdx, idx >= 0, idx < staff.assistants.count { return staff.assistants[idx] }
        return staff.assistants.first
    }()

    let headOff = Double(head.skills.offensiveCoaching)
    let headDef = Double(head.skills.defensiveCoaching)
    let prepOff = prep.map { Double($0.skills.offensiveCoaching) } ?? headOff
    let prepDef = prep.map { Double($0.skills.defensiveCoaching) } ?? headDef

    let offEdge = (headOff * headCoachGameImpactWeight + prepOff * gamePrepAssistantGameImpactWeight - 50) / 50
    let defEdge = (headDef * headCoachGameImpactWeight + prepDef * gamePrepAssistantGameImpactWeight - 50) / 50
    let offMult = 1 + max(-1, min(1, offEdge)) * coachingEdgeMaxMultiplier
    let defMult = 1 + max(-1, min(1, defEdge)) * coachingEdgeMaxMultiplier
    let homeMult = isHome ? homeCourtBoost : 1.0

    for idx in team.players.indices {
        team.players[idx].condition.offensiveCoachingModifier = offMult
        team.players[idx].condition.defensiveCoachingModifier = defMult
        team.players[idx].condition.homeCourtMultiplier = homeMult
    }
    for idx in team.lineup.indices {
        team.lineup[idx].condition.offensiveCoachingModifier = offMult
        team.lineup[idx].condition.defensiveCoachingModifier = defMult
        team.lineup[idx].condition.homeCourtMultiplier = homeMult
    }
}
