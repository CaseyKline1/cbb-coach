import Foundation

public let DEFAULT_TOTAL_REGULAR_SEASON_GAMES = 31
public let LEAGUE_SAVE_FORMAT = "cbb-coach.league-state"
public let LEAGUE_SAVE_VERSION = 1

public struct LeagueTeamSummary: Codable, Equatable, Sendable {
    public var id: String
    public var name: String
    public var conferenceId: String
}

public struct ConferenceSummary: Codable, Equatable, Sendable {
    public var id: String
    public var name: String
    public var teamIds: [String]
    public var conferenceGamesTarget: Int
}

public struct ScheduledGame: Codable, Equatable, Sendable {
    public var id: String
    public var day: Int
    public var homeTeamId: String
    public var awayTeamId: String
    public var isConferenceGame: Bool
    public var completed: Bool = false
    public var homeScore: Int?
    public var awayScore: Int?

    public init(id: String, day: Int, homeTeamId: String, awayTeamId: String, isConferenceGame: Bool) {
        self.id = id
        self.day = day
        self.homeTeamId = homeTeamId
        self.awayTeamId = awayTeamId
        self.isConferenceGame = isConferenceGame
    }
}

public struct UserPreseasonState: Codable, Equatable, Sendable {
    public var requiredNonConferenceGames: Int
    public var nonConferenceOpponentIds: [String]
}

public struct LeagueSchedule: Codable, Equatable, Sendable {
    public var games: [ScheduledGame]
    public var totalDays: Int
}

public struct LeagueTeamRecord: Codable, Equatable, Sendable {
    public var wins: Int = 0
    public var losses: Int = 0
    public var conferenceWins: Int = 0
    public var conferenceLosses: Int = 0
}

public struct LeagueState: Codable, Equatable, Sendable {
    public var status: String
    public var currentDay: Int
    public var userTeamId: String
    public var teamsById: [String: Team]
    public var teamSummaries: [LeagueTeamSummary]
    public var conferences: [ConferenceSummary]
    public var userPreseason: UserPreseasonState
    public var schedule: LeagueSchedule?
    public var records: [String: LeagueTeamRecord]
    public var completedGames: [ScheduledGame]
}

public struct NonConferenceOption: Codable, Equatable, Sendable {
    public var teamId: String
    public var teamName: String
    public var conferenceName: String
}

public struct PreseasonBoard: Codable, Equatable, Sendable {
    public var page: Int
    public var pageSize: Int
    public var total: Int
    public var results: [NonConferenceOption]
}

public struct UserGameSummary: Codable, Equatable, Sendable {
    public var gameId: String
    public var day: Int
    public var opponent: String
    public var home: Bool
    public var completed: Bool
    public var userScore: Int?
    public var opponentScore: Int?
}

public struct ConferenceStanding: Codable, Equatable, Sendable {
    public var conferenceId: String
    public var conferenceName: String
    public var teamId: String
    public var teamName: String
    public var wins: Int
    public var losses: Int
    public var conferenceWins: Int
    public var conferenceLosses: Int
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

public struct CreateLeagueOptions: Sendable {
    public var userTeamName: String
    public var seed: String
    public var totalRegularSeasonGames: Int

    public init(userTeamName: String, seed: String = "default", totalRegularSeasonGames: Int = DEFAULT_TOTAL_REGULAR_SEASON_GAMES) {
        self.userTeamName = userTeamName
        self.seed = seed
        self.totalRegularSeasonGames = totalRegularSeasonGames
    }
}

private struct Snapshot: Codable {
    struct SnapshotConference: Codable {
        struct SnapshotTeam: Codable {
            let id: String
            let name: String
        }

        let id: String
        let name: String
        let teams: [SnapshotTeam]
        let inferredConferenceGames: Int?
    }

    let conferences: [SnapshotConference]
}

private func slugify(_ value: String) -> String {
    value
        .lowercased()
        .replacingOccurrences(of: "&", with: " and ")
        .replacingOccurrences(of: "[^a-z0-9]+", with: "-", options: .regularExpression)
        .replacingOccurrences(of: "^-+|-+$", with: "", options: .regularExpression)
}

private func canonicalName(_ value: String) -> String {
    value
        .lowercased()
        .replacingOccurrences(of: "[^a-z0-9]+", with: "", options: .regularExpression)
}

private func decodeD1Snapshot() throws -> Snapshot {
    let candidates = [
        Bundle.module.url(forResource: "d1-conferences.2026", withExtension: "json"),
        Bundle.module.url(forResource: "d1-conferences", withExtension: "2026.json")
    ].compactMap { $0 }

    guard let url = candidates.first else {
        throw NSError(domain: "CBBCoachCore", code: 1, userInfo: [NSLocalizedDescriptionKey: "D1 snapshot resource not found"]) 
    }

    let data = try Data(contentsOf: url)
    return try JSONDecoder().decode(Snapshot.self, from: data)
}

private func conferenceGamesTarget(teamCount: Int, raw: Int?, total: Int) -> Int {
    let fallback: Int
    if teamCount <= 8 { fallback = 14 }
    else if teamCount <= 10 { fallback = 18 }
    else { fallback = 20 }

    let parsed = raw ?? fallback
    let minByConvention = 12
    let maxByConvention = min(24, max(12, total - 8))
    let maxByOpponentPool = max(1, (teamCount - 1) * 3)
    return clamp(parsed, min: minByConvention, max: min(maxByConvention, maxByOpponentPool))
}

private func makePlayer(name: String, position: PlayerPosition, random: inout SeededRandom) -> Player {
    var player = createPlayer()
    player.bio.name = name
    player.bio.position = position
    player.bio.year = [.fr, .so, .jr, .sr][random.int(0, 3)]

    let base = random.int(45, 82)
    player.shooting.threePointShooting = clamp(base + random.int(-8, 8), min: 30, max: 99)
    player.shooting.midrangeShot = clamp(base + random.int(-8, 8), min: 30, max: 99)
    player.shooting.layups = clamp(base + random.int(-8, 8), min: 30, max: 99)
    player.skills.shotIQ = clamp(base + random.int(-5, 5), min: 30, max: 99)
    player.skills.ballHandling = clamp(base + random.int(-8, 8), min: 30, max: 99)
    player.skills.passingIQ = clamp(base + random.int(-8, 8), min: 30, max: 99)
    player.defense.perimeterDefense = clamp(base + random.int(-10, 8), min: 30, max: 99)
    player.defense.shotContest = clamp(base + random.int(-10, 8), min: 30, max: 99)
    player.rebounding.defensiveRebound = clamp(base + random.int(-8, 8), min: 30, max: 99)
    player.athleticism.burst = clamp(base + random.int(-8, 10), min: 30, max: 99)
    return player
}

private func generateRoster(teamName: String, random: inout SeededRandom) -> [Player] {
    let firstNames = ["Jalen", "Marcus", "Eli", "Noah", "Ty", "Jordan", "Malik", "Darius", "Caleb", "Cameron"]
    let lastNames = ["Carter", "Brooks", "Davis", "Coleman", "Thomas", "Hill", "Moore", "Young", "Turner", "Jenkins"]
    let positions: [PlayerPosition] = [.pg, .sg, .sf, .pf, .c, .cg, .wing, .f, .big, .pg]

    return (0..<10).map { idx in
        let first = firstNames[random.int(0, firstNames.count - 1)]
        let last = lastNames[random.int(0, lastNames.count - 1)]
        let name = "\(first) \(last)"
        return makePlayer(name: name, position: positions[idx], random: &random)
    }
}

private func getTeamOverall(_ team: Team) -> Double {
    let lineup = team.lineup.isEmpty ? team.players : team.lineup
    guard !lineup.isEmpty else { return 50 }

    let aggregate = lineup.map { player in
        Double(player.shooting.threePointShooting + player.shooting.midrangeShot + player.shooting.layups + player.skills.shotIQ + player.defense.perimeterDefense)
    }.reduce(0, +)

    return aggregate / Double(lineup.count * 5)
}

private func chooseFormation(random: inout SeededRandom) -> OffensiveFormation {
    OffensiveFormation.allCases[random.int(0, OffensiveFormation.allCases.count - 1)]
}

private func chooseDefense(random: inout SeededRandom) -> DefenseScheme {
    DefenseScheme.allCases[random.int(0, DefenseScheme.allCases.count - 1)]
}

private func choosePace(random: inout SeededRandom) -> PaceProfile {
    PaceProfile.allCases[random.int(0, PaceProfile.allCases.count - 1)]
}

public func createD1League(options: CreateLeagueOptions) throws -> LeagueState {
    let snapshot = try decodeD1Snapshot()
    var random = SeededRandom(seed: hashString(options.seed))

    var teamsById: [String: Team] = [:]
    var summaries: [LeagueTeamSummary] = []
    var conferences: [ConferenceSummary] = []

    for conference in snapshot.conferences {
        let teamIds = conference.teams.map(\.id)
        conferences.append(
            ConferenceSummary(
                id: conference.id,
                name: conference.name,
                teamIds: teamIds,
                conferenceGamesTarget: conferenceGamesTarget(teamCount: teamIds.count, raw: conference.inferredConferenceGames, total: options.totalRegularSeasonGames)
            )
        )

        for team in conference.teams {
            let roster = generateRoster(teamName: team.name, random: &random)
            var createOptions = CreateTeamOptions(name: team.name, players: roster)
            createOptions.lineup = Array(roster.prefix(5))
            createOptions.formation = chooseFormation(random: &random)
            createOptions.defenseScheme = chooseDefense(random: &random)
            createOptions.pace = choosePace(random: &random)
            createOptions.schoolPool = [team.name]

            let generatedTeam = createTeam(options: createOptions, random: &random)
            teamsById[team.id] = generatedTeam
            summaries.append(LeagueTeamSummary(id: team.id, name: team.name, conferenceId: conference.id))
        }
    }

    guard let userTeam = summaries.first(where: { canonicalName($0.name) == canonicalName(options.userTeamName) }) else {
        throw NSError(domain: "CBBCoachCore", code: 2, userInfo: [NSLocalizedDescriptionKey: "User team not found: \(options.userTeamName)"])
    }

    let records = Dictionary(uniqueKeysWithValues: summaries.map { ($0.id, LeagueTeamRecord()) })

    return LeagueState(
        status: "preseason",
        currentDay: 0,
        userTeamId: userTeam.id,
        teamsById: teamsById,
        teamSummaries: summaries,
        conferences: conferences,
        userPreseason: UserPreseasonState(requiredNonConferenceGames: 11, nonConferenceOpponentIds: []),
        schedule: nil,
        records: records,
        completedGames: []
    )
}

public func listUserNonConferenceOptions(_ league: LeagueState) -> [NonConferenceOption] {
    guard let user = league.teamSummaries.first(where: { $0.id == league.userTeamId }) else { return [] }
    let userConference = user.conferenceId
    let conferenceNameById = Dictionary(uniqueKeysWithValues: league.conferences.map { ($0.id, $0.name) })

    return league.teamSummaries
        .filter { $0.id != league.userTeamId && $0.conferenceId != userConference }
        .map {
            NonConferenceOption(teamId: $0.id, teamName: $0.name, conferenceName: conferenceNameById[$0.conferenceId] ?? $0.conferenceId)
        }
        .sorted { $0.teamName < $1.teamName }
}

public func getPreseasonSchedulingBoard(_ league: LeagueState, page: Int = 1, pageSize: Int = 20, query: String? = nil) -> PreseasonBoard {
    var items = listUserNonConferenceOptions(league)

    if let query, !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        let needle = canonicalName(query)
        items = items.filter { canonicalName($0.teamName).contains(needle) || canonicalName($0.conferenceName).contains(needle) }
    }

    let size = max(1, pageSize)
    let normalizedPage = max(1, page)
    let start = min((normalizedPage - 1) * size, items.count)
    let end = min(start + size, items.count)

    return PreseasonBoard(page: normalizedPage, pageSize: size, total: items.count, results: Array(items[start..<end]))
}

public func setUserNonConferenceOpponents(_ league: inout LeagueState, opponentTeamIds: [String]) {
    let options = Set(listUserNonConferenceOptions(league).map(\.teamId))
    let uniqueValid = Array(Set(opponentTeamIds.filter { options.contains($0) }))
    let required = max(0, league.userPreseason.requiredNonConferenceGames)
    league.userPreseason.nonConferenceOpponentIds = Array(uniqueValid.prefix(required))
}

public func autoFillUserNonConferenceOpponents(_ league: inout LeagueState, seed: String = "autofill") {
    let needed = max(0, league.userPreseason.requiredNonConferenceGames - league.userPreseason.nonConferenceOpponentIds.count)
    guard needed > 0 else { return }

    var random = SeededRandom(seed: hashString(seed))
    var options = listUserNonConferenceOptions(league).map(\.teamId)
    options.removeAll(where: { league.userPreseason.nonConferenceOpponentIds.contains($0) })

    for _ in 0..<needed {
        guard !options.isEmpty else { break }
        let idx = random.int(0, options.count - 1)
        league.userPreseason.nonConferenceOpponentIds.append(options.remove(at: idx))
    }
}

private func pairings(_ ids: [String], random: inout SeededRandom) -> [(String, String)] {
    var shuffled = ids
    for i in stride(from: shuffled.count - 1, through: 1, by: -1) {
        let j = random.int(0, i)
        shuffled.swapAt(i, j)
    }

    var matches: [(String, String)] = []
    var index = 0
    while index + 1 < shuffled.count {
        matches.append((shuffled[index], shuffled[index + 1]))
        index += 2
    }
    return matches
}

public func generateSeasonSchedule(_ league: inout LeagueState, seed: String = "schedule") {
    var random = SeededRandom(seed: hashString(seed))
    var games: [ScheduledGame] = []
    var day = 1

    if !league.userPreseason.nonConferenceOpponentIds.isEmpty {
        for oppId in league.userPreseason.nonConferenceOpponentIds {
            let home = random.nextUnit() < 0.5
            games.append(
                ScheduledGame(
                    id: UUID().uuidString,
                    day: day,
                    homeTeamId: home ? league.userTeamId : oppId,
                    awayTeamId: home ? oppId : league.userTeamId,
                    isConferenceGame: false
                )
            )
            day += 1
        }
    }

    for conference in league.conferences {
        let ids = conference.teamIds
        let rounds = max(1, min(3, conference.conferenceGamesTarget / max(1, ids.count - 1)))

        for round in 0..<rounds {
            for (a, b) in pairings(ids, random: &random) {
                let homeFirst = (round + day) % 2 == 0
                games.append(
                    ScheduledGame(
                        id: UUID().uuidString,
                        day: day,
                        homeTeamId: homeFirst ? a : b,
                        awayTeamId: homeFirst ? b : a,
                        isConferenceGame: true
                    )
                )
            }
            day += 1
        }
    }

    let teamIds = league.teamSummaries.map(\.id)
    for _ in 0..<20 {
        for (a, b) in pairings(teamIds, random: &random) {
            if games.contains(where: {
                ($0.homeTeamId == a && $0.awayTeamId == b) ||
                ($0.homeTeamId == b && $0.awayTeamId == a)
            }) {
                continue
            }

            games.append(
                ScheduledGame(
                    id: UUID().uuidString,
                    day: day,
                    homeTeamId: random.nextUnit() < 0.5 ? a : b,
                    awayTeamId: random.nextUnit() < 0.5 ? b : a,
                    isConferenceGame: false
                )
            )
        }
        day += 1
    }

    league.schedule = LeagueSchedule(games: games.sorted { $0.day < $1.day }, totalDays: max(day, 1))
    league.status = "in_season"
    league.currentDay = 0
}

private func applyResult(_ game: ScheduledGame, to league: inout LeagueState) {
    guard let homeScore = game.homeScore, let awayScore = game.awayScore else { return }

    var homeRecord = league.records[game.homeTeamId] ?? LeagueTeamRecord()
    var awayRecord = league.records[game.awayTeamId] ?? LeagueTeamRecord()

    if homeScore > awayScore {
        homeRecord.wins += 1
        awayRecord.losses += 1
        if game.isConferenceGame {
            homeRecord.conferenceWins += 1
            awayRecord.conferenceLosses += 1
        }
    } else {
        awayRecord.wins += 1
        homeRecord.losses += 1
        if game.isConferenceGame {
            awayRecord.conferenceWins += 1
            homeRecord.conferenceLosses += 1
        }
    }

    league.records[game.homeTeamId] = homeRecord
    league.records[game.awayTeamId] = awayRecord
}

private func simulateScheduledGame(_ game: inout ScheduledGame, league: inout LeagueState, random: inout SeededRandom) {
    guard var home = league.teamsById[game.homeTeamId], var away = league.teamsById[game.awayTeamId] else { return }

    let homeOVR = getTeamOverall(home)
    let awayOVR = getTeamOverall(away)

    let close = abs(homeOVR - awayOVR) < 2.5
    if close {
        let result = simulateGame(homeTeam: home, awayTeam: away, random: &random)
        game.homeScore = result.home.score
        game.awayScore = result.away.score
    } else {
        let baseHome = Int(62 + homeOVR * 0.65 + (random.nextUnit() - 0.5) * 14)
        let baseAway = Int(62 + awayOVR * 0.65 + (random.nextUnit() - 0.5) * 14)
        game.homeScore = max(40, baseHome)
        game.awayScore = max(40, baseAway)

        if game.homeScore == game.awayScore {
            if random.nextUnit() < 0.5 { game.homeScore! += 1 } else { game.awayScore! += 1 }
        }
    }

    game.completed = true
    applyResult(game, to: &league)

    home.score = 0
    away.score = 0
    league.teamsById[game.homeTeamId] = home
    league.teamsById[game.awayTeamId] = away
}

public func getUserSchedule(_ league: LeagueState) -> [UserGameSummary] {
    guard let schedule = league.schedule else { return [] }
    let teamNameById = Dictionary(uniqueKeysWithValues: league.teamSummaries.map { ($0.id, $0.name) })

    return schedule.games
        .filter { $0.homeTeamId == league.userTeamId || $0.awayTeamId == league.userTeamId }
        .sorted { $0.day < $1.day }
        .map { game in
            let isHome = game.homeTeamId == league.userTeamId
            let opponentId = isHome ? game.awayTeamId : game.homeTeamId
            return UserGameSummary(
                gameId: game.id,
                day: game.day,
                opponent: teamNameById[opponentId] ?? opponentId,
                home: isHome,
                completed: game.completed,
                userScore: isHome ? game.homeScore : game.awayScore,
                opponentScore: isHome ? game.awayScore : game.homeScore
            )
        }
}

public func advanceToNextUserGame(_ league: inout LeagueState, seed: String = "advance") -> UserGameSummary? {
    guard var schedule = league.schedule else { return nil }
    var random = SeededRandom(seed: hashString("\(seed)-\(league.currentDay)-\(league.completedGames.count)"))

    while let idx = schedule.games.firstIndex(where: { !$0.completed && $0.day >= league.currentDay }) {
        var game = schedule.games[idx]
        simulateScheduledGame(&game, league: &league, random: &random)
        schedule.games[idx] = game
        league.completedGames.append(game)
        league.currentDay = max(league.currentDay, game.day)

        if game.homeTeamId == league.userTeamId || game.awayTeamId == league.userTeamId {
            league.schedule = schedule
            return getUserSchedule(league).first(where: { $0.gameId == game.id })
        }
    }

    league.schedule = schedule
    league.status = "completed"
    return nil
}

public func getUserCompletedGames(_ league: LeagueState) -> [UserGameSummary] {
    getUserSchedule(league).filter(\.completed)
}

public func getConferenceStandings(_ league: LeagueState) -> [ConferenceStanding] {
    let teamById = Dictionary(uniqueKeysWithValues: league.teamSummaries.map { ($0.id, $0) })

    return league.conferences.flatMap { conference in
        conference.teamIds.compactMap { teamId -> ConferenceStanding? in
            guard let team = teamById[teamId] else { return nil }
            let record = league.records[teamId] ?? LeagueTeamRecord()
            return ConferenceStanding(
                conferenceId: conference.id,
                conferenceName: conference.name,
                teamId: team.id,
                teamName: team.name,
                wins: record.wins,
                losses: record.losses,
                conferenceWins: record.conferenceWins,
                conferenceLosses: record.conferenceLosses
            )
        }
        .sorted {
            if $0.conferenceWins == $1.conferenceWins {
                return $0.teamName < $1.teamName
            }
            return $0.conferenceWins > $1.conferenceWins
        }
    }
}

public func getLeagueSummary(_ league: LeagueState) -> LeagueSummary {
    let userTeamName = league.teamSummaries.first(where: { $0.id == league.userTeamId })?.name ?? league.userTeamId

    return LeagueSummary(
        status: league.status,
        currentDay: league.currentDay,
        totalTeams: league.teamSummaries.count,
        totalConferences: league.conferences.count,
        userTeamId: league.userTeamId,
        userTeamName: userTeamName,
        requiredUserNonConferenceGames: league.userPreseason.requiredNonConferenceGames,
        userSelectedNonConferenceGames: league.userPreseason.nonConferenceOpponentIds.count,
        scheduleGenerated: league.schedule != nil,
        totalScheduledGames: league.schedule?.games.count ?? 0
    )
}

public func saveLeagueState(_ league: LeagueState, destinationPath: String, pretty: Bool = true) throws -> (filePath: String, bytes: Int, format: String, version: Int, savedAt: String) {
    let fileURL = URL(fileURLWithPath: destinationPath).standardizedFileURL
    let savedAt = ISO8601DateFormatter().string(from: Date())

    struct Payload: Codable {
        let format: String
        let version: Int
        let savedAt: String
        let league: LeagueState
    }

    let payload = Payload(format: LEAGUE_SAVE_FORMAT, version: LEAGUE_SAVE_VERSION, savedAt: savedAt, league: league)
    let encoder = JSONEncoder()
    encoder.outputFormatting = pretty ? [.prettyPrinted, .sortedKeys] : []
    let data = try encoder.encode(payload)

    try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    try data.write(to: fileURL)

    return (filePath: fileURL.path, bytes: data.count, format: LEAGUE_SAVE_FORMAT, version: LEAGUE_SAVE_VERSION, savedAt: savedAt)
}

public func loadLeagueState(_ sourcePath: String) throws -> LeagueState {
    let fileURL = URL(fileURLWithPath: sourcePath).standardizedFileURL
    let data = try Data(contentsOf: fileURL)

    struct Payload: Codable {
        let format: String?
        let version: Int?
        let savedAt: String?
        let league: LeagueState?
    }

    let decoder = JSONDecoder()
    if let payload = try? decoder.decode(Payload.self, from: data), let league = payload.league {
        return league
    }

    return try decoder.decode(LeagueState.self, from: data)
}
