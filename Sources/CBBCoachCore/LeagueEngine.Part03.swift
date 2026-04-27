import Foundation

private struct LeagueAdvanceContext {
    var userTeamId: String
    var teamIndexById: [String: Int]
    var scheduleCount: Int
    var pendingIndexesByDay: [Int: [Int]]
    var pendingDays: [Int]
    var pendingUserIndexes: [Int]
}

private func seasonCompleteSummary(currentDay: Int) -> UserGameSummary {
    UserGameSummary(
        gameId: nil,
        day: currentDay,
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

private func prepareAdvanceContext(_ state: LeagueStore.State, cached: LeagueAdvanceContext?) -> LeagueAdvanceContext {
    if let cached,
       cached.userTeamId == state.userTeamId,
       cached.teamIndexById.count == state.teams.count,
       cached.scheduleCount == state.schedule.count
    {
        return cached
    }

    var pendingIndexesByDay: [Int: [Int]] = [:]
    var pendingDays: [Int] = []
    var pendingUserIndexes: [Int] = []
    pendingUserIndexes.reserveCapacity(32)

    for (idx, game) in state.schedule.enumerated() where !game.completed {
        if pendingIndexesByDay[game.day] == nil {
            pendingIndexesByDay[game.day] = []
            pendingDays.append(game.day)
        }
        pendingIndexesByDay[game.day]?.append(idx)
        if game.homeTeamId == state.userTeamId || game.awayTeamId == state.userTeamId {
            pendingUserIndexes.append(idx)
        }
    }

    return LeagueAdvanceContext(
        userTeamId: state.userTeamId,
        teamIndexById: Dictionary(uniqueKeysWithValues: state.teams.enumerated().map { ($0.element.teamId, $0.offset) }),
        scheduleCount: state.schedule.count,
        pendingIndexesByDay: pendingIndexesByDay,
        pendingDays: pendingDays,
        pendingUserIndexes: pendingUserIndexes
    )
}

private func nextPendingDay(_ context: inout LeagueAdvanceContext) -> Int? {
    while let day = context.pendingDays.first {
        if let indexes = context.pendingIndexesByDay[day], !indexes.isEmpty {
            return day
        }
        context.pendingIndexesByDay.removeValue(forKey: day)
        context.pendingDays.removeFirst()
    }
    return nil
}

private func popPendingDayIndexes(_ context: inout LeagueAdvanceContext, day: Int) -> [Int] {
    let indexes = context.pendingIndexesByDay.removeValue(forKey: day) ?? []
    if let dayIndex = context.pendingDays.firstIndex(of: day) {
        context.pendingDays.remove(at: dayIndex)
    }
    return indexes
}

private func markCompletedInAdvanceContext(_ context: inout LeagueAdvanceContext, scheduleIndexes: [Int]) {
    guard !scheduleIndexes.isEmpty else { return }
    let completedSet = Set(scheduleIndexes)
    context.pendingUserIndexes.removeAll { completedSet.contains($0) }
}

private func nextPendingUserGame(_ state: LeagueStore.State, context: inout LeagueAdvanceContext) -> (offset: Int, element: LeagueStore.ScheduledGame)? {
    while let firstPending = context.pendingUserIndexes.first {
        guard firstPending >= 0, firstPending < state.schedule.count else {
            context.pendingUserIndexes.removeFirst()
            continue
        }
        let game = state.schedule[firstPending]
        if game.completed || (game.homeTeamId != context.userTeamId && game.awayTeamId != context.userTeamId) {
            context.pendingUserIndexes.removeFirst()
            continue
        }
        return (firstPending, game)
    }
    return nil
}

private func advanceToNextUserGameInState(_ state: inout LeagueStore.State, cachedContext: inout LeagueAdvanceContext?) -> UserGameSummary {
    if !state.scheduleGenerated || state.schedule.isEmpty {
        generateSeasonScheduleInState(&state)
    }
    prepareConferenceTournamentsIfNeeded(&state)

    var context = prepareAdvanceContext(state, cached: cachedContext)
    cachedContext = context
    let userTeamId = context.userTeamId
    let teamIndexById = context.teamIndexById

    var pending = nextPendingUserGame(state, context: &context)
    while pending == nil {
        guard let nextDay = nextPendingDay(&context) else {
            state.status = "completed"
            return seasonCompleteSummary(currentDay: state.currentDay)
        }

        state.currentDay = nextDay
        let dayIndexes = popPendingDayIndexes(&context, day: nextDay)
        simulateScheduledDayInState(&state, scheduleIndexes: dayIndexes, teamIndexById: teamIndexById)
        markCompletedInAdvanceContext(&context, scheduleIndexes: dayIndexes)
        let scheduleCountBeforeTournamentPrep = state.schedule.count
        prepareConferenceTournamentsIfNeeded(&state)
        if state.schedule.count != scheduleCountBeforeTournamentPrep {
            context = prepareAdvanceContext(state, cached: nil)
        }
        pending = nextPendingUserGame(state, context: &context)
    }
    cachedContext = context

    guard let pending else {
        state.status = "completed"
        return seasonCompleteSummary(currentDay: state.currentDay)
    }

    let simDay = pending.element.day
    let targetScheduleIndex = pending.offset
    let targetGameId = pending.element.gameId

    while let day = nextPendingDay(&context), day <= simDay {
        state.currentDay = day
        let dayIndexes = popPendingDayIndexes(&context, day: day)
        simulateScheduledDayInState(&state, scheduleIndexes: dayIndexes, teamIndexById: teamIndexById)
        markCompletedInAdvanceContext(&context, scheduleIndexes: dayIndexes)
        let scheduleCountBeforeTournamentPrep = state.schedule.count
        prepareConferenceTournamentsIfNeeded(&state)
        if state.schedule.count != scheduleCountBeforeTournamentPrep {
            context = prepareAdvanceContext(state, cached: nil)
        }
    }
    cachedContext = context

    let completedUserGame: LeagueStore.ScheduledGame?
    if targetScheduleIndex >= 0,
       targetScheduleIndex < state.schedule.count,
       state.schedule[targetScheduleIndex].gameId == targetGameId
    {
        completedUserGame = state.schedule[targetScheduleIndex]
    } else {
        completedUserGame = state.schedule.first(where: { $0.gameId == targetGameId })
    }

    guard let completedUserGame else {
        state.status = "completed"
        return seasonCompleteSummary(currentDay: state.currentDay)
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

public func advanceToNextUserGame(_ league: inout LeagueState) -> UserGameSummary? {
    LeagueStore.update(league.handle) { state in
        var cachedContext: LeagueAdvanceContext?
        return advanceToNextUserGameInState(&state, cachedContext: &cachedContext)
    }
}

public func advanceUserGames(_ league: inout LeagueState, maxGames: Int) -> UserGameAdvanceBatch {
    let safeMaxGames = max(0, maxGames)
    guard safeMaxGames > 0 else {
        return UserGameAdvanceBatch(results: [], seasonCompleted: false)
    }
    return LeagueStore.update(league.handle) { state in
        var cachedContext: LeagueAdvanceContext?
        var completedUserGames: [UserGameSummary] = []
        completedUserGames.reserveCapacity(safeMaxGames)
        var seasonCompleted = false

        for _ in 0..<safeMaxGames {
            let result = advanceToNextUserGameInState(&state, cachedContext: &cachedContext)
            if result.done == true {
                seasonCompleted = true
                break
            }
            completedUserGames.append(result)
        }
        return UserGameAdvanceBatch(results: completedUserGames, seasonCompleted: seasonCompleted)
    } ?? UserGameAdvanceBatch(results: [], seasonCompleted: false)
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

public enum LeagueSaveStyle: Sendable {
    case compact
    case pretty
}

public func saveLeagueState(_ league: LeagueState, destinationPath: String, pretty: Bool = true) throws -> (filePath: String, bytes: Int, format: String, version: Int, savedAt: String) {
    let style: LeagueSaveStyle = pretty ? .pretty : .compact
    return try saveLeagueState(league, destinationPath: destinationPath, style: style)
}

public func saveLeagueState(
    _ league: LeagueState,
    destinationPath: String,
    style: LeagueSaveStyle
) throws -> (filePath: String, bytes: Int, format: String, version: Int, savedAt: String) {
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
    if style == .pretty {
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }
    let data = try encoder.encode(payload)

    let url = URL(fileURLWithPath: destinationPath)
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try data.write(to: url, options: .atomic)

    return (url.path, data.count, LEAGUE_SAVE_FORMAT, LEAGUE_SAVE_VERSION, savedAt)
}

public func saveLeagueStateForAutosave(
    _ league: LeagueState,
    destinationPath: String
) throws -> (filePath: String, bytes: Int, format: String, version: Int, savedAt: String) {
    try saveLeagueState(league, destinationPath: destinationPath, style: .compact)
}

public func saveLeagueStateForExport(
    _ league: LeagueState,
    destinationPath: String
) throws -> (filePath: String, bytes: Int, format: String, version: Int, savedAt: String) {
    try saveLeagueState(league, destinationPath: destinationPath, style: .pretty)
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

func userSummaryFromGame(_ game: LeagueStore.ScheduledGame, userTeamId: String) -> UserGameSummary {
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

func leagueSummaryFromGame(_ game: LeagueStore.ScheduledGame) -> LeagueGameSummary {
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

func boxScoreJSONValue(_ boxScore: [TeamBoxScore]) -> JSONValue {
    .array(boxScore.map(teamBoxScoreJSONValue))
}

func teamBoxScoreJSONValue(_ team: TeamBoxScore) -> JSONValue {
    var object: [String: JSONValue] = [
        "name": .string(team.name),
        "players": .array(team.players.map(playerBoxScoreJSONValue)),
    ]
    if let teamExtras = team.teamExtras {
        object["teamExtras"] = .object(teamExtras.mapValues { .number(Double($0)) })
    }
    return .object(object)
}

func playerBoxScoreJSONValue(_ player: PlayerBoxScore) -> JSONValue {
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

func conferenceTournamentEntrantCount(for teamCount: Int) -> Int {
    for size in [16, 12, 8, 4] where size <= teamCount {
        return size
    }
    return 0
}
