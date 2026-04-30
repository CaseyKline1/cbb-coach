import SwiftUI
import UniformTypeIdentifiers
import CBBCoachCore

struct NationalBracketView: View {
    let bracket: NationalTournamentBracket?
    let userTeamId: String?

    private let roundTitles = ["Round of 64", "Round of 32", "Sweet 16", "Elite 8", "Final Four", "Title"]
    private let columnWidth: CGFloat = 184
    private let gameHeight: CGFloat = 74

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            if let bracket {
                ScrollView([.horizontal, .vertical], showsIndicators: true) {
                    HStack(alignment: .top, spacing: 28) {
                        ForEach(Array(bracket.rounds.enumerated()), id: \.offset) { roundIndex, games in
                            VStack(alignment: .leading, spacing: 10) {
                                Text(roundTitles[safe: roundIndex] ?? "Round \(roundIndex + 1)")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.secondary)
                                    .frame(width: columnWidth, alignment: .leading)

                                VStack(spacing: verticalSpacing(for: roundIndex)) {
                                    ForEach(games) { game in
                                        BracketGameCard(
                                            game: game,
                                            userTeamId: userTeamId,
                                            height: gameHeight
                                        )
                                        .frame(width: columnWidth, height: gameHeight)
                                    }
                                }
                                .padding(.top, topInset(for: roundIndex))
                            }
                        }
                    }
                    .padding(16)
                    .frame(minWidth: 1320, minHeight: 1200, alignment: .topLeading)
                }
            } else {
                VStack(spacing: 10) {
                    Text("Bracket")
                        .font(.title2.weight(.black))
                    Text("The national tournament field appears after conference tournaments finish.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
            }
        }
        .navigationTitle("Bracket")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func verticalSpacing(for roundIndex: Int) -> CGFloat {
        switch roundIndex {
        case 0: 10
        case 1: 94
        case 2: 262
        case 3: 598
        case 4: 1270
        default: 0
        }
    }

    private func topInset(for roundIndex: Int) -> CGFloat {
        switch roundIndex {
        case 0: 0
        case 1: 42
        case 2: 126
        case 3: 294
        case 4: 630
        default: 1302
        }
    }
}

private struct BracketGameCard: View {
    let game: NationalTournamentGame
    let userTeamId: String?
    let height: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            teamRow(game.topTeam)
            Divider()
            teamRow(game.bottomTeam)
        }
        .frame(height: height)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(AppTheme.cardBorder, lineWidth: 1)
        )
    }

    private func teamRow(_ team: NationalTournamentTeam?) -> some View {
        let isWinner = team?.teamId == game.winnerTeamId
        let isUser = team?.teamId == userTeamId

        return HStack(spacing: 8) {
            Text(team.map { "\($0.seedLine)" } ?? "-")
                .font(.caption2.monospacedDigit().weight(.black))
                .foregroundStyle(isWinner ? .white : (isUser ? AppTheme.accent : .secondary))
                .frame(width: 22, height: 22)
                .background(isWinner ? AppTheme.success : Color(UIColor.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))

            Text(team?.teamName ?? "TBD")
                .font(.caption.weight(isUser || isWinner ? .bold : .semibold))
                .foregroundStyle(isWinner ? AppTheme.success : (isUser ? AppTheme.accent : AppTheme.ink))
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Spacer(minLength: 4)

            if team?.automaticBid == true {
                Text("AQ")
                    .font(.caption2.weight(.black))
                    .foregroundStyle(AppTheme.warning)
            }
        }
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(isUser ? AppTheme.accent.opacity(0.08) : .clear)
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

struct RankingsView: View {
    let rankings: LeagueRankings?
    let userTeamId: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if let rankings {
                    GameCard {
                        VStack(spacing: 0) {
                            HStack(spacing: 0) {
                                AppTableTextCell(text: "RANK", width: 54, font: .caption2.weight(.bold), foreground: .secondary)
                                AppTableTextCell(text: "TEAM", width: 152, alignment: .leading, font: .caption2.weight(.bold), foreground: .secondary)
                                AppTableTextCell(text: "REC", width: 58, font: .caption2.weight(.bold), foreground: .secondary)
                                AppTableTextCell(text: "NET", width: 56, font: .caption2.weight(.bold), foreground: .secondary)
                                AppTableTextCell(text: "SOS", width: 56, font: .caption2.weight(.bold), foreground: .secondary)
                            }
                            .padding(.vertical, 6)
                            .background(AppTheme.cardBackground)
                            Divider()

                            ForEach(Array(rankings.rankings.enumerated()), id: \.element.id) { index, team in
                                HStack(spacing: 0) {
                                    AppTableTextCell(
                                        text: "#\(team.rank)",
                                        width: 54,
                                        font: .caption.monospacedDigit().weight(.semibold),
                                        foreground: team.teamId == userTeamId ? AppTheme.accent : .primary
                                    )
                                    AppTableTextCell(
                                        text: team.teamName,
                                        width: 152,
                                        alignment: .leading,
                                        font: .caption.weight(team.teamId == userTeamId ? .bold : .semibold),
                                        foreground: team.teamId == userTeamId ? AppTheme.accent : .primary
                                    )
                                    AppTableTextCell(
                                        text: team.record,
                                        width: 58,
                                        font: .caption.monospacedDigit().weight(.medium)
                                    )
                                    AppTableTextCell(
                                        text: String(format: "%.1f", team.pointDifferentialPerGame),
                                        width: 56,
                                        font: .caption.monospacedDigit().weight(.medium)
                                    )
                                    AppTableTextCell(
                                        text: String(format: "%.3f", team.strengthOfSchedule),
                                        width: 56,
                                        font: .caption.monospacedDigit().weight(.medium)
                                    )
                                }
                                .padding(.vertical, 6)
                                .background(team.teamId == userTeamId ? AppTheme.accent.opacity(0.08) : .clear)
                                if index < rankings.rankings.count - 1 {
                                    Divider()
                                }
                            }
                        }
                    }
                } else {
                    Text("Rankings unavailable.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(16)
        }
        .navigationTitle("Rankings")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct SeasonRecapView: View {
    let games: [LeagueGameSummary]
    let schedule: [UserGameSummary]
    let userTeamId: String?
    let userTeamName: String
    let userConferenceId: String?
    let standingsByConference: [String: [ConferenceStanding]]
    let conferenceNamesById: [String: String]
    let bracket: NationalTournamentBracket?
    let nilBudgetSummary: NILBudgetSummary?
    let playersLeavingSummary: PlayersLeavingSummary?
    let roster: [UserRosterPlayerSummary]
    let teamRostersByName: [String: [UserRosterPlayerSummary]]

    private enum RecapTab: String, CaseIterable {
        case team = "Team"
        case nationalAwards = "Awards"
        case allAmericans = "All-Americans"
        case allConference = "All-Conference"
    }

    @State private var tab: RecapTab = .team
    @State private var selectedConferenceId: String

    init(
        games: [LeagueGameSummary],
        schedule: [UserGameSummary],
        userTeamId: String?,
        userTeamName: String,
        userConferenceId: String?,
        standingsByConference: [String: [ConferenceStanding]],
        conferenceNamesById: [String: String],
        bracket: NationalTournamentBracket?,
        nilBudgetSummary: NILBudgetSummary?,
        playersLeavingSummary: PlayersLeavingSummary?,
        roster: [UserRosterPlayerSummary],
        teamRostersByName: [String: [UserRosterPlayerSummary]]
    ) {
        self.games = games
        self.schedule = schedule
        self.userTeamId = userTeamId
        self.userTeamName = userTeamName
        self.userConferenceId = userConferenceId
        self.standingsByConference = standingsByConference
        self.conferenceNamesById = conferenceNamesById
        self.bracket = bracket
        self.nilBudgetSummary = nilBudgetSummary
        self.playersLeavingSummary = playersLeavingSummary
        self.roster = roster
        self.teamRostersByName = teamRostersByName
        _selectedConferenceId = State(initialValue: userConferenceId ?? standingsByConference.keys.sorted().first ?? "")
    }

    private var playerStats: [SeasonPlayerStat] {
        SeasonPlayerStat.build(from: games, conferenceIdByTeamId: conferenceIdByTeamId, teamRostersByName: teamRostersByName)
    }

    private var conferenceIdByTeamId: [String: String] {
        var result: [String: String] = [:]
        for rows in standingsByConference.values {
            for row in rows {
                result[row.teamId] = row.conferenceId
            }
        }
        return result
    }

    private var userStats: [SeasonPlayerStat] {
        playerStats
            .filter { $0.teamName.caseInsensitiveCompare(userTeamName) == .orderedSame }
            .sorted { lhs, rhs in
                if lhs.pointsPerGame != rhs.pointsPerGame { return lhs.pointsPerGame > rhs.pointsPerGame }
                return lhs.playerName.localizedCaseInsensitiveCompare(rhs.playerName) == .orderedAscending
            }
    }

    private var eligibleStats: [SeasonPlayerStat] {
        playerStats
            .filter { $0.games >= 8 && $0.minutesPerGame >= 12 }
            .sorted { lhs, rhs in
                if lhs.awardScore != rhs.awardScore { return lhs.awardScore > rhs.awardScore }
                return lhs.playerName.localizedCaseInsensitiveCompare(rhs.playerName) == .orderedAscending
            }
    }

    private var awardRows: [(title: String, stat: SeasonPlayerStat?)] {
        [
            ("NPOY", eligibleStats.first),
            ("Freshman of the Year", eligibleStats.first { $0.year.uppercased() == "FR" }),
            ("Best PG", bestPlayer(for: "PG")),
            ("Best SG", bestPlayer(for: "SG")),
            ("Best SF", bestPlayer(for: "SF")),
            ("Best PF", bestPlayer(for: "PF")),
            ("Best C", bestPlayer(for: "C")),
        ]
    }

    private var allAmericans: [(team: String, players: [SeasonPlayerStat])] {
        let top = Array(eligibleStats.prefix(15))
        return [
            ("First Team", Array(top.prefix(5))),
            ("Second Team", Array(top.dropFirst(5).prefix(5))),
            ("Third Team", Array(top.dropFirst(10).prefix(5))),
        ]
    }

    private var selectedAllConference: [SeasonPlayerStat] {
        eligibleStats
            .filter { $0.conferenceId == selectedConferenceId }
            .prefix(15)
            .map { $0 }
    }

    private var userAwardLines: [String] {
        let national = awardRows.compactMap { title, stat in
            stat?.teamName.caseInsensitiveCompare(userTeamName) == .orderedSame ? "\(stat?.playerName ?? ""): \(title)" : nil
        }
        let americans = allAmericans.flatMap { team, players in
            players.filter { $0.teamName.caseInsensitiveCompare(userTeamName) == .orderedSame }
                .map { "\($0.playerName): \(team) All-American" }
        }
        let conference = eligibleStats
            .filter { $0.teamName.caseInsensitiveCompare(userTeamName) == .orderedSame && $0.conferenceId == userConferenceId }
            .prefix(15)
            .map { "\($0.playerName): All-\(conferenceTitle($0.conferenceId ?? userConferenceId ?? ""))" }
        return national + americans + conference
    }

    private var userStanding: ConferenceStanding? {
        guard let userTeamId else { return nil }
        return standingsByConference.values.flatMap { $0 }.first { $0.teamId == userTeamId }
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Recap", selection: $tab) {
                ForEach(RecapTab.allCases, id: \.self) { item in
                    Text(item.rawValue).tag(item)
                }
            }
            .pickerStyle(.segmented)
            .padding([.horizontal, .top], 16)
            .padding(.bottom, 8)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    switch tab {
                    case .team:
                        teamTab
                    case .nationalAwards:
                        awardsTab
                    case .allAmericans:
                        allAmericansTab
                    case .allConference:
                        allConferenceTab
                    }

                    NavigationLink {
                        OffseasonScheduleView(nilBudgetSummary: nilBudgetSummary, playersLeavingSummary: playersLeavingSummary)
                    } label: {
                        Text("Offseason Schedule")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(GameButtonStyle(variant: .primary))
                    .padding(.top, 4)
                }
                .padding(16)
            }
        }
        .background(AppTheme.background)
        .navigationTitle("Season Recap")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var teamTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            GameCard {
                VStack(alignment: .leading, spacing: 8) {
                    GameSectionHeader(title: userTeamName)
                    HStack(spacing: 8) {
                        StatChip(title: "RECORD", value: userStanding.map { "\($0.wins)-\($0.losses)" } ?? "--")
                        StatChip(title: "CONF", value: userStanding.map { "\($0.conferenceWins)-\($0.conferenceLosses)" } ?? "--")
                        StatChip(title: "POST", value: postseasonText)
                    }
                }
            }

            GameCard {
                GameSectionHeader(title: "Player Awards")
                if userAwardLines.isEmpty {
                    Text("No award winners this season.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(userAwardLines, id: \.self) { line in
                            Text(line)
                                .font(.subheadline.weight(.semibold))
                        }
                    }
                }
            }

            playerTable(title: "Final Player Stats", stats: userStats)
        }
    }

    private var awardsTab: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(awardRows, id: \.title) { row in
                if let stat = row.stat {
                    awardRow(title: row.title, stat: stat)
                }
            }
        }
    }

    private var allAmericansTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(allAmericans, id: \.team) { section in
                playerListCard(title: section.team, stats: section.players)
            }
        }
    }

    private var allConferenceTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            Picker("Conference", selection: $selectedConferenceId) {
                ForEach(standingsByConference.keys.sorted { conferenceTitle($0) < conferenceTitle($1) }, id: \.self) { id in
                    Text(conferenceTitle(id)).tag(id)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, alignment: .leading)

            playerListCard(title: "All-\(conferenceTitle(selectedConferenceId))", stats: selectedAllConference)
        }
    }

    private func playerTable(title: String, stats: [SeasonPlayerStat]) -> some View {
        let columns: [AppTableColumn<String>] = [
            .init(id: "name", title: "", width: 166, alignment: .leading),
            .init(id: "g", title: "G", width: 36),
            .init(id: "pts", title: "PTS", width: 48),
            .init(id: "reb", title: "REB", width: 48),
            .init(id: "ast", title: "AST", width: 48),
            .init(id: "efg", title: "EFG", width: 56),
            .init(id: "a/to", title: "A:TO", width: 54),
        ]
        return GameCard {
            GameSectionHeader(title: title)
            AppTable(columns: columns, rows: stats.map { (id: AnyHashable($0.id), data: $0) }) { stat in
                HStack(spacing: 0) {
                    NavigationLink {
                        playerCard(for: stat)
                    } label: {
                        AppTableTextCell(text: stat.playerName, width: 166, alignment: .leading, foreground: AppTheme.accent)
                    }
                    .buttonStyle(.plain)
                    AppTableTextCell(text: "\(stat.games)", width: 36)
                    AppTableTextCell(text: format(stat.pointsPerGame), width: 48)
                    AppTableTextCell(text: format(stat.reboundsPerGame), width: 48)
                    AppTableTextCell(text: format(stat.assistsPerGame), width: 48)
                    AppTableTextCell(text: pct(stat.effectiveFieldGoalPercentage), width: 56)
                    AppTableTextCell(text: format(stat.assistTurnoverRatio), width: 54)
                }
            }
        }
    }

    private func playerListCard(title: String, stats: [SeasonPlayerStat]) -> some View {
        GameCard {
            GameSectionHeader(title: title)
            if stats.isEmpty {
                Text("No qualified players.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 10) {
                    ForEach(Array(stats.enumerated()), id: \.element.id) { index, stat in
                        HStack(spacing: 10) {
                            Text("\(index + 1)")
                                .font(.callout.weight(.black))
                                .foregroundStyle(index < 5 ? AppTheme.accent : .secondary)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                NavigationLink {
                                    playerCard(for: stat)
                                } label: {
                                    Text(stat.playerName)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(AppTheme.accent)
                                }
                                .buttonStyle(.plain)
                                Text("\(stat.position) • \(stat.teamName)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(format(stat.awardScore))
                                .font(.callout.monospacedDigit().weight(.bold))
                        }
                    }
                }
            }
        }
    }

    private func awardRow(title: String, stat: SeasonPlayerStat) -> some View {
        GameCard {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                    NavigationLink {
                        playerCard(for: stat)
                    } label: {
                        Text(stat.playerName)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(AppTheme.accent)
                    }
                    .buttonStyle(.plain)
                    Text("\(stat.position) • \(stat.teamName) • \(format(stat.pointsPerGame)) PPG, \(format(stat.reboundsPerGame)) RPG, \(format(stat.assistsPerGame)) APG")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(format(stat.awardScore))
                    .font(.title3.monospacedDigit().bold())
                    .foregroundStyle(AppTheme.ink)
            }
        }
    }

    private var postseasonText: String {
        guard let userTeamId else { return "None" }
        if let champ = bracket?.rounds.last?.first?.winnerTeamId, champ == userTeamId {
            return "Champion"
        }
        let completedUserNationalWins = games.filter { game in
            game.type == "national_tournament"
                && game.result?.objectDictionary?["winnerTeamId"]?.stringValue == userTeamId
        }.count
        if completedUserNationalWins > 0 {
            let labels = ["R32", "Sweet 16", "Elite 8", "Final 4", "Title Game", "Champion"]
            return labels[safe: min(completedUserNationalWins - 1, labels.count - 1)] ?? "Tournament"
        }
        if bracket?.teams.contains(where: { $0.teamId == userTeamId }) == true {
            return "Tournament"
        }
        return "None"
    }

    private func bestPlayer(for position: String) -> SeasonPlayerStat? {
        eligibleStats.first { $0.normalizedPosition == position }
    }

    private func playerCard(for stat: SeasonPlayerStat) -> PlayerCardDetailView {
        PlayerCardDetailView(player: playerProfile(for: stat), games: games, teamName: stat.teamName)
    }

    private func playerProfile(for stat: SeasonPlayerStat) -> UserRosterPlayerSummary {
        let matches = rosterForTeam(named: stat.teamName)?.filter { $0.name == stat.playerName } ?? []
        if matches.count == 1 { return matches[0] }
        if let positional = matches.first(where: { normalizePosition($0.position) == stat.normalizedPosition }) {
            return positional
        }
        if stat.teamName.caseInsensitiveCompare(userTeamName) == .orderedSame,
           let userMatch = roster.first(where: { $0.name == stat.playerName }) {
            return userMatch
        }
        return UserRosterPlayerSummary(
            playerIndex: -1,
            name: stat.playerName,
            position: stat.position,
            year: stat.year.isEmpty ? "N/A" : stat.year,
            home: nil,
            height: nil,
            weight: nil,
            wingspan: nil,
            overall: 0,
            isStarter: false,
            attributes: nil
        )
    }

    private func rosterForTeam(named teamName: String) -> [UserRosterPlayerSummary]? {
        if let direct = teamRostersByName[teamName] { return direct }
        return teamRostersByName.first { $0.key.caseInsensitiveCompare(teamName) == .orderedSame }?.value
    }

    private func conferenceTitle(_ id: String) -> String {
        conferenceNamesById[id] ?? id.split(separator: "-").map { String($0).capitalized }.joined(separator: " ")
    }

    private func format(_ value: Double) -> String {
        String(format: "%.1f", value)
    }

    private func pct(_ value: Double) -> String {
        guard value > 0 else { return "--" }
        return String(format: "%.1f%%", value)
    }
}

struct OffseasonSchedulePhase: Identifiable, Hashable {
    enum Status: String {
        case completed = "Completed"
        case current = "Current"
        case upcoming = "Upcoming"
    }

    let id: String
    let title: String
    let detail: String
    let status: Status

    static let initialPhases: [OffseasonSchedulePhase] = [
        OffseasonSchedulePhase(
            id: "season-recap",
            title: "Season Recap",
            detail: "Review final results, awards, standings, and team stats.",
            status: .completed
        ),
        OffseasonSchedulePhase(
            id: "nil-budgets",
            title: "NIL Budgets",
            detail: "Reveal next season's revenue sharing and donor pool.",
            status: .completed
        ),
        OffseasonSchedulePhase(
            id: "players-leaving",
            title: "Players Leaving",
            detail: "Seniors graduate and transfer risks decide whether to move on.",
            status: .current
        ),
    ]
}

struct OffseasonScheduleView: View {
    let nilBudgetSummary: NILBudgetSummary?
    let playersLeavingSummary: PlayersLeavingSummary?

    private let phases = OffseasonSchedulePhase.initialPhases

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                GameCard {
                    VStack(alignment: .leading, spacing: 8) {
                        GameSectionHeader(title: "Offseason")
                        Text("Each offseason phase will appear here as it is added.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                ForEach(Array(phases.enumerated()), id: \.element.id) { index, phase in
                    if phase.id == "nil-budgets" {
                        NavigationLink {
                            NILBudgetView(summary: nilBudgetSummary)
                        } label: {
                            offseasonPhaseRow(phase, number: index + 1)
                        }
                        .buttonStyle(.plain)
                    } else if phase.id == "players-leaving" {
                        NavigationLink {
                            PlayersLeavingView(summary: playersLeavingSummary)
                        } label: {
                            offseasonPhaseRow(phase, number: index + 1)
                        }
                        .buttonStyle(.plain)
                    } else {
                        offseasonPhaseRow(phase, number: index + 1)
                    }
                }
            }
            .padding(16)
        }
        .background(AppTheme.background)
        .navigationTitle("Offseason Schedule")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func offseasonPhaseRow(_ phase: OffseasonSchedulePhase, number: Int) -> some View {
        GameCard {
            HStack(alignment: .top, spacing: 12) {
                Text("\(number)")
                    .font(.caption.monospacedDigit().weight(.black))
                    .foregroundStyle(phase.status == .current ? .white : AppTheme.accent)
                    .frame(width: 28, height: 28)
                    .background(phase.status == .current ? AppTheme.accent : AppTheme.accent.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(phase.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.ink)

                        Spacer(minLength: 8)

                        GamePill(text: phase.status.rawValue, color: statusColor(phase.status))
                    }

                    HStack(spacing: 8) {
                        Text(phase.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 8)
                        if phase.id == "nil-budgets" || phase.id == "players-leaving" {
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private func statusColor(_ status: OffseasonSchedulePhase.Status) -> Color {
        switch status {
        case .completed: return AppTheme.success
        case .current: return AppTheme.accent
        case .upcoming: return .secondary
        }
    }
}

struct NILBudgetView: View {
    let summary: NILBudgetSummary?

    private var userBudget: NILBudgetTeamSummary? {
        summary?.userTeam
    }

    private var topBudgets: [NILBudgetTeamSummary] {
        Array((summary?.teams ?? []).prefix(8))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if let budget = userBudget {
                    teamHeaderCard(budget)
                    budgetBreakdownCard(budget)
                    factorsCard(budget)
                    leagueContextCard(budget)
                    topBudgetsCard
                } else {
                    GameCard {
                        VStack(alignment: .leading, spacing: 8) {
                            GameSectionHeader(title: "NIL Budgets")
                            Text("Budget data is not available for this league yet.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(AppTheme.background)
        .navigationTitle("NIL Budgets")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func teamHeaderCard(_ budget: NILBudgetTeamSummary) -> some View {
        GameCard {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(budget.teamName)
                        .font(.headline.weight(.black))
                        .foregroundStyle(AppTheme.ink)
                    GameBadge(text: budget.conferenceName, color: AppTheme.accent)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(moneyText(budget.total))
                        .font(.title2.monospacedDigit().weight(.black))
                        .foregroundStyle(budget.total > 0 ? AppTheme.accent : AppTheme.warning)
                    Text("available")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func budgetBreakdownCard(_ budget: NILBudgetTeamSummary) -> some View {
        GameCard {
            VStack(alignment: .leading, spacing: 0) {
                GameSectionHeader(title: "Budget Breakdown")
                budgetRow(label: "Revenue Sharing", note: revenueSharingNote(for: budget), amount: budget.revenueSharing)
                Divider().padding(.vertical, 8)
                budgetRow(label: "Donations", note: "Prestige, fundraising, winning, postseason results, and awards", amount: budget.donations)
                Divider().padding(.vertical, 8)
                HStack(alignment: .firstTextBaseline) {
                    Text("Total NIL Budget")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(AppTheme.ink)
                    Spacer()
                    Text(moneyText(budget.total))
                        .font(.title3.monospacedDigit().weight(.black))
                        .foregroundStyle(AppTheme.accent)
                }
            }
        }
    }

    private func factorsCard(_ budget: NILBudgetTeamSummary) -> some View {
        GameCard {
            VStack(alignment: .leading, spacing: 10) {
                GameSectionHeader(title: "Donation Drivers")
                HStack(spacing: 8) {
                    factorChip(title: "PRESTIGE", value: percentText(budget.prestigeScore))
                    factorChip(title: "FUND", value: percentText(budget.fundraisingScore))
                    factorChip(title: "SUCCESS", value: scoreText(budget.successScore))
                    factorChip(title: "AWARDS", value: scoreText(budget.awardScore))
                }
            }
        }
    }

    private func leagueContextCard(_ budget: NILBudgetTeamSummary) -> some View {
        GameCard {
            VStack(alignment: .leading, spacing: 0) {
                GameSectionHeader(title: "League Context")
                contextRow(label: "\(budget.conferenceName) Average", amount: summary?.conferenceAverage ?? 0)
                Divider().padding(.vertical, 8)
                contextRow(label: "National Average", amount: summary?.nationalAverage ?? 0)
            }
        }
    }

    private var topBudgetsCard: some View {
        GameCard {
            VStack(alignment: .leading, spacing: 10) {
                GameSectionHeader(title: "Top NIL Budgets")
                ForEach(Array(topBudgets.enumerated()), id: \.element.teamId) { index, team in
                    HStack(spacing: 10) {
                        Text("\(index + 1)")
                            .font(.caption.monospacedDigit().weight(.black))
                            .foregroundStyle(team.teamId == summary?.userTeamId ? .white : AppTheme.accent)
                            .frame(width: 24, height: 24)
                            .background(team.teamId == summary?.userTeamId ? AppTheme.accent : AppTheme.accent.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(team.teamName)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(team.teamId == summary?.userTeamId ? AppTheme.accent : AppTheme.ink)
                            Text(team.conferenceName)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(moneyText(team.total))
                            .font(.subheadline.monospacedDigit().weight(.bold))
                    }
                }
            }
        }
    }

    private func budgetRow(label: String, note: String, amount: Double) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.ink)
                Text(note)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Text(moneyText(amount))
                .font(.subheadline.monospacedDigit().weight(.bold))
                .foregroundStyle(AppTheme.ink)
        }
    }

    private func contextRow(label: String, amount: Double) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(moneyText(amount))
                .font(.subheadline.monospacedDigit().weight(.bold))
                .foregroundStyle(AppTheme.ink)
        }
    }

    private func factorChip(title: String, value: String) -> some View {
        VStack(spacing: 3) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.monospacedDigit().weight(.black))
                .foregroundStyle(AppTheme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func revenueSharingNote(for budget: NILBudgetTeamSummary) -> String {
        if budget.serviceAcademy { return "Service academies do not use NIL budgets" }
        if budget.teamName.caseInsensitiveCompare("UConn") == .orderedSame { return "UConn basketball premium" }
        switch budget.conferenceId {
        case "acc", "big-ten", "big-12":
            return "\(budget.conferenceName) revenue sharing"
        case "sec":
            return "SEC revenue sharing"
        default:
            return "Baseline D-I revenue sharing"
        }
    }

    private func moneyText(_ amount: Double) -> String {
        if amount >= 1_000_000 {
            return "$\(String(format: "%.1f", amount / 1_000_000))M"
        }
        return "$\(Int(amount / 1_000).formatted())K"
    }

    private func percentText(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))"
    }

    private func scoreText(_ value: Double) -> String {
        String(format: "%.1f", value)
    }
}

struct PlayersLeavingView: View {
    let summary: PlayersLeavingSummary?

    private var userRows: [PlayerLeavingEntry] {
        summary?.userEntries ?? []
    }

    private var transferRows: [PlayerLeavingEntry] {
        userRows.filter { $0.outcome == .transfer }
    }

    private var graduationRows: [PlayerLeavingEntry] {
        userRows.filter { $0.outcome == .graduated }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                GameCard {
                    VStack(alignment: .leading, spacing: 10) {
                        GameSectionHeader(title: "Players Leaving")
                        HStack(spacing: 8) {
                            summaryTile(title: "Graduating", value: "\(graduationRows.count)")
                            summaryTile(title: "Transfers", value: "\(transferRows.count)")
                        }
                    }
                }

                leavingSection(title: "Graduating Seniors", rows: graduationRows, emptyText: "No seniors are graduating this offseason.")
                leavingSection(title: "Transfer Decisions", rows: transferRows, emptyText: "No returners decided to transfer.")
            }
            .padding(16)
        }
        .background(AppTheme.background)
        .navigationTitle("Players Leaving")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func leavingSection(title: String, rows: [PlayerLeavingEntry], emptyText: String) -> some View {
        GameCard {
            VStack(alignment: .leading, spacing: 10) {
                GameSectionHeader(title: title)
                if rows.isEmpty {
                    Text(emptyText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    VStack(spacing: 0) {
                        ForEach(rows) { row in
                            leavingRow(row)
                            if row.id != rows.last?.id {
                                Divider()
                            }
                        }
                    }
                }
            }
        }
    }

    private func leavingRow(_ row: PlayerLeavingEntry) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(row.playerName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.ink)
                    Text("\(row.year) \(row.position) | OVR \(row.overall) | POT \(row.potential)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                GamePill(text: row.outcome.rawValue, color: row.outcome == .graduated ? .secondary : AppTheme.warning)
            }

            Text(row.reason)
                .font(.caption)
                .foregroundStyle(.secondary)

            if row.outcome == .transfer {
                HStack(spacing: 8) {
                    metricChip(title: "MIN", value: percentText(row.minutesShare))
                    metricChip(title: "EXP", value: percentText(row.expectedMinutesShare))
                    metricChip(title: "Risk", value: percentText(row.transferRisk))
                    metricChip(title: "Loy", value: "\(Int(row.loyalty.rounded()))")
                    metricChip(title: "Greed", value: "\(Int(row.greed.rounded()))")
                }
            }
        }
        .padding(.vertical, 10)
    }

    private func summaryTile(title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.monospacedDigit().weight(.black))
                .foregroundStyle(AppTheme.ink)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func metricChip(title: String, value: String) -> some View {
        VStack(spacing: 3) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.monospacedDigit().weight(.black))
                .foregroundStyle(AppTheme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 7)
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func percentText(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }
}

private struct SeasonPlayerStat: Hashable {
    let playerName: String
    let teamId: String
    let teamName: String
    let conferenceId: String?
    let position: String
    let year: String
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
    var ftMade: Int = 0
    var ftAttempts: Int = 0

    var id: String { "\(teamName)|\(playerName)|\(position)" }
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
    var trueShootingPercentage: Double {
        let attempts = 2 * (Double(fgAttempts) + 0.44 * Double(ftAttempts))
        guard attempts > 0 else { return 0 }
        return (Double(points) / attempts) * 100
    }
    var assistTurnoverRatio: Double {
        Double(assists) / Double(max(1, turnovers))
    }
    var normalizedPosition: String { normalizePosition(position) }
    var awardScore: Double {
        pointsPerGame
        + reboundsPerGame * 1.15
        + assistsPerGame * 1.45
        + stealsPerGame * 2.2
        + blocksPerGame * 2.0
        + effectiveFieldGoalPercentage * 0.08
        + trueShootingPercentage * 0.06
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

    static func build(
        from games: [LeagueGameSummary],
        conferenceIdByTeamId: [String: String],
        teamRostersByName: [String: [UserRosterPlayerSummary]]
    ) -> [SeasonPlayerStat] {
        struct Key: Hashable {
            let playerName: String
            let teamName: String
            let position: String
        }

        var rosterByTeamName: [String: [UserRosterPlayerSummary]] = [:]
        for (teamName, roster) in teamRostersByName {
            rosterByTeamName[teamName.lowercased()] = rosterByTeamName[teamName.lowercased()] ?? roster
        }
        var totals: [Key: SeasonPlayerStat] = [:]

        for game in games where game.completed == true {
            guard
                let resultObject = game.result?.objectDictionary,
                let boxArray = resultObject["boxScore"]?.arrayValues
            else { continue }

            for (index, boxValue) in boxArray.enumerated() {
                guard let teamObject = boxValue.objectDictionary else { continue }
                let teamName = index == 0 ? (game.homeTeamName ?? teamObject["name"]?.stringValue ?? "Team") : (game.awayTeamName ?? teamObject["name"]?.stringValue ?? "Team")
                let teamId = index == 0 ? (game.homeTeamId ?? teamName) : (game.awayTeamId ?? teamName)
                let players = teamObject["players"]?.arrayValues ?? []
                let roster = rosterByTeamName[teamName.lowercased()] ?? []

                for player in players {
                    guard let parsed = ParsedPlayerBoxScore(value: player) else { continue }
                    let key = Key(playerName: parsed.playerName, teamName: teamName, position: parsed.position)
                    let parsedPosition = normalizePosition(parsed.position)
                    let positionalProfile = roster.first { rosterPlayer in
                        rosterPlayer.name == parsed.playerName
                            && normalizePosition(rosterPlayer.position) == parsedPosition
                    }
                    let nameProfile = roster.first { rosterPlayer in
                        rosterPlayer.name == parsed.playerName
                    }
                    let profile = positionalProfile ?? nameProfile
                    var current = totals[key] ?? SeasonPlayerStat(
                        playerName: parsed.playerName,
                        teamId: teamId,
                        teamName: teamName,
                        conferenceId: conferenceIdByTeamId[teamId],
                        position: parsed.position,
                        year: profile?.year ?? ""
                    )
                    current.games += 1
                    current.minutes += parsed.minutes
                    current.points += parsed.points
                    current.rebounds += parsed.rebounds
                    current.assists += parsed.assists
                    current.steals += parsed.steals
                    current.blocks += parsed.blocks
                    current.turnovers += parsed.turnovers
                    current.fgMade += parsed.fgMade
                    current.fgAttempts += parsed.fgAttempts
                    current.threeMade += parsed.threeMade
                    current.ftMade += parsed.ftMade
                    current.ftAttempts += parsed.ftAttempts
                    totals[key] = current
                }
            }
        }

        return Array(totals.values)
    }
}

private func normalizePosition(_ position: String) -> String {
    switch position.uppercased() {
    case "PG":
        return "PG"
    case "SG", "CG":
        return "SG"
    case "SF", "WING":
        return "SF"
    case "PF", "F":
        return "PF"
    case "C", "BIG":
        return "C"
    default:
        return position.uppercased()
    }
}

struct ParsedTeamBoxScore {
    let name: String
    let players: [ParsedPlayerBoxScore]

    static func parse(from value: JSONValue?) -> [ParsedTeamBoxScore] {
        guard
            let resultObject = value?.objectDictionary,
            let boxArray = resultObject["boxScore"]?.arrayValues
        else {
            return []
        }

        return boxArray.compactMap { boxValue in
            guard let teamObj = boxValue.objectDictionary else { return nil }
            let teamName = teamObj["name"]?.stringValue ?? "Team"
            let players = teamObj["players"]?.arrayValues?.compactMap(ParsedPlayerBoxScore.init(value:)) ?? []
            return ParsedTeamBoxScore(name: teamName, players: players)
        }
    }
}

struct ParsedPlayerBoxScore {
    let playerName: String
    let position: String
    let minutes: Double
    let points: Int
    let fgMade: Int
    let fgAttempts: Int
    let threeMade: Int
    let threeAttempts: Int
    let ftMade: Int
    let ftAttempts: Int
    let rebounds: Int
    let offensiveRebounds: Int
    let defensiveRebounds: Int
    let assists: Int
    let steals: Int
    let blocks: Int
    let turnovers: Int
    let fouls: Int
    let plusMinus: Int

    init?(value: JSONValue) {
        guard let object = value.objectDictionary else { return nil }
        playerName = object["playerName"]?.stringValue ?? "Unknown"
        position = object["position"]?.stringValue ?? ""
        minutes = object["minutes"]?.numberValue ?? 0
        points = object["points"]?.intValue ?? 0
        fgMade = object["fgMade"]?.intValue ?? 0
        fgAttempts = object["fgAttempts"]?.intValue ?? 0
        threeMade = object["threeMade"]?.intValue ?? 0
        threeAttempts = object["threeAttempts"]?.intValue ?? 0
        ftMade = object["ftMade"]?.intValue ?? 0
        ftAttempts = object["ftAttempts"]?.intValue ?? 0
        rebounds = object["rebounds"]?.intValue ?? 0
        let parsedOffensiveRebounds = object["offensiveRebounds"]?.intValue
        let parsedDefensiveRebounds = object["defensiveRebounds"]?.intValue
        if let parsedOffensiveRebounds, let parsedDefensiveRebounds {
            offensiveRebounds = max(0, parsedOffensiveRebounds)
            defensiveRebounds = max(0, parsedDefensiveRebounds)
        } else if let parsedOffensiveRebounds {
            offensiveRebounds = max(0, parsedOffensiveRebounds)
            defensiveRebounds = max(0, rebounds - offensiveRebounds)
        } else if let parsedDefensiveRebounds {
            defensiveRebounds = max(0, parsedDefensiveRebounds)
            offensiveRebounds = max(0, rebounds - defensiveRebounds)
        } else {
            offensiveRebounds = 0
            defensiveRebounds = max(0, rebounds)
        }
        assists = object["assists"]?.intValue ?? 0
        steals = object["steals"]?.intValue ?? 0
        blocks = object["blocks"]?.intValue ?? 0
        turnovers = object["turnovers"]?.intValue ?? 0
        fouls = object["fouls"]?.intValue ?? 0
        plusMinus = object["plusMinus"]?.intValue ?? 0
    }
}

extension PaceProfile {
    var label: String {
        switch self {
        case .verySlow: "Very Slow"
        case .slow: "Slow"
        case .slightlySlow: "Slightly Slow"
        case .normal: "Balanced"
        case .slightlyFast: "Slightly Fast"
        case .fast: "Fast"
        case .veryFast: "Very Fast"
        }
    }
}

extension CoachArchetype {
    var label: String {
        switch self {
        case .recruiting: "Recruiting"
        case .offense: "Offense"
        case .defense: "Defense"
        case .playerDevelopment: "Player Development"
        case .fundraising: "Fundraising"
        }
    }

    var summary: String {
        switch self {
        case .recruiting:
            "Elite relationship builder. Starts with stronger recruiting and scouting ratings."
        case .offense:
            "System play-caller. Starts with stronger offensive coaching and guard/wing development."
        case .defense:
            "Stops-first tactician. Starts with stronger defensive coaching and scouting ratings."
        case .playerDevelopment:
            "Teacher and builder. Starts with stronger player growth ratings across positions."
        case .fundraising:
            "Program CEO. Starts with stronger fundraising and long-term program potential ratings."
        }
    }

    var initialSkills: CoachSkills {
        var skills = CoachSkills()
        switch self {
        case .recruiting:
            skills.recruiting = 84
            skills.scouting = 76
            skills.playerDevelopment = 66
            skills.guardDevelopment = 64
            skills.wingDevelopment = 64
            skills.bigDevelopment = 62
            skills.offensiveCoaching = 62
            skills.defensiveCoaching = 62
            skills.fundraising = 58
            skills.potential = 70
        case .offense:
            skills.recruiting = 60
            skills.scouting = 64
            skills.playerDevelopment = 72
            skills.guardDevelopment = 80
            skills.wingDevelopment = 76
            skills.bigDevelopment = 66
            skills.offensiveCoaching = 84
            skills.defensiveCoaching = 58
            skills.fundraising = 56
            skills.potential = 68
        case .defense:
            skills.recruiting = 60
            skills.scouting = 76
            skills.playerDevelopment = 70
            skills.guardDevelopment = 68
            skills.wingDevelopment = 70
            skills.bigDevelopment = 74
            skills.offensiveCoaching = 56
            skills.defensiveCoaching = 84
            skills.fundraising = 56
            skills.potential = 68
        case .playerDevelopment:
            skills.recruiting = 62
            skills.scouting = 66
            skills.playerDevelopment = 84
            skills.guardDevelopment = 76
            skills.wingDevelopment = 76
            skills.bigDevelopment = 76
            skills.offensiveCoaching = 66
            skills.defensiveCoaching = 66
            skills.fundraising = 56
            skills.potential = 72
        case .fundraising:
            skills.recruiting = 64
            skills.scouting = 62
            skills.playerDevelopment = 62
            skills.guardDevelopment = 60
            skills.wingDevelopment = 60
            skills.bigDevelopment = 60
            skills.offensiveCoaching = 62
            skills.defensiveCoaching = 62
            skills.fundraising = 84
            skills.potential = 78
        }
        return skills
    }
}

extension OffensiveFormation {
    var label: String {
        switch self {
        case .fiveOut: "5-Out"
        case .fourOutOnePost: "4-Out 1-Post"
        case .highLow: "High-Low"
        case .triangle: "Triangle"
        case .motion: "Motion"
        }
    }
}

extension DefenseScheme {
    var label: String {
        switch self {
        case .manToMan: "Man-to-Man"
        case .zone23: "2-3 Zone"
        case .zone32: "3-2 Zone"
        case .zone131: "1-3-1 Zone"
        case .packLine: "Pack Line"
        }
    }
}

extension AssistantFocus {
    var label: String {
        switch self {
        case .recruiting: "Recruiting"
        case .development: "Development"
        case .gamePrep: "Game Prep"
        case .scouting: "Scouting"
        }
    }
}

extension Coach {
    var displayName: String {
        guard let name, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "Unnamed Coach"
        }
        return name
    }

    var allTraitValues: [(title: String, value: Int)] {
        [
            ("Recruiting", skills.recruiting),
            ("Player Dev", skills.playerDevelopment),
            ("Guard Dev", skills.guardDevelopment),
            ("Wing Dev", skills.wingDevelopment),
            ("Big Dev", skills.bigDevelopment),
            ("Offensive", skills.offensiveCoaching),
            ("Defensive", skills.defensiveCoaching),
            ("Fundraising", skills.fundraising),
            ("Scouting", skills.scouting),
            ("Potential", skills.potential),
        ]
    }

    var bioLine: String {
        let trimmedAlma = almaMater.trimmingCharacters(in: .whitespacesAndNewlines)
        let almaLabel = trimmedAlma.isEmpty ? "Independent" : trimmedAlma

        let trimmedPipeline = pipelineState.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let pipelineLabel = trimmedPipeline.isEmpty ? "--" : trimmedPipeline

        return "Alma: \(almaLabel) · Pipeline: \(pipelineLabel)"
    }
}

extension JSONValue {
    var objectDictionary: [String: JSONValue]? {
        guard case let .object(values) = self else { return nil }
        return values
    }

    var arrayValues: [JSONValue]? {
        guard case let .array(values) = self else { return nil }
        return values
    }

    var stringValue: String? {
        guard case let .string(value) = self else { return nil }
        return value
    }

    var numberValue: Double? {
        guard case let .number(value) = self else { return nil }
        return value
    }

    var intValue: Int? {
        guard case let .number(value) = self else { return nil }
        return Int(value.rounded())
    }

    func intValue(for key: String) -> Int? {
        guard case let .object(values) = self, let value = values[key], case let .number(number) = value else {
            return nil
        }
        return Int(number.rounded())
    }

    func numberValue(for key: String) -> Double? {
        guard case let .object(values) = self, let value = values[key], case let .number(number) = value else {
            return nil
        }
        return number
    }

    func boolValue(for key: String) -> Bool? {
        guard case let .object(values) = self, let value = values[key], case let .bool(boolValue) = value else {
            return nil
        }
        return boolValue
    }
}

extension Double {
    var roundedInt: Int {
        Int(self.rounded())
    }
}

#Preview {
    ContentView()
}
