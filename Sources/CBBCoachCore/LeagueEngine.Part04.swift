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

func nationalTournamentTemplate() -> [[LeagueStore.NationalTournamentState.Matchup]] {
    typealias Ref = LeagueStore.NationalTournamentState.ParticipantRef
    typealias Matchup = LeagueStore.NationalTournamentState.Matchup

    func seed(_ value: Int) -> Ref {
        Ref(overallSeed: value, fromRound: nil, fromGame: nil)
    }

    func winner(_ round: Int, _ game: Int) -> Ref {
        Ref(overallSeed: nil, fromRound: round, fromGame: game)
    }

    let regionSeeds = [
        [1, 16, 8, 9, 5, 12, 4, 13, 6, 11, 3, 14, 7, 10, 2, 15],
        [4, 13, 5, 12, 8, 9, 1, 16, 7, 10, 2, 15, 6, 11, 3, 14],
        [3, 14, 6, 11, 7, 10, 2, 15, 8, 9, 1, 16, 5, 12, 4, 13],
        [2, 15, 7, 10, 6, 11, 3, 14, 5, 12, 4, 13, 8, 9, 1, 16],
    ]

    let roundOne = regionSeeds.enumerated().flatMap { regionIndex, region -> [Matchup] in
        stride(from: 0, to: region.count, by: 2).map { index in
            let topOverallSeed = (region[index] - 1) * 4 + regionIndex + 1
            let bottomOverallSeed = (region[index + 1] - 1) * 4 + regionIndex + 1
            return Matchup(top: seed(topOverallSeed), bottom: seed(bottomOverallSeed))
        }
    }
    let roundTwo = stride(from: 0, to: 32, by: 2).map { Matchup(top: winner(0, $0), bottom: winner(0, $0 + 1)) }
    let roundThree = stride(from: 0, to: 16, by: 2).map { Matchup(top: winner(1, $0), bottom: winner(1, $0 + 1)) }
    let roundFour = stride(from: 0, to: 8, by: 2).map { Matchup(top: winner(2, $0), bottom: winner(2, $0 + 1)) }
    let roundFive = stride(from: 0, to: 4, by: 2).map { Matchup(top: winner(3, $0), bottom: winner(3, $0 + 1)) }
    let championship = [Matchup(top: winner(4, 0), bottom: winner(4, 1))]

    return [roundOne, roundTwo, roundThree, roundFour, roundFive, championship]
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
    prepareNationalTournamentIfNeeded(&state)
    appendReadyNationalTournamentRoundsInState(&state)
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

func conferenceTournamentChampions(_ state: LeagueStore.State) -> [String] {
    guard let tournaments = state.conferenceTournaments, !tournaments.isEmpty else { return [] }
    var champions: [String] = []
    champions.reserveCapacity(tournaments.count)

    for tournament in tournaments {
        guard let finalRound = tournament.winnersByRound.last, finalRound.count == 1, let champion = finalRound.first ?? nil else {
            return []
        }
        champions.append(champion)
    }

    return champions
}

func prepareNationalTournamentIfNeeded(_ state: inout LeagueStore.State) {
    guard state.nationalTournament == nil else { return }
    let automaticBidIds = conferenceTournamentChampions(state)
    guard !automaticBidIds.isEmpty else { return }

    let rankings = calculateRankings(state, topN: state.teams.count).rankings
    var selectedIds = Set(automaticBidIds)
    var orderedIds = automaticBidIds

    for team in rankings where orderedIds.count < 64 {
        guard !selectedIds.contains(team.teamId) else { continue }
        selectedIds.insert(team.teamId)
        orderedIds.append(team.teamId)
    }

    guard orderedIds.count == 64 else { return }

    let rankingIndexByTeamId = Dictionary(uniqueKeysWithValues: rankings.enumerated().map { ($0.element.teamId, $0.offset) })
    orderedIds.sort {
        let lhsRank = rankingIndexByTeamId[$0] ?? Int.max
        let rhsRank = rankingIndexByTeamId[$1] ?? Int.max
        if lhsRank != rhsRank { return lhsRank < rhsRank }
        return $0 < $1
    }

    let automaticBidSet = Set(automaticBidIds)
    let entrants = orderedIds.enumerated().map { index, teamId in
        LeagueStore.NationalTournamentState.Entrant(
            teamId: teamId,
            overallSeed: index + 1,
            seedLine: index / 4 + 1,
            automaticBid: automaticBidSet.contains(teamId)
        )
    }
    let rounds = nationalTournamentTemplate()
    state.nationalTournament = LeagueStore.NationalTournamentState(
        entrants: entrants,
        rounds: rounds,
        winnersByRound: rounds.map { Array(repeating: nil, count: $0.count) },
        scheduledRoundCount: 0
    )
}

func appendReadyNationalTournamentRoundsInState(_ state: inout LeagueStore.State) {
    guard var tournament = state.nationalTournament else { return }

    let roundIndex = tournament.scheduledRoundCount
    guard roundIndex < tournament.rounds.count else { return }

    let teamById = Dictionary(uniqueKeysWithValues: state.teams.map { ($0.teamId, $0) })
    let round = tournament.rounds[roundIndex]
    var resolved: [(homeId: String, awayId: String, gameIndex: Int)] = []
    resolved.reserveCapacity(round.count)

    for gameIndex in round.indices {
        let matchup = round[gameIndex]
        guard
            let topTeamId = resolveNationalTournamentParticipantTeamId(tournament: tournament, participant: matchup.top),
            let bottomTeamId = resolveNationalTournamentParticipantTeamId(tournament: tournament, participant: matchup.bottom)
        else {
            resolved.removeAll(keepingCapacity: false)
            break
        }
        resolved.append((homeId: topTeamId, awayId: bottomTeamId, gameIndex: gameIndex))
    }

    guard resolved.count == round.count else { return }

    let conferenceTournamentEndDay = state.schedule
        .filter { $0.type == "conference_tournament" }
        .map(\.day)
        .max() ?? state.totalRegularSeasonGames
    let day = conferenceTournamentEndDay + 1 + roundIndex

    for game in resolved {
        guard let homeTeam = teamById[game.homeId], let awayTeam = teamById[game.awayId] else { continue }
        state.schedule.append(
            LeagueStore.ScheduledGame(
                gameId: "nt_r\(roundIndex + 1)_g\(game.gameIndex + 1)",
                day: day,
                type: "national_tournament",
                siteType: "neutral",
                neutralSite: true,
                homeTeamId: homeTeam.teamId,
                homeTeamName: homeTeam.teamName,
                awayTeamId: awayTeam.teamId,
                awayTeamName: awayTeam.teamName,
                conferenceId: nil,
                tournamentRound: roundIndex,
                tournamentGameIndex: game.gameIndex,
                completed: false,
                result: nil
            )
        )
    }

    tournament.scheduledRoundCount += 1
    state.nationalTournament = tournament
    state.schedule.sort {
        if $0.day != $1.day { return $0.day < $1.day }
        return $0.gameId < $1.gameId
    }
}

func resolveNationalTournamentParticipantTeamId(
    tournament: LeagueStore.NationalTournamentState,
    participant: LeagueStore.NationalTournamentState.ParticipantRef
) -> String? {
    if let overallSeed = participant.overallSeed {
        return tournament.entrants.first(where: { $0.overallSeed == overallSeed })?.teamId
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

func recordNationalTournamentWinner(
    _ state: inout LeagueStore.State,
    roundIndex: Int,
    gameIndex: Int,
    winnerTeamId: String?
) {
    guard let winnerTeamId else { return }
    guard var tournament = state.nationalTournament else { return }
    guard roundIndex >= 0, roundIndex < tournament.winnersByRound.count else { return }
    guard gameIndex >= 0, gameIndex < tournament.winnersByRound[roundIndex].count else { return }

    tournament.winnersByRound[roundIndex][gameIndex] = winnerTeamId
    state.nationalTournament = tournament
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
    state.nationalTournament = nil
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
    var scheduledGamesByTeamId = Dictionary(uniqueKeysWithValues: state.teams.map { ($0.teamId, 0) })
    var scheduledConferenceGamesByTeamId = Dictionary(uniqueKeysWithValues: state.teams.map { ($0.teamId, 0) })

    func remainingGames(for teamId: String) -> Int {
        guard let team = teamById[teamId] else { return 0 }
        return max(0, team.targetGames - (scheduledGamesByTeamId[teamId] ?? 0))
    }

    func remainingConferenceGames(for teamId: String) -> Int {
        guard let team = teamById[teamId] else { return 0 }
        return max(0, team.targetConferenceGames - (scheduledConferenceGamesByTeamId[teamId] ?? 0))
    }

    func conferenceIdForGame(homeTeam: LeagueStore.TeamState, awayTeam: LeagueStore.TeamState) -> String? {
        homeTeam.conferenceId == awayTeam.conferenceId ? homeTeam.conferenceId : nil
    }

    for opponentId in userOpponents {
        guard let opponent = teamById[opponentId], user.conferenceId == opponent.conferenceId else { continue }
        scheduledConferenceGamesByTeamId[user.teamId, default: 0] += 1
        scheduledConferenceGamesByTeamId[opponent.teamId, default: 0] += 1
    }

    func recordScheduledGame(
        homeTeam: LeagueStore.TeamState,
        awayTeam: LeagueStore.TeamState,
        forcedConferenceId: String? = nil,
        conferenceAlreadyClaimed: Bool = false
    ) -> String? {
        let scheduledConferenceId: String?
        if let forcedConferenceId {
            scheduledConferenceId = forcedConferenceId
        } else if conferenceIdForGame(homeTeam: homeTeam, awayTeam: awayTeam) != nil,
           remainingConferenceGames(for: homeTeam.teamId) > 0,
           remainingConferenceGames(for: awayTeam.teamId) > 0 {
            scheduledConferenceId = homeTeam.conferenceId
        } else {
            scheduledConferenceId = nil
        }

        scheduledGamesByTeamId[homeTeam.teamId, default: 0] += 1
        scheduledGamesByTeamId[awayTeam.teamId, default: 0] += 1
        if scheduledConferenceId != nil && !conferenceAlreadyClaimed {
            scheduledConferenceGamesByTeamId[homeTeam.teamId, default: 0] += 1
            scheduledConferenceGamesByTeamId[awayTeam.teamId, default: 0] += 1
        }
        return scheduledConferenceId
    }

    func takeCPUPair(from availableCPUIds: inout [String]) -> (LeagueStore.TeamState, LeagueStore.TeamState)? {
        availableCPUIds.sort {
            let lhsConferenceNeed = remainingConferenceGames(for: $0)
            let rhsConferenceNeed = remainingConferenceGames(for: $1)
            if lhsConferenceNeed != rhsConferenceNeed { return lhsConferenceNeed > rhsConferenceNeed }
            let lhsGamesNeed = remainingGames(for: $0)
            let rhsGamesNeed = remainingGames(for: $1)
            if lhsGamesNeed != rhsGamesNeed { return lhsGamesNeed > rhsGamesNeed }
            return $0 < $1
        }

        for teamAIndex in availableCPUIds.indices {
            let teamAId = availableCPUIds[teamAIndex]
            guard let teamA = teamById[teamAId], remainingConferenceGames(for: teamAId) > 0 else { continue }
            guard let teamBIndex = availableCPUIds.indices.first(where: { candidateIndex in
                guard candidateIndex != teamAIndex else { return false }
                let candidateId = availableCPUIds[candidateIndex]
                guard let candidate = teamById[candidateId] else { return false }
                return candidate.conferenceId == teamA.conferenceId && remainingConferenceGames(for: candidateId) > 0
            }) else {
                continue
            }
            let firstRemoval = max(teamAIndex, teamBIndex)
            let secondRemoval = min(teamAIndex, teamBIndex)
            let firstTeamId = availableCPUIds.remove(at: firstRemoval)
            let secondTeamId = availableCPUIds.remove(at: secondRemoval)
            guard let firstTeam = teamById[firstTeamId], let secondTeam = teamById[secondTeamId] else { return nil }
            return (firstTeam, secondTeam)
        }

        guard let teamAId = availableCPUIds.first else { return nil }
        availableCPUIds.removeFirst()
        guard let teamA = teamById[teamAId] else { return nil }
        let opponentIndex = availableCPUIds.firstIndex { opponentId in
            guard let opponent = teamById[opponentId] else { return false }
            return opponent.conferenceId != teamA.conferenceId
        } ?? availableCPUIds.indices.first
        guard let opponentIndex else { return nil }
        let teamBId = availableCPUIds.remove(at: opponentIndex)
        guard let teamB = teamById[teamBId] else { return nil }
        return (teamA, teamB)
    }

    for (index, opponentId) in userOpponents.enumerated() {
        guard let opp = teamById[opponentId] else { continue }
        let day = index + 1
        let userHome = random.nextUnit() < 0.52
        let homeTeam = userHome ? user : opp
        let awayTeam = userHome ? opp : user
        let userConferenceId = conferenceIdForGame(homeTeam: homeTeam, awayTeam: awayTeam)
        let scheduledConferenceId = recordScheduledGame(
            homeTeam: homeTeam,
            awayTeam: awayTeam,
            forcedConferenceId: userConferenceId,
            conferenceAlreadyClaimed: userConferenceId != nil
        )
        state.schedule.append(
            LeagueStore.ScheduledGame(
                gameId: "g_\(day)_user",
                day: day,
                type: "regular_season",
                siteType: userHome ? "home" : "away",
                neutralSite: false,
                homeTeamId: homeTeam.teamId,
                homeTeamName: homeTeam.teamName,
                awayTeamId: awayTeam.teamId,
                awayTeamName: awayTeam.teamName,
                conferenceId: scheduledConferenceId,
                tournamentRound: nil,
                tournamentGameIndex: nil,
                completed: false,
                result: nil
            )
        )

        var availableCPUIds = state.teams
            .map(\.teamId)
            .filter { $0 != user.teamId && $0 != opp.teamId && remainingGames(for: $0) > 0 }

        if availableCPUIds.count >= 2 {
            var dayRandom = SeededRandom(seed: hashString("schedule:\(state.optionsSeed):day:\(day)"))
            for idx in stride(from: availableCPUIds.count - 1, through: 1, by: -1) {
                let swapIdx = dayRandom.int(0, idx)
                if swapIdx != idx {
                    availableCPUIds.swapAt(idx, swapIdx)
                }
            }

            var gameNumber = 1
            while let (teamA, teamB) = takeCPUPair(from: &availableCPUIds) {
                let teamAHome = dayRandom.nextUnit() < 0.5
                let homeTeam = teamAHome ? teamA : teamB
                let awayTeam = teamAHome ? teamB : teamA
                let scheduledConferenceId = recordScheduledGame(homeTeam: homeTeam, awayTeam: awayTeam)

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
                        conferenceId: scheduledConferenceId,
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

    return ScheduledGameSimulationInput(
        scheduleIndex: scheduleIndex,
        game: game,
        homeIndex: homeIndex,
        awayIndex: awayIndex,
        homeTeam: homeTeam,
        awayTeam: awayTeam
    )
}

private func simulateScheduledGameOutcome(optionsSeed: String, input: ScheduledGameSimulationInput) -> ScheduledGameSimulationOutcome {
    var random = SeededRandom(seed: hashString("sim:\(optionsSeed):\(input.game.gameId)"))
    let result = simulateGameForBatch(
        homeTeam: input.homeTeam,
        awayTeam: input.awayTeam,
        random: &random,
        includePlayByPlay: false
    )

    var homeScore = result.home.score
    var awayScore = result.away.score
    if (input.game.type == "conference_tournament" || input.game.type == "national_tournament"), homeScore == awayScore {
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

    let updatesConferenceStandings = game.type == "regular_season" && game.conferenceId != nil

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

    if game.type == "national_tournament",
       let roundIndex = game.tournamentRound,
       let gameIndex = game.tournamentGameIndex {
        recordNationalTournamentWinner(
            &state,
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
    LeagueSimulationPauseGate.waitIfPaused()
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
    for day in orderedDayIndexes {
        let indexes = day.indexes.sorted()
        guard indexes.allSatisfy({ idx in
            idx >= 0 && idx < state.schedule.count && state.schedule[idx].type == "regular_season"
        }) else {
            return false
        }
        simulateScheduledDayInState(&state, scheduleIndexes: indexes, teamIndexById: teamIndexById)
        state.currentDay = day.day
    }
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
