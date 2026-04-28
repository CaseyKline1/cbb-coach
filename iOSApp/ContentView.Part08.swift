import SwiftUI
import UniformTypeIdentifiers
import CBBCoachCore

struct TeamAggregateStats: Sendable {
    let teamId: String
    let teamName: String
    var games: Int = 0
    var points: Int = 0
    var rebounds: Int = 0
    var opponentRebounds: Int = 0
    var assists: Int = 0
    var steals: Int = 0
    var blocks: Int = 0
    var turnovers: Int = 0
    var fgMade: Int = 0
    var fgAttempts: Int = 0
    var threeMade: Int = 0
    var threeAttempts: Int = 0
    var ftMade: Int = 0
    var ftAttempts: Int = 0
    var fastBreakPoints: Int = 0
    var pointsInPaint: Int = 0
    var offensiveRebounds: Int = 0
    var opponentDefensiveRebounds: Int = 0

    private func perGame(_ value: Int) -> Double {
        guard games > 0 else { return 0 }
        return Double(value) / Double(games)
    }

    var pointsPerGame: Double { perGame(points) }
    var assistsPerGame: Double { perGame(assists) }
    var stealsPerGame: Double { perGame(steals) }
    var blocksPerGame: Double { perGame(blocks) }
    var turnoversPerGame: Double { perGame(turnovers) }
    var netReboundsPerGame: Double { perGame(rebounds - opponentRebounds) }
    var fastBreakPointsPerGame: Double { perGame(fastBreakPoints) }
    var pointsInPaintPerGame: Double { perGame(pointsInPaint) }

    var twoPointMade: Int { max(0, fgMade - threeMade) }
    var twoPointAttempts: Int { max(0, fgAttempts - threeAttempts) }
    var twoPointPct: Double {
        guard twoPointAttempts > 0 else { return 0 }
        return (Double(twoPointMade) / Double(twoPointAttempts)) * 100
    }
    var threePointPct: Double {
        guard threeAttempts > 0 else { return 0 }
        return (Double(threeMade) / Double(threeAttempts)) * 100
    }
    var freeThrowPct: Double {
        guard ftAttempts > 0 else { return 0 }
        return (Double(ftMade) / Double(ftAttempts)) * 100
    }
    var offensiveReboundPct: Double {
        let missedFieldGoals = max(0, fgAttempts - fgMade)
        guard missedFieldGoals > 0 else { return 0 }
        return (Double(offensiveRebounds) / Double(missedFieldGoals)) * 100
    }
}

struct TeamGameBoxLine {
    let teamId: String
    let teamName: String
    let points: Int
    let rebounds: Int
    let assists: Int
    let steals: Int
    let blocks: Int
    let turnovers: Int
    let fgMade: Int
    let fgAttempts: Int
    let threeMade: Int
    let threeAttempts: Int
    let ftMade: Int
    let ftAttempts: Int
    let fastBreakPoints: Int
    let pointsInPaint: Int
    let offensiveRebounds: Int
    let defensiveRebounds: Int
}

struct TeamStatsMetricRow: Hashable {
    let id: String
    let stat: String
    let value: String
    let conferenceRank: String
    let nationalRank: String
}

struct TeamStatsView: View {
    let teamStatsById: [String: TeamAggregateStats]
    let userTeamId: String?
    let userConferenceId: String?
    let conferenceIdByTeamId: [String: String]
    let userRank: Int?

    private struct MetricDefinition {
        let id: String
        let title: String
        let higherIsBetter: Bool
        let extractor: (TeamAggregateStats) -> Double
        let formatter: (Double) -> String
    }

    nonisolated static func aggregateTeamStats(from games: [LeagueGameSummary]) -> [String: TeamAggregateStats] {
        var totals: [String: TeamAggregateStats] = [:]
        for game in games {
            let lines = parseGameLines(from: game)
            for index in lines.indices {
                let line = lines[index]
                let opponentRebounds = lines.count > 1
                    ? lines[(index + 1) % lines.count].rebounds
                    : 0
                var current = totals[line.teamId] ?? TeamAggregateStats(teamId: line.teamId, teamName: line.teamName)
                current.games += 1
                current.points += line.points
                current.rebounds += line.rebounds
                current.opponentRebounds += opponentRebounds
                current.assists += line.assists
                current.steals += line.steals
                current.blocks += line.blocks
                current.turnovers += line.turnovers
                current.fgMade += line.fgMade
                current.fgAttempts += line.fgAttempts
                current.threeMade += line.threeMade
                current.threeAttempts += line.threeAttempts
                current.ftMade += line.ftMade
                current.ftAttempts += line.ftAttempts
                current.fastBreakPoints += line.fastBreakPoints
                current.pointsInPaint += line.pointsInPaint
                current.offensiveRebounds += line.offensiveRebounds
                current.opponentDefensiveRebounds += lines.count > 1
                    ? lines[(index + 1) % lines.count].defensiveRebounds
                    : 0
                totals[line.teamId] = current
            }
        }
        return totals
    }

    private var sortedTeamStats: [TeamAggregateStats] {
        teamStatsById.values
            .filter { $0.games > 0 }
            .sorted { lhs, rhs in
                if lhs.teamName != rhs.teamName {
                    return lhs.teamName.localizedCaseInsensitiveCompare(rhs.teamName) == .orderedAscending
                }
                return lhs.teamId < rhs.teamId
            }
    }

    private var userStats: TeamAggregateStats? {
        guard let userTeamId else { return nil }
        return teamStatsById[userTeamId]
    }

    private var conferenceTeamStats: [TeamAggregateStats] {
        guard let userConferenceId else { return [] }
        return sortedTeamStats.filter { team in
            conferenceIdByTeamId[team.teamId] == userConferenceId
        }
    }

    private var metricDefinitions: [MetricDefinition] {
        [
            .init(id: "ppg", title: "PPG", higherIsBetter: true, extractor: { $0.pointsPerGame }, formatter: formatPerGame),
            .init(id: "apg", title: "APG", higherIsBetter: true, extractor: { $0.assistsPerGame }, formatter: formatPerGame),
            .init(id: "spg", title: "SPG", higherIsBetter: true, extractor: { $0.stealsPerGame }, formatter: formatPerGame),
            .init(id: "bpg", title: "BPG", higherIsBetter: true, extractor: { $0.blocksPerGame }, formatter: formatPerGame),
            .init(id: "tovpg", title: "TO/G", higherIsBetter: false, extractor: { $0.turnoversPerGame }, formatter: formatPerGame),
            .init(id: "netreb", title: "NET REB/G", higherIsBetter: true, extractor: { $0.netReboundsPerGame }, formatter: formatPerGame),
            .init(id: "fastbreak", title: "FAST BREAK/G", higherIsBetter: true, extractor: { $0.fastBreakPointsPerGame }, formatter: formatPerGame),
            .init(id: "paint", title: "PIP/G", higherIsBetter: true, extractor: { $0.pointsInPaintPerGame }, formatter: formatPerGame),
            .init(id: "orpct", title: "OR%", higherIsBetter: true, extractor: { $0.offensiveReboundPct }, formatter: formatPercent),
            .init(id: "2pt", title: "2PT%", higherIsBetter: true, extractor: { $0.twoPointPct }, formatter: formatPercent),
            .init(id: "3pt", title: "3PT%", higherIsBetter: true, extractor: { $0.threePointPct }, formatter: formatPercent),
            .init(id: "ft", title: "FT%", higherIsBetter: true, extractor: { $0.freeThrowPct }, formatter: formatPercent),
        ]
    }

    private var metricRows: [TeamStatsMetricRow] {
        guard let userStats else { return [] }
        return metricDefinitions.map { metric in
            TeamStatsMetricRow(
                id: metric.id,
                stat: metric.title,
                value: metric.formatter(metric.extractor(userStats)),
                conferenceRank: formatRank(
                    rank(
                        for: userStats.teamId,
                        in: conferenceTeamStats,
                        metric: metric.extractor,
                        higherIsBetter: metric.higherIsBetter
                    ),
                    total: conferenceTeamStats.count
                ),
                nationalRank: formatRank(
                    rank(
                        for: userStats.teamId,
                        in: sortedTeamStats,
                        metric: metric.extractor,
                        higherIsBetter: metric.higherIsBetter
                    ),
                    total: sortedTeamStats.count
                )
            )
        }
    }

    private var navigationTitleText: String {
        let name = userStats?.teamName ?? "Team Stats"
        if let userRank {
            return "#\(userRank) \(name)"
        }
        return name
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if userStats != nil {
                    let columns: [AppTableColumn<String>] = [
                        .init(id: "stat", title: "STAT", width: 130, alignment: .leading),
                        .init(id: "value", title: "VALUE", width: 72),
                        .init(id: "conf", title: "CONF", width: 78),
                        .init(id: "nat", title: "NAT", width: 78),
                    ]

                    AppTable(
                        columns: columns,
                        rows: metricRows.map { (id: AnyHashable($0.id), data: $0) }
                    ) { row in
                        HStack(spacing: 0) {
                            AppTableTextCell(text: row.stat, width: 130, alignment: .leading, font: .caption.monospacedDigit().weight(.semibold))
                            AppTableTextCell(text: row.value, width: 72, font: .caption.monospacedDigit())
                            AppTableTextCell(text: row.conferenceRank, width: 78, font: .caption.monospacedDigit())
                            AppTableTextCell(text: row.nationalRank, width: 78, font: .caption.monospacedDigit())
                        }
                    }
                } else {
                    GameCard {
                        Text("No completed games yet.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(16)
        }
        .background(AppTheme.background)
        .navigationTitle(navigationTitleText)
        .navigationBarTitleDisplayMode(.inline)
    }

    nonisolated private static func parseGameLines(from game: LeagueGameSummary) -> [TeamGameBoxLine] {
        guard
            let resultObject = game.result?.objectDictionary,
            let boxArray = resultObject["boxScore"]?.arrayValues
        else {
            return []
        }

        let pointsByIndex: [Int] = [
            resultObject["homeScore"]?.intValue ?? 0,
            resultObject["awayScore"]?.intValue ?? 0,
        ]
        let idsByIndex: [Int: String] = [
            0: game.homeTeamId ?? (game.homeTeamName ?? "home"),
            1: game.awayTeamId ?? (game.awayTeamName ?? "away"),
        ]
        let namesByIndex: [Int: String] = [
            0: game.homeTeamName ?? "Home",
            1: game.awayTeamName ?? "Away",
        ]

        return boxArray.enumerated().compactMap { index, boxValue in
            guard let teamObject = boxValue.objectDictionary else { return nil }
            let teamName = namesByIndex[index] ?? teamObject["name"]?.stringValue ?? "Team"
            let teamId = idsByIndex[index] ?? teamName
            let points = index < pointsByIndex.count ? pointsByIndex[index] : 0
            let players = teamObject["players"]?.arrayValues ?? []
            let teamExtras = teamObject["teamExtras"]?.objectDictionary ?? [:]

            var rebounds = 0
            var assists = 0
            var steals = 0
            var blocks = 0
            var turnoversFromPlayers = 0
            var fgMade = 0
            var fgAttempts = 0
            var threeMade = 0
            var threeAttempts = 0
            var ftMade = 0
            var ftAttempts = 0
            var offensiveRebounds = 0

            for player in players {
                guard let parsed = ParsedPlayerBoxScore(value: player) else { continue }
                rebounds += parsed.rebounds
                assists += parsed.assists
                steals += parsed.steals
                blocks += parsed.blocks
                turnoversFromPlayers += parsed.turnovers
                fgMade += parsed.fgMade
                fgAttempts += parsed.fgAttempts
                threeMade += parsed.threeMade
                threeAttempts += parsed.threeAttempts
                ftMade += parsed.ftMade
                ftAttempts += parsed.ftAttempts
                offensiveRebounds += parsed.offensiveRebounds
            }
            offensiveRebounds = min(offensiveRebounds, rebounds)
            let defensiveRebounds = max(0, rebounds - offensiveRebounds)

            return TeamGameBoxLine(
                teamId: teamId,
                teamName: teamName,
                points: points,
                rebounds: rebounds,
                assists: assists,
                steals: steals,
                blocks: blocks,
                turnovers: teamExtras["turnovers"]?.intValue ?? turnoversFromPlayers,
                fgMade: fgMade,
                fgAttempts: fgAttempts,
                threeMade: threeMade,
                threeAttempts: threeAttempts,
                ftMade: ftMade,
                ftAttempts: ftAttempts,
                fastBreakPoints: teamExtras["fastBreakPoints"]?.intValue ?? 0,
                pointsInPaint: teamExtras["pointsInPaint"]?.intValue ?? 0,
                offensiveRebounds: offensiveRebounds,
                defensiveRebounds: defensiveRebounds
            )
        }
    }

    private func rank(
        for teamId: String,
        in teams: [TeamAggregateStats],
        metric: (TeamAggregateStats) -> Double,
        higherIsBetter: Bool
    ) -> Int? {
        let sorted = teams.sorted { lhs, rhs in
            let lhsValue = metric(lhs)
            let rhsValue = metric(rhs)
            if lhsValue != rhsValue {
                return higherIsBetter ? lhsValue > rhsValue : lhsValue < rhsValue
            }
            return lhs.teamName.localizedCaseInsensitiveCompare(rhs.teamName) == .orderedAscending
        }
        guard let index = sorted.firstIndex(where: { $0.teamId == teamId }) else { return nil }
        return index + 1
    }

    private func formatRank(_ rank: Int?, total: Int) -> String {
        guard let rank, total > 0 else { return "--" }
        return "\(rank)/\(total)"
    }

    private func formatPerGame(_ value: Double) -> String {
        String(format: "%.1f", value)
    }

    private func formatPercent(_ value: Double) -> String {
        String(format: "%.1f%%", value)
    }
}

struct NationalLeaderStats {
    let playerName: String
    let teamName: String
    var games: Int = 0
    var points: Int = 0
    var rebounds: Int = 0
    var assists: Int = 0
    var steals: Int = 0
    var blocks: Int = 0
    var fgMade: Int = 0
    var fgAttempts: Int = 0
    var threeMade: Int = 0
    var threeAttempts: Int = 0
    var ftMade: Int = 0
    var ftAttempts: Int = 0

    private func perGame(_ value: Int) -> Double {
        guard games > 0 else { return 0 }
        return Double(value) / Double(games)
    }

    var pointsPerGame: Double { perGame(points) }
    var reboundsPerGame: Double { perGame(rebounds) }
    var assistsPerGame: Double { perGame(assists) }
    var stealsPerGame: Double { perGame(steals) }
    var blocksPerGame: Double { perGame(blocks) }

    var fgPercentage: Double {
        guard fgAttempts > 0 else { return 0 }
        return (Double(fgMade) / Double(fgAttempts)) * 100
    }

    var threePercentage: Double {
        guard threeAttempts > 0 else { return 0 }
        return (Double(threeMade) / Double(threeAttempts)) * 100
    }

    var ftPercentage: Double {
        guard ftAttempts > 0 else { return 0 }
        return (Double(ftMade) / Double(ftAttempts)) * 100
    }
}
