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

public func getNILRetentionSummary(_ league: LeagueState) -> NILRetentionSummary {
    guard let summary = LeagueStore.update(league.handle, { state -> NILRetentionSummary in
        guard state.status == "completed",
              let stage = state.offseasonStage,
              stage == .playerRetention || stage == .transferPortal || stage == .complete
        else {
            return NILRetentionSummary(
                userTeamId: state.userTeamId,
                budget: nilRetentionBudgetSummary(state, negotiations: state.nilRetention ?? []),
                entries: state.nilRetention ?? []
            )
        }
        prepareNILRetentionIfNeeded(&state)
        return NILRetentionSummary(
            userTeamId: state.userTeamId,
            budget: nilRetentionBudgetSummary(state, negotiations: state.nilRetention ?? []),
            entries: state.nilRetention ?? []
        )
    }) else {
        return NILRetentionSummary(
            userTeamId: "",
            budget: NILRetentionBudgetSummary(total: 0, allocated: 0, remaining: 0),
            entries: []
        )
    }
    return summary
}

public func setNILRetentionOffer(_ league: inout LeagueState, negotiationId: String, offer: Double) -> NILNegotiationEntry? {
    LeagueStore.update(league.handle) { state -> NILNegotiationEntry? in
        prepareNILRetentionIfNeeded(&state)
        guard var rows = state.nilRetention,
              let index = rows.firstIndex(where: { $0.id == negotiationId && $0.teamId == state.userTeamId }),
              rows[index].status == .open
        else { return nil }
        rows[index].offer = clamp(offer, min: 0, max: 10_000_000)
        state.nilRetention = rows
        return rows[index]
    } ?? nil
}

public func submitNILRetentionOffer(_ league: inout LeagueState, negotiationId: String) -> NILNegotiationEntry? {
    LeagueStore.update(league.handle) { state -> NILNegotiationEntry? in
        prepareNILRetentionIfNeeded(&state)
        guard var rows = state.nilRetention,
              let index = rows.firstIndex(where: { $0.id == negotiationId && $0.teamId == state.userTeamId }),
              rows[index].status == .open
        else { return nil }

        var row = rows[index]
        row.rounds += 1
        let budget = nilRetentionBudgetSummary(state, negotiations: rows)
        if row.offer > budget.remaining {
            row.responseText = "Not enough remaining NIL budget."
            rows[index] = row
            state.nilRetention = rows
            return row
        }

        let greedFactor = clamp(row.greed / 100, min: 0, max: 1)
        let loyaltyFactor = clamp(row.loyalty / 100, min: 0, max: 1)
        let acceptanceThreshold = nilAcceptanceThreshold(row)
        let effectiveOffer = row.offer
        if effectiveOffer >= acceptanceThreshold {
            row.status = .accepted
            row.demand = row.offer
            row.responseText = "Accepted."
            rows[index] = row
            state.nilRetention = rows
            applyNILRetentionContract(&state, row: row)
            return row
        }

        let belowChance = belowDemandAcceptanceChance(
            offer: effectiveOffer,
            threshold: acceptanceThreshold,
            greedFactor: greedFactor,
            loyaltyFactor: loyaltyFactor
        )
        let belowRoll = deterministicNILNegotiationRoll(state: state, playerId: row.id, round: row.rounds, salt: "below")
        if belowRoll < belowChance {
            row.status = .accepted
            row.demand = row.offer
            row.responseText = "Accepted below demand."
            rows[index] = row
            state.nilRetention = rows
            applyNILRetentionContract(&state, row: row)
            return row
        }

        let ratio = row.demand > 0 ? clamp(effectiveOffer / row.demand, min: 0, max: 1.5) : 1
        let portalChance = clamp(
            0.08 + (1 - ratio) * 0.55 + greedFactor * 0.20 - loyaltyFactor * 0.15,
            min: 0.04,
            max: 0.84
        )
        let portalRoll = deterministicNILNegotiationRoll(state: state, playerId: row.id, round: row.rounds, salt: "portal")
        if portalRoll < portalChance {
            row.status = .portal
            row.responseText = "Declined and entered the portal."
            rows[index] = row
            state.nilRetention = rows
            return row
        }

        let counterRoll = deterministicNILNegotiationRoll(state: state, playerId: row.id, round: row.rounds, salt: "counter")
        let direction = counterRoll < (0.42 + loyaltyFactor * 0.18) ? -1.0 : 1.0
        let delta = row.intrinsicValue * (0.025 + greedFactor * 0.055)
        row.demand = clamp(row.demand + direction * delta, min: 0, max: row.intrinsicValue * 1.65)
        row.responseText = direction < 0 ? "Countered lower." : "Countered higher."
        rows[index] = row
        state.nilRetention = rows
        return row
    } ?? nil
}

public func meetNILRetentionDemand(_ league: inout LeagueState, negotiationId: String) -> NILNegotiationEntry? {
    LeagueStore.update(league.handle) { state -> NILNegotiationEntry? in
        prepareNILRetentionIfNeeded(&state)
        guard var rows = state.nilRetention,
              let index = rows.firstIndex(where: { $0.id == negotiationId && $0.teamId == state.userTeamId }),
              rows[index].status == .open
        else { return nil }
        var row = rows[index]
        let budget = nilRetentionBudgetSummary(state, negotiations: rows)
        guard row.demand <= budget.remaining else {
            row.responseText = "Not enough remaining NIL budget."
            rows[index] = row
            state.nilRetention = rows
            return row
        }
        row.offer = row.demand
        row.status = .accepted
        row.responseText = "Accepted."
        rows[index] = row
        state.nilRetention = rows
        applyNILRetentionContract(&state, row: row)
        return row
    } ?? nil
}

public func delegateNILRetentionToAssistants(_ league: inout LeagueState) -> NILRetentionSummary {
    LeagueStore.update(league.handle) { state -> NILRetentionSummary in
        prepareNILRetentionIfNeeded(&state)
        guard var rows = state.nilRetention else {
            return NILRetentionSummary(
                userTeamId: state.userTeamId,
                budget: nilRetentionBudgetSummary(state, negotiations: []),
                entries: []
            )
        }
        let openIndexes = rows.indices
            .filter { rows[$0].teamId == state.userTeamId && rows[$0].status == .open }
            .sorted {
                if rows[$0].priority != rows[$1].priority { return rows[$0].priority > rows[$1].priority }
                return rows[$0].playerName < rows[$1].playerName
            }
        for index in openIndexes {
            var row = rows[index]
            let budget = nilRetentionBudgetSummary(state, negotiations: rows)
            let target = max(nilAcceptanceThreshold(row) * nilRetentionPremium(row), row.intrinsicValue * 0.90)
            let offer = min(row.demand, target)
            guard offer <= budget.remaining else { continue }
            row.offer = offer
            row.status = .accepted
            row.demand = offer
            row.responseText = "Accepted."
            rows[index] = row
            state.nilRetention = rows
            applyNILRetentionContract(&state, row: row)
        }
        state.nilRetention = rows
        return NILRetentionSummary(
            userTeamId: state.userTeamId,
            budget: nilRetentionBudgetSummary(state, negotiations: rows),
            entries: rows
        )
    } ?? NILRetentionSummary(
        userTeamId: "",
        budget: NILRetentionBudgetSummary(total: 0, allocated: 0, remaining: 0),
        entries: []
    )
}

public func getTransferPortalSummary(_ league: LeagueState) -> TransferPortalSummary {
    guard let summary = LeagueStore.update(league.handle, { state -> TransferPortalSummary in
        guard state.status == "completed",
              let stage = state.offseasonStage,
              stage == .transferPortal || stage == .complete
        else {
            return TransferPortalSummary(userTeamId: state.userTeamId, entries: state.transferPortal ?? [])
        }
        finalizeNILRetentionAndBuildPortalIfNeeded(&state)
        return TransferPortalSummary(userTeamId: state.userTeamId, entries: state.transferPortal ?? [])
    }) else {
        return TransferPortalSummary(userTeamId: "", entries: [])
    }
    return summary
}

public func getOffseasonProgress(_ league: LeagueState) -> LeagueOffseasonProgress? {
    LeagueStore.update(league.handle) { state -> LeagueOffseasonProgress? in
        guard state.status == "completed" else { return nil }
        if state.offseasonStage == nil {
            state.offseasonStage = .seasonRecap
        }
        return LeagueOffseasonProgress(stage: state.offseasonStage ?? .schedule)
    } ?? nil
}

private func prepareNILRetentionIfNeeded(_ state: inout LeagueStore.State) {
    if state.playersLeaving == nil {
        state.playersLeaving = calculatePlayersLeaving(state)
    }
    if state.draftPicks == nil {
        state.draftPicks = calculateDraftPicks(state)
    }
    guard state.nilRetention == nil else { return }

    let departedIds = Set((state.playersLeaving ?? [])
        .filter { $0.outcome == .graduated || $0.outcome == .draft || $0.outcome == .transfer }
        .map { playerKey(teamId: $0.teamId, playerName: $0.playerName) })
    let budgetByTeam = Dictionary(uniqueKeysWithValues: calculateNILBudgetSummary(state).teams.map { ($0.teamId, $0.total) })
    let statsByTeamAndPlayer = Dictionary(grouping: buildHallCandidateStats(state), by: \.teamId)
        .mapValues { rows in
            Dictionary(rows.map { ($0.playerName, $0) }, uniquingKeysWith: { first, second in
                first.awardScore >= second.awardScore ? first : second
            })
        }

    var rows: [NILNegotiationEntry] = []
    for team in state.teams {
        let lineupNames = Set(team.teamModel.lineup.map(\.bio.name))
        let rosterSummaries = rosterSummaryPlayers(from: team.teamModel, lineupNames: lineupNames)
        for (playerIndex, player) in team.teamModel.players.enumerated() {
            guard player.bio.year != .sr, player.bio.year != .hs, player.bio.year != .graduated else { continue }
            guard !departedIds.contains(playerKey(teamId: team.teamId, playerName: player.bio.name)) else { continue }
            let overall = playerOverall(player)
            let loyalty = resolvedLoyalty(player, teamId: team.teamId)
            let greed = resolvedGreed(player, teamId: team.teamId)
            let lastYearAmount = player.bio.nilDollarsLastYear ?? 0
            let playerSummary = playerIndex < rosterSummaries.count ? rosterSummaries[playerIndex] : nil
            let intrinsic = nilIntrinsicValue(
                player: player,
                overall: overall,
                stats: statsByTeamAndPlayer[team.teamId]?[player.bio.name],
                team: team,
                teamBudget: budgetByTeam[team.teamId] ?? 0
            )
            let discount = returningDiscount(loyalty: loyalty, greed: greed, lastYearAmount: lastYearAmount, intrinsicValue: intrinsic)
            let demand = initialNILDemand(
                intrinsicValue: intrinsic,
                lastYearAmount: lastYearAmount,
                loyalty: loyalty,
                greed: greed,
                returningDiscount: discount,
                seed: "\(state.optionsSeed):nil-demand:\(team.teamId):\(player.bio.name)"
            )
            rows.append(
                NILNegotiationEntry(
                    id: "\(team.teamId):\(playerIndex):\(player.bio.name):retention",
                    teamId: team.teamId,
                    teamName: team.teamName,
                    player: playerSummary,
                    playerIndex: playerIndex,
                    playerName: player.bio.name,
                    position: player.bio.position.rawValue,
                    year: player.bio.year.rawValue,
                    overall: overall,
                    potential: player.bio.potential,
                    intrinsicValue: intrinsic,
                    demand: demand,
                    offer: max(lastYearAmount, demand * 0.72),
                    lastYearAmount: lastYearAmount,
                    rounds: 0,
                    status: .open,
                    responseText: "",
                    loyalty: loyalty,
                    greed: greed,
                    returningDiscount: discount,
                    priority: nilRetentionPriority(overall: overall, potential: player.bio.potential, value: intrinsic, position: player.bio.position)
                )
            )
        }
    }

    rows = resolveCPUNILRetention(state, rows: rows, budgetByTeam: budgetByTeam)
    state.nilRetention = rows.sorted { lhs, rhs in
        if lhs.teamId == rhs.teamId {
            if lhs.priority != rhs.priority { return lhs.priority > rhs.priority }
            return lhs.playerName < rhs.playerName
        }
        return lhs.teamName < rhs.teamName
    }
}

private func resolveCPUNILRetention(
    _ state: LeagueStore.State,
    rows: [NILNegotiationEntry],
    budgetByTeam: [String: Double]
) -> [NILNegotiationEntry] {
    var rows = rows
    let rowIndexesByTeam = Dictionary(grouping: rows.indices, by: { rows[$0].teamId })
    for team in state.teams where team.teamId != state.userTeamId {
        var remaining = max(0, (budgetByTeam[team.teamId] ?? 0) * 0.38)
        let indexes = (rowIndexesByTeam[team.teamId] ?? []).sorted {
            if rows[$0].priority != rows[$1].priority { return rows[$0].priority > rows[$1].priority }
            return rows[$0].playerName < rows[$1].playerName
        }
        for index in indexes {
            var row = rows[index]
            let target = max(nilAcceptanceThreshold(row) * nilRetentionPremium(row), row.intrinsicValue * 0.84)
            let roll = deterministicNILValueRoll(seed: "\(state.optionsSeed):cpu-nil:\(row.id)")
            let offer = min(row.demand, target * (0.95 + roll * 0.10))
            guard offer <= remaining else { continue }
            row.offer = offer
            row.status = .accepted
            row.demand = offer
            row.responseText = "Accepted."
            rows[index] = row
            remaining -= offer
        }
    }
    return rows
}

private func finalizeNILRetentionAndBuildPortalIfNeeded(_ state: inout LeagueStore.State) {
    prepareNILRetentionIfNeeded(&state)
    guard state.nilRetentionFinalized != true else { return }

    var portal = state.transferPortal ?? []
    var portalIds = Set(portal.map(\.id))
    let departures = state.playersLeaving ?? calculatePlayersLeaving(state)
    let retentionRows = state.nilRetention ?? []
    let retainedIds = Set(retentionRows.filter { $0.status == .accepted }.map { playerKey(teamId: $0.teamId, playerName: $0.playerName) })
    let retentionPortalIds = Set(retentionRows.filter { $0.status == .portal || $0.status == .open }.map { playerKey(teamId: $0.teamId, playerName: $0.playerName) })
    let mandatoryDepartureIds = Set(departures
        .filter { $0.outcome == .graduated || $0.outcome == .draft || $0.outcome == .transfer }
        .map { playerKey(teamId: $0.teamId, playerName: $0.playerName) })
    let rosterPlayerById = Dictionary(uniqueKeysWithValues: state.teams.flatMap { team in
        team.teamModel.players.map { player in
            (playerKey(teamId: team.teamId, playerName: player.bio.name), player)
        }
    })

    func appendPortalEntry(_ entry: TransferPortalEntry) {
        if portalIds.insert(entry.id).inserted {
            portal.append(entry)
        }
    }

    for departure in departures where departure.outcome == .transfer {
        let ask = portalAskingPrice(
            intrinsicValue: max(1, transferIntrinsicFallback(departure)),
            greed: departure.greed,
            loyalty: departure.loyalty
        )
        appendPortalEntry(
            TransferPortalEntry(
                id: "\(departure.teamId):\(departure.playerName):portal",
                previousTeamId: departure.teamId,
                previousTeamName: departure.teamName,
                player: departure.player,
                playerModel: rosterPlayerById[playerKey(teamId: departure.teamId, playerName: departure.playerName)],
                playerName: departure.playerName,
                position: departure.position,
                year: departure.year,
                overall: departure.overall,
                potential: departure.potential,
                askingPrice: ask,
                intrinsicValue: max(1, transferIntrinsicFallback(departure)),
                reason: departure.reason,
                loyalty: departure.loyalty,
                greed: departure.greed
            )
        )
    }

    for row in retentionRows where row.status == .portal || row.status == .open {
        appendPortalEntry(
            TransferPortalEntry(
                id: "\(row.teamId):\(row.playerName):portal",
                previousTeamId: row.teamId,
                previousTeamName: row.teamName,
                player: row.player,
                playerModel: rosterPlayerById[playerKey(teamId: row.teamId, playerName: row.playerName)],
                playerName: row.playerName,
                position: row.position,
                year: row.year,
                overall: row.overall,
                potential: row.potential,
                askingPrice: portalAskingPrice(intrinsicValue: row.intrinsicValue, greed: row.greed, loyalty: row.loyalty),
                intrinsicValue: row.intrinsicValue,
                reason: row.status == .open ? "Did not agree to NIL terms." : "Declined retention offer.",
                loyalty: row.loyalty,
                greed: row.greed
            )
        )
    }

    for teamIndex in state.teams.indices {
        let teamId = state.teams[teamIndex].teamId
        for playerIndex in state.teams[teamIndex].teamModel.players.indices {
            let name = state.teams[teamIndex].teamModel.players[playerIndex].bio.name
            let key = playerKey(teamId: teamId, playerName: name)
            if let row = retentionRows.first(where: { playerKey(teamId: $0.teamId, playerName: $0.playerName) == key && $0.status == .accepted }) {
                state.teams[teamIndex].teamModel.players[playerIndex].bio.nilDollarsLastYear = row.offer
            } else if !retainedIds.contains(key) {
                state.teams[teamIndex].teamModel.players[playerIndex].bio.nilDollarsLastYear = 0
            }
        }
        state.teams[teamIndex].teamModel.players.removeAll { player in
            let key = playerKey(teamId: teamId, playerName: player.bio.name)
            return mandatoryDepartureIds.contains(key) || retentionPortalIds.contains(key)
        }
        let remainingNames = Set(state.teams[teamIndex].teamModel.players.map(\.bio.name))
        state.teams[teamIndex].teamModel.lineup.removeAll { !remainingNames.contains($0.bio.name) }
    }

    state.transferPortal = portal.sorted {
        if $0.overall != $1.overall { return $0.overall > $1.overall }
        if $0.askingPrice != $1.askingPrice { return $0.askingPrice > $1.askingPrice }
        return $0.playerName < $1.playerName
    }
    state.nilRetentionFinalized = true
}

private func nilRetentionBudgetSummary(_ state: LeagueStore.State, negotiations: [NILNegotiationEntry]) -> NILRetentionBudgetSummary {
    let total = calculateNILBudgetSummary(state).userTeam?.total ?? 0
    let allocated = negotiations
        .filter { $0.teamId == state.userTeamId && $0.status == .accepted }
        .reduce(0.0) { $0 + $1.offer }
    return NILRetentionBudgetSummary(total: total, allocated: allocated, remaining: max(0, total - allocated))
}

private func nilIntrinsicValue(
    player: Player,
    overall: Int,
    stats: HallCandidateStat?,
    team: LeagueStore.TeamState,
    teamBudget: Double
) -> Double {
    let quality = clamp((Double(overall) - 54) / 42, min: 0, max: 1)
    let upside = clamp((Double(player.bio.potential) - Double(overall) + 8) / 24, min: 0, max: 1)
    let production = clamp((stats?.awardScore ?? 0) / 42, min: 0, max: 1)
    let prestige = clamp(team.prestige, min: 0, max: 1)
    let budgetSignal = clamp(teamBudget / 8_500_000, min: 0.18, max: 1.25)
    let positionMultiplier: Double
    switch player.bio.position {
    case .pg, .cg:
        positionMultiplier = 1.08
    case .sg, .sf, .wing:
        positionMultiplier = 1.04
    case .pf, .f:
        positionMultiplier = 0.98
    case .c, .big:
        positionMultiplier = 1.03
    }
    let eliteTier = clamp((Double(overall) - 86) / 12, min: 0, max: 1)
    let nationalStarTier = clamp((Double(overall) - 92) / 7, min: 0, max: 1)
    let elitePremium = 1.0 + pow(eliteTier, 1.7) * 0.48 + pow(nationalStarTier, 2.0) * 0.72
    let base = 18_000
        + pow(quality, 1.45) * 520_000
        + pow(max(quality, production), 2.15) * 1_050_000
        + production * 480_000
        + upside * quality * 210_000
    let market = base * (0.70 + prestige * 0.42) * (0.72 + budgetSignal * 0.34) * positionMultiplier * elitePremium
    return max(3_000, roundToNearestThousand(market))
}

private func initialNILDemand(
    intrinsicValue: Double,
    lastYearAmount: Double,
    loyalty: Double,
    greed: Double,
    returningDiscount: Double,
    seed: String
) -> Double {
    let greedFactor = clamp(greed / 100, min: 0, max: 1)
    let loyaltyFactor = clamp(loyalty / 100, min: 0, max: 1)
    let variance = 0.91 + deterministicNILValueRoll(seed: seed) * 0.20
    let marketDemand = intrinsicValue * (1.02 + greedFactor * 0.28 - loyaltyFactor * 0.08) * (1.0 - returningDiscount) * variance
    guard lastYearAmount > 0 else { return roundToNearestThousand(max(0, marketDemand)) }
    let anchor = lastYearAmount * (0.76 + greedFactor * 0.30 - loyaltyFactor * 0.13)
    return roundToNearestThousand(max(marketDemand, anchor))
}

private func returningDiscount(loyalty: Double, greed: Double, lastYearAmount: Double, intrinsicValue: Double) -> Double {
    let loyaltyFactor = clamp(loyalty / 100, min: 0, max: 1)
    let greedFactor = clamp(greed / 100, min: 0, max: 1)
    let paidComfort = lastYearAmount > 0 ? clamp(lastYearAmount / max(1, intrinsicValue), min: 0, max: 1) * 0.04 : 0
    return clamp(0.02 + loyaltyFactor * 0.16 + paidComfort - greedFactor * 0.11, min: 0, max: 0.24)
}

private func nilAcceptanceThreshold(_ row: NILNegotiationEntry) -> Double {
    let greedFactor = clamp(row.greed / 100, min: 0, max: 1)
    let loyaltyFactor = clamp(row.loyalty / 100, min: 0, max: 1)
    return row.demand * (0.95 + greedFactor * 0.10 - loyaltyFactor * 0.08)
}

private func belowDemandAcceptanceChance(offer: Double, threshold: Double, greedFactor: Double, loyaltyFactor: Double) -> Double {
    guard offer < threshold else { return 1 }
    let shortfall = clamp((threshold - offer) / max(1, threshold), min: 0, max: 1)
    let nearMiss = clamp(1.0 - shortfall / 0.30, min: 0, max: 1)
    return clamp(0.01 + loyaltyFactor * 0.06 - greedFactor * 0.03 + pow(nearMiss, 1.55) * (0.32 + loyaltyFactor * 0.14 - greedFactor * 0.10), min: 0, max: 0.55)
}

private func nilRetentionPremium(_ row: NILNegotiationEntry) -> Double {
    let elite = row.overall >= 86 ? 0.08 : (row.overall >= 80 ? 0.04 : 0)
    let position: Double
    switch row.position.uppercased() {
    case "PG", "CG", "C", "BIG":
        position = 0.04
    default:
        position = 0
    }
    return 1.0 + elite + position
}

private func nilRetentionPriority(overall: Int, potential: Int, value: Double, position: PlayerPosition) -> Double {
    let positionPremium: Double
    switch position {
    case .pg, .cg: positionPremium = 7
    case .c, .big: positionPremium = 5
    default: positionPremium = 0
    }
    return Double(overall) * 1.45 + Double(potential) * 0.20 + min(value / 25_000, 70) + positionPremium
}

private func portalAskingPrice(intrinsicValue: Double, greed: Double, loyalty: Double) -> Double {
    let greedFactor = clamp(greed / 100, min: 0, max: 1)
    let loyaltyFactor = clamp(loyalty / 100, min: 0, max: 1)
    let eliteTail = clamp((intrinsicValue - 1_800_000) / 2_500_000, min: 0, max: 1)
    let multiplier = 1.03 + greedFactor * 0.30 - loyaltyFactor * 0.06 + pow(eliteTail, 1.6) * 0.14
    return roundToNearestThousand(intrinsicValue * multiplier)
}

private func transferIntrinsicFallback(_ departure: PlayerLeavingEntry) -> Double {
    let quality = clamp((Double(departure.overall) - 54) / 42, min: 0, max: 1)
    let upside = clamp((Double(departure.potential) - Double(departure.overall) + 8) / 24, min: 0, max: 1)
    let lastYear = departure.nilDollarsLastYear
    let eliteTier = clamp((Double(departure.overall) - 86) / 12, min: 0, max: 1)
    let nationalStarTier = clamp((Double(departure.overall) - 92) / 7, min: 0, max: 1)
    let base = 15_000
        + pow(quality, 1.55) * 520_000
        + pow(quality, 2.2) * 1_150_000
        + upside * quality * 260_000
    let premium = 1.0 + pow(eliteTier, 1.7) * 0.58 + pow(nationalStarTier, 2.0) * 0.82
    return roundToNearestThousand(max(base * premium, lastYear * 0.85))
}

private func applyNILRetentionContract(_ state: inout LeagueStore.State, row: NILNegotiationEntry) {
    guard let teamIndex = state.teams.firstIndex(where: { $0.teamId == row.teamId }) else { return }
    if row.playerIndex >= 0,
       row.playerIndex < state.teams[teamIndex].teamModel.players.count,
       state.teams[teamIndex].teamModel.players[row.playerIndex].bio.name == row.playerName {
        state.teams[teamIndex].teamModel.players[row.playerIndex].bio.nilDollarsLastYear = row.offer
        return
    }
    guard let playerIndex = state.teams[teamIndex].teamModel.players.firstIndex(where: { $0.bio.name == row.playerName }) else { return }
    state.teams[teamIndex].teamModel.players[playerIndex].bio.nilDollarsLastYear = row.offer
}

private func deterministicNILNegotiationRoll(state: LeagueStore.State, playerId: String, round: Int, salt: String) -> Double {
    var random = SeededRandom(seed: hashString("\(state.optionsSeed):nil-negotiation:\(state.currentDay):\(playerId):\(round):\(salt)"))
    return random.nextUnit()
}

private func deterministicNILValueRoll(seed: String) -> Double {
    var random = SeededRandom(seed: hashString(seed))
    return random.nextUnit()
}

private func playerKey(teamId: String, playerName: String) -> String {
    "\(teamId):\(playerName)"
}

private func roundToNearestThousand(_ value: Double) -> Double {
    (value / 1_000).rounded() * 1_000
}

private let offseasonRosterTarget = 13

private func completeTransferPortalAndStartNewYear(_ state: inout LeagueStore.State) {
    finalizeNILRetentionAndBuildPortalIfNeeded(&state)
    applyTransferPortalCommits(&state)
    startNextSeasonAfterOffseason(&state)
}

private func applyTransferPortalCommits(_ state: inout LeagueStore.State) {
    guard var portal = state.transferPortal, !portal.isEmpty else { return }

    let orderedIndexes = portal.indices.sorted {
        if portal[$0].overall != portal[$1].overall { return portal[$0].overall > portal[$1].overall }
        if portal[$0].askingPrice != portal[$1].askingPrice { return portal[$0].askingPrice > portal[$1].askingPrice }
        return portal[$0].playerName < portal[$1].playerName
    }

    for portalIndex in orderedIndexes {
        guard portal[portalIndex].committedTeamId == nil else { continue }
        guard let destinationIndex = transferPortalDestinationIndex(for: portal[portalIndex], state: state) else { continue }

        var player = transferPortalPlayer(from: portal[portalIndex], seed: "\(state.optionsSeed):portal-player:\(portal[portalIndex].id)")
        player.bio.nilDollarsLastYear = portal[portalIndex].askingPrice
        state.teams[destinationIndex].teamModel.players.append(player)
        state.teams[destinationIndex].teamModel.lineup.append(player)
        portal[portalIndex].committedTeamId = state.teams[destinationIndex].teamId
        portal[portalIndex].committedTeamName = state.teams[destinationIndex].teamName
    }

    state.transferPortal = portal
}

private func transferPortalDestinationIndex(for entry: TransferPortalEntry, state: LeagueStore.State) -> Int? {
    let candidates = state.teams.indices.filter { state.teams[$0].teamId != entry.previousTeamId }
    guard !candidates.isEmpty else { return nil }

    func score(_ index: Int) -> Double {
        let team = state.teams[index]
        let rosterCount = team.teamModel.players.count
        let need = Double(max(0, offseasonRosterTarget - rosterCount)) * 120
        let capacity = rosterCount < offseasonRosterTarget ? 40 : Double(max(0, 15 - rosterCount)) * 4
        let prestigeFit = team.prestige * 18
        let roleFit = transferPositionNeedScore(entry.position, players: team.teamModel.players) * 14
        let sameSchoolPenalty: Double = team.teamId == entry.previousTeamId ? -500 : 0
        let variance = deterministicNILValueRoll(seed: "\(state.optionsSeed):portal-destination:\(entry.id):\(team.teamId)") * 20
        let total = need + capacity + prestigeFit + roleFit
        return total + variance + sameSchoolPenalty
    }

    return candidates.max {
        let lhsScore = score($0)
        let rhsScore = score($1)
        if lhsScore != rhsScore { return lhsScore < rhsScore }
        return state.teams[$0].teamName > state.teams[$1].teamName
    }
}

private func transferPositionNeedScore(_ position: String, players: [Player]) -> Double {
    let normalized = normalizeHallPosition(position)
    let current = players.filter { normalizeHallPosition($0.bio.position.rawValue) == normalized }.count
    let target: Int
    switch normalized {
    case "PG": target = 2
    case "SG", "SF", "PF": target = 3
    case "C": target = 2
    default: target = 2
    }
    return Double(max(0, target - current))
}

private func transferPortalPlayer(from entry: TransferPortalEntry, seed: String) -> Player {
    if let player = entry.playerModel {
        return player
    }

    var random = SeededRandom(seed: hashString(seed))
    var player = createPlayer()
    player.bio.name = entry.playerName
    player.bio.position = PlayerPosition(rawValue: entry.position) ?? .wing
    player.bio.year = PlayerYear(rawValue: entry.year) ?? .so
    player.bio.home = entry.player?.home ?? ""
    player.bio.potential = entry.potential
    player.bio.redshirtUsed = false
    player.bio.nilDollarsLastYear = entry.askingPrice
    player.greed = entry.greed
    player.loyalty = entry.loyalty
    applyRatings(&player, base: entry.overall, random: &random)

    let height = entry.player?.height.flatMap(parseMeasurementInches) ?? sampleHeightInches(for: player.bio.position, random: &random)
    player.size.height = formatHeight(inches: height)
    player.size.weight = entry.player?.weight ?? "\(sampleWeightPounds(for: player.bio.position, heightInches: height, random: &random))"
    let wingspan = entry.player?.wingspan.flatMap(parseMeasurementInches) ?? height + sampleWingspanDelta(for: player.bio.position, random: &random)
    player.size.wingspan = formatHeight(inches: wingspan)
    return player
}

private func startNextSeasonAfterOffseason(_ state: inout LeagueStore.State) {
    for teamIndex in state.teams.indices {
        let completedGames = max(1, state.teams[teamIndex].wins + state.teams[teamIndex].losses)
        state.teams[teamIndex].lastYearResult = clamp(Double(state.teams[teamIndex].wins) / Double(completedGames), min: 0, max: 1)

        for playerIndex in state.teams[teamIndex].teamModel.players.indices {
            advancePlayerClassForNewSeason(&state.teams[teamIndex].teamModel.players[playerIndex])
        }
        fillWalkOnsIfNeeded(team: &state.teams[teamIndex], seed: "\(state.optionsSeed):walkon:\(state.teams[teamIndex].teamId):\(state.currentDay)")
        state.teams[teamIndex].teamModel.lineup = state.teams[teamIndex].teamModel.players
    }

    state.status = "in_progress"
    state.currentDay = 0
    state.schedule = []
    state.userGameHistory = []
    state.scheduleGenerated = false
    state.conferenceTournaments = nil
    state.nationalTournament = nil
    state.remainingRegularSeasonGames = nil
    state.offseasonStage = nil
    state.playersLeaving = nil
    state.schoolHallOfFame = nil
    state.draftPicks = nil
    state.nilRetention = nil
    state.transferPortal = nil
    state.nilRetentionFinalized = nil
    state.userSelectedOpponentIds = []
    resetTeamRecords(&state)
    autoFillUserNonConferenceOpponentsInState(&state, seed: "new-season:\(state.optionsSeed):\(state.currentDay)")
    generateSeasonScheduleInState(&state)
}

private func advancePlayerClassForNewSeason(_ player: inout Player) {
    switch player.bio.year {
    case .hs:
        player.bio.year = .fr
    case .fr:
        player.bio.year = .so
    case .so:
        player.bio.year = .jr
    case .jr:
        player.bio.year = .sr
    case .sr:
        player.bio.year = .sr
        player.bio.redshirtUsed = true
    case .graduated:
        break
    }
    player.condition.energy = 100
    player.condition.clutchTime = false
    player.condition.fouledOut = false
    player.condition.possessionRole = nil
}

private func fillWalkOnsIfNeeded(team: inout LeagueStore.TeamState, seed: String) {
    var random = SeededRandom(seed: hashString(seed))
    var usedNames = Set(team.teamModel.players.map(\.bio.name))
    while team.teamModel.players.count < offseasonRosterTarget {
        let index = team.teamModel.players.count
        let player = generateWalkOnPlayer(teamName: team.teamName, rosterIndex: index, usedNames: &usedNames, random: &random)
        team.teamModel.players.append(player)
    }
}

private func generateWalkOnPlayer(teamName: String, rosterIndex: Int, usedNames: inout Set<String>, random: inout SeededRandom) -> Player {
    let positionCycle: [PlayerPosition] = [.pg, .sg, .sf, .pf, .c, .cg, .wing, .f, .big, .sg, .pf, .pg, .c]
    var player = createPlayer()
    var name = ""
    repeat {
        let first = rosterFirstNames[random.int(0, rosterFirstNames.count - 1)]
        let last = rosterLastNames[random.int(0, rosterLastNames.count - 1)]
        name = "\(first) \(last)"
    } while usedNames.contains(name)
    usedNames.insert(name)

    player.bio.name = name
    player.bio.position = positionCycle[rosterIndex % positionCycle.count]
    player.bio.year = [.fr, .so, .jr][random.int(0, 2)]
    player.bio.home = ["CA", "TX", "FL", "NY", "NC", "IL", "GA", "PA"][random.int(0, 7)]
    player.bio.redshirtUsed = false
    player.bio.nilDollarsLastYear = 0
    player.greed = Double(clamp(35 + random.int(-12, 12), min: 5, max: 65))
    player.loyalty = Double(clamp(62 + random.int(-18, 20), min: 25, max: 95))

    let base = clamp(35 + random.int(-6, 7), min: 25, max: 46)
    player.bio.potential = clamp(base + random.int(-2, 8), min: 25, max: 52)
    applyRatings(&player, base: base, random: &random)

    let height = sampleHeightInches(for: player.bio.position, random: &random)
    player.size.height = formatHeight(inches: height)
    player.size.weight = "\(sampleWeightPounds(for: player.bio.position, heightInches: height, random: &random))"
    player.size.wingspan = formatHeight(inches: height + sampleWingspanDelta(for: player.bio.position, random: &random))
    player.condition.energy = 100
    return player
}

@discardableResult
public func advanceOffseason(_ league: inout LeagueState) -> LeagueOffseasonProgress? {
    LeagueStore.update(league.handle) { state -> LeagueOffseasonProgress? in
        guard state.status == "completed" else { return nil }

        let currentStage = state.offseasonStage ?? .seasonRecap
        switch currentStage {
        case .schedule:
            state.offseasonStage = .nilBudgets
        case .seasonRecap:
            state.offseasonStage = .schedule
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
            prepareNILRetentionIfNeeded(&state)
            state.offseasonStage = .playerRetention
        case .playerRetention:
            finalizeNILRetentionAndBuildPortalIfNeeded(&state)
            state.offseasonStage = .transferPortal
        case .transferPortal:
            completeTransferPortalAndStartNewYear(&state)
            return LeagueOffseasonProgress(stage: .complete)
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
