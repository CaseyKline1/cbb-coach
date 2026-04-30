import Foundation

private struct LeavingPlayerStat {
    var games: Int = 0
    var minutes: Double = 0
}

private struct HallCandidateStat: Hashable {
    let playerName: String
    let teamId: String
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

    var normalizedPosition: String { normalizeHallPosition(position) }
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

public func getSchoolHallOfFameSummary(_ league: LeagueState) -> SchoolHallOfFameSummary {
    guard let summary = LeagueStore.update(league.handle, { state -> SchoolHallOfFameSummary in
        guard state.status == "completed" else {
            return SchoolHallOfFameSummary(userTeamId: state.userTeamId, entries: state.schoolHallOfFame ?? [])
        }
        if state.playersLeaving == nil {
            state.playersLeaving = calculatePlayersLeaving(state)
        }
        if state.schoolHallOfFame == nil {
            state.schoolHallOfFame = calculateSchoolHallOfFame(state)
        }
        return SchoolHallOfFameSummary(userTeamId: state.userTeamId, entries: state.schoolHallOfFame ?? [])
    }) else {
        return SchoolHallOfFameSummary(userTeamId: "", entries: [])
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
        let lineupNames = Set(team.teamModel.lineup.map(\.bio.name))
        let rosterSummaries = rosterSummaryPlayers(from: team.teamModel, lineupNames: lineupNames)

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
                        playerSummary: playerIndex < rosterSummaries.count ? rosterSummaries[playerIndex] : nil,
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
                    playerSummary: playerIndex < rosterSummaries.count ? rosterSummaries[playerIndex] : nil,
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

func calculateSchoolHallOfFame(_ state: LeagueStore.State) -> [SchoolHallOfFameEntry] {
    let honorsByTeamAndPlayer = hallHonorsByTeamAndPlayer(state)
    let leaving = state.playersLeaving ?? calculatePlayersLeaving(state)
    var entries: [SchoolHallOfFameEntry] = []

    for departure in leaving where departure.outcome == .graduated {
        guard let honors = honorsByTeamAndPlayer[departure.teamId]?[departure.playerName], !honors.isEmpty else { continue }
        guard let team = state.teams.first(where: { $0.teamId == departure.teamId }) else { continue }
        guard let playerSummary = departure.player ?? rosterSummaryPlayers(
            from: team.teamModel,
            lineupNames: Set(team.teamModel.lineup.map(\.bio.name))
        ).first(where: { $0.name == departure.playerName }) else { continue }

        entries.append(
            SchoolHallOfFameEntry(
                id: "\(departure.teamId):\(departure.playerName)",
                teamId: departure.teamId,
                teamName: departure.teamName,
                conferenceId: team.conferenceId,
                conferenceName: team.conferenceName,
                player: playerSummary,
                honors: honors,
                inductionReason: honors.first ?? "School Hall of Fame"
            )
        )
    }

    return entries.sorted { lhs, rhs in
        if lhs.teamId != rhs.teamId { return lhs.teamName < rhs.teamName }
        if lhs.honors.count != rhs.honors.count { return lhs.honors.count > rhs.honors.count }
        if lhs.player.overall != rhs.player.overall { return lhs.player.overall > rhs.player.overall }
        return lhs.player.name < rhs.player.name
    }
}

private func hallHonorsByTeamAndPlayer(_ state: LeagueStore.State) -> [String: [String: [String]]] {
    let stats = buildHallCandidateStats(state)
    let eligible = stats
        .filter { $0.games >= 8 && $0.minutesPerGame >= 12 }
        .sorted { lhs, rhs in
            if lhs.awardScore != rhs.awardScore { return lhs.awardScore > rhs.awardScore }
            return lhs.playerName < rhs.playerName
        }

    var honors: [String: [String: [String]]] = [:]
    func add(_ stat: HallCandidateStat, honor: String) {
        var current = honors[stat.teamId]?[stat.playerName] ?? []
        if !current.contains(honor) {
            current.append(honor)
        }
        honors[stat.teamId, default: [:]][stat.playerName] = current
    }

    if let national = eligible.first {
        add(national, honor: "National Player of the Year")
    }
    if let freshman = eligible.first(where: { $0.year == .fr }) {
        add(freshman, honor: "Freshman of the Year")
    }
    for position in ["PG", "SG", "SF", "PF", "C"] {
        if let best = eligible.first(where: { $0.normalizedPosition == position }) {
            add(best, honor: "Best \(position)")
        }
    }

    for (index, player) in eligible.prefix(15).enumerated() {
        let team = index < 5 ? "First Team" : (index < 10 ? "Second Team" : "Third Team")
        add(player, honor: "\(team) All-American")
    }

    let conferenceIds = Set(state.teams.map(\.conferenceId))
    let conferenceNameById = Dictionary(state.teams.map { ($0.conferenceId, $0.conferenceName) }, uniquingKeysWith: { first, _ in first })
    for conferenceId in conferenceIds {
        let firstTeam = eligible.filter { stat in
            state.teams.first(where: { $0.teamId == stat.teamId })?.conferenceId == conferenceId
        }.prefix(5)
        let conferenceName = conferenceNameById[conferenceId] ?? conferenceId
        for player in firstTeam {
            add(player, honor: "First Team All-\(conferenceName)")
        }
    }

    return honors
}

private func buildHallCandidateStats(_ state: LeagueStore.State) -> [HallCandidateStat] {
    struct Key: Hashable {
        let playerName: String
        let teamId: String
        let position: String
    }

    let rosterPlayerByTeamAndName = Dictionary(uniqueKeysWithValues: state.teams.map { team in
        let playersByName = Dictionary(grouping: team.teamModel.players, by: { $0.bio.name })
        return (team.teamId, playersByName)
    })

    var totals: [Key: HallCandidateStat] = [:]
    for game in state.schedule where game.completed {
        guard let boxScore = game.result?.boxScore else { continue }
        for (index, teamBox) in boxScore.enumerated() {
            let teamId = index == 0 ? game.homeTeamId : game.awayTeamId
            for player in teamBox.players {
                let key = Key(playerName: player.playerName, teamId: teamId, position: player.position)
                let rosterPlayer = rosterPlayerByTeamAndName[teamId]?[player.playerName]?.first
                var current = totals[key] ?? HallCandidateStat(
                    playerName: player.playerName,
                    teamId: teamId,
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
                current.ftAttempts += player.ftAttempts
                totals[key] = current
            }
        }
    }

    return Array(totals.values)
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
    playerSummary: UserRosterPlayerSummary?,
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
        player: playerSummary,
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

private func normalizeHallPosition(_ position: String) -> String {
    switch position.uppercased() {
    case "CG": return "PG"
    case "WING": return "SF"
    case "F": return "PF"
    case "BIG": return "C"
    default: return position.uppercased()
    }
}
