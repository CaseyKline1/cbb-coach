import Foundation

private struct LeavingPlayerStat {
    var games: Int = 0
    var minutes: Double = 0
}

public func getPlayersLeavingSummary(_ league: LeagueState) -> PlayersLeavingSummary {
    guard let summary = LeagueStore.update(league.handle, { state -> PlayersLeavingSummary in
        guard state.status == "completed" else {
            return PlayersLeavingSummary(userTeamId: state.userTeamId, entries: state.playersLeaving ?? [])
        }
        if state.playersLeaving == nil {
            state.playersLeaving = calculatePlayersLeaving(state)
        }
        return PlayersLeavingSummary(userTeamId: state.userTeamId, entries: state.playersLeaving ?? [])
    }) else {
        return PlayersLeavingSummary(userTeamId: "", entries: [])
    }
    return summary
}

func calculatePlayersLeaving(_ state: LeagueStore.State) -> [PlayerLeavingEntry] {
    let minutesByTeamAndPlayer = buildLeavingPlayerStats(state)
    var entries: [PlayerLeavingEntry] = []

    for team in state.teams {
        let teamPrestige = clamp(team.prestige, min: 0, max: 1)
        let teamStats = minutesByTeamAndPlayer[team.teamId] ?? [:]
        let totalTeamMinutes = max(1, teamStats.values.reduce(0) { $0 + $1.minutes })

        for (playerIndex, player) in team.teamModel.players.enumerated() {
            let overall = playerOverall(player)
            let stats = teamStats[player.bio.name] ?? LeavingPlayerStat()
            let minutesShare = clamp(stats.minutes / totalTeamMinutes, min: 0, max: 1)
            let expectedShare = expectedMinutesShare(for: player, overall: overall)
            let loyalty = resolvedLoyalty(player, teamId: team.teamId)
            let greed = resolvedGreed(player, teamId: team.teamId)
            let nilDollars = player.bio.nilDollarsLastYear ?? 0

            if player.bio.year == .sr && !isLikelyRedshirtingSenior(player, stats: stats, teamGames: max(1, team.wins + team.losses)) {
                entries.append(
                    leavingEntry(
                        team: team,
                        player: player,
                        playerIndex: playerIndex,
                        overall: overall,
                        outcome: .graduated,
                        reason: "Graduated after senior season.",
                        minutesShare: minutesShare,
                        expectedShare: expectedShare,
                        transferRisk: 1,
                        loyalty: loyalty,
                        greed: greed,
                        nilDollars: nilDollars
                    )
                )
                continue
            }

            guard player.bio.year != .sr else { continue }

            let playingTimeGap = max(0, expectedShare - minutesShare)
            let tooGoodPressure = clamp((Double(overall) - 78) / 16, min: 0, max: 1)
                * clamp((0.74 - teamPrestige) / 0.34, min: 0, max: 1)
            let nilExpectation = clamp(nilDollars / 450_000, min: 0, max: 1) * 0.12
            let loyaltyStay = clamp(loyalty / 100, min: 0, max: 1)
            let greedPressure = clamp(greed / 100, min: 0, max: 1)
            let volatility = deterministicLeavingRoll(state: state, teamId: team.teamId, playerName: player.bio.name, salt: "variance") - 0.5
            let risk = clamp(
                0.015
                    + playingTimeGap * 1.28
                    + tooGoodPressure * 0.32
                    + nilExpectation
                    + greedPressure * 0.11
                    - loyaltyStay * 0.14
                    + volatility * 0.08,
                min: 0.005,
                max: 0.72
            )
            let roll = deterministicLeavingRoll(state: state, teamId: team.teamId, playerName: player.bio.name, salt: "decision")
            guard roll < risk else { continue }

            let reason: String
            if tooGoodPressure > 0.28 && tooGoodPressure >= playingTimeGap {
                reason = "Wants a bigger stage and stronger NIL market."
            } else if playingTimeGap > 0.10 {
                reason = "Frustrated with limited playing time."
            } else if nilDollars > 0 {
                reason = "Role is not matching last year's NIL expectations."
            } else {
                reason = "Exploring a better fit."
            }

            entries.append(
                leavingEntry(
                    team: team,
                    player: player,
                    playerIndex: playerIndex,
                    overall: overall,
                    outcome: .transfer,
                    reason: reason,
                    minutesShare: minutesShare,
                    expectedShare: expectedShare,
                    transferRisk: risk,
                    loyalty: loyalty,
                    greed: greed,
                    nilDollars: nilDollars
                )
            )
        }
    }

    return entries.sorted { lhs, rhs in
        if lhs.teamId == rhs.teamId {
            if lhs.outcome != rhs.outcome { return lhs.outcome == .graduated }
            if lhs.transferRisk != rhs.transferRisk { return lhs.transferRisk > rhs.transferRisk }
            return lhs.playerName < rhs.playerName
        }
        return lhs.teamName < rhs.teamName
    }
}

private func buildLeavingPlayerStats(_ state: LeagueStore.State) -> [String: [String: LeavingPlayerStat]] {
    var totals: [String: [String: LeavingPlayerStat]] = [:]
    for game in state.schedule where game.completed {
        guard let boxScore = game.result?.boxScore else { continue }
        for (index, teamBox) in boxScore.enumerated() {
            let teamId = index == 0 ? game.homeTeamId : game.awayTeamId
            for player in teamBox.players {
                var current = totals[teamId]?[player.playerName] ?? LeavingPlayerStat()
                current.games += 1
                current.minutes += player.minutes
                totals[teamId, default: [:]][player.playerName] = current
            }
        }
    }
    return totals
}

private func expectedMinutesShare(for player: Player, overall: Int) -> Double {
    let overallFactor = clamp((Double(overall) - 54) / 36, min: 0, max: 1)
    let potentialFactor = clamp((Double(player.bio.potential) - 58) / 34, min: 0, max: 1)
    let nilFactor = clamp((player.bio.nilDollarsLastYear ?? 0) / 650_000, min: 0, max: 1)
    let classBump: Double
    switch player.bio.year {
    case .fr: classBump = -0.025
    case .so: classBump = 0.0
    case .jr: classBump = 0.025
    case .sr: classBump = 0.04
    default: classBump = 0.0
    }
    return clamp(0.035 + overallFactor * 0.175 + potentialFactor * 0.055 + nilFactor * 0.075 + classBump, min: 0.02, max: 0.31)
}

private func isLikelyRedshirtingSenior(_ player: Player, stats: LeavingPlayerStat, teamGames: Int) -> Bool {
    guard !player.bio.redshirtUsed else { return false }
    guard teamGames > 0 else { return false }
    let gamesShare = Double(stats.games) / Double(teamGames)
    let minutesPerTeamGame = stats.minutes / Double(teamGames)
    return gamesShare <= 0.25 && minutesPerTeamGame < 4.0
}

private func resolvedGreed(_ player: Player, teamId: String) -> Double {
    if let greed = player.greed { return clamp(greed, min: 0, max: 100) }
    return 50 + (deterministicPersonalityRoll(player, teamId: teamId, salt: "greed") - 0.5) * 34
}

private func resolvedLoyalty(_ player: Player, teamId: String) -> Double {
    if let loyalty = player.loyalty { return clamp(loyalty, min: 0, max: 100) }
    return 52 + (deterministicPersonalityRoll(player, teamId: teamId, salt: "loyalty") - 0.5) * 38
}

private func deterministicPersonalityRoll(_ player: Player, teamId: String, salt: String) -> Double {
    var random = SeededRandom(seed: hashString("\(teamId):\(player.bio.name):\(salt)"))
    return random.nextUnit()
}

private func deterministicLeavingRoll(state: LeagueStore.State, teamId: String, playerName: String, salt: String) -> Double {
    var random = SeededRandom(seed: hashString("\(state.optionsSeed):leaving:\(state.currentDay):\(teamId):\(playerName):\(salt)"))
    return random.nextUnit()
}

private func leavingEntry(
    team: LeagueStore.TeamState,
    player: Player,
    playerIndex: Int,
    overall: Int,
    outcome: PlayerLeavingOutcome,
    reason: String,
    minutesShare: Double,
    expectedShare: Double,
    transferRisk: Double,
    loyalty: Double,
    greed: Double,
    nilDollars: Double
) -> PlayerLeavingEntry {
    PlayerLeavingEntry(
        id: "\(team.teamId):\(playerIndex):\(player.bio.name):\(outcome.rawValue)",
        teamId: team.teamId,
        teamName: team.teamName,
        playerName: player.bio.name,
        position: player.bio.position.rawValue,
        year: player.bio.year.rawValue,
        overall: overall,
        potential: player.bio.potential,
        outcome: outcome,
        reason: reason,
        minutesShare: minutesShare,
        expectedMinutesShare: expectedShare,
        transferRisk: transferRisk,
        loyalty: loyalty,
        greed: greed,
        nilDollarsLastYear: nilDollars
    )
}
