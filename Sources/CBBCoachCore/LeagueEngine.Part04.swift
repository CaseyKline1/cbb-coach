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

func simulateScheduledGameInState(
    _ state: inout LeagueStore.State,
    scheduleIndex: Int,
    teamIndexById: [String: Int]? = nil
) {
    guard scheduleIndex >= 0, scheduleIndex < state.schedule.count else { return }
    guard !state.schedule[scheduleIndex].completed else { return }

    let game = state.schedule[scheduleIndex]
    let resolvedTeamIndexById: [String: Int]
    if let teamIndexById {
        resolvedTeamIndexById = teamIndexById
    } else {
        resolvedTeamIndexById = Dictionary(
            uniqueKeysWithValues: state.teams.enumerated().map { ($0.element.teamId, $0.offset) }
        )
    }
    guard
        let homeIndex = resolvedTeamIndexById[game.homeTeamId],
        let awayIndex = resolvedTeamIndexById[game.awayTeamId]
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
