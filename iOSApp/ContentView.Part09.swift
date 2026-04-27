import SwiftUI
import UniformTypeIdentifiers
import CBBCoachCore

struct StatLeadersView: View {
    let games: [LeagueGameSummary]
    let userTeamName: String
    let roster: [UserRosterPlayerSummary]
    let teamRostersByName: [String: [UserRosterPlayerSummary]]

    private enum StatCategory: String, CaseIterable {
        case points = "Points"
        case rebounds = "Rebounds"
        case assists = "Assists"
        case steals = "Steals"
        case blocks = "Blocks"
        case fgPct = "FG%"
        case threePct = "3PT%"
        case ftPct = "FT%"
    }

    private struct LeaderEntry {
        let playerName: String
        let teamName: String
        let value: String
        let sub: String
    }

    @State private var category: StatCategory = .points

    private var allStats: [NationalLeaderStats] {
        struct Key: Hashable {
            let playerName: String
            let teamName: String
        }

        var totals: [Key: NationalLeaderStats] = [:]

        for game in games {
            guard
                let resultObject = game.result?.objectDictionary,
                let boxArray = resultObject["boxScore"]?.arrayValues
            else { continue }

            for teamBox in boxArray {
                guard let teamObject = teamBox.objectDictionary else { continue }
                let teamName = teamObject["name"]?.stringValue ?? "Team"
                let players = teamObject["players"]?.arrayValues ?? []
                for player in players {
                    guard let parsed = ParsedPlayerBoxScore(value: player) else { continue }
                    let key = Key(playerName: parsed.playerName, teamName: teamName)
                    var current = totals[key] ?? NationalLeaderStats(playerName: parsed.playerName, teamName: teamName)
                    current.games += 1
                    current.points += parsed.points
                    current.rebounds += parsed.rebounds
                    current.assists += parsed.assists
                    current.steals += parsed.steals
                    current.blocks += parsed.blocks
                    current.fgMade += parsed.fgMade
                    current.fgAttempts += parsed.fgAttempts
                    current.threeMade += parsed.threeMade
                    current.threeAttempts += parsed.threeAttempts
                    current.ftMade += parsed.ftMade
                    current.ftAttempts += parsed.ftAttempts
                    totals[key] = current
                }
            }
        }

        return Array(totals.values)
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(StatCategory.allCases, id: \.self) { item in
                        Button {
                            category = item
                        } label: {
                            Text(item.rawValue)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(category == item ? AppTheme.ink : .secondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(category == item ? AppTheme.accent.opacity(0.2) : AppTheme.cardBackground)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .strokeBorder(category == item ? AppTheme.accent : AppTheme.cardBorder, lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    GameSectionHeader(title: "\(category.rawValue) Leaders")

                    let topLeaders = Array(leaders(for: category).prefix(25))
                    if topLeaders.isEmpty {
                        GameCard {
                            Text("No qualified leaders yet.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        ForEach(Array(topLeaders.enumerated()), id: \.offset) { index, entry in
                            leaderRow(rank: index + 1, entry: entry)
                        }
                    }
                }
                .padding(16)
            }
        }
        .background(AppTheme.background)
        .navigationTitle("Stat Leaders")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func leaders(for category: StatCategory) -> [LeaderEntry] {
        switch category {
        case .points:
            return allStats
                .sorted { lhs, rhs in
                    if lhs.points != rhs.points { return lhs.points > rhs.points }
                    return lhs.pointsPerGame > rhs.pointsPerGame
                }
                .map { row in
                    LeaderEntry(
                        playerName: row.playerName,
                        teamName: row.teamName,
                        value: "\(row.points) PTS",
                        sub: "\(format(row.pointsPerGame)) PPG • \(row.games) G"
                    )
                }
        case .rebounds:
            return allStats
                .sorted { lhs, rhs in
                    if lhs.rebounds != rhs.rebounds { return lhs.rebounds > rhs.rebounds }
                    return lhs.reboundsPerGame > rhs.reboundsPerGame
                }
                .map { row in
                    LeaderEntry(
                        playerName: row.playerName,
                        teamName: row.teamName,
                        value: "\(row.rebounds) REB",
                        sub: "\(format(row.reboundsPerGame)) RPG • \(row.games) G"
                    )
                }
        case .assists:
            return allStats
                .sorted { lhs, rhs in
                    if lhs.assists != rhs.assists { return lhs.assists > rhs.assists }
                    return lhs.assistsPerGame > rhs.assistsPerGame
                }
                .map { row in
                    LeaderEntry(
                        playerName: row.playerName,
                        teamName: row.teamName,
                        value: "\(row.assists) AST",
                        sub: "\(format(row.assistsPerGame)) APG • \(row.games) G"
                    )
                }
        case .steals:
            return allStats
                .sorted { lhs, rhs in
                    if lhs.steals != rhs.steals { return lhs.steals > rhs.steals }
                    return lhs.stealsPerGame > rhs.stealsPerGame
                }
                .map { row in
                    LeaderEntry(
                        playerName: row.playerName,
                        teamName: row.teamName,
                        value: "\(row.steals) STL",
                        sub: "\(format(row.stealsPerGame)) SPG • \(row.games) G"
                    )
                }
        case .blocks:
            return allStats
                .sorted { lhs, rhs in
                    if lhs.blocks != rhs.blocks { return lhs.blocks > rhs.blocks }
                    return lhs.blocksPerGame > rhs.blocksPerGame
                }
                .map { row in
                    LeaderEntry(
                        playerName: row.playerName,
                        teamName: row.teamName,
                        value: "\(row.blocks) BLK",
                        sub: "\(format(row.blocksPerGame)) BPG • \(row.games) G"
                    )
                }
        case .fgPct:
            return allStats
                .filter { $0.fgAttempts >= 50 }
                .sorted { lhs, rhs in
                    if lhs.fgPercentage != rhs.fgPercentage { return lhs.fgPercentage > rhs.fgPercentage }
                    return lhs.fgAttempts > rhs.fgAttempts
                }
                .map { row in
                    LeaderEntry(
                        playerName: row.playerName,
                        teamName: row.teamName,
                        value: "\(format(row.fgPercentage))%",
                        sub: "\(row.fgMade)/\(row.fgAttempts) FG • \(row.games) G"
                    )
                }
        case .threePct:
            return allStats
                .filter { $0.threeAttempts >= 30 }
                .sorted { lhs, rhs in
                    if lhs.threePercentage != rhs.threePercentage { return lhs.threePercentage > rhs.threePercentage }
                    return lhs.threeAttempts > rhs.threeAttempts
                }
                .map { row in
                    LeaderEntry(
                        playerName: row.playerName,
                        teamName: row.teamName,
                        value: "\(format(row.threePercentage))%",
                        sub: "\(row.threeMade)/\(row.threeAttempts) 3PT • \(row.games) G"
                    )
                }
        case .ftPct:
            return allStats
                .filter { $0.ftAttempts >= 25 }
                .sorted { lhs, rhs in
                    if lhs.ftPercentage != rhs.ftPercentage { return lhs.ftPercentage > rhs.ftPercentage }
                    return lhs.ftAttempts > rhs.ftAttempts
                }
                .map { row in
                    LeaderEntry(
                        playerName: row.playerName,
                        teamName: row.teamName,
                        value: "\(format(row.ftPercentage))%",
                        sub: "\(row.ftMade)/\(row.ftAttempts) FT • \(row.games) G"
                    )
                }
        }
    }

    private func leaderRow(rank: Int, entry: LeaderEntry) -> some View {
        GameCard {
            HStack(spacing: 12) {
                Text("\(rank)")
                    .font(.callout.weight(.black))
                    .foregroundStyle(rankColor(rank))
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    NavigationLink {
                        PlayerCardDetailView(
                            player: playerForEntry(entry),
                            games: games,
                            teamName: entry.teamName
                        )
                    } label: {
                        Text(entry.playerName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.accent)
                    }
                    .buttonStyle(.plain)
                    Text(entry.sub)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(entry.value)
                        .font(.callout.weight(.bold))
                        .foregroundStyle(AppTheme.ink)
                    Text(entry.teamName)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func rankColor(_ rank: Int) -> Color {
        if rank == 1 { return AppTheme.accent }
        if rank <= 3 { return AppTheme.success }
        return .secondary
    }

    private func format(_ value: Double) -> String {
        String(format: "%.1f", value)
    }

    private func playerForEntry(_ entry: LeaderEntry) -> UserRosterPlayerSummary {
        if let fullProfile = rosterPlayer(for: entry) {
            return fullProfile
        }

        if entry.teamName == userTeamName,
           let rosterPlayer = roster.first(where: { $0.name == entry.playerName }) {
            return rosterPlayer
        }

        return UserRosterPlayerSummary(
            playerIndex: -1,
            name: entry.playerName,
            position: inferredPosition(for: entry) ?? "",
            year: "N/A",
            home: nil,
            height: nil,
            weight: nil,
            wingspan: nil,
            overall: 0,
            isStarter: false,
            attributes: nil
        )
    }

    private func inferredPosition(for entry: LeaderEntry) -> String? {
        for game in games where game.completed == true {
            guard
                let resultObject = game.result?.objectDictionary,
                let boxArray = resultObject["boxScore"]?.arrayValues
            else { continue }

            guard let teamBox = boxArray.first(where: { box in
                box.objectDictionary?["name"]?.stringValue == entry.teamName
            }) else { continue }

            let players = teamBox.objectDictionary?["players"]?.arrayValues ?? []
            if let line = players
                .compactMap(ParsedPlayerBoxScore.init(value:))
                .first(where: { $0.playerName == entry.playerName }) {
                return line.position
            }
        }
        return nil
    }

    private func rosterPlayer(for entry: LeaderEntry) -> UserRosterPlayerSummary? {
        guard let teamRoster = rosterForTeam(named: entry.teamName) else { return nil }
        let nameMatches = teamRoster.filter { $0.name == entry.playerName }
        guard !nameMatches.isEmpty else { return nil }

        if nameMatches.count == 1 {
            return nameMatches[0]
        }

        if let inferredPosition = inferredPosition(for: entry),
           let positionalMatch = nameMatches.first(where: { $0.position == inferredPosition }) {
            return positionalMatch
        }

        return nameMatches.first
    }

    private func rosterForTeam(named teamName: String) -> [UserRosterPlayerSummary]? {
        if let direct = teamRostersByName[teamName] {
            return direct
        }
        return teamRostersByName.first(where: {
            $0.key.caseInsensitiveCompare(teamName) == .orderedSame
        })?.value
    }
}

struct ConferenceStandingsView: View {
    let standingsByConference: [String: [ConferenceStanding]]
    let conferenceNamesById: [String: String]
    let preferredConferenceId: String?

    private var orderedConferences: [String] {
        var result: [String] = []
        if let preferredConferenceId, standingsByConference[preferredConferenceId] != nil {
            result.append(preferredConferenceId)
        }
        let rest = standingsByConference.keys.filter { $0 != preferredConferenceId }.sorted()
        result.append(contentsOf: rest)
        return result
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ForEach(orderedConferences, id: \.self) { conferenceId in
                    if let rows = standingsByConference[conferenceId], !rows.isEmpty {
                        let columns: [AppTableColumn<String>] = [
                            .init(id: "team", title: "TEAM", width: 140, alignment: .leading),
                            .init(id: "conf", title: "CONF", width: 56),
                            .init(id: "overall", title: "OVR", width: 56),
                            .init(id: "pf", title: "PPG", width: 56),
                            .init(id: "pa", title: "PAPG", width: 56),
                            .init(id: "diff", title: "DIFF/G", width: 56),
                        ]
                        let tableRows = rows.map { (id: AnyHashable($0.teamId), data: $0) }

                        GameCard {
                            GameSectionHeader(title: conferenceTitle(conferenceId))
                            AppTable(columns: columns, rows: tableRows) { row in
                                HStack(spacing: 0) {
                                    AppTableTextCell(
                                        text: row.teamName,
                                        width: 140,
                                        alignment: .leading,
                                        font: .subheadline.weight(.semibold),
                                        foreground: .primary
                                    )
                                    AppTableTextCell(
                                        text: "\(row.conferenceWins)-\(row.conferenceLosses)",
                                        width: 56,
                                        font: .caption.monospacedDigit().weight(.medium)
                                    )
                                    AppTableTextCell(
                                        text: "\(row.wins)-\(row.losses)",
                                        width: 56,
                                        font: .caption.monospacedDigit().weight(.medium)
                                    )
                                    AppTableTextCell(
                                        text: formatPerGame(points: row.pointsFor ?? 0, wins: row.wins, losses: row.losses),
                                        width: 56,
                                        font: .caption.monospacedDigit().weight(.medium)
                                    )
                                    AppTableTextCell(
                                        text: formatPerGame(points: row.pointsAgainst ?? 0, wins: row.wins, losses: row.losses),
                                        width: 56,
                                        font: .caption.monospacedDigit().weight(.medium)
                                    )
                                    AppTableTextCell(
                                        text: formatPerGame(
                                            points: (row.pointsFor ?? 0) - (row.pointsAgainst ?? 0),
                                            wins: row.wins,
                                            losses: row.losses
                                        ),
                                        width: 56,
                                        font: .caption.monospacedDigit().weight(.medium)
                                    )
                                }
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
        .navigationTitle("Standings")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func conferenceTitle(_ id: String) -> String {
        if let knownName = conferenceNamesById[id] {
            return knownName
        }
        return id
            .split(separator: "-")
            .map { String($0).capitalized }
            .joined(separator: " ")
    }

    private func formatPerGame(points: Int, wins: Int, losses: Int) -> String {
        let gamesPlayed = wins + losses
        guard gamesPlayed > 0 else { return "0.0" }
        return String(format: "%.1f", Double(points) / Double(gamesPlayed))
    }
}
