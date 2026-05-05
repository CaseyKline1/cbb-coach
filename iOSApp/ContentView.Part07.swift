import SwiftUI
import UniformTypeIdentifiers
import CBBCoachCore

struct ScheduleListView: View {
    let schedule: [UserGameSummary]
    let userTeamName: String

    private var orderedGames: [UserGameSummary] {
        schedule.sorted {
            let lhsDay = $0.day ?? Int.max
            let rhsDay = $1.day ?? Int.max
            if lhsDay != rhsDay {
                return lhsDay < rhsDay
            }
            return ($0.gameId ?? "") < ($1.gameId ?? "")
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ForEach(Array(orderedGames.enumerated()), id: \.offset) { index, game in
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Game \(index + 1)")
                            .font(.headline)
                        scheduleRow(game)
                    }
                }
            }
            .padding(16)
        }
        .navigationTitle("Schedule")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func scheduleRow(_ game: UserGameSummary) -> some View {
        Group {
            if game.completed == true, let gameId = game.gameId {
                NavigationLink(value: LeagueMenuDestination.boxScore(gameId)) {
                    scheduleRowContent(game)
                }
                .buttonStyle(.plain)
            } else {
                scheduleRowContent(game)
            }
        }
    }

    private func scheduleRowContent(_ game: UserGameSummary) -> some View {
        GameCard {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(game.isHome == true ? "vs" : "@") \(game.opponentName ?? "Unknown")")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(game.type?.replacingOccurrences(of: "_", with: " ").capitalized ?? "Game")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if game.completed == true {
                    let home = game.result?.intValue(for: "homeScore") ?? 0
                    let away = game.result?.intValue(for: "awayScore") ?? 0
                    let userScore = game.isHome == true ? home : away
                    let oppScore = game.isHome == true ? away : home
                    HStack(spacing: 6) {
                        GamePill(text: userScore > oppScore ? "W" : "L", color: userScore > oppScore ? AppTheme.success : AppTheme.danger)
                        Text("\(userScore)-\(oppScore)")
                            .font(.subheadline.monospacedDigit().weight(.semibold))
                            .foregroundStyle(.primary)
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("Upcoming")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct BoxScoreDetailView: View {
    let game: UserGameSummary
    let userTeamName: String
    let games: [LeagueGameSummary]
    let roster: [UserRosterPlayerSummary]
    let teamRostersByName: [String: [UserRosterPlayerSummary]]

    private var homeScore: Int { game.result?.intValue(for: "homeScore") ?? 0 }
    private var awayScore: Int { game.result?.intValue(for: "awayScore") ?? 0 }
    private var overtime: Bool { game.result?.boolValue(for: "wentToOvertime") ?? false }
    private var boxTeams: [ParsedTeamBoxScore] { ParsedTeamBoxScore.parse(from: game.result) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                GameCard {
                    GameSectionHeader(title: "Final")
                    VStack(alignment: .leading, spacing: 6) {
                        Text("\(game.isHome == true ? "vs" : "@") \(game.opponentName ?? "Unknown")")
                            .font(.subheadline.weight(.semibold))
                        Text("\(awayScore)-\(homeScore)\(overtime ? " OT" : "")")
                            .font(.title2.monospacedDigit().bold())
                    }
                }

                if boxTeams.isEmpty {
                    Text("No detailed box score available for this game.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(boxTeams, id: \.name) { team in
                        teamSection(team)
                    }
                }
            }
            .padding(16)
        }
        .navigationTitle("Box Score")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func teamSection(_ team: ParsedTeamBoxScore) -> some View {
        let columns: [AppTableColumn<String>] = [
            .init(id: "player", title: "", width: 130, alignment: .leading),
            .init(id: "min", title: "MIN", width: 40),
            .init(id: "pts", title: "PTS", width: 38),
            .init(id: "reb", title: "REB", width: 38),
            .init(id: "ast", title: "AST", width: 38),
            .init(id: "stl", title: "STL", width: 38),
            .init(id: "blk", title: "BLK", width: 38),
            .init(id: "to", title: "TO", width: 38),
            .init(id: "fg", title: "FG", width: 56),
            .init(id: "three", title: "3PT", width: 56),
            .init(id: "ft", title: "FT", width: 56),
            .init(id: "plusMinus", title: "+/-", width: 40),
            .init(id: "pf", title: "PF", width: 38),
        ]
        let tableRows = Array(team.players.enumerated()).map {
            (id: AnyHashable("\($0.offset)-\($0.element.playerName)"), data: $0.element)
        }

        return GameCard {
            GameSectionHeader(title: team.name)
            AppTable(columns: columns, rows: tableRows) { player in
                HStack(spacing: 0) {
                    HStack(spacing: 0) {
                        NavigationLink {
                            PlayerCardDetailView(
                                player: resolvedPlayer(teamName: team.name, boxLine: player),
                                games: games,
                                teamName: team.name
                            )
                        } label: {
                            Text(player.playerName)
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)

                        Text(" (\(player.position))")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                    }
                    .frame(width: 130, alignment: .leading)

                    AppTableTextCell(text: "\(Int(player.minutes.rounded()))", width: 40, font: .caption.monospacedDigit())
                    AppTableTextCell(text: "\(player.points)", width: 38, font: .caption.monospacedDigit())
                    AppTableTextCell(text: "\(player.rebounds)", width: 38, font: .caption.monospacedDigit())
                    AppTableTextCell(text: "\(player.assists)", width: 38, font: .caption.monospacedDigit())
                    AppTableTextCell(text: "\(player.steals)", width: 38, font: .caption.monospacedDigit())
                    AppTableTextCell(text: "\(player.blocks)", width: 38, font: .caption.monospacedDigit())
                    AppTableTextCell(text: "\(player.turnovers)", width: 38, font: .caption.monospacedDigit())
                    AppTableTextCell(text: "\(player.fgMade)-\(player.fgAttempts)", width: 56, font: .caption.monospacedDigit())
                    AppTableTextCell(text: "\(player.threeMade)-\(player.threeAttempts)", width: 56, font: .caption.monospacedDigit())
                    AppTableTextCell(text: "\(player.ftMade)-\(player.ftAttempts)", width: 56, font: .caption.monospacedDigit())
                    AppTableTextCell(text: formatPlusMinus(player.plusMinus), width: 40, font: .caption.monospacedDigit())
                    AppTableTextCell(text: "\(player.fouls)", width: 38, font: .caption.monospacedDigit())
                }
            }
        }
    }

    private func formatPlusMinus(_ value: Int) -> String {
        if value > 0 { return "+\(value)" }
        return "\(value)"
    }

    private func rosterForTeam(named teamName: String) -> [UserRosterPlayerSummary]? {
        if let direct = teamRostersByName[teamName] {
            return direct
        }
        return teamRostersByName.first(where: {
            $0.key.caseInsensitiveCompare(teamName) == .orderedSame
        })?.value
    }

    private func resolvedPlayer(teamName: String, boxLine: ParsedPlayerBoxScore) -> UserRosterPlayerSummary {
        if let teamRoster = rosterForTeam(named: teamName),
           let match = teamRoster.first(where: { $0.name == boxLine.playerName }) {
            return match
        }
        if teamName == userTeamName,
           let match = roster.first(where: { $0.name == boxLine.playerName }) {
            return match
        }

        return UserRosterPlayerSummary(
            playerIndex: -1,
            name: boxLine.playerName,
            position: boxLine.position,
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
}

struct PlayerStatsRow: Hashable {
    let name: String
    let games: Int
    let minutes: Double
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

    var minutesPerGame: Double { perGame(minutes) }
    var pointsPerGame: Double { perGame(points) }
    var reboundsPerGame: Double { perGame(rebounds) }
    var assistsPerGame: Double { perGame(assists) }
    var stealsPerGame: Double { perGame(steals) }
    var blocksPerGame: Double { perGame(blocks) }
    var turnoversPerGame: Double { perGame(turnovers) }
    var fgMadePerGame: Double { perGame(fgMade) }
    var fgAttemptsPerGame: Double { perGame(fgAttempts) }
    var threeMadePerGame: Double { perGame(threeMade) }
    var threeAttemptsPerGame: Double { perGame(threeAttempts) }
    var ftMadePerGame: Double { perGame(ftMade) }
    var ftAttemptsPerGame: Double { perGame(ftAttempts) }
    var fgPercentage: Double { percentage(made: fgMade, attempts: fgAttempts) }
    var threePercentage: Double { percentage(made: threeMade, attempts: threeAttempts) }
    var ftPercentage: Double { percentage(made: ftMade, attempts: ftAttempts) }
    var effectiveFieldGoalPercentage: Double {
        guard fgAttempts > 0 else { return 0 }
        return ((Double(fgMade) + 0.5 * Double(threeMade)) / Double(fgAttempts)) * 100
    }

    private func perGame(_ value: Int) -> Double {
        guard games > 0 else { return 0 }
        return Double(value) / Double(games)
    }

    private func perGame(_ value: Double) -> Double {
        guard games > 0 else { return 0 }
        return value / Double(games)
    }

    private func percentage(made: Int, attempts: Int) -> Double {
        guard attempts > 0 else { return 0 }
        return (Double(made) / Double(attempts)) * 100
    }
}

struct PlayerStatsView: View {
    let schedule: [UserGameSummary]
    let games: [LeagueGameSummary]
    let userTeamName: String
    let roster: [UserRosterPlayerSummary]
    let teamRostersByName: [String: [UserRosterPlayerSummary]]
    @State private var sortColumn: String = "points"
    @State private var isAscending: Bool = false

    private var rows: [PlayerStatsRow] {
        var totals: [String: PlayerStatsRow] = [:]

        for game in schedule where game.completed == true {
            guard
                let resultObj = game.result?.objectDictionary,
                let teamBoxes = resultObj["boxScore"]?.arrayValues
            else { continue }

            guard let userTeamBox = teamBoxes.first(where: { box in
                box.objectDictionary?["name"]?.stringValue == userTeamName
            }) else { continue }

            let players = userTeamBox.objectDictionary?["players"]?.arrayValues ?? []
            for player in players {
                guard let parsed = ParsedPlayerBoxScore(value: player) else { continue }
                let current = totals[parsed.playerName]
                totals[parsed.playerName] = PlayerStatsRow(
                    name: parsed.playerName,
                    games: (current?.games ?? 0) + 1,
                    minutes: (current?.minutes ?? 0) + parsed.minutes,
                    points: (current?.points ?? 0) + parsed.points,
                    rebounds: (current?.rebounds ?? 0) + parsed.rebounds,
                    assists: (current?.assists ?? 0) + parsed.assists,
                    steals: (current?.steals ?? 0) + parsed.steals,
                    blocks: (current?.blocks ?? 0) + parsed.blocks,
                    turnovers: (current?.turnovers ?? 0) + parsed.turnovers,
                    fgMade: (current?.fgMade ?? 0) + parsed.fgMade,
                    fgAttempts: (current?.fgAttempts ?? 0) + parsed.fgAttempts,
                    threeMade: (current?.threeMade ?? 0) + parsed.threeMade,
                    threeAttempts: (current?.threeAttempts ?? 0) + parsed.threeAttempts,
                    ftMade: (current?.ftMade ?? 0) + parsed.ftMade,
                    ftAttempts: (current?.ftAttempts ?? 0) + parsed.ftAttempts
                )
            }
        }

        return totals.values.sorted { lhs, rhs in
            let comparison = compare(lhs, rhs)
            if comparison == .orderedSame {
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
            return isAscending ? (comparison == .orderedAscending) : (comparison == .orderedDescending)
        }
    }

    private var columns: [AppTableColumn<String>] {
        [
            .init(id: "name", title: "", width: 170, alignment: .leading),
            .init(id: "games", title: "G", width: 42),
            .init(id: "mpg", title: "MPG", width: 48),
            .init(id: "points", title: "PPG", width: 48),
            .init(id: "rebounds", title: "REB", width: 48),
            .init(id: "assists", title: "AST", width: 48),
            .init(id: "steals", title: "STL", width: 48),
            .init(id: "blocks", title: "BLK", width: 48),
            .init(id: "turnovers", title: "TO", width: 48),
            .init(id: "fg", title: "FG%", width: 64),
            .init(id: "three", title: "3PT%", width: 64),
            .init(id: "ft", title: "FT%", width: 64),
            .init(id: "efg", title: "EFG%", width: 56),
            .init(id: "fgm", title: "FGM", width: 46),
            .init(id: "fga", title: "FGA", width: 46),
            .init(id: "tpm", title: "3PM", width: 46),
            .init(id: "tpa", title: "3PA", width: 46),
            .init(id: "ftm", title: "FTM", width: 46),
            .init(id: "fta", title: "FTA", width: 46),
        ]
    }

    private var tableRows: [(id: AnyHashable, data: PlayerStatsRow)] {
        rows.map { (id: AnyHashable($0.name), data: $0) }
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            AppTable(
                columns: columns,
                rows: tableRows,
                sortState: .init(column: sortColumn, ascending: isAscending),
                onSort: toggleSort
            ) { row in
                HStack(spacing: 0) {
                    NavigationLink {
                        PlayerCardDetailView(
                            player: playerForRow(named: row.name),
                            games: games,
                            teamName: userTeamName
                        )
                    } label: {
                        AppTableTextCell(text: row.name, width: 170, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    AppTableTextCell(text: "\(row.games)", width: 42)
                    AppTableTextCell(text: format(row.minutesPerGame), width: 48)
                    AppTableTextCell(text: format(row.pointsPerGame), width: 48)
                    AppTableTextCell(text: format(row.reboundsPerGame), width: 48)
                    AppTableTextCell(text: format(row.assistsPerGame), width: 48)
                    AppTableTextCell(text: format(row.stealsPerGame), width: 48)
                    AppTableTextCell(text: format(row.blocksPerGame), width: 48)
                    AppTableTextCell(text: format(row.turnoversPerGame), width: 48)
                    AppTableTextCell(text: formatPercentage(row.fgPercentage, attempts: row.fgAttempts), width: 64)
                    AppTableTextCell(text: formatPercentage(row.threePercentage, attempts: row.threeAttempts), width: 64)
                    AppTableTextCell(text: formatPercentage(row.ftPercentage, attempts: row.ftAttempts), width: 64)
                    AppTableTextCell(text: formatPercentage(row.effectiveFieldGoalPercentage, attempts: row.fgAttempts), width: 56)
                    AppTableTextCell(text: format(row.fgMadePerGame), width: 46)
                    AppTableTextCell(text: format(row.fgAttemptsPerGame), width: 46)
                    AppTableTextCell(text: format(row.threeMadePerGame), width: 46)
                    AppTableTextCell(text: format(row.threeAttemptsPerGame), width: 46)
                    AppTableTextCell(text: format(row.ftMadePerGame), width: 46)
                    AppTableTextCell(text: format(row.ftAttemptsPerGame), width: 46)
                }
            }
        }
        .background(AppTheme.background)
        .navigationTitle("Player Stats")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func playerForRow(named playerName: String) -> UserRosterPlayerSummary {
        if let rosterPlayer = roster.first(where: { $0.name == playerName }) {
            return rosterPlayer
        }
        if let teamPlayer = rosterForTeam(named: userTeamName)?.first(where: { $0.name == playerName }) {
            return teamPlayer
        }

        return UserRosterPlayerSummary(
            playerIndex: -1,
            name: playerName,
            position: inferredPosition(for: playerName) ?? "",
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

    private func inferredPosition(for playerName: String) -> String? {
        for game in schedule where game.completed == true {
            guard
                let resultObj = game.result?.objectDictionary,
                let teamBoxes = resultObj["boxScore"]?.arrayValues
            else { continue }

            guard let userTeamBox = teamBoxes.first(where: { box in
                box.objectDictionary?["name"]?.stringValue == userTeamName
            }) else { continue }

            let players = userTeamBox.objectDictionary?["players"]?.arrayValues ?? []
            if let line = players
                .compactMap(ParsedPlayerBoxScore.init(value:))
                .first(where: { $0.playerName == playerName }) {
                return line.position
            }
        }
        return nil
    }

    private func rosterForTeam(named teamName: String) -> [UserRosterPlayerSummary]? {
        if let direct = teamRostersByName[teamName] {
            return direct
        }
        return teamRostersByName.first(where: {
            $0.key.caseInsensitiveCompare(teamName) == .orderedSame
        })?.value
    }

    private func toggleSort(_ id: String) {
        if sortColumn == id {
            isAscending.toggle()
        } else {
            sortColumn = id
            isAscending = false
        }
    }

    private func compare(_ lhs: PlayerStatsRow, _ rhs: PlayerStatsRow) -> ComparisonResult {
        switch sortColumn {
        case "name":
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name)
        case "games":
            return numeric(lhs.games, rhs.games)
        case "mpg":
            return numeric(lhs.minutesPerGame, rhs.minutesPerGame)
        case "points":
            return numeric(lhs.pointsPerGame, rhs.pointsPerGame)
        case "rebounds":
            return numeric(lhs.reboundsPerGame, rhs.reboundsPerGame)
        case "assists":
            return numeric(lhs.assistsPerGame, rhs.assistsPerGame)
        case "steals":
            return numeric(lhs.stealsPerGame, rhs.stealsPerGame)
        case "blocks":
            return numeric(lhs.blocksPerGame, rhs.blocksPerGame)
        case "turnovers":
            return numeric(lhs.turnoversPerGame, rhs.turnoversPerGame)
        case "fg":
            return numeric(lhs.fgPercentage, rhs.fgPercentage)
        case "three":
            return numeric(lhs.threePercentage, rhs.threePercentage)
        case "ft":
            return numeric(lhs.ftPercentage, rhs.ftPercentage)
        case "efg":
            return numeric(lhs.effectiveFieldGoalPercentage, rhs.effectiveFieldGoalPercentage)
        case "fgm":
            return numeric(lhs.fgMadePerGame, rhs.fgMadePerGame)
        case "fga":
            return numeric(lhs.fgAttemptsPerGame, rhs.fgAttemptsPerGame)
        case "tpm":
            return numeric(lhs.threeMadePerGame, rhs.threeMadePerGame)
        case "tpa":
            return numeric(lhs.threeAttemptsPerGame, rhs.threeAttemptsPerGame)
        case "ftm":
            return numeric(lhs.ftMadePerGame, rhs.ftMadePerGame)
        case "fta":
            return numeric(lhs.ftAttemptsPerGame, rhs.ftAttemptsPerGame)
        default:
            return .orderedSame
        }
    }

    private func numeric(_ lhs: Int, _ rhs: Int) -> ComparisonResult {
        if lhs == rhs { return .orderedSame }
        return lhs < rhs ? .orderedAscending : .orderedDescending
    }

    private func numeric(_ lhs: Double, _ rhs: Double) -> ComparisonResult {
        if lhs == rhs { return .orderedSame }
        return lhs < rhs ? .orderedAscending : .orderedDescending
    }

    private func format(_ value: Double) -> String {
        String(format: "%.1f", value)
    }

    private func formatPercentage(_ value: Double, attempts: Int) -> String {
        guard attempts > 0 else { return "--" }
        return String(format: "%.1f%%", value)
    }
}
