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
        var completed: Bool
        var result: GameResult?
    }

    struct GameResult: Codable, Equatable, Sendable {
        var homeScore: Int
        var awayScore: Int
        var winnerTeamId: String?
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
    static let shared: D1Snapshot = {
        let url = Bundle.module.url(forResource: "d1-conferences.2026", withExtension: "json", subdirectory: "js")
        guard let url else {
            fatalError("Missing bundled D1 conference data")
        }
        guard let data = try? Data(contentsOf: url) else {
            fatalError("Failed reading D1 conference data")
        }
        guard let decoded = try? JSONDecoder().decode(D1Snapshot.self, from: data) else {
            fatalError("Failed decoding D1 conference data")
        }
        return decoded
    }()
}

public func createD1League(options: CreateLeagueOptions) throws -> LeagueState {
    let dataset = LoadedD1Data.shared
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
        var rosterRandom = random
        let roster = buildTeamRoster(teamName: teamRef.name, random: &rosterRandom)

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
                prestige: clamp(0.25 + random.nextUnit() * 0.7, min: 0, max: 1),
                lastYearResult: clamp(0.2 + random.nextUnit() * 0.75, min: 0, max: 1),
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
        scheduleGenerated: false
    )

    autoFillUserNonConferenceOpponentsInState(&state, seed: "create:\(options.seed)")
    generateSeasonScheduleInState(&state)

    let handle = LeagueStore.put(state)
    return LeagueState(handle: handle)
}

public func listCareerTeamOptions() -> [CareerTeamOption] {
    LoadedD1Data.shared.conferences
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
        resetTeamRecords(&state)
    }
}

public func autoFillUserNonConferenceOpponents(_ league: inout LeagueState, seed: String = "autofill") {
    _ = LeagueStore.update(league.handle) { state in
        autoFillUserNonConferenceOpponentsInState(&state, seed: seed)
        state.scheduleGenerated = false
        state.schedule.removeAll()
        state.userGameHistory.removeAll()
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

    let lineupNames = Set(user.teamModel.lineup.map { $0.bio.name })
    return user.teamModel.players.enumerated().map { idx, player in
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
                "shotIQ": player.skills.shotIQ,
                "threePoint": player.shooting.threePointShooting,
                "midrange": player.shooting.midrangeShot,
                "closeShot": player.shooting.closeShot,
                "perimeterDefense": player.defense.perimeterDefense,
                "postDefense": player.defense.postDefense,
                "speed": player.athleticism.speed,
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

        let userTeamId = state.userTeamId
        let pending = state.schedule
            .enumerated()
            .filter { _, game in !game.completed && (game.homeTeamId == userTeamId || game.awayTeamId == userTeamId) }
            .min { lhs, rhs in
                if lhs.element.day != rhs.element.day { return lhs.element.day < rhs.element.day }
                return lhs.element.gameId < rhs.element.gameId
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
        state.currentDay = simDay

        let sameDayIndexes = state.schedule.enumerated().filter { _, game in !game.completed && game.day == simDay }.map(\ .offset)
        for idx in sameDayIndexes {
            simulateScheduledGameInState(&state, scheduleIndex: idx)
        }

        let completedUserGame = state.schedule[pending.offset]
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
        resultValue = .object([
            "homeScore": .number(Double(result.homeScore)),
            "awayScore": .number(Double(result.awayScore)),
            "winnerTeamId": result.winnerTeamId.map(JSONValue.string) ?? .null,
        ])
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
        resultValue = .object([
            "homeScore": .number(Double(result.homeScore)),
            "awayScore": .number(Double(result.awayScore)),
            "winnerTeamId": result.winnerTeamId.map(JSONValue.string) ?? .null,
        ])
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

    let confGames = min(user.targetConferenceGames, state.totalRegularSeasonGames)
    if !confOpponents.isEmpty {
        var i = 0
        while userOpponents.count < confGames {
            userOpponents.append(confOpponents[i % confOpponents.count])
            i += 1
        }
    }

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
    userOpponents.append(contentsOf: nonConf.prefix(max(0, state.totalRegularSeasonGames - userOpponents.count)))

    let fillerPool = state.teams.filter { $0.teamId != user.teamId }.map(\ .teamId)
    var fillerIndex = 0
    while userOpponents.count < state.totalRegularSeasonGames, !fillerPool.isEmpty {
        userOpponents.append(fillerPool[fillerIndex % fillerPool.count])
        fillerIndex += 1
    }

    for (index, opponentId) in userOpponents.enumerated() {
        guard let opp = state.teams.first(where: { $0.teamId == opponentId }) else { continue }
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
                completed: false,
                result: nil
            )
        )

        let cpuPool = state.teams.filter { $0.teamId != user.teamId && $0.teamId != opp.teamId }
        if cpuPool.count >= 2 {
            let a = cpuPool[random.int(0, cpuPool.count - 1)]
            var b = cpuPool[random.int(0, cpuPool.count - 1)]
            if b.teamId == a.teamId, let alt = cpuPool.first(where: { $0.teamId != a.teamId }) {
                b = alt
            }
            if a.teamId != b.teamId {
                state.schedule.append(
                    LeagueStore.ScheduledGame(
                        gameId: "g_\(day)_cpu",
                        day: day,
                        type: "regular_season",
                        siteType: "home",
                        neutralSite: false,
                        homeTeamId: a.teamId,
                        homeTeamName: a.teamName,
                        awayTeamId: b.teamId,
                        awayTeamName: b.teamName,
                        completed: false,
                        result: nil
                    )
                )
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
    let result = simulateGame(homeTeam: state.teams[homeIndex].teamModel, awayTeam: state.teams[awayIndex].teamModel, random: &random)

    let homeScore = result.home.score
    let awayScore = result.away.score
    let winnerTeamId: String?
    if homeScore == awayScore {
        winnerTeamId = nil
    } else {
        winnerTeamId = homeScore > awayScore ? game.homeTeamId : game.awayTeamId
    }

    state.schedule[scheduleIndex].completed = true
    state.schedule[scheduleIndex].result = LeagueStore.GameResult(homeScore: homeScore, awayScore: awayScore, winnerTeamId: winnerTeamId)

    state.teams[homeIndex].pointsFor += homeScore
    state.teams[homeIndex].pointsAgainst += awayScore
    state.teams[awayIndex].pointsFor += awayScore
    state.teams[awayIndex].pointsAgainst += homeScore

    let isConference = state.teams[homeIndex].conferenceId == state.teams[awayIndex].conferenceId

    if homeScore > awayScore {
        state.teams[homeIndex].wins += 1
        state.teams[awayIndex].losses += 1
        if isConference {
            state.teams[homeIndex].conferenceWins += 1
            state.teams[awayIndex].conferenceLosses += 1
        }
    } else if awayScore > homeScore {
        state.teams[awayIndex].wins += 1
        state.teams[homeIndex].losses += 1
        if isConference {
            state.teams[awayIndex].conferenceWins += 1
            state.teams[homeIndex].conferenceLosses += 1
        }
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

private func buildTeamRoster(teamName: String, random: inout SeededRandom) -> [Player] {
    let positionCycle: [PlayerPosition] = [.pg, .sg, .sf, .pf, .c, .cg, .wing, .f, .big, .pg, .sg, .sf, .pf]
    let yearCycle: [PlayerYear] = [.fr, .so, .jr, .sr]

    return (0..<13).map { idx in
        var player = createPlayer()
        player.bio.name = "\(teamName) Player \(idx + 1)"
        player.bio.position = positionCycle[idx % positionCycle.count]
        player.bio.year = yearCycle[idx % yearCycle.count]
        player.bio.home = ["CA", "TX", "FL", "NY", "NC", "IL", "GA", "PA"][idx % 8]

        let base = clamp(58 + random.int(-8, 18), min: 35, max: 92)
        applyRatings(&player, base: base, random: &random)

        let height = 72 + idx % 7
        player.size.height = "\(height / 12)-\(height % 12)"
        player.size.weight = "\(190 + idx * 4)"
        player.size.wingspan = "\((height + 3) / 12)-\((height + 3) % 12)"
        player.condition.energy = 100
        return player
    }
}

private func applyRatings(_ player: inout Player, base: Int, random: inout SeededRandom) {
    func r(_ delta: Int = 0) -> Int { clamp(base + delta + random.int(-9, 9), min: 25, max: 99) }

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
    player.tendencies.shootVsPass = r(0)
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
        return UserRotationSlot(slot: idx, playerIndex: playerIndex, position: player.bio.position.rawValue, minutes: idx < 2 ? 32 : 30)
    }

    let benchPlayers = team.players.enumerated().filter { !lineupNames.contains($0.element.bio.name) }
    let benchSlots = benchPlayers.prefix(5).enumerated().map { benchIdx, pair in
        UserRotationSlot(slot: benchIdx + 5, playerIndex: pair.offset, position: pair.element.bio.position.rawValue, minutes: benchIdx < 2 ? 18 : 12)
    }

    return starterSlots + benchSlots
}
