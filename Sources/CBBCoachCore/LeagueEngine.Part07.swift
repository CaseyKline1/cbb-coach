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
        guard state.status == "completed",
              let stage = state.offseasonStage,
              stage == .playersLeaving || stage == .draft || stage == .complete
        else {
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
        guard state.status == "completed",
              let stage = state.offseasonStage,
              stage == .draft || stage == .complete
        else {
            return SchoolHallOfFameSummary(userTeamId: state.userTeamId, entries: state.schoolHallOfFame ?? [])
        }
        if state.playersLeaving == nil {
            state.playersLeaving = calculatePlayersLeaving(state)
        }
        if state.draftPicks == nil {
            state.draftPicks = calculateDraftPicks(state)
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

public func getDraftSummary(_ league: LeagueState) -> DraftSummary {
    guard let summary = LeagueStore.update(league.handle, { state -> DraftSummary in
        guard state.status == "completed",
              let stage = state.offseasonStage,
              stage == .draft || stage == .complete
        else {
            return DraftSummary(userTeamId: state.userTeamId, picks: state.draftPicks ?? [])
        }
        if state.playersLeaving == nil {
            state.playersLeaving = calculatePlayersLeaving(state)
        }
        if state.draftPicks == nil {
            state.draftPicks = calculateDraftPicks(state)
        }
        if state.schoolHallOfFame != nil {
            state.schoolHallOfFame = calculateSchoolHallOfFame(state)
        }
        return DraftSummary(userTeamId: state.userTeamId, picks: state.draftPicks ?? [])
    }) else {
        return DraftSummary(userTeamId: "", picks: [])
    }
    return summary
}

public func getOffseasonProgress(_ league: LeagueState) -> LeagueOffseasonProgress? {
    LeagueStore.update(league.handle) { state -> LeagueOffseasonProgress? in
        guard state.status == "completed" else { return nil }
        if state.offseasonStage == nil {
            state.offseasonStage = .schedule
        }
        return LeagueOffseasonProgress(stage: state.offseasonStage ?? .schedule)
    } ?? nil
}

@discardableResult
public func advanceOffseason(_ league: inout LeagueState) -> LeagueOffseasonProgress? {
    LeagueStore.update(league.handle) { state -> LeagueOffseasonProgress? in
        guard state.status == "completed" else { return nil }

        let currentStage = state.offseasonStage ?? .schedule
        switch currentStage {
        case .schedule:
            state.offseasonStage = .seasonRecap
        case .seasonRecap:
            state.offseasonStage = .nilBudgets
        case .nilBudgets:
            if state.playersLeaving == nil {
                state.playersLeaving = calculatePlayersLeaving(state)
            }
            state.offseasonStage = .playersLeaving
        case .playersLeaving:
            if state.playersLeaving == nil {
                state.playersLeaving = calculatePlayersLeaving(state)
            }
            if state.draftPicks == nil {
                state.draftPicks = calculateDraftPicks(state)
            }
            if state.schoolHallOfFame == nil {
                state.schoolHallOfFame = calculateSchoolHallOfFame(state)
            }
            state.offseasonStage = .draft
        case .draft:
            state.offseasonStage = .complete
        case .complete:
            break
        }

        return LeagueOffseasonProgress(stage: state.offseasonStage ?? .schedule)
    } ?? nil
}

func calculatePlayersLeaving(_ state: LeagueStore.State) -> [PlayerLeavingEntry] {
    let minutesByTeamAndPlayer = buildLeavingPlayerStats(state)
    let draftProspectRankById = buildDraftProspectRankById(state)
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
            let playerSummary = playerIndex < rosterSummaries.count ? rosterSummaries[playerIndex] : nil

            if player.bio.year == .sr && !isLikelyRedshirtingSenior(player, stats: stats, teamGames: max(1, team.wins + team.losses)) {
                entries.append(
                    leavingEntry(
                        team: team,
                        player: player,
                        playerIndex: playerIndex,
                        playerSummary: playerSummary,
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

            if let prospectRank = draftProspectRankById["\(team.teamId):\(player.bio.name)"] {
                let chance = draftDeclarationChance(
                    rank: prospectRank,
                    loyalty: loyalty,
                    greed: greed
                )
                let roll = deterministicLeavingRoll(
                    state: state,
                    teamId: team.teamId,
                    playerName: player.bio.name,
                    salt: "draft-decision"
                )
                if roll < chance {
                    entries.append(
                        leavingEntry(
                            team: team,
                            player: player,
                            playerIndex: playerIndex,
                            playerSummary: playerSummary,
                            overall: overall,
                            outcome: .draft,
                            reason: "Projected as the #\(prospectRank) draft prospect.",
                            minutesShare: minutesShare,
                            expectedShare: expectedShare,
                            transferRisk: chance,
                            loyalty: loyalty,
                            greed: greed,
                            nilDollars: nilDollars
                        )
                    )
                    continue
                }
            }

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
                    playerSummary: playerSummary,
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
            if lhs.outcome != rhs.outcome { return leavingOutcomeSortValue(lhs.outcome) < leavingOutcomeSortValue(rhs.outcome) }
            if lhs.transferRisk != rhs.transferRisk { return lhs.transferRisk > rhs.transferRisk }
            return lhs.playerName < rhs.playerName
        }
        return lhs.teamName < rhs.teamName
    }
}

func calculateSchoolHallOfFame(_ state: LeagueStore.State) -> [SchoolHallOfFameEntry] {
    let honorsByTeamAndPlayer = hallHonorsByTeamAndPlayer(state)
    let leaving = state.playersLeaving ?? calculatePlayersLeaving(state)
    let draftSlotByPlayerId = Dictionary(uniqueKeysWithValues: (state.draftPicks ?? calculateDraftPicks(state)).map { ($0.id, $0.slot) })
    var entries: [SchoolHallOfFameEntry] = []

    for departure in leaving where departure.outcome == .graduated || departure.outcome == .draft {
        guard let honors = honorsByTeamAndPlayer[departure.teamId]?[departure.playerName], !honors.isEmpty else { continue }
        guard let team = state.teams.first(where: { $0.teamId == departure.teamId }) else { continue }
        guard var playerSummary = departure.player ?? rosterSummaryPlayers(
            from: team.teamModel,
            lineupNames: Set(team.teamModel.lineup.map(\.bio.name))
        ).first(where: { $0.name == departure.playerName }) else { continue }
        playerSummary.draftSlot = draftSlotByPlayerId["\(departure.teamId):\(departure.playerName)"]

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

func calculateDraftPicks(_ state: LeagueStore.State) -> [DraftPickEntry] {
    let leaving = state.playersLeaving ?? calculatePlayersLeaving(state)
    let statsByTeamAndPlayer = Dictionary(grouping: buildHallCandidateStats(state), by: \.teamId)
        .mapValues { rows in
            Dictionary(rows.map { ($0.playerName, $0) }, uniquingKeysWith: { first, second in
                first.awardScore >= second.awardScore ? first : second
            })
        }
    let teamById = Dictionary(uniqueKeysWithValues: state.teams.map { ($0.teamId, $0) })

    let candidates = leaving.compactMap { departure -> (departure: PlayerLeavingEntry, score: Double, boardScore: Double)? in
        guard departure.outcome == .graduated || departure.outcome == .draft else { return nil }
        guard let player = departure.player else { return nil }
        let stats = statsByTeamAndPlayer[departure.teamId]?[departure.playerName]
        let score = draftScore(
            player: player,
            stats: stats,
            seed: "\(state.optionsSeed):draft:\(departure.teamId):\(departure.playerName)"
        )
        let variance = deterministicDraftRoll(state: state, teamId: departure.teamId, playerName: departure.playerName, salt: "board") * 9.0
        let teamPrestige = teamById[departure.teamId]?.prestige ?? 0.5
        let boardScore = score + variance + teamPrestige * 2.0
        return (departure, score, boardScore)
    }
    .sorted { lhs, rhs in
        if lhs.boardScore != rhs.boardScore { return lhs.boardScore > rhs.boardScore }
        return lhs.departure.playerName < rhs.departure.playerName
    }

    return candidates.prefix(60).enumerated().map { index, row in
        var player = row.departure.player ?? UserRosterPlayerSummary(
            playerIndex: -1,
            name: row.departure.playerName,
            position: row.departure.position,
            year: row.departure.year,
            home: nil,
            height: nil,
            weight: nil,
            wingspan: nil,
            overall: row.departure.overall,
            isStarter: false,
            attributes: ["potential": row.departure.potential]
        )
        player.draftSlot = index + 1
        return DraftPickEntry(
            id: "\(row.departure.teamId):\(row.departure.playerName)",
            slot: index + 1,
            teamId: row.departure.teamId,
            teamName: row.departure.teamName,
            player: player,
            draftScore: row.score
        )
    }
}

private func buildDraftProspectRankById(_ state: LeagueStore.State) -> [String: Int] {
    let statsByTeamAndPlayer = Dictionary(grouping: buildHallCandidateStats(state), by: \.teamId)
        .mapValues { rows in
            Dictionary(rows.map { ($0.playerName, $0) }, uniquingKeysWith: { first, second in
                first.awardScore >= second.awardScore ? first : second
            })
        }

    var prospects: [(id: String, score: Double)] = []
    for team in state.teams {
        let lineupNames = Set(team.teamModel.lineup.map(\.bio.name))
        let summaries = rosterSummaryPlayers(from: team.teamModel, lineupNames: lineupNames)
        for (index, player) in team.teamModel.players.enumerated() {
            guard player.bio.year != .sr, player.bio.year != .hs, player.bio.year != .graduated else { continue }
            guard index < summaries.count else { continue }
            let stats = statsByTeamAndPlayer[team.teamId]?[player.bio.name]
            let score = draftScore(
                player: summaries[index],
                stats: stats,
                seed: "\(state.optionsSeed):prospect:\(team.teamId):\(player.bio.name)"
            )
            prospects.append((id: "\(team.teamId):\(player.bio.name)", score: score))
        }
    }

    let ordered = prospects.sorted { lhs, rhs in
        if lhs.score != rhs.score { return lhs.score > rhs.score }
        return lhs.id < rhs.id
    }
    return Dictionary(uniqueKeysWithValues: ordered.enumerated().map { ($0.element.id, $0.offset + 1) })
}

private func draftDeclarationChance(rank: Int, loyalty: Double, greed: Double) -> Double {
    let base: Double
    switch rank {
    case 1...7:
        base = 0.99
    case 8...14:
        base = 0.95
    case 15...30:
        base = 0.70
    case 31...60:
        base = 0.30
    case 61...100:
        base = 0.08
    default:
        return 0
    }

    let greedAdjustment = (clamp(greed, min: 0, max: 100) - 50) / 50
    let loyaltyAdjustment = (50 - clamp(loyalty, min: 0, max: 100)) / 50
    let adjusted = base + greedAdjustment * 0.025 + loyaltyAdjustment * 0.025

    switch rank {
    case 1...7:
        return clamp(adjusted, min: 0.94, max: 0.995)
    case 8...14:
        return clamp(adjusted, min: 0.86, max: 0.985)
    case 15...30:
        return clamp(adjusted, min: 0.52, max: 0.86)
    case 31...60:
        return clamp(adjusted, min: 0.18, max: 0.48)
    case 61...100:
        return clamp(adjusted, min: 0.03, max: 0.18)
    default:
        return 0
    }
}

private func leavingOutcomeSortValue(_ outcome: PlayerLeavingOutcome) -> Int {
    switch outcome {
    case .graduated: return 0
    case .draft: return 1
    case .transfer: return 2
    }
}

private func draftScore(player: UserRosterPlayerSummary, stats: HallCandidateStat?, seed: String) -> Double {
    let potential = Double(player.attributes?["potential"] ?? player.overall)
    let overallScore = Double(player.overall)
    let productionScore = draftProductionScore(stats)
    let youthScore = draftYouthScore(player.year)
    let measurementScore = draftMeasurementScore(position: player.position, height: player.height, wingspan: player.wingspan)
    var random = SeededRandom(seed: hashString(seed))
    let privateWorkout = (random.nextUnit() - 0.5) * 4.0

    return clamp(
        overallScore * 0.48
            + potential * 0.22
            + productionScore * 0.18
            + youthScore * 0.06
            + measurementScore * 0.06
            + privateWorkout,
        min: 0,
        max: 110
    )
}

private func draftProductionScore(_ stats: HallCandidateStat?) -> Double {
    guard let stats, stats.games > 0 else { return 0 }

    let assistTurnoverScore = min(stats.assistTurnoverRatio, 3.0)
    let score = stats.pointsPerGame
        + stats.reboundsPerGame * 1.15
        + stats.assistsPerGame * 1.05
        + stats.stealsPerGame * 2.1
        + stats.blocksPerGame * 2.1
        + stats.effectiveFieldGoalPercentage * 0.08
        + assistTurnoverScore * 0.65
        + stats.minutesPerGame * 0.06
        - stats.turnoversPerGame * 0.9
        + min(Double(stats.games), 38) * 0.06

    return clamp(score / 54.0, min: 0, max: 1) * 100
}

private func draftYouthScore(_ year: String) -> Double {
    switch year.uppercased() {
    case "FR": return 100
    case "SO": return 82
    case "JR": return 60
    case "SR": return 34
    default: return 48
    }
}

private func draftMeasurementScore(position: String, height: String?, wingspan: String?) -> Double {
    let heightInches = parseMeasurementInches(height)
    let wingspanInches = parseMeasurementInches(wingspan)
    let target = draftMeasurementTarget(position)
    let heightScore = heightInches.map { clamp((Double($0) - Double(target.height - 4)) / 8.0, min: 0, max: 1) } ?? 0.45
    let wingspanScore = wingspanInches.map { clamp((Double($0) - Double(target.wingspan - 4)) / 9.0, min: 0, max: 1) } ?? 0.45
    return (heightScore * 0.45 + wingspanScore * 0.55) * 100
}

private func draftMeasurementTarget(_ position: String) -> (height: Int, wingspan: Int) {
    switch normalizeHallPosition(position) {
    case "PG": return (74, 77)
    case "SG": return (77, 80)
    case "SF": return (80, 83)
    case "PF": return (82, 86)
    case "C": return (84, 88)
    default: return (79, 82)
    }
}

private func parseMeasurementInches(_ value: String?) -> Int? {
    guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else { return nil }
    let normalized = trimmed
        .replacingOccurrences(of: "'", with: "-")
        .replacingOccurrences(of: "\"", with: "")
    let parts = normalized.split(separator: "-", maxSplits: 1)
    if parts.count == 2, let feet = Int(parts[0]), let inches = Int(parts[1]) {
        return feet * 12 + inches
    }
    return Int(trimmed)
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
        let conferencePlayers = eligible.filter { stat in
            state.teams.first(where: { $0.teamId == stat.teamId })?.conferenceId == conferenceId
        }
        let conferenceName = conferenceNameById[conferenceId] ?? conferenceId
        for player in conferencePlayers.prefix(5) {
            add(player, honor: "First Team All-\(conferenceName)")
        }
        for player in conferencePlayers.dropFirst(5).prefix(5) {
            add(player, honor: "Second Team All-\(conferenceName)")
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

private func deterministicDraftRoll(state: LeagueStore.State, teamId: String, playerName: String, salt: String) -> Double {
    var random = SeededRandom(seed: hashString("\(state.optionsSeed):draft:\(state.currentDay):\(teamId):\(playerName):\(salt)"))
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
