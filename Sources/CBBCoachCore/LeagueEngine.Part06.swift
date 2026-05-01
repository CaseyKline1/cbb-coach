import Foundation

private let nilServiceAcademyNames: Set<String> = [
    "Air Force",
    "Army",
    "Army West Point",
    "Navy",
]

private struct NILAwardAccumulator {
    var nationalAwards: Int = 0
    var allAmericanFirstTeam: Int = 0
    var allAmericanSecondTeam: Int = 0
    var allAmericanThirdTeam: Int = 0
    var allConference: Int = 0

    var score: Double {
        Double(nationalAwards) * 0.55
            + Double(allAmericanFirstTeam) * 0.22
            + Double(allAmericanSecondTeam) * 0.14
            + Double(allAmericanThirdTeam) * 0.09
            + Double(allConference) * 0.035
    }
}

private struct NILPlayerStat: Hashable {
    let playerName: String
    let teamId: String
    let teamName: String
    let conferenceId: String
    let position: String
    let year: PlayerYear?
    var games: Int = 0
    var minutes: Double = 0
    var points: Int = 0
    var rebounds: Int = 0
    var assists: Int = 0
    var steals: Int = 0
    var blocks: Int = 0
    var turnovers: Int = 0
    var fgMade: Int = 0
    var fgAttempts: Int = 0
    var threeMade: Int = 0
    var ftAttempts: Int = 0
    var ftMade: Int = 0

    var normalizedPosition: String {
        normalizeNILPosition(position)
    }

    var minutesPerGame: Double { perGame(minutes) }
    var pointsPerGame: Double { perGame(points) }
    var reboundsPerGame: Double { perGame(rebounds) }
    var assistsPerGame: Double { perGame(assists) }
    var stealsPerGame: Double { perGame(steals) }
    var blocksPerGame: Double { perGame(blocks) }
    var turnoversPerGame: Double { perGame(turnovers) }

    var effectiveFieldGoalPercentage: Double {
        guard fgAttempts > 0 else { return 0 }
        return ((Double(fgMade) + 0.5 * Double(threeMade)) / Double(fgAttempts)) * 100
    }

    var trueShootingPercentage: Double {
        let attempts = 2 * (Double(fgAttempts) + 0.44 * Double(ftAttempts))
        guard attempts > 0 else { return 0 }
        return (Double(points) / attempts) * 100
    }

    var assistTurnoverRatio: Double {
        Double(assists) / Double(max(1, turnovers))
    }

    var awardScore: Double {
        pointsPerGame
            + reboundsPerGame * 1.15
            + assistsPerGame * 1.45
            + stealsPerGame * 2.2
            + blocksPerGame * 2.0
            + effectiveFieldGoalPercentage * 0.08
            + trueShootingPercentage * 0.06
            + assistTurnoverRatio * 1.2
            + minutesPerGame * 0.08
            - turnoversPerGame * 0.9
            + min(Double(games), 38) * 0.06
    }

    private func perGame(_ value: Int) -> Double {
        guard games > 0 else { return 0 }
        return Double(value) / Double(games)
    }

    private func perGame(_ value: Double) -> Double {
        guard games > 0 else { return 0 }
        return value / Double(games)
    }
}

public func getNILBudgetSummary(_ league: LeagueState) -> NILBudgetSummary {
    guard let state = LeagueStore.get(league.handle) else {
        return NILBudgetSummary(userTeamId: "", teams: [], conferenceAverage: 0, nationalAverage: 0)
    }

    return calculateNILBudgetSummary(state)
}

func calculateNILBudgetSummary(_ state: LeagueStore.State) -> NILBudgetSummary {
    let awardsByTeamId = calculateNILAwardsByTeamId(state)
    let nationalTournamentTeamIds = Set(state.nationalTournament?.entrants.map(\.teamId) ?? [])
    let nationalChampionTeamId = state.nationalTournament?.winnersByRound.last?.first ?? nil
    let conferenceTournamentChampionIds = Set((state.conferenceTournaments ?? []).compactMap { $0.winnersByRound.last?.first ?? nil })
    let regularSeasonChampionIds = regularSeasonConferenceChampionIds(state)
    let nationalWinsByTeamId = nationalTournamentWinsByTeamId(state)

    let teams = state.teams.map { team -> NILBudgetTeamSummary in
        let serviceAcademy = isNILServiceAcademy(team.teamName)
        if serviceAcademy {
            return NILBudgetTeamSummary(
                teamId: team.teamId,
                teamName: team.teamName,
                conferenceId: team.conferenceId,
                conferenceName: team.conferenceName,
                revenueSharing: 0,
                donations: 0,
                total: 0,
                serviceAcademy: true,
                prestigeScore: team.prestige,
                fundraisingScore: Double(team.teamModel.coachingStaff.headCoach.skills.fundraising) / 100,
                successScore: 0,
                awardScore: 0
            )
        }

        let revenue = nilRevenueSharing(for: team)
        let awardScore = awardsByTeamId[team.teamId]?.score ?? 0
        let successScore = nilSuccessScore(
            team: team,
            madeNationalTournament: nationalTournamentTeamIds.contains(team.teamId),
            nationalTournamentWins: nationalWinsByTeamId[team.teamId] ?? 0,
            nationalChampion: nationalChampionTeamId == team.teamId,
            conferenceTournamentChampion: conferenceTournamentChampionIds.contains(team.teamId),
            regularSeasonChampion: regularSeasonChampionIds.contains(team.teamId),
            awardScore: awardScore
        )
        let fundraising = Double(team.teamModel.coachingStaff.headCoach.skills.fundraising) / 100
        let donations = nilDonations(
            team: team,
            fundraisingScore: fundraising,
            successScore: successScore,
            awardScore: awardScore,
            optionsSeed: state.optionsSeed
        )

        return NILBudgetTeamSummary(
            teamId: team.teamId,
            teamName: team.teamName,
            conferenceId: team.conferenceId,
            conferenceName: team.conferenceName,
            revenueSharing: revenue,
            donations: donations,
            total: revenue + donations,
            serviceAcademy: false,
            prestigeScore: team.prestige,
            fundraisingScore: fundraising,
            successScore: successScore,
            awardScore: awardScore
        )
    }
    .sorted {
        if $0.total != $1.total { return $0.total > $1.total }
        return $0.teamName < $1.teamName
    }

    let nationalAverage = average(teams.map(\.total))
    let userConferenceId = state.teams.first(where: { $0.teamId == state.userTeamId })?.conferenceId
    let conferenceTeams = teams.filter { $0.conferenceId == userConferenceId }
    let conferenceAverage = average(conferenceTeams.map(\.total))

    return NILBudgetSummary(
        userTeamId: state.userTeamId,
        teams: teams,
        conferenceAverage: conferenceAverage,
        nationalAverage: nationalAverage
    )
}

private func nilRevenueSharing(for team: LeagueStore.TeamState) -> Double {
    if isNILServiceAcademy(team.teamName) { return 0 }
    if team.teamName.caseInsensitiveCompare("UConn") == .orderedSame { return 8_000_000 }

    switch team.conferenceId {
    case "acc", "big-ten", "big-12":
        return 6_000_000
    case "sec":
        return 3_000_000
    default:
        return 1_000_000
    }
}

private func nilDonations(
    team: LeagueStore.TeamState,
    fundraisingScore: Double,
    successScore: Double,
    awardScore: Double,
    optionsSeed: String
) -> Double {
    let prestigeBase = pow(clamp(team.prestige, min: 0, max: 1), 1.05) * 2_700_000
    let fundraisingMultiplier = 0.48 + clamp(fundraisingScore, min: 0, max: 1) * 1.12
    let successAmount = successScore * 1_350_000
    let awardAmount = awardScore * 550_000
    let variance = 0.82 + deterministicNILRoll(seed: "\(optionsSeed):nil:\(team.teamId)") * 0.36
    let donationScale = 0.75
    return max(0, (prestigeBase + successAmount + awardAmount) * fundraisingMultiplier * variance * donationScale)
}

private func nilSuccessScore(
    team: LeagueStore.TeamState,
    madeNationalTournament: Bool,
    nationalTournamentWins: Int,
    nationalChampion: Bool,
    conferenceTournamentChampion: Bool,
    regularSeasonChampion: Bool,
    awardScore: Double
) -> Double {
    let games = max(1, team.wins + team.losses)
    let winRate = Double(team.wins) / Double(games)
    let recordScore = clamp((winRate - 0.38) / 0.42, min: 0, max: 1) * 0.75
    let winsScore = clamp(Double(team.wins) / 34, min: 0, max: 1) * 0.4
    let appearanceScore = madeNationalTournament ? 0.45 : 0
    let tournamentWinScore = Double(nationalTournamentWins) * 0.34
    let finalFourScore = nationalTournamentWins >= 4 ? 0.8 : 0
    let runnerUpScore = nationalTournamentWins >= 5 ? 0.7 : 0
    let championshipScore = nationalChampion ? 1.5 : 0
    let conferenceTournamentScore = conferenceTournamentChampion ? 0.7 : 0
    let regularSeasonTitleScore = regularSeasonChampion ? 0.55 : 0

    return recordScore
        + winsScore
        + appearanceScore
        + tournamentWinScore
        + finalFourScore
        + runnerUpScore
        + championshipScore
        + conferenceTournamentScore
        + regularSeasonTitleScore
        + awardScore * 0.28
}

private func regularSeasonConferenceChampionIds(_ state: LeagueStore.State) -> Set<String> {
    var result: Set<String> = []
    let grouped = Dictionary(grouping: state.teams, by: \.conferenceId)
    for teams in grouped.values {
        guard let top = teams.sorted(by: regularSeasonChampionSort).first else { continue }
        result.insert(top.teamId)
    }
    return result
}

private func regularSeasonChampionSort(_ lhs: LeagueStore.TeamState, _ rhs: LeagueStore.TeamState) -> Bool {
    if lhs.conferenceWins != rhs.conferenceWins { return lhs.conferenceWins > rhs.conferenceWins }
    if lhs.conferenceLosses != rhs.conferenceLosses { return lhs.conferenceLosses < rhs.conferenceLosses }
    if lhs.wins != rhs.wins { return lhs.wins > rhs.wins }
    if lhs.losses != rhs.losses { return lhs.losses < rhs.losses }
    return lhs.teamName < rhs.teamName
}

private func nationalTournamentWinsByTeamId(_ state: LeagueStore.State) -> [String: Int] {
    var result: [String: Int] = [:]
    for game in state.schedule where game.type == "national_tournament" && game.completed {
        guard let winnerTeamId = game.result?.winnerTeamId else { continue }
        result[winnerTeamId, default: 0] += 1
    }
    return result
}

private func calculateNILAwardsByTeamId(_ state: LeagueStore.State) -> [String: NILAwardAccumulator] {
    let stats = buildNILPlayerStats(state)
    let eligible = stats
        .filter { $0.games >= 8 && $0.minutesPerGame >= 12 }
        .sorted {
            if $0.awardScore != $1.awardScore { return $0.awardScore > $1.awardScore }
            return $0.playerName.localizedCaseInsensitiveCompare($1.playerName) == .orderedAscending
        }
    guard !eligible.isEmpty else { return [:] }

    var result: [String: NILAwardAccumulator] = [:]
    func add(_ teamId: String, _ apply: (inout NILAwardAccumulator) -> Void) {
        var current = result[teamId] ?? NILAwardAccumulator()
        apply(&current)
        result[teamId] = current
    }

    if let top = eligible.first {
        add(top.teamId) { $0.nationalAwards += 1 }
    }
    if let freshman = eligible.first(where: { $0.year == .fr }) {
        add(freshman.teamId) { $0.nationalAwards += 1 }
    }
    for position in ["PG", "SG", "SF", "PF", "C"] {
        if let best = eligible.first(where: { $0.normalizedPosition == position }) {
            add(best.teamId) { $0.nationalAwards += 1 }
        }
    }

    let allAmericans = Array(eligible.prefix(15))
    for (index, player) in allAmericans.enumerated() {
        add(player.teamId) { accumulator in
            switch index {
            case 0..<5: accumulator.allAmericanFirstTeam += 1
            case 5..<10: accumulator.allAmericanSecondTeam += 1
            default: accumulator.allAmericanThirdTeam += 1
            }
        }
    }

    let byConference = Dictionary(grouping: eligible, by: \.conferenceId)
    for players in byConference.values {
        for player in players.prefix(10) {
            add(player.teamId) { $0.allConference += 1 }
        }
    }

    return result
}

private func buildNILPlayerStats(_ state: LeagueStore.State) -> [NILPlayerStat] {
    struct Key: Hashable {
        let playerName: String
        let teamId: String
        let position: String
    }

    let rosterPlayerByTeamAndName = Dictionary(uniqueKeysWithValues: state.teams.map { team in
        let playersByName = Dictionary(grouping: team.teamModel.players, by: { $0.bio.name })
        return (team.teamId, playersByName)
    })
    let teamByName = Dictionary(uniqueKeysWithValues: state.teams.map { ($0.teamName, $0) })

    var totals: [Key: NILPlayerStat] = [:]
    for game in state.schedule where game.completed {
        guard let boxScore = game.result?.boxScore else { continue }
        for (index, teamBox) in boxScore.enumerated() {
            let teamId = index == 0 ? game.homeTeamId : game.awayTeamId
            let fallbackTeamName = index == 0 ? game.homeTeamName : game.awayTeamName
            guard let team = state.teams.first(where: { $0.teamId == teamId }) ?? teamByName[teamBox.name] else { continue }

            for player in teamBox.players {
                let key = Key(playerName: player.playerName, teamId: team.teamId, position: player.position)
                let rosterPlayer = rosterPlayerByTeamAndName[team.teamId]?[player.playerName]?.first
                var current = totals[key] ?? NILPlayerStat(
                    playerName: player.playerName,
                    teamId: team.teamId,
                    teamName: fallbackTeamName,
                    conferenceId: team.conferenceId,
                    position: player.position,
                    year: rosterPlayer?.bio.year
                )
                current.games += 1
                current.minutes += player.minutes
                current.points += player.points
                current.rebounds += player.rebounds
                current.assists += player.assists
                current.steals += player.steals
                current.blocks += player.blocks
                current.turnovers += player.turnovers
                current.fgMade += player.fgMade
                current.fgAttempts += player.fgAttempts
                current.threeMade += player.threeMade
                current.ftMade += player.ftMade
                current.ftAttempts += player.ftAttempts
                totals[key] = current
            }
        }
    }

    return Array(totals.values)
}

private func isNILServiceAcademy(_ teamName: String) -> Bool {
    nilServiceAcademyNames.contains { teamName.caseInsensitiveCompare($0) == .orderedSame }
}

private func normalizeNILPosition(_ position: String) -> String {
    switch position.uppercased() {
    case "POINT GUARD", "PG": return "PG"
    case "SHOOTING GUARD", "SG": return "SG"
    case "SMALL FORWARD", "SF": return "SF"
    case "POWER FORWARD", "PF": return "PF"
    case "CENTER", "C": return "C"
    default: return position.uppercased()
    }
}

private func deterministicNILRoll(seed: String) -> Double {
    var rng = SeededRandom(seed: hashString(seed))
    return rng.nextUnit()
}
