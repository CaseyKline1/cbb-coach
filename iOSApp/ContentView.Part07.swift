import SwiftUI
import UniformTypeIdentifiers
import CBBCoachCore

struct ScheduleListView: View {
    let schedule: [UserGameSummary]
    let userTeamName: String
    let games: [LeagueGameSummary]
    let roster: [UserRosterPlayerSummary]
    let teamRostersByName: [String: [UserRosterPlayerSummary]]

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

    private var columns: [AppTableColumn<String>] {
        [
            .init(id: "site", title: "H/A/N", width: 48),
            .init(id: "opponent", title: "OPPONENT", width: 150, alignment: .leading),
            .init(id: "record", title: "REC", width: 58),
            .init(id: "score", title: "SCORE", width: 78),
            .init(id: "mvp", title: "GAMEMVP", width: 132, alignment: .leading),
            .init(id: "scorer", title: "SCORER", width: 132, alignment: .leading),
            .init(id: "rebounder", title: "REBOUNDER", width: 132, alignment: .leading),
            .init(id: "assister", title: "ASSISTER", width: 132, alignment: .leading),
        ]
    }

    private var tableRows: [(id: AnyHashable, data: ScheduleGameRow)] {
        orderedGames.enumerated().map { index, game in
            (id: AnyHashable(game.gameId ?? "schedule-\(index)"), data: row(for: game))
        }
    }

    var body: some View {
        ScrollView {
            AppTable(columns: columns, rows: tableRows) { row in
                HStack(spacing: 0) {
                    AppTableTextCell(text: row.site, width: 48)
                    AppTableTextCell(text: row.opponent, width: 150, alignment: .leading)
                    AppTableTextCell(text: row.opponentRecord, width: 58)

                    Group {
                        if row.isCompleted, let gameId = row.game.gameId {
                            NavigationLink(value: LeagueMenuDestination.boxScore(gameId)) {
                                AppTableTextCell(text: row.score, width: 78)
                            }
                            .buttonStyle(.plain)
                        } else {
                            AppTableTextCell(text: row.score, width: 78, foreground: .secondary)
                        }
                    }

                    leaderCell(row.gameMVP, width: 132, showValue: false)
                    leaderCell(row.leadingScorer, width: 132)
                    leaderCell(row.leadingRebounder, width: 132)
                    leaderCell(row.leadingAssister, width: 132)
                }
            }
            .padding(16)
        }
        .navigationTitle("Schedule")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func leaderCell(_ leader: ScheduleGameLeader?, width: CGFloat, showValue: Bool = true) -> some View {
        if let leader {
            NavigationLink {
                PlayerCardDetailView(
                    player: resolvedPlayer(teamName: leader.teamName, boxLine: leader.boxLine),
                    games: games,
                    teamName: leader.teamName
                )
            } label: {
                AppTableTextCell(
                    text: showValue ? "\(leader.playerName) \(leader.value)" : leader.playerName,
                    width: width,
                    alignment: .leading,
                    foreground: leader.isUserTeam ? AppTheme.ink : .secondary.opacity(0.65)
                )
            }
            .buttonStyle(.plain)
        } else {
            AppTableTextCell(text: "--", width: width, alignment: .leading, foreground: .secondary)
        }
    }

    private func row(for game: UserGameSummary) -> ScheduleGameRow {
        let leaders = leaders(for: game)
        return ScheduleGameRow(
            game: game,
            site: siteText(for: game),
            opponent: game.opponentName ?? "Unknown",
            opponentRecord: recordText(from: game.opponentRecord),
            score: scoreText(for: game),
            isCompleted: game.completed == true,
            gameMVP: leaders.mvp,
            leadingScorer: leaders.scorer,
            leadingRebounder: leaders.rebounder,
            leadingAssister: leaders.assister
        )
    }

    private func siteText(for game: UserGameSummary) -> String {
        if game.neutralSite == true || game.siteType == "neutral" {
            return "N"
        }
        return game.isHome == true ? "H" : "A"
    }

    private func scoreText(for game: UserGameSummary) -> String {
        guard game.completed == true else { return "--" }
        let home = game.result?.intValue(for: "homeScore") ?? 0
        let away = game.result?.intValue(for: "awayScore") ?? 0
        let userScore = game.isHome == true ? home : away
        let oppScore = game.isHome == true ? away : home
        let marker = userScore > oppScore ? "W" : "L"
        return "\(marker) \(userScore)-\(oppScore)"
    }

    private func recordText(from value: JSONValue?) -> String {
        guard let wins = value?.intValue(for: "wins"),
              let losses = value?.intValue(for: "losses") else {
            return "--"
        }
        return "\(wins)-\(losses)"
    }

    private func leaders(for game: UserGameSummary) -> (
        mvp: ScheduleGameLeader?,
        scorer: ScheduleGameLeader?,
        rebounder: ScheduleGameLeader?,
        assister: ScheduleGameLeader?
    ) {
        let leaders = ParsedTeamBoxScore.parse(from: game.result).flatMap { team in
            team.players.map { boxLine in
                ScheduleGameLeader(
                    playerName: boxLine.playerName,
                    teamName: team.name,
                    value: 0,
                    isUserTeam: team.name.caseInsensitiveCompare(userTeamName) == .orderedSame,
                    boxLine: boxLine
                )
            }
        }

        return (
            topLeader(leaders, value: mvpValue),
            topLeader(leaders, value: { $0.boxLine.points }),
            topLeader(leaders, value: { $0.boxLine.rebounds }),
            topLeader(leaders, value: { $0.boxLine.assists })
        )
    }

    private func topLeader(
        _ leaders: [ScheduleGameLeader],
        value: (ScheduleGameLeader) -> Int
    ) -> ScheduleGameLeader? {
        leaders
            .map { leader -> ScheduleGameLeader in
                var updated = leader
                updated.value = value(leader)
                return updated
            }
            .max { lhs, rhs in
                if lhs.value != rhs.value { return lhs.value < rhs.value }
                return lhs.playerName.localizedCaseInsensitiveCompare(rhs.playerName) == .orderedDescending
            }
    }

    private func mvpValue(_ leader: ScheduleGameLeader) -> Int {
        let line = leader.boxLine
        return line.points
            + Int((Double(line.rebounds) * 1.2).rounded())
            + Int((Double(line.assists) * 1.5).rounded())
            + (line.steals * 2)
            + (line.blocks * 2)
            - line.turnovers
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

private struct ScheduleGameRow {
    let game: UserGameSummary
    let site: String
    let opponent: String
    let opponentRecord: String
    let score: String
    let isCompleted: Bool
    let gameMVP: ScheduleGameLeader?
    let leadingScorer: ScheduleGameLeader?
    let leadingRebounder: ScheduleGameLeader?
    let leadingAssister: ScheduleGameLeader?
}

private struct ScheduleGameLeader {
    let playerName: String
    let teamName: String
    var value: Int
    let isUserTeam: Bool
    let boxLine: ParsedPlayerBoxScore
}

private enum BoxScoreTableRow {
    case player(ParsedPlayerBoxScore)
    case team(ParsedTeamBoxScore)
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
        var tableRows: [(id: AnyHashable, data: BoxScoreTableRow)] = Array(team.players.enumerated()).map {
            (id: AnyHashable("player-\($0.offset)-\($0.element.playerName)"), data: .player($0.element))
        }
        tableRows.append((id: AnyHashable("team-\(team.name)"), data: .team(team)))

        return GameCard {
            GameSectionHeader(title: team.name)
            AppTable(columns: columns, rows: tableRows) { row in
                HStack(spacing: 0) {
                    switch row {
                    case .player(let player):
                        playerNameCell(player, teamName: team.name)
                        boxScoreStatCells(
                            minutes: Int(player.minutes.rounded()),
                            points: player.points,
                            rebounds: player.rebounds,
                            assists: player.assists,
                            steals: player.steals,
                            blocks: player.blocks,
                            turnovers: player.turnovers,
                            fg: "\(player.fgMade)-\(player.fgAttempts)",
                            three: "\(player.threeMade)-\(player.threeAttempts)",
                            ft: "\(player.ftMade)-\(player.ftAttempts)",
                            plusMinus: formatPlusMinus(player.plusMinus),
                            fouls: player.fouls
                        )
                    case .team(let team):
                        AppTableTextCell(text: "TEAM", width: 130, alignment: .leading, font: .caption.monospacedDigit().weight(.semibold))
                        boxScoreStatCells(
                            minutes: team.minutes,
                            points: team.points,
                            rebounds: team.rebounds,
                            assists: team.assists,
                            steals: team.steals,
                            blocks: team.blocks,
                            turnovers: team.turnovers,
                            fg: "\(team.fgMade)-\(team.fgAttempts)",
                            three: "\(team.threeMade)-\(team.threeAttempts)",
                            ft: "\(team.ftMade)-\(team.ftAttempts)",
                            plusMinus: team.plusMinus.map(formatPlusMinus) ?? "-",
                            fouls: team.fouls,
                            font: .caption.monospacedDigit().weight(.semibold)
                        )
                    }
                }
            }
        }
    }

    private func playerNameCell(_ player: ParsedPlayerBoxScore, teamName: String) -> some View {
        HStack(spacing: 0) {
            NavigationLink {
                PlayerCardDetailView(
                    player: resolvedPlayer(teamName: teamName, boxLine: player),
                    games: games,
                    teamName: teamName
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
    }

    private func boxScoreStatCells(
        minutes: Int,
        points: Int,
        rebounds: Int,
        assists: Int,
        steals: Int,
        blocks: Int,
        turnovers: Int,
        fg: String,
        three: String,
        ft: String,
        plusMinus: String,
        fouls: Int,
        font: Font = .caption.monospacedDigit()
    ) -> some View {
        Group {
            AppTableTextCell(text: "\(minutes)", width: 40, font: font)
            AppTableTextCell(text: "\(points)", width: 38, font: font)
            AppTableTextCell(text: "\(rebounds)", width: 38, font: font)
            AppTableTextCell(text: "\(assists)", width: 38, font: font)
            AppTableTextCell(text: "\(steals)", width: 38, font: font)
            AppTableTextCell(text: "\(blocks)", width: 38, font: font)
            AppTableTextCell(text: "\(turnovers)", width: 38, font: font)
            AppTableTextCell(text: fg, width: 56, font: font)
            AppTableTextCell(text: three, width: 56, font: font)
            AppTableTextCell(text: ft, width: 56, font: font)
            AppTableTextCell(text: plusMinus, width: 40, font: font)
            AppTableTextCell(text: "\(fouls)", width: 38, font: font)
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
