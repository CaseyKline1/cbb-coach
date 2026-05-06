import Foundation

func currentSeasonSchoolLegacyStats(_ state: LeagueStore.State) -> [String: SchoolLegacyStats] {
    var result: [String: SchoolLegacyStats] = [:]
    for team in state.teams {
        result[team.teamId] = SchoolLegacyStats(
            wins: team.wins,
            losses: team.losses,
            conferenceWins: team.conferenceWins,
            conferenceLosses: team.conferenceLosses
        )
    }

    let confChampions = conferenceTournamentChampions(state)
    for teamId in confChampions {
        result[teamId, default: SchoolLegacyStats()].conferenceTournamentTitles += 1
    }

    if let national = state.nationalTournament {
        for entrant in national.entrants {
            result[entrant.teamId, default: SchoolLegacyStats()].nationalTournamentAppearances += 1
        }
        if national.winnersByRound.indices.contains(4) {
            for case let teamId? in national.winnersByRound[4] {
                result[teamId, default: SchoolLegacyStats()].finalFourAppearances += 1
            }
        }
        if let last = national.winnersByRound.last,
           last.count == 1,
           let champ = last.first ?? nil {
            result[champ, default: SchoolLegacyStats()].nationalTitles += 1
        }
    }

    for game in state.schedule where game.type == "national_tournament" && game.completed {
        guard let winnerId = game.result?.winnerTeamId else { continue }
        result[winnerId, default: SchoolLegacyStats()].nationalTournamentWins += 1
    }

    let honors = hallHonorsByTeamAndPlayer(state)
    for (teamId, players) in honors {
        var stats = result[teamId] ?? SchoolLegacyStats()
        for honorList in players.values {
            for honor in honorList {
                if honor == "National Player of the Year" {
                    stats.nationalPlayersOfYear += 1
                } else if honor == "Freshman of the Year" {
                    stats.freshmenOfYear += 1
                } else if honor == "First Team All-American" {
                    stats.allAmericanFirstTeam += 1
                } else if honor == "Second Team All-American" {
                    stats.allAmericanSecondTeam += 1
                } else if honor == "Third Team All-American" {
                    stats.allAmericanThirdTeam += 1
                } else if honor.hasPrefix("First Team All-") {
                    stats.allConferenceFirstTeam += 1
                } else if honor.hasPrefix("Second Team All-") {
                    stats.allConferenceSecondTeam += 1
                }
            }
        }
        result[teamId] = stats
    }

    if let hofEntries = state.schoolHallOfFame {
        for entry in hofEntries {
            result[entry.teamId, default: SchoolLegacyStats()].hallOfFamers += 1
        }
    }

    if let picks = state.draftPicks {
        for pick in picks {
            var stats = result[pick.teamId] ?? SchoolLegacyStats()
            stats.totalDraftPicks += 1
            if pick.slot <= 30 {
                stats.firstRoundDraftPicks += 1
            }
            result[pick.teamId] = stats
        }
    }

    return result
}

func archiveCompletedSeasonLegacies(_ state: inout LeagueStore.State) {
    if state.playersLeaving == nil {
        state.playersLeaving = calculatePlayersLeaving(state)
    }
    if state.draftPicks == nil {
        state.draftPicks = calculateDraftPicks(state)
    }
    if state.schoolHallOfFame == nil {
        state.schoolHallOfFame = calculateSchoolHallOfFame(state)
    }

    let seasonStats = currentSeasonSchoolLegacyStats(state)
    var archive = state.schoolLegacyByTeamId ?? [:]
    for (teamId, stats) in seasonStats {
        archive[teamId] = (archive[teamId] ?? SchoolLegacyStats()) + stats
    }
    state.schoolLegacyByTeamId = archive
    state.schoolLegacySeasonsTracked = (state.schoolLegacySeasonsTracked ?? 0) + 1
    updatePrestigeFromSchoolLegacies(&state, seasonStats: seasonStats)
}

private func updatePrestigeFromSchoolLegacies(
    _ state: inout LeagueStore.State,
    seasonStats: [String: SchoolLegacyStats]
) {
    let seasonsTracked = max(1, state.schoolLegacySeasonsTracked ?? 1)
    let currentPrestigeByConference = Dictionary(grouping: state.teams, by: \.conferenceId)
        .mapValues { teams in
            teams.reduce(0) { $0 + clamp($1.prestige, min: 0, max: 1) } / Double(max(1, teams.count))
        }
    let nationalAveragePrestige = max(
        0.01,
        state.teams.reduce(0) { $0 + clamp($1.prestige, min: 0, max: 1) } / Double(max(1, state.teams.count))
    )

    for index in state.teams.indices {
        let team = state.teams[index]
        let archivedStats = state.schoolLegacyByTeamId?[team.teamId] ?? SchoolLegacyStats()
        let currentSeasonStats = seasonStats[team.teamId] ?? SchoolLegacyStats()
        let conferenceAveragePrestige = currentPrestigeByConference[team.conferenceId] ?? nationalAveragePrestige
        let conferenceCurve = clamp(
            0.76 + (conferenceAveragePrestige / nationalAveragePrestige) * 0.24,
            min: 0.78,
            max: 1.18
        )
        let historicalBaseline = prestigeForTeam(teamId: team.teamId, conferenceId: team.conferenceId)
        let fullLegacyTarget = prestigeTarget(
            for: archivedStats,
            seasonsTracked: seasonsTracked,
            conferenceCurve: conferenceCurve,
            historicalBaseline: historicalBaseline
        )
        let seasonMomentum = prestigeTarget(
            for: currentSeasonStats,
            seasonsTracked: 1,
            conferenceCurve: conferenceCurve,
            historicalBaseline: historicalBaseline
        )
        let baselineWeight = 0.38 + clamp(team.prestige - 0.72, min: 0, max: 0.22)
        let performanceTarget = fullLegacyTarget * 0.72 + seasonMomentum * 0.28
        let target = historicalBaseline * baselineWeight + performanceTarget * (1 - baselineWeight)
        let riseRate = 0.055 + clamp((0.62 - team.prestige) * 0.055, min: 0, max: 0.024)
        let fallRate = 0.034 + clamp((team.prestige - 0.82) * 0.09, min: 0, max: 0.026)
        let adjustmentRate = target >= team.prestige ? riseRate : fallRate
        let nextPrestige = team.prestige + (target - team.prestige) * adjustmentRate
        state.teams[index].prestige = clamp(nextPrestige, min: 0.16, max: 0.985)
    }
}

private func prestigeTarget(
    for stats: SchoolLegacyStats,
    seasonsTracked: Int,
    conferenceCurve: Double,
    historicalBaseline: Double
) -> Double {
    let seasons = Double(max(1, seasonsTracked))
    let games = max(1, stats.wins + stats.losses)
    let conferenceGames = max(1, stats.conferenceWins + stats.conferenceLosses)
    let winPct = Double(stats.wins) / Double(games)
    let conferenceWinPct = Double(stats.conferenceWins) / Double(conferenceGames)

    let regularSeasonScore = (winPct - 0.50) * 0.42
    let conferenceScore = ((conferenceWinPct - 0.50) * 0.22
        + perSeason(stats.conferenceTournamentTitles, seasons) * 0.16) * conferenceCurve
    let nationalScore = perSeason(stats.nationalTournamentAppearances, seasons) * 0.07
        + perSeason(stats.nationalTournamentWins, seasons) * 0.055
        + perSeason(stats.finalFourAppearances, seasons) * 0.30
        + perSeason(stats.nationalTitles, seasons) * 0.52
    let playerDevelopmentScore = perSeason(stats.totalDraftPicks, seasons) * 0.030
        + perSeason(stats.firstRoundDraftPicks, seasons) * 0.055
        + perSeason(stats.hallOfFamers, seasons) * 0.030
    let awardScore = perSeason(stats.nationalPlayersOfYear, seasons) * 0.050
        + perSeason(stats.freshmenOfYear, seasons) * 0.028
        + perSeason(stats.allAmericanFirstTeam, seasons) * 0.035
        + perSeason(stats.allAmericanSecondTeam, seasons) * 0.024
        + perSeason(stats.allAmericanThirdTeam, seasons) * 0.018
        + perSeason(stats.allConferenceFirstTeam, seasons) * 0.010 * conferenceCurve
        + perSeason(stats.allConferenceSecondTeam, seasons) * 0.006 * conferenceCurve

    let elitePostseasonLift = stats.nationalTitles > 0
        ? 0.08
        : (stats.finalFourAppearances > 0 ? 0.035 : 0)
    let target = 0.46
        + (historicalBaseline - 0.50) * 0.28
        + regularSeasonScore
        + conferenceScore
        + nationalScore
        + playerDevelopmentScore
        + awardScore
        + elitePostseasonLift

    return clamp(target, min: 0.18, max: 0.985)
}

private func perSeason(_ value: Int, _ seasons: Double) -> Double {
    Double(value) / max(1, seasons)
}

public func getSchoolLegaciesSummary(_ league: LeagueState) -> SchoolLegaciesSummary {
    guard let summary = LeagueStore.update(league.handle, { state -> SchoolLegaciesSummary in
        let archived = state.schoolLegacyByTeamId ?? [:]
        let archivedSeasons = state.schoolLegacySeasonsTracked ?? 0

        let isMidSeasonOrCompleted = state.scheduleGenerated
        let currentLayer = isMidSeasonOrCompleted ? currentSeasonSchoolLegacyStats(state) : [:]

        var entries: [SchoolLegacyEntry] = []
        entries.reserveCapacity(state.teams.count)
        for team in state.teams {
            let combined = (archived[team.teamId] ?? SchoolLegacyStats())
                + (currentLayer[team.teamId] ?? SchoolLegacyStats())
            entries.append(
                SchoolLegacyEntry(
                    teamId: team.teamId,
                    teamName: team.teamName,
                    conferenceId: team.conferenceId,
                    conferenceName: team.conferenceName,
                    stats: combined
                )
            )
        }
        entries.sort { lhs, rhs in
            if lhs.stats.nationalTitles != rhs.stats.nationalTitles {
                return lhs.stats.nationalTitles > rhs.stats.nationalTitles
            }
            if lhs.stats.conferenceTournamentTitles != rhs.stats.conferenceTournamentTitles {
                return lhs.stats.conferenceTournamentTitles > rhs.stats.conferenceTournamentTitles
            }
            if lhs.stats.wins != rhs.stats.wins {
                return lhs.stats.wins > rhs.stats.wins
            }
            return lhs.teamName.localizedCaseInsensitiveCompare(rhs.teamName) == .orderedAscending
        }
        return SchoolLegaciesSummary(
            userTeamId: state.userTeamId,
            seasonsTracked: archivedSeasons,
            entries: entries
        )
    }) else {
        return SchoolLegaciesSummary(userTeamId: "", seasonsTracked: 0, entries: [])
    }
    return summary
}
