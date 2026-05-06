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
    let seasonStats = currentSeasonSchoolLegacyStats(state)
    var archive = state.schoolLegacyByTeamId ?? [:]
    for (teamId, stats) in seasonStats {
        archive[teamId] = (archive[teamId] ?? SchoolLegacyStats()) + stats
    }
    state.schoolLegacyByTeamId = archive
    state.schoolLegacySeasonsTracked = (state.schoolLegacySeasonsTracked ?? 0) + 1
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
