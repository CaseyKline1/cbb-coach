import SwiftUI
import UniformTypeIdentifiers
import CBBCoachCore

private func nilMoneyText(_ amount: Double) -> String {
    if abs(amount) >= 1_000_000 {
        let millions = amount / 1_000_000
        let absMillions = abs(millions)
        let decimals = absMillions >= 99.5 ? 0 : (absMillions >= 9.95 ? 1 : 2)
        return "$\(String(format: "%.\(decimals)f", millions))M"
    }
    return "$\(Int(amount / 1_000).formatted())K"
}

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
    let draftSummary: DraftSummary?
    let nilRetentionSummary: NILRetentionSummary?
    let transferPortalSummary: TransferPortalSummary?
    let hallOfFameSummary: SchoolHallOfFameSummary?
    let roster: [UserRosterPlayerSummary]
    let teamRostersByName: [String: [UserRosterPlayerSummary]]
    let onAdvanceToOffseasonSchedule: () -> Void

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
        draftSummary: DraftSummary?,
        nilRetentionSummary: NILRetentionSummary?,
        transferPortalSummary: TransferPortalSummary?,
        hallOfFameSummary: SchoolHallOfFameSummary?,
        roster: [UserRosterPlayerSummary],
        teamRostersByName: [String: [UserRosterPlayerSummary]],
        onAdvanceToOffseasonSchedule: @escaping () -> Void
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
        self.draftSummary = draftSummary
        self.nilRetentionSummary = nilRetentionSummary
        self.transferPortalSummary = transferPortalSummary
        self.hallOfFameSummary = hallOfFameSummary
        self.roster = roster
        self.teamRostersByName = teamRostersByName
        self.onAdvanceToOffseasonSchedule = onAdvanceToOffseasonSchedule
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

    private var selectedAllConferenceTeams: [(team: String, players: [SeasonPlayerStat])] {
        let top = Array(eligibleStats
            .filter { $0.conferenceId == selectedConferenceId }
            .prefix(10))
        return [
            ("First Team", Array(top.prefix(5))),
            ("Second Team", Array(top.dropFirst(5).prefix(5))),
        ]
    }

    private var userAwardLines: [String] {
        let national = awardRows.compactMap { title, stat in
            stat?.teamName.caseInsensitiveCompare(userTeamName) == .orderedSame ? "\(stat?.playerName ?? ""): \(title)" : nil
        }
        let americans = allAmericans.flatMap { team, players in
            players.filter { $0.teamName.caseInsensitiveCompare(userTeamName) == .orderedSame }
                .map { "\($0.playerName): \(team) All-American" }
        }
        let conference = selectedUserAllConferenceTeams.flatMap { team, players in
            players
                .filter { $0.teamName.caseInsensitiveCompare(userTeamName) == .orderedSame }
                .map { "\($0.playerName): \(team) All-\(conferenceTitle($0.conferenceId ?? userConferenceId ?? ""))" }
        }
        return national + americans + conference
    }

    private var selectedUserAllConferenceTeams: [(team: String, players: [SeasonPlayerStat])] {
        guard let userConferenceId else { return [] }
        let top = Array(eligibleStats
            .filter { $0.conferenceId == userConferenceId }
            .prefix(10))
        return [
            ("First Team", Array(top.prefix(5))),
            ("Second Team", Array(top.dropFirst(5).prefix(5))),
        ]
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

                    Button {
                        onAdvanceToOffseasonSchedule()
                    } label: {
                        Text("Advance to Offseason Schedule")
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

            ForEach(selectedAllConferenceTeams, id: \.team) { section in
                playerListCard(title: "\(section.team) All-\(conferenceTitle(selectedConferenceId))", stats: section.players)
            }
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
                        AppTableTextCell(text: stat.playerName, width: 166, alignment: .leading, foreground: AppTheme.ink)
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
                                        .foregroundStyle(AppTheme.ink)
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
                            .foregroundStyle(AppTheme.ink)
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
    let id: String
    let title: String
    let detail: String
    let stage: LeagueOffseasonStage

    static let initialPhases: [OffseasonSchedulePhase] = [
        OffseasonSchedulePhase(
            id: "nil-budgets",
            title: "NIL Budgets",
            detail: "Reveal next season's revenue sharing and donor pool.",
            stage: .nilBudgets
        ),
        OffseasonSchedulePhase(
            id: "players-leaving",
            title: "Players Leaving",
            detail: "Seniors graduate and transfer risks decide whether to move on.",
            stage: .playersLeaving
        ),
        OffseasonSchedulePhase(
            id: "draft",
            title: "Draft",
            detail: "The top 60 draft entrants come off the board.",
            stage: .draft
        ),
        OffseasonSchedulePhase(
            id: "player-retention",
            title: "Player Retention",
            detail: "Negotiate one-year NIL deals with returning players.",
            stage: .playerRetention
        ),
        OffseasonSchedulePhase(
            id: "transfer-portal",
            title: "Transfer Portal",
            detail: "Unsigned players and transfer departures enter the national market.",
            stage: .transferPortal
        ),
    ]
}

struct OffseasonScheduleView: View {
    let progress: LeagueOffseasonProgress?
    let nilBudgetSummary: NILBudgetSummary?
    let playersLeavingSummary: PlayersLeavingSummary?
    let draftSummary: DraftSummary?
    let nilRetentionSummary: NILRetentionSummary?
    let transferPortalSummary: TransferPortalSummary?
    let hallOfFameSummary: SchoolHallOfFameSummary?
    let games: [LeagueGameSummary]
    let teamRostersByName: [String: [UserRosterPlayerSummary]]
    let onAdvance: () -> Void

    private let phases = OffseasonSchedulePhase.initialPhases

    private var currentStage: LeagueOffseasonStage {
        progress?.stage ?? .schedule
    }

    private var advanceTitle: String {
        switch currentStage {
        case .schedule:
            return "Advance to NIL Budgets"
        case .seasonRecap:
            return "Advance to Offseason Schedule"
        case .nilBudgets:
            return "Advance to Players Leaving"
        case .playersLeaving:
            return "Advance to Draft"
        case .draft:
            return "Advance to Player Retention"
        case .playerRetention:
            return "Advance to Transfer Portal"
        case .transferPortal:
            return "Complete Offseason Schedule"
        case .complete:
            return "Offseason Schedule Complete"
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                scheduleTable

                Button(advanceTitle) {
                    onAdvance()
                }
                .buttonStyle(GameButtonStyle(variant: .primary))
                .disabled(currentStage == .complete)
            }
            .padding(16)
        }
        .background(AppTheme.background)
        .navigationTitle("Offseason Schedule")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var scheduleTable: some View {
        GameCard {
            VStack(alignment: .leading, spacing: 0) {
                GameSectionHeader(title: "Offseason Schedule")

                HStack(alignment: .center, spacing: 0) {
                    scheduleHeader("Order", width: 48, alignment: .leading)
                    scheduleHeader("Event", alignment: .leading)
                }
                .padding(.vertical, 8)
                .overlay(alignment: .bottom) {
                    Divider()
                }

                ForEach(Array(phases.enumerated()), id: \.element.id) { index, phase in
                    VStack(spacing: 0) {
                        HStack(alignment: .top, spacing: 0) {
                            Text("\(index + 1)")
                                .font(.caption.monospacedDigit().weight(.semibold))
                                .foregroundStyle(.secondary)
                                .frame(width: 48, alignment: .leading)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(phase.title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(AppTheme.ink)
                                    .fixedSize(horizontal: false, vertical: true)

                                Text(phase.detail)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.vertical, 12)

                        if index < phases.count - 1 {
                            Divider()
                        }
                    }
                }
            }
        }
    }

    private func scheduleHeader(
        _ title: String,
        width: CGFloat? = nil,
        alignment: Alignment
    ) -> some View {
        Text(title)
            .font(.caption2.weight(.bold))
            .foregroundStyle(.secondary)
            .frame(width: width, alignment: alignment)
            .frame(maxWidth: width == nil ? .infinity : nil, alignment: alignment)
    }
}

struct NILBudgetView: View {
    let summary: NILBudgetSummary?
    let onAdvance: () -> Void

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

                Button {
                    onAdvance()
                } label: {
                    Text("Advance to Players Leaving")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(GameButtonStyle(variant: .primary))
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
        nilMoneyText(amount)
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
    let hallOfFameSummary: SchoolHallOfFameSummary?
    let games: [LeagueGameSummary]
    let teamRostersByName: [String: [UserRosterPlayerSummary]]
    let onAdvance: () -> Void

    private let hallGold = Color(red: 0.96, green: 0.68, blue: 0.18)

    private var userRows: [PlayerLeavingEntry] {
        summary?.userEntries ?? []
    }

    private var transferRows: [PlayerLeavingEntry] {
        userRows.filter { $0.outcome == .transfer }
    }

    private var draftRows: [PlayerLeavingEntry] {
        userRows.filter { $0.outcome == .draft }
    }

    private var graduationRows: [PlayerLeavingEntry] {
        userRows.filter { $0.outcome == .graduated }
    }

    private var hallPlayerIds: Set<String> {
        Set((hallOfFameSummary?.entries ?? []).map { hallKey(teamId: $0.teamId, playerName: $0.player.name) })
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                GameCard {
                    VStack(alignment: .leading, spacing: 10) {
                        GameSectionHeader(title: "Players Leaving")
                        HStack(spacing: 8) {
                            summaryTile(title: "Graduating", value: "\(graduationRows.count)")
                            summaryTile(title: "Draft", value: "\(draftRows.count)")
                            summaryTile(title: "Transfers", value: "\(transferRows.count)")
                        }
                    }
                }

                leavingSection(title: "Graduating Seniors", rows: graduationRows, emptyText: "No seniors are graduating this offseason.")
                leavingSection(title: "Draft Entrants", rows: draftRows, emptyText: "No underclassmen entered the draft.")
                leavingSection(title: "Transfer Decisions", rows: transferRows, emptyText: "No returners decided to transfer.")

                Button {
                    onAdvance()
                } label: {
                    Text("Advance to Draft")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(GameButtonStyle(variant: .primary))
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
                    NavigationLink {
                        PlayerCardDetailView(
                            player: playerProfile(for: row),
                            games: games,
                            teamName: row.teamName
                        )
                    } label: {
                        Text(row.playerName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(isHallOfFamer(row) ? hallGold : AppTheme.ink)
                    }
                    .buttonStyle(.plain)
                    Text("\(row.year) \(row.position) | OVR \(row.overall) | POT \(row.potential)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                GamePill(text: row.outcome.rawValue, color: outcomeColor(row.outcome))
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

    private func outcomeColor(_ outcome: PlayerLeavingOutcome) -> Color {
        switch outcome {
        case .graduated: return .secondary
        case .draft: return AppTheme.accent
        case .transfer: return AppTheme.warning
        }
    }

    private func isHallOfFamer(_ row: PlayerLeavingEntry) -> Bool {
        hallPlayerIds.contains(hallKey(teamId: row.teamId, playerName: row.playerName))
    }

    private func hallKey(teamId: String, playerName: String) -> String {
        "\(teamId):\(playerName)"
    }

    private func playerProfile(for row: PlayerLeavingEntry) -> UserRosterPlayerSummary {
        if let player = row.player { return player }
        if let match = rosterForTeam(named: row.teamName).first(where: { $0.name == row.playerName && $0.position == row.position }) {
            return match
        }
        if let match = rosterForTeam(named: row.teamName).first(where: { $0.name == row.playerName }) {
            return match
        }
        return UserRosterPlayerSummary(
            playerIndex: -1,
            name: row.playerName,
            position: row.position,
            year: row.year,
            home: nil,
            height: nil,
            weight: nil,
            wingspan: nil,
            overall: row.overall,
            isStarter: false,
            attributes: ["potential": row.potential]
        )
    }

    private func rosterForTeam(named teamName: String) -> [UserRosterPlayerSummary] {
        if let direct = teamRostersByName[teamName] { return direct }
        return teamRostersByName.first { $0.key.caseInsensitiveCompare(teamName) == .orderedSame }?.value ?? []
    }
}

struct SchoolHallOfFameView: View {
    let summary: SchoolHallOfFameSummary?
    let games: [LeagueGameSummary]
    let userTeamName: String

    private let hallGold = Color(red: 0.96, green: 0.68, blue: 0.18)

    private var rows: [SchoolHallOfFameEntry] {
        summary?.userEntries ?? []
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                GameCard {
                    VStack(alignment: .leading, spacing: 8) {
                        GameSectionHeader(title: "School Hall of Fame")
                        Text("\(rows.count) inductees")
                            .font(.subheadline.monospacedDigit().weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }

                if rows.isEmpty {
                    GameCard {
                        Text("No players have been inducted yet.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    GameCard {
                        VStack(spacing: 0) {
                            ForEach(rows) { row in
                                hallRow(row)
                                if row.id != rows.last?.id {
                                    Divider()
                                }
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(AppTheme.background)
        .navigationTitle("Hall of Fame")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func hallRow(_ row: SchoolHallOfFameEntry) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                NavigationLink {
                    PlayerCardDetailView(player: row.player, games: games, teamName: row.teamName)
                } label: {
                    Text(row.player.name)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(hallGold)
                }
                .buttonStyle(.plain)
                Spacer(minLength: 8)
                Text("OVR \(row.player.overall)")
                    .font(.caption.monospacedDigit().weight(.bold))
                    .foregroundStyle(AppTheme.ink)
            }

            Text("\(row.player.year) \(row.player.position) | \(row.inductionReason)")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(row.honors.joined(separator: " | "))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 12)
    }
}

struct DraftView: View {
    let summary: DraftSummary?
    let games: [LeagueGameSummary]
    let onAdvance: () -> Void
    private let userSchoolGold = Color(red: 0.96, green: 0.68, blue: 0.18)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                draftListCard

                Button {
                    onAdvance()
                } label: {
                    Text("Advance to Player Retention")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(GameButtonStyle(variant: .primary))
            }
            .padding(16)
        }
        .background(AppTheme.background)
        .navigationTitle("Draft")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var draftListCard: some View {
        GameCard {
            VStack(alignment: .leading, spacing: 0) {
                GameSectionHeader(title: "Draft Results")

                if picks.isEmpty {
                    Text("Draft results are not available yet.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)
                } else {
                    HStack(spacing: 8) {
                        draftHeader("Pick", width: 42, alignment: .leading)
                        draftHeader("Player", alignment: .leading)
                        draftHeader("Score", width: 38, alignment: .trailing)
                    }
                    .padding(.top, 2)
                    .padding(.bottom, 6)

                    ForEach(Array(picks.enumerated()), id: \.element.id) { index, pick in
                        VStack(spacing: 0) {
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text(formattedDraftSlot(pick.slot))
                                    .font(.system(size: 14, weight: .bold, design: .rounded).monospacedDigit())
                                    .foregroundStyle(AppTheme.ink)
                                    .frame(width: 42, alignment: .leading)

                                VStack(alignment: .leading, spacing: 1) {
                                    Text(pick.player.name)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(isUserSchoolPick(pick) ? userSchoolGold : AppTheme.ink)
                                        .lineLimit(1)
                                        .truncationMode(.tail)

                                    Text(playerDetail(for: pick))
                                        .font(.system(size: 11, weight: .regular))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)

                                Text(String(format: "%.1f", pick.draftScore))
                                    .font(.system(size: 12, weight: .semibold, design: .rounded).monospacedDigit())
                                    .foregroundStyle(.secondary)
                                    .frame(width: 38, alignment: .trailing)
                            }
                            .padding(.vertical, 6)

                            if index < picks.count - 1 {
                                Divider()
                            }
                        }
                    }
                }
            }
        }
        .dynamicTypeSize(.xSmall ... .large)
    }

    private func draftHeader(
        _ title: String,
        width: CGFloat? = nil,
        alignment: Alignment
    ) -> some View {
        Text(title)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .frame(width: width, alignment: alignment)
            .frame(maxWidth: width == nil ? .infinity : nil, alignment: alignment)
    }

    private var picks: [DraftPickEntry] {
        (summary?.picks ?? []).sorted { $0.slot < $1.slot }
    }

    private func isUserSchoolPick(_ pick: DraftPickEntry) -> Bool {
        guard let userTeamId = summary?.userTeamId, !userTeamId.isEmpty else { return false }
        return pick.teamId == userTeamId
    }

    private func playerDetail(for pick: DraftPickEntry) -> String {
        "\(pick.player.year) \(pick.player.position) | \(pick.teamName) | OVR \(pick.player.overall)"
    }

    private func formattedDraftSlot(_ slot: Int) -> String {
        let clamped = max(1, slot)
        let round = ((clamped - 1) / 30) + 1
        let pickInRound = ((clamped - 1) % 30) + 1
        return String(format: "%d.%02d", round, pickInRound)
    }
}

struct NILOfferAmountControl: View {
    let amount: Int
    let minimum: Int
    let maximum: Int
    let postSecondFireSpeedMultiplier: Double
    let onSetAmount: (Int) -> Void

    @Environment(\.isEnabled) private var isViewEnabled
    @State private var localAmount: Int?

    private var displayedAmount: Int {
        clamped(localAmount ?? amount)
    }

    var body: some View {
        HStack(spacing: 2) {
            amountButton(title: "-$", delta: -50_000)

            Text(moneyText(Double(displayedAmount)))
                .font(.caption.monospacedDigit().weight(.semibold))
                .frame(minWidth: 54, alignment: .center)
                .foregroundStyle(AppTheme.ink)

            amountButton(title: "+$", delta: 50_000)
        }
        .onChange(of: amount) { _, newValue in
            localAmount = clamped(newValue)
        }
        .onChange(of: maximum) { _, _ in
            localAmount = displayedAmount
        }
        .onAppear {
            localAmount = displayedAmount
        }
    }

    @ViewBuilder
    private func amountButton(title: String, delta: Int) -> some View {
        let isControlEnabled = isEnabled(for: delta)
        HoldRepeatButton(
            action: { adjust(by: delta) },
            isEnabled: isControlEnabled,
            initialRepeatDelay: 0.01,
            holdRepeatInterval: 0.005,
            postSecondFireSpeedMultiplier: postSecondFireSpeedMultiplier
        ) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .frame(minWidth: 24)
        }
        .foregroundStyle((isViewEnabled && isControlEnabled) ? AppTheme.accent : .secondary.opacity(0.45))
    }

    private func adjust(by delta: Int) {
        let next = clamped(displayedAmount + delta)
        guard next != displayedAmount else { return }
        localAmount = next
        onSetAmount(next)
    }

    private func isEnabled(for delta: Int) -> Bool {
        let next = displayedAmount + delta
        if delta > 0 {
            return displayedAmount < maximum && next <= maximum
        }
        if delta < 0 {
            return displayedAmount > minimum && next >= minimum
        }
        return false
    }

    private func clamped(_ value: Int) -> Int {
        min(max(value, minimum), maximum)
    }

    private func moneyText(_ amount: Double) -> String {
        nilMoneyText(amount)
    }
}

struct HoldRepeatButton<Label: View>: View {
    let action: () -> Void
    let isEnabled: Bool
    private let holdRepeatInterval: TimeInterval
    private let initialRepeatDelay: TimeInterval
    private let postSecondFireSpeedMultiplier: Double
    @ViewBuilder let label: () -> Label

    @State private var holdTask: Task<Void, Never>?
    @State private var isHolding = false
    @State private var holdSessionID: UInt64 = 0
    @Environment(\.isEnabled) private var isViewEnabled

    init(
        action: @escaping () -> Void,
        isEnabled: Bool,
        initialRepeatDelay: TimeInterval = 0.4,
        holdRepeatInterval: TimeInterval = 0.06,
        postSecondFireSpeedMultiplier: Double = 1.0,
        @ViewBuilder label: @escaping () -> Label
    ) {
        self.action = action
        self.isEnabled = isEnabled
        self.initialRepeatDelay = initialRepeatDelay
        self.holdRepeatInterval = max(0.03, holdRepeatInterval)
        self.postSecondFireSpeedMultiplier = max(1.0, postSecondFireSpeedMultiplier)
        self.label = label
    }

    var body: some View {
        label()
            .contentShape(Rectangle())
            .highPriorityGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard isEnabled && isViewEnabled else {
                            stopHoldRepeat()
                            return
                        }
                        startHoldRepeat()
                    }
                    .onEnded { _ in
                        stopHoldRepeat()
                    }
            )
            .onChange(of: isEnabled) { _, enabled in
                if !enabled { stopHoldRepeat() }
            }
            .onChange(of: isViewEnabled) { _, enabled in
                if !enabled { stopHoldRepeat() }
            }
            .onDisappear {
                stopHoldRepeat()
            }
    }

    private func startHoldRepeat() {
        guard !isHolding else { return }
        isHolding = true
        holdSessionID &+= 1
        let sessionID = holdSessionID
        action()

        let initialDelayNanos = UInt64(max(0.0, initialRepeatDelay) * 1_000_000_000)
        let acceleratedIntervalNanos = UInt64(max(0.03, holdRepeatInterval / postSecondFireSpeedMultiplier) * 1_000_000_000)

        holdTask?.cancel()
        holdTask = Task {
            if initialDelayNanos > 0 {
                try? await Task.sleep(nanoseconds: initialDelayNanos)
            }
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard sessionID == holdSessionID, isHolding, isEnabled, isViewEnabled else { return }
                action()
            }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: acceleratedIntervalNanos)
                await MainActor.run {
                    guard sessionID == holdSessionID, isHolding, isEnabled, isViewEnabled else { return }
                    action()
                }
            }
        }
    }

    private func stopHoldRepeat() {
        holdSessionID &+= 1
        isHolding = false
        holdTask?.cancel()
        holdTask = nil
    }
}

struct NILRetentionView: View {
    let summary: NILRetentionSummary?
    let games: [LeagueGameSummary]
    let onSetOffer: (String, Double) -> Void
    let onSubmitOffer: (String) -> Void
    let onMeetDemand: (String) -> Void
    let onDelegate: () -> Void
    let onAdvance: () -> Void

    private var budget: NILRetentionBudgetSummary {
        summary?.budget ?? NILRetentionBudgetSummary(total: 0, allocated: 0, remaining: 0)
    }

    private var rows: [NILNegotiationEntry] {
        (summary?.userEntries ?? []).sorted {
            if $0.status != $1.status { return statusSort($0.status) < statusSort($1.status) }
            if $0.priority != $1.priority { return $0.priority > $1.priority }
            return $0.playerName < $1.playerName
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                budgetCard

                Button {
                    onDelegate()
                } label: {
                    Text("Delegate to Assistants")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(GameButtonStyle(variant: .secondary))

                if rows.isEmpty {
                    GameCard {
                        Text("No returning players need NIL negotiations.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    GameCard {
                        VStack(spacing: 0) {
                            ForEach(rows) { row in
                                retentionRow(row)
                                if row.id != rows.last?.id {
                                    Divider()
                                }
                            }
                        }
                    }
                }

                Button {
                    onAdvance()
                } label: {
                    Text("Advance to Transfer Portal")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(GameButtonStyle(variant: .primary))
            }
            .padding(16)
        }
        .background(AppTheme.background)
        .navigationTitle("Player Retention")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var budgetCard: some View {
        GameCard {
            VStack(alignment: .leading, spacing: 10) {
                GameSectionHeader(title: "NIL Budget")
                HStack(spacing: 8) {
                    summaryTile(title: "TOTAL", value: moneyText(budget.total))
                    summaryTile(title: "SIGNED", value: moneyText(budget.allocated))
                    summaryTile(title: "LEFT", value: moneyText(budget.remaining))
                }
            }
        }
    }

    private func retentionRow(_ row: NILNegotiationEntry) -> some View {
        let maximumOffer = Int(max(row.demand * 1.25, 100_000).rounded())

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                VStack(alignment: .leading, spacing: 3) {
                    NavigationLink {
                        PlayerCardDetailView(player: playerProfile(row), games: games, teamName: row.teamName)
                    } label: {
                        Text(row.playerName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.ink)
                    }
                    .buttonStyle(.plain)
                    Text("\(row.year) \(row.position) | OVR \(row.overall) | POT \(row.potential)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                GamePill(text: statusText(row.status), color: statusColor(row.status))
            }

            HStack(spacing: 8) {
                metricChip(title: "VALUE", value: moneyText(row.intrinsicValue))
                metricChip(title: "LAST", value: moneyText(row.lastYearAmount))
                metricChip(title: "ASK", value: moneyText(row.demand))
                metricChip(title: "DISC", value: "\(Int((row.returningDiscount * 100).rounded()))%")
            }

            HStack(spacing: 8) {
                metricChip(title: "LOY", value: "\(Int(row.loyalty.rounded()))")
                metricChip(title: "GREED", value: "\(Int(row.greed.rounded()))")
                metricChip(title: "OFFER", value: moneyText(row.offer))
            }

            if row.status == .open {
                NILOfferAmountControl(
                    amount: Int(row.offer.rounded()),
                    minimum: 0,
                    maximum: maximumOffer,
                    postSecondFireSpeedMultiplier: 1,
                    onSetAmount: { amount in
                        onSetOffer(row.id, Double(amount))
                    }
                )
                HStack(spacing: 8) {
                    Button("Offer") {
                        onSubmitOffer(row.id)
                    }
                    .buttonStyle(GameButtonStyle(variant: .secondary, size: .compact))

                    Button("Meet Ask") {
                        onMeetDemand(row.id)
                    }
                    .buttonStyle(GameButtonStyle(variant: .primary, size: .compact))
                }
            }

            if !row.responseText.isEmpty {
                Text(row.responseText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 12)
    }

    private func summaryTile(title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.monospacedDigit().weight(.black))
                .foregroundStyle(AppTheme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
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
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 7)
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func statusSort(_ status: NILNegotiationStatus) -> Int {
        switch status {
        case .open: return 0
        case .accepted: return 1
        case .portal: return 2
        }
    }

    private func statusText(_ status: NILNegotiationStatus) -> String {
        switch status {
        case .open: return "OPEN"
        case .accepted: return "SIGNED"
        case .portal: return "PORTAL"
        }
    }

    private func statusColor(_ status: NILNegotiationStatus) -> Color {
        switch status {
        case .open: return AppTheme.accent
        case .accepted: return AppTheme.success
        case .portal: return AppTheme.warning
        }
    }

    private func playerProfile(_ row: NILNegotiationEntry) -> UserRosterPlayerSummary {
        row.player ?? UserRosterPlayerSummary(
            playerIndex: row.playerIndex,
            name: row.playerName,
            position: row.position,
            year: row.year,
            home: nil,
            height: nil,
            weight: nil,
            wingspan: nil,
            overall: row.overall,
            isStarter: false,
            attributes: ["potential": row.potential]
        )
    }

    private func moneyText(_ amount: Double) -> String {
        nilMoneyText(amount)
    }
}

struct TransferPortalView: View {
    private enum PortalTableColumn: String, Hashable {
        case target, player, position, year, previous, overall, potential, points, rebounds, assists, minutes, ask, status
    }

    private enum BoardTableColumn: String, Hashable {
        case player, position, overall, points, ask, offer, interest, finalists, status, actions
    }

    private enum PortalStatusFilter: String, CaseIterable, Hashable {
        case all = "All"
        case available = "Available"
        case targeted = "Board"
        case committed = "Committed"
        case previousTeam = "From You"
    }

    let summary: TransferPortalSummary?
    let games: [LeagueGameSummary]
    let onSetTargeted: (String, Bool) -> Void
    let onSetOffer: (String, Double) -> Void
    let onAdvance: () -> Void

    @State private var searchText = ""
    @State private var positionFilter = "All"
    @State private var statusFilter: PortalStatusFilter = .available
    @State private var sortColumn: PortalTableColumn = .overall
    @State private var isAscending = false
    @State private var boardSortColumn: BoardTableColumn = .overall
    @State private var boardIsAscending = false

    private var rows: [TransferPortalEntry] { summary?.entries ?? [] }

    private var userRows: [TransferPortalEntry] {
        summary?.userEntries ?? []
    }

    private var targetedRows: [TransferPortalEntry] {
        summary?.targetedEntries ?? []
    }

    private var committedRows: [TransferPortalEntry] {
        rows.filter { $0.committedTeamId != nil }
    }

    private var activeRows: [TransferPortalEntry] {
        rows.filter { $0.committedTeamId == nil }
    }

    private var availableRows: [TransferPortalEntry] {
        activeRows.filter { $0.previousTeamId != summary?.userTeamId }
    }

    private var targetIds: Set<String> {
        Set(summary?.userTargetIds ?? [])
    }

    private var positionOptions: [(label: String, value: String)] {
        let positions = Set(rows.map(\.position))
        return [("All", "All")] + positions.sorted().map { ($0, $0) }
    }

    private var filteredPortalRows: [TransferPortalEntry] {
        sortedPortalRows(rows.filter { row in
            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            let matchesSearch = query.isEmpty
                || row.playerName.localizedCaseInsensitiveContains(query)
                || row.previousTeamName.localizedCaseInsensitiveContains(query)
            let matchesPosition = positionFilter == "All" || row.position == positionFilter
            let matchesStatus: Bool
            switch statusFilter {
            case .all:
                matchesStatus = true
            case .available:
                matchesStatus = row.committedTeamId == nil && row.previousTeamId != summary?.userTeamId
            case .targeted:
                matchesStatus = targetIds.contains(row.id)
            case .committed:
                matchesStatus = row.committedTeamId != nil
            case .previousTeam:
                matchesStatus = row.previousTeamId == summary?.userTeamId
            }
            return matchesSearch && matchesPosition && matchesStatus
        })
    }

    private var sortedBoardRows: [TransferPortalEntry] {
        targetedRows.sorted { lhs, rhs in
            let comparison = compareBoard(lhs: lhs, rhs: rhs, column: boardSortColumn)
            if comparison == .orderedSame {
                return lhs.playerName.localizedCaseInsensitiveCompare(rhs.playerName) == .orderedAscending
            }
            return boardIsAscending ? comparison == .orderedAscending : comparison == .orderedDescending
        }
    }

    private var portalWeekText: String {
        guard let summary else { return "Week 1" }
        if summary.week > summary.maxWeeks {
            return "Signing Day"
        }
        return "Week \(summary.week) of \(summary.maxWeeks)"
    }

    private var portalColumns: [AppTableColumn<PortalTableColumn>] {
        [
            .init(id: .target, title: "BD", width: 42),
            .init(id: .player, title: "PLAYER", width: 136, alignment: .leading),
            .init(id: .position, title: "POS", width: 42),
            .init(id: .year, title: "YR", width: 34),
            .init(id: .previous, title: "FROM", width: 112, alignment: .leading),
            .init(id: .overall, title: "OVR", width: 42),
            .init(id: .potential, title: "POT", width: 42),
            .init(id: .points, title: "PTS", width: 46),
            .init(id: .rebounds, title: "REB", width: 46),
            .init(id: .assists, title: "AST", width: 46),
            .init(id: .minutes, title: "MIN", width: 46),
            .init(id: .ask, title: "ASK", width: 72),
            .init(id: .status, title: "STATUS", width: 118, alignment: .leading),
        ]
    }

    private var boardColumns: [AppTableColumn<BoardTableColumn>] {
        [
            .init(id: .player, title: "PLAYER", width: 136, alignment: .leading),
            .init(id: .position, title: "POS", width: 42),
            .init(id: .overall, title: "OVR", width: 42),
            .init(id: .points, title: "PTS", width: 46),
            .init(id: .ask, title: "ASK", width: 72),
            .init(id: .offer, title: "OFFER", width: 86),
            .init(id: .interest, title: "INT", width: 46),
            .init(id: .finalists, title: "FINALISTS", width: 150, alignment: .leading),
            .init(id: .status, title: "STATUS", width: 96, alignment: .leading),
            .init(id: .actions, title: "", width: 140),
        ]
    }

    private var portalTableRows: [(id: AnyHashable, data: TransferPortalEntry)] {
        filteredPortalRows.map { (id: AnyHashable($0.id), data: $0) }
    }

    private var boardTableRows: [(id: AnyHashable, data: TransferPortalEntry)] {
        sortedBoardRows.map { (id: AnyHashable($0.id), data: $0) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                GameCard {
                    VStack(alignment: .leading, spacing: 10) {
                        GameSectionHeader(title: "Transfer Portal")
                        HStack(spacing: 8) {
                            summaryTile(title: "NATIONAL", value: "\(rows.count)")
                            summaryTile(title: "AVAILABLE", value: "\(availableRows.count)")
                            summaryTile(title: "TARGETS", value: "\(targetedRows.count)")
                        }
                        HStack(spacing: 8) {
                            summaryTile(title: "PERIOD", value: portalWeekText)
                            summaryTile(title: "REMAINING", value: moneyText(summary?.budget.remaining ?? 0))
                            summaryTile(title: "COMMITS", value: "\(committedRows.count)")
                        }
                    }
                }

                boardSection
                portalTableSection

                Button {
                    onAdvance()
                } label: {
                    Text((summary?.week ?? 1) > (summary?.maxWeeks ?? 4) ? "Complete Offseason Schedule" : "Advance Portal Week")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(GameButtonStyle(variant: .primary))
            }
            .padding(16)
        }
        .background(AppTheme.background)
        .navigationTitle("Transfer Portal")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var boardSection: some View {
        GameCard {
            VStack(alignment: .leading, spacing: 10) {
                GameSectionHeader(title: "Recruiting Board")
                Text("\(targetedRows.count)/8 targets")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                if sortedBoardRows.isEmpty {
                    Text("Add portal players from the table below to build your board.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    AppTable(
                        columns: boardColumns,
                        rows: boardTableRows,
                        sortState: .init(column: boardSortColumn, ascending: boardIsAscending),
                        onSort: toggleBoardSort
                    ) { row in
                        HStack(spacing: 0) {
                            playerLink(row, width: 136)
                            AppTableTextCell(text: row.position, width: 42)
                            AppTableTextCell(text: "\(row.overall)", width: 42)
                            AppTableTextCell(text: statText(row.stats?.pointsPerGame), width: 46)
                            AppTableTextCell(text: moneyText(row.askingPrice), width: 72)
                            AppTableTextCell(text: moneyText(summary?.userOffers[row.id] ?? 0), width: 86)
                            AppTableTextCell(text: interestText(row), width: 46)
                            AppTableTextCell(text: finalistsText(row), width: 150, alignment: .leading)
                            AppTableTextCell(text: statusText(row), width: 96, alignment: .leading)
                            boardActions(row)
                        }
                    }
                }
            }
        }
    }

    private var portalTableSection: some View {
        GameCard {
            VStack(alignment: .leading, spacing: 10) {
                GameSectionHeader(title: "Portal Players")
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        searchField
                        FilterDropdown(
                            title: "",
                            selection: $positionFilter,
                            options: positionOptions,
                            isSearchEnabled: false,
                            isCompact: true
                        )
                        .frame(width: 104)
                    }
                    FilterDropdown(
                        title: "",
                        selection: $statusFilter,
                        options: PortalStatusFilter.allCases.map { ($0.rawValue, $0) },
                        isSearchEnabled: false,
                        isCompact: true
                    )
                }

                if filteredPortalRows.isEmpty {
                    Text("No portal players match the current filters.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    AppTable(
                        columns: portalColumns,
                        rows: portalTableRows,
                        sortState: .init(column: sortColumn, ascending: isAscending),
                        onSort: togglePortalSort,
                        maxBodyHeight: 430
                    ) { row in
                        HStack(spacing: 0) {
                            targetButton(row)
                            playerLink(row, width: 136)
                            AppTableTextCell(text: row.position, width: 42)
                            AppTableTextCell(text: row.year, width: 34)
                            AppTableTextCell(text: row.previousTeamName, width: 112, alignment: .leading)
                            AppTableTextCell(text: "\(row.overall)", width: 42)
                            AppTableTextCell(text: "\(row.potential)", width: 42)
                            AppTableTextCell(text: statText(row.stats?.pointsPerGame), width: 46)
                            AppTableTextCell(text: statText(row.stats?.reboundsPerGame), width: 46)
                            AppTableTextCell(text: statText(row.stats?.assistsPerGame), width: 46)
                            AppTableTextCell(text: statText(row.stats?.minutesPerGame), width: 46)
                            AppTableTextCell(text: moneyText(row.askingPrice), width: 72)
                            AppTableTextCell(text: statusText(row), width: 118, alignment: .leading)
                        }
                    }
                }
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            TextField("Search players or schools", text: $searchText)
                .font(.footnote)
                .autocorrectionDisabled()
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color(UIColor.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.black.opacity(0.14), lineWidth: 1)
        )
    }

    private func playerLink(_ row: TransferPortalEntry, width: CGFloat) -> some View {
        NavigationLink {
            PlayerCardDetailView(player: playerProfile(row), games: games, teamName: row.previousTeamName)
        } label: {
            Text(row.playerName)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.accent)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(width: width, alignment: .leading)
        }
        .buttonStyle(.plain)
    }

    private func targetButton(_ row: TransferPortalEntry) -> some View {
        let isTargeted = targetIds.contains(row.id)
        let isUserDeparture = row.previousTeamId == summary?.userTeamId
        let canRecruit = !isUserDeparture && row.committedTeamId == nil
        let isBoardFull = !isTargeted && (summary?.userTargetIds.count ?? 0) >= 8

        return Button {
            onSetTargeted(row.id, !isTargeted)
        } label: {
            Image(systemName: isTargeted ? "checkmark.circle.fill" : "plus.circle")
                .font(.caption.weight(.bold))
                .foregroundStyle(isTargeted ? AppTheme.success : AppTheme.accent)
                .frame(width: 42)
        }
        .buttonStyle(.plain)
        .disabled(!canRecruit || isBoardFull)
        .opacity(canRecruit ? 1 : 0.35)
        .accessibilityLabel(isTargeted ? "Remove from recruiting board" : "Add to recruiting board")
    }

    private func boardActions(_ row: TransferPortalEntry) -> some View {
        let offer = summary?.userOffers[row.id] ?? 0
        let isOpen = row.committedTeamId == nil && row.previousTeamId != summary?.userTeamId

        return HStack(spacing: 6) {
            Button {
                onSetOffer(row.id, max(0, offer - 50_000))
            } label: {
                Image(systemName: "minus")
                    .frame(width: 28)
            }
            .buttonStyle(GameButtonStyle(variant: .secondary, size: .compact))
            .disabled(!isOpen || offer <= 0)

            Button {
                onSetOffer(row.id, offer + 50_000)
            } label: {
                Image(systemName: "plus")
                    .frame(width: 28)
            }
            .buttonStyle(GameButtonStyle(variant: .secondary, size: .compact))
            .disabled(!isOpen)

            Button {
                onSetTargeted(row.id, false)
            } label: {
                Image(systemName: "minus.circle")
                    .frame(width: 28)
            }
        }
        .buttonStyle(GameButtonStyle(variant: .secondary, size: .compact))
        .disabled(!isOpen)
        .frame(width: 140)
    }

    private func sortedPortalRows(_ input: [TransferPortalEntry]) -> [TransferPortalEntry] {
        input.sorted { lhs, rhs in
            let comparison = comparePortal(lhs: lhs, rhs: rhs, column: sortColumn)
            if comparison == .orderedSame {
                return lhs.playerName.localizedCaseInsensitiveCompare(rhs.playerName) == .orderedAscending
            }
            return isAscending ? comparison == .orderedAscending : comparison == .orderedDescending
        }
    }

    private func togglePortalSort(_ id: PortalTableColumn) {
        if sortColumn == id {
            isAscending.toggle()
        } else {
            sortColumn = id
            isAscending = id == .player || id == .position || id == .year || id == .previous || id == .status
        }
    }

    private func toggleBoardSort(_ id: BoardTableColumn) {
        if boardSortColumn == id {
            boardIsAscending.toggle()
        } else {
            boardSortColumn = id
            boardIsAscending = id == .player || id == .position || id == .finalists || id == .status || id == .actions
        }
    }

    private func comparePortal(lhs: TransferPortalEntry, rhs: TransferPortalEntry, column: PortalTableColumn) -> ComparisonResult {
        switch column {
        case .target:
            return numericCompare(lhs: targetIds.contains(lhs.id) ? 1 : 0, rhs: targetIds.contains(rhs.id) ? 1 : 0)
        case .player:
            return lhs.playerName.localizedCaseInsensitiveCompare(rhs.playerName)
        case .position:
            return lhs.position.localizedCaseInsensitiveCompare(rhs.position)
        case .year:
            return lhs.year.localizedCaseInsensitiveCompare(rhs.year)
        case .previous:
            return lhs.previousTeamName.localizedCaseInsensitiveCompare(rhs.previousTeamName)
        case .overall:
            return numericCompare(lhs: lhs.overall, rhs: rhs.overall)
        case .potential:
            return numericCompare(lhs: lhs.potential, rhs: rhs.potential)
        case .points:
            return numericCompare(lhs: lhs.stats?.pointsPerGame ?? -1, rhs: rhs.stats?.pointsPerGame ?? -1)
        case .rebounds:
            return numericCompare(lhs: lhs.stats?.reboundsPerGame ?? -1, rhs: rhs.stats?.reboundsPerGame ?? -1)
        case .assists:
            return numericCompare(lhs: lhs.stats?.assistsPerGame ?? -1, rhs: rhs.stats?.assistsPerGame ?? -1)
        case .minutes:
            return numericCompare(lhs: lhs.stats?.minutesPerGame ?? -1, rhs: rhs.stats?.minutesPerGame ?? -1)
        case .ask:
            return numericCompare(lhs: lhs.askingPrice, rhs: rhs.askingPrice)
        case .status:
            return statusText(lhs).localizedCaseInsensitiveCompare(statusText(rhs))
        }
    }

    private func compareBoard(lhs: TransferPortalEntry, rhs: TransferPortalEntry, column: BoardTableColumn) -> ComparisonResult {
        switch column {
        case .player:
            return lhs.playerName.localizedCaseInsensitiveCompare(rhs.playerName)
        case .position:
            return lhs.position.localizedCaseInsensitiveCompare(rhs.position)
        case .overall:
            return numericCompare(lhs: lhs.overall, rhs: rhs.overall)
        case .points:
            return numericCompare(lhs: lhs.stats?.pointsPerGame ?? -1, rhs: rhs.stats?.pointsPerGame ?? -1)
        case .ask:
            return numericCompare(lhs: lhs.askingPrice, rhs: rhs.askingPrice)
        case .offer:
            return numericCompare(lhs: summary?.userOffers[lhs.id] ?? 0, rhs: summary?.userOffers[rhs.id] ?? 0)
        case .interest:
            return numericCompare(lhs: userInterest(lhs), rhs: userInterest(rhs))
        case .finalists:
            return finalistsText(lhs).localizedCaseInsensitiveCompare(finalistsText(rhs))
        case .status:
            return statusText(lhs).localizedCaseInsensitiveCompare(statusText(rhs))
        case .actions:
            return lhs.playerName.localizedCaseInsensitiveCompare(rhs.playerName)
        }
    }

    private func numericCompare<T: Comparable>(lhs: T, rhs: T) -> ComparisonResult {
        if lhs < rhs { return .orderedAscending }
        if lhs > rhs { return .orderedDescending }
        return .orderedSame
    }

    private func userInterest(_ row: TransferPortalEntry) -> Double {
        row.interestByTeamId[summary?.userTeamId ?? ""] ?? 0
    }

    private func interestText(_ row: TransferPortalEntry) -> String {
        let interest = userInterest(row)
        return interest > 0 ? "\(Int(interest.rounded()))" : "-"
    }

    private func finalistsText(_ row: TransferPortalEntry) -> String {
        row.finalistTeamNames.isEmpty ? "-" : row.finalistTeamNames.joined(separator: ", ")
    }

    private func statusText(_ row: TransferPortalEntry) -> String {
        if let committed = row.committedTeamName {
            return "Committed \(committed)"
        }
        if row.previousTeamId == summary?.userTeamId {
            return "From you"
        }
        if row.finalistTeamIds.contains(summary?.userTeamId ?? "") {
            return "Finalist"
        }
        if targetIds.contains(row.id) {
            return "On board"
        }
        if row.finalistTeamNames.isEmpty {
            return "Open"
        }
        return "Finalists"
    }

    private func statText(_ value: Double?) -> String {
        guard let value else { return "-" }
        return String(format: "%.1f", value)
    }

    private func summaryTile(title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.monospacedDigit().weight(.black))
                .foregroundStyle(AppTheme.ink)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func playerProfile(_ row: TransferPortalEntry) -> UserRosterPlayerSummary {
        row.player ?? UserRosterPlayerSummary(
            playerIndex: -1,
            name: row.playerName,
            position: row.position,
            year: row.year,
            home: nil,
            height: nil,
            weight: nil,
            wingspan: nil,
            overall: row.overall,
            isStarter: false,
            attributes: ["potential": row.potential]
        )
    }

    private func average(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }

    private func moneyText(_ amount: Double) -> String {
        nilMoneyText(amount)
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
