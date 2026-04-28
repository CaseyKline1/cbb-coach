import Foundation

func conferenceTournamentTemplate(entrantCount: Int) -> [[LeagueStore.ConferenceTournamentState.Matchup]] {
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

func sortedConferenceTeamIdsForSeeding(_ state: LeagueStore.State, conferenceId: String) -> [String] {
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

func ensureRemainingRegularSeasonGames(_ state: inout LeagueStore.State) {
    if state.remainingRegularSeasonGames == nil {
        state.remainingRegularSeasonGames = state.schedule.reduce(0) { total, game in
            total + ((game.type == "regular_season" && !game.completed) ? 1 : 0)
        }
    }
}

func isRegularSeasonComplete(_ state: inout LeagueStore.State) -> Bool {
    ensureRemainingRegularSeasonGames(&state)
    guard let remaining = state.remainingRegularSeasonGames else { return false }
    return remaining == 0
}

func prepareConferenceTournamentsIfNeeded(_ state: inout LeagueStore.State) {
    guard isRegularSeasonComplete(&state) else { return }

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

func appendReadyConferenceTournamentRoundsInState(_ state: inout LeagueStore.State) {
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

func resolveConferenceTournamentParticipantTeamId(
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

func recordConferenceTournamentWinner(
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

func autoFillUserNonConferenceOpponentsInState(_ state: inout LeagueStore.State, seed: String) {
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

func generateSeasonScheduleInState(_ state: inout LeagueStore.State) {
    state.schedule.removeAll(keepingCapacity: true)
    state.userGameHistory.removeAll(keepingCapacity: true)
    state.conferenceTournaments = nil
    state.remainingRegularSeasonGames = nil
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
    state.remainingRegularSeasonGames = state.schedule.reduce(0) { total, game in
        total + ((game.type == "regular_season" && !game.completed) ? 1 : 0)
    }
    state.scheduleGenerated = true
    state.currentDay = 0
    state.status = "in_progress"
}

private struct ScheduledGameSimulationInput {
    let scheduleIndex: Int
    let game: LeagueStore.ScheduledGame
    let homeIndex: Int
    let awayIndex: Int
    let homeTeam: Team
    let awayTeam: Team
    let homePower: Double
    let awayPower: Double
    let homeConferenceBaseline: Double
    let awayConferenceBaseline: Double
}

private struct ScheduledGameSimulationOutcome {
    let scheduleIndex: Int
    let game: LeagueStore.ScheduledGame
    let homeIndex: Int
    let awayIndex: Int
    let homeScore: Int
    let awayScore: Int
    let winnerTeamId: String?
    let wentToOvertime: Bool
    let boxScore: [TeamBoxScore]?
}

private final class ScheduledGameOutcomeCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var outcomes: [ScheduledGameSimulationOutcome]

    init(capacity: Int) {
        outcomes = []
        outcomes.reserveCapacity(capacity)
    }

    func append(_ outcome: ScheduledGameSimulationOutcome) {
        lock.lock()
        outcomes.append(outcome)
        lock.unlock()
    }

    func snapshotSorted() -> [ScheduledGameSimulationOutcome] {
        lock.lock()
        defer { lock.unlock() }
        return outcomes.sorted { $0.scheduleIndex < $1.scheduleIndex }
    }
}

private func makeScheduledGameSimulationInput(
    state: LeagueStore.State,
    scheduleIndex: Int,
    teamIndexById: [String: Int]
) -> ScheduledGameSimulationInput? {
    guard scheduleIndex >= 0, scheduleIndex < state.schedule.count else { return nil }
    let game = state.schedule[scheduleIndex]
    guard !game.completed else { return nil }
    guard
        let homeIndex = teamIndexById[game.homeTeamId],
        let awayIndex = teamIndexById[game.awayTeamId]
    else {
        return nil
    }

    var homeTeam = state.teams[homeIndex].teamModel
    var awayTeam = state.teams[awayIndex].teamModel
    applyPreGameModifiers(team: &homeTeam, isHome: !game.neutralSite)
    applyPreGameModifiers(team: &awayTeam, isHome: false)

    let homeState = state.teams[homeIndex]
    let awayState = state.teams[awayIndex]

    return ScheduledGameSimulationInput(
        scheduleIndex: scheduleIndex,
        game: game,
        homeIndex: homeIndex,
        awayIndex: awayIndex,
        homeTeam: homeTeam,
        awayTeam: awayTeam,
        homePower: matchupPower(for: homeState),
        awayPower: matchupPower(for: awayState),
        homeConferenceBaseline: historicalConferenceBaseline(for: homeState.conferenceId),
        awayConferenceBaseline: historicalConferenceBaseline(for: awayState.conferenceId)
    )
}

private func matchupPower(for team: LeagueStore.TeamState) -> Double {
    let playerSkill = teamOverall(team.teamModel) / 100
    return clamp(
        playerSkill * 0.48
            + team.prestige * 0.26
            + team.lastYearResult * 0.26,
        min: 0,
        max: 1
    )
}

private func applyTeamExecutionModifier(team: inout Team, multiplier: Double) {
    let safeMultiplier = clamp(multiplier, min: 0.88, max: 1.1)
    for idx in team.players.indices {
        team.players[idx].condition.offensiveCoachingModifier *= safeMultiplier
        team.players[idx].condition.defensiveCoachingModifier *= safeMultiplier
    }
    for idx in team.lineup.indices {
        team.lineup[idx].condition.offensiveCoachingModifier *= safeMultiplier
        team.lineup[idx].condition.defensiveCoachingModifier *= safeMultiplier
    }
}

private func applyScheduledGameVolatility(
    homeTeam: inout Team,
    awayTeam: inout Team,
    input: ScheduledGameSimulationInput,
    random: inout SeededRandom
) {
    guard input.game.type == "regular_season" else { return }

    let powerGap = input.homePower - input.awayPower
    let homeScheduleEdge = input.homeConferenceBaseline - input.awayConferenceBaseline
    let gameNoise = random.nextUnit() + random.nextUnit() + random.nextUnit() - 1.5
    let tailNoise = random.nextUnit() < 0.26 ? (random.nextUnit() - 0.5) * 1.7 : 0
    let underdogSurge = clamp(-(powerGap + homeScheduleEdge * 0.24), min: 0, max: 0.36)
    let favoriteDrag = clamp(powerGap + homeScheduleEdge * 0.16, min: 0, max: 0.4)
    let homeExecution = 1
        + gameNoise * 0.03
        + tailNoise * 0.022
        + underdogSurge * 0.105
        - favoriteDrag * 0.046
    let awayNoise = random.nextUnit() + random.nextUnit() + random.nextUnit() - 1.5
    let awayTailNoise = random.nextUnit() < 0.32 ? (random.nextUnit() - 0.5) * 2.0 : 0
    let awayUnderdogSurge = clamp(powerGap - homeScheduleEdge * 0.12, min: 0, max: 0.42)
    let awayFavoriteDrag = clamp(-powerGap + homeScheduleEdge * 0.08, min: 0, max: 0.36)
    let awayExecution = 1
        + awayNoise * 0.037
        + awayTailNoise * 0.027
        + awayUnderdogSurge * 0.14
        - awayFavoriteDrag * 0.044
        - (input.game.neutralSite ? 0 : 0.016)

    applyTeamExecutionModifier(team: &homeTeam, multiplier: homeExecution)
    applyTeamExecutionModifier(team: &awayTeam, multiplier: awayExecution)
}

private func simulateScheduledGameOutcome(optionsSeed: String, input: ScheduledGameSimulationInput) -> ScheduledGameSimulationOutcome {
    var random = SeededRandom(seed: hashString("sim:\(optionsSeed):\(input.game.gameId)"))
    var homeTeam = input.homeTeam
    var awayTeam = input.awayTeam
    applyScheduledGameVolatility(
        homeTeam: &homeTeam,
        awayTeam: &awayTeam,
        input: input,
        random: &random
    )
    let result = simulateGameForBatch(
        homeTeam: homeTeam,
        awayTeam: awayTeam,
        random: &random,
        includePlayByPlay: false
    )

    var homeScore = result.home.score
    var awayScore = result.away.score
    if input.game.type == "conference_tournament", homeScore == awayScore {
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
        winnerTeamId = homeScore > awayScore ? input.game.homeTeamId : input.game.awayTeamId
    }

    return ScheduledGameSimulationOutcome(
        scheduleIndex: input.scheduleIndex,
        game: input.game,
        homeIndex: input.homeIndex,
        awayIndex: input.awayIndex,
        homeScore: homeScore,
        awayScore: awayScore,
        winnerTeamId: winnerTeamId,
        wentToOvertime: result.wentToOvertime,
        boxScore: result.boxScore
    )
}

private func applyScheduledGameOutcomeInState(_ state: inout LeagueStore.State, outcome: ScheduledGameSimulationOutcome) {
    let scheduleIndex = outcome.scheduleIndex
    let game = outcome.game
    let homeIndex = outcome.homeIndex
    let awayIndex = outcome.awayIndex
    let homeScore = outcome.homeScore
    let awayScore = outcome.awayScore
    let winnerTeamId = outcome.winnerTeamId

    guard scheduleIndex >= 0, scheduleIndex < state.schedule.count else { return }
    guard !state.schedule[scheduleIndex].completed else { return }

    state.schedule[scheduleIndex].completed = true
    state.schedule[scheduleIndex].result = LeagueStore.GameResult(
        homeScore: homeScore,
        awayScore: awayScore,
        winnerTeamId: winnerTeamId,
        wentToOvertime: outcome.wentToOvertime,
        boxScore: outcome.boxScore
    )
    if game.type == "regular_season" {
        if state.remainingRegularSeasonGames == nil {
            state.remainingRegularSeasonGames = state.schedule.reduce(0) { total, scheduledGame in
                total + ((scheduledGame.type == "regular_season" && !scheduledGame.completed) ? 1 : 0)
            }
        }
        if let remaining = state.remainingRegularSeasonGames {
            state.remainingRegularSeasonGames = max(0, remaining - 1)
        }
    }

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

func simulateScheduledDayInState(
    _ state: inout LeagueStore.State,
    scheduleIndexes: [Int],
    teamIndexById: [String: Int]? = nil
) {
    guard !scheduleIndexes.isEmpty else { return }
    let resolvedTeamIndexById: [String: Int]
    if let teamIndexById {
        resolvedTeamIndexById = teamIndexById
    } else {
        resolvedTeamIndexById = Dictionary(
            uniqueKeysWithValues: state.teams.enumerated().map { ($0.element.teamId, $0.offset) }
        )
    }

    let orderedIndexes = scheduleIndexes.sorted()
    var inputs: [ScheduledGameSimulationInput] = []
    inputs.reserveCapacity(orderedIndexes.count)
    for scheduleIndex in orderedIndexes {
        guard let input = makeScheduledGameSimulationInput(
            state: state,
            scheduleIndex: scheduleIndex,
            teamIndexById: resolvedTeamIndexById
        ) else { continue }
        inputs.append(input)
    }
    guard !inputs.isEmpty else { return }

    var hasTeamOverlap = false
    var seenTeamIds = Set<String>()
    for input in inputs {
        if seenTeamIds.contains(input.game.homeTeamId) || seenTeamIds.contains(input.game.awayTeamId) {
            hasTeamOverlap = true
            break
        }
        seenTeamIds.insert(input.game.homeTeamId)
        seenTeamIds.insert(input.game.awayTeamId)
    }

    let canParallelize = !hasTeamOverlap
        && inputs.count >= 4
        && ProcessInfo.processInfo.activeProcessorCount > 1

    if canParallelize {
        let optionsSeed = state.optionsSeed
        let dayInputs = inputs
        let collector = ScheduledGameOutcomeCollector(capacity: dayInputs.count)
        DispatchQueue.concurrentPerform(iterations: dayInputs.count) { index in
            let outcome = simulateScheduledGameOutcome(optionsSeed: optionsSeed, input: dayInputs[index])
            collector.append(outcome)
        }
        for outcome in collector.snapshotSorted() {
            applyScheduledGameOutcomeInState(&state, outcome: outcome)
        }
        return
    }

    for input in inputs {
        let outcome = simulateScheduledGameOutcome(optionsSeed: state.optionsSeed, input: input)
        applyScheduledGameOutcomeInState(&state, outcome: outcome)
    }
}

func simulateScheduledRegularSeasonDaysInState(
    _ state: inout LeagueStore.State,
    dayIndexes: [(day: Int, indexes: [Int])],
    teamIndexById: [String: Int]
) -> Bool {
    guard !dayIndexes.isEmpty else { return true }

    let orderedDayIndexes = dayIndexes.sorted { lhs, rhs in lhs.day < rhs.day }
    var inputs: [ScheduledGameSimulationInput] = []
    inputs.reserveCapacity(orderedDayIndexes.reduce(0) { $0 + $1.indexes.count })

    for day in orderedDayIndexes {
        for scheduleIndex in day.indexes.sorted() {
            guard let input = makeScheduledGameSimulationInput(
                state: state,
                scheduleIndex: scheduleIndex,
                teamIndexById: teamIndexById
            ) else { continue }
            guard input.game.type == "regular_season" else { return false }
            inputs.append(input)
        }
    }
    guard !inputs.isEmpty else { return true }

    let optionsSeed = state.optionsSeed
    let collector = ScheduledGameOutcomeCollector(capacity: inputs.count)
    let simulationInputs = inputs
    if simulationInputs.count >= 4, ProcessInfo.processInfo.activeProcessorCount > 1 {
        DispatchQueue.concurrentPerform(iterations: simulationInputs.count) { index in
            let outcome = simulateScheduledGameOutcome(optionsSeed: optionsSeed, input: simulationInputs[index])
            collector.append(outcome)
        }
    } else {
        for input in simulationInputs {
            collector.append(simulateScheduledGameOutcome(optionsSeed: optionsSeed, input: input))
        }
    }

    let dayByScheduleIndex = Dictionary(uniqueKeysWithValues: simulationInputs.map { ($0.scheduleIndex, $0.game.day) })
    let outcomes = collector.snapshotSorted().sorted { lhs, rhs in
        let lhsDay = dayByScheduleIndex[lhs.scheduleIndex] ?? lhs.game.day
        let rhsDay = dayByScheduleIndex[rhs.scheduleIndex] ?? rhs.game.day
        if lhsDay != rhsDay { return lhsDay < rhsDay }
        return lhs.scheduleIndex < rhs.scheduleIndex
    }
    for outcome in outcomes {
        applyScheduledGameOutcomeInState(&state, outcome: outcome)
    }
    state.currentDay = orderedDayIndexes.last?.day ?? state.currentDay
    return true
}

func simulateScheduledGameInState(
    _ state: inout LeagueStore.State,
    scheduleIndex: Int,
    teamIndexById: [String: Int]? = nil
) {
    simulateScheduledDayInState(&state, scheduleIndexes: [scheduleIndex], teamIndexById: teamIndexById)
}

func resetTeamRecords(_ state: inout LeagueStore.State) {
    for idx in state.teams.indices {
        state.teams[idx].wins = 0
        state.teams[idx].losses = 0
        state.teams[idx].conferenceWins = 0
        state.teams[idx].conferenceLosses = 0
        state.teams[idx].pointsFor = 0
        state.teams[idx].pointsAgainst = 0
    }
}

func prestigeForTeam(teamId: String, conferenceId: String) -> Double {
    let historical = historicalPrestigeByTeamId[teamId]
        ?? clamp(historicalConferenceBaseline(for: conferenceId) + deterministicSpread(teamId: teamId, salt: "hist", amplitude: 0.12), min: 0.22, max: 0.85)
    let recent = recentSuccessByTeamId[teamId]
        ?? clamp(recentConferenceBaseline(for: conferenceId) + deterministicSpread(teamId: teamId, salt: "recent", amplitude: 0.18), min: 0.18, max: 0.9)
    return clamp(historical * 0.7 + recent * 0.3, min: 0.2, max: 0.98)
}
