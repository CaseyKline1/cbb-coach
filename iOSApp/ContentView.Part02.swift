import SwiftUI
import UniformTypeIdentifiers
import CBBCoachCore

struct OnboardingStepScaffold<Content: View>: View {
    let title: String
    let subtitle: String
    let navTitle: String
    let nextLabel: String
    let nextDisabled: Bool
    let onNext: () -> Void
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    VStack(spacing: 6) {
                        Text(title)
                            .font(.title2.weight(.black))
                            .multilineTextAlignment(.center)
                        Text(subtitle)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }

                    content()

                    Button(action: onNext) {
                        Text(nextLabel)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(GameButtonStyle(variant: .primary))
                    .disabled(nextDisabled)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
        }
        .navigationTitle(navTitle)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct CollegeLeagueHomeView: View {
    let profile: CoachCreationProfile
    let teamName: String
    let onChooseDifferentTeam: () -> Void
    let onCreateNewCoach: () -> Void

    @State private var league: LeagueState?
    @State private var statusText: String = "Creating league..."
    @State private var roster: [UserRosterPlayerSummary] = []
    @State private var schedule: [UserGameSummary] = []
    @State private var rotationSlots: [UserRotationSlot] = []
    @State private var coachingStaff: UserCoachingStaffSummary?
    @State private var summary: LeagueSummary?
    @State private var conferenceStandings: [String: [ConferenceStanding]] = [:]
    @State private var conferenceNamesById: [String: String] = [:]
    @State private var rankings: LeagueRankings?
    @State private var completedLeagueGames: [LeagueGameSummary] = []
    @State private var teamRostersByName: [String: [UserRosterPlayerSummary]] = [:]
    @State private var showingSkipAheadOptions = false
    @State private var isSkipAheadInProgress = false
    @State private var skipAheadTitle = ""
    @State private var skipAheadGameRecaps: [String] = []

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(teamHeaderText)
                            .font(.largeTitle.bold())
                    }

                    if let lastPlayed = latestCompletedGame {
                        GameCard {
                            GameSectionHeader(title: "Last Result")
                            NavigationLink(value: LeagueMenuDestination.boxScore(lastPlayed.gameId ?? "")) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Game \(gameNumber(for: lastPlayed)): \(lastPlayed.isHome == true ? "vs" : "@") \(lastPlayed.opponentName ?? "Unknown")")
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(.primary)
                                        Text(resultSummaryText(for: lastPlayed))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    HStack(spacing: 10) {
                        Button("Sim Next User Game") {
                            playNextGame()
                        }
                        .buttonStyle(GameButtonStyle(variant: .primary))
                        .disabled(isSkipAheadInProgress)

                        Button("Skip Ahead") {
                            if canSkipToMidseason || canSkipToEndRegularSeason {
                                showingSkipAheadOptions = true
                            } else {
                                statusText = "Already past midseason and end of regular season checkpoints."
                            }
                        }
                        .buttonStyle(GameButtonStyle(variant: .secondary))
                        .disabled(isSkipAheadInProgress)
                    }

                    if let summary {
                        HStack(spacing: 14) {
                            StatChip(title: "Game", value: "\(summary.currentDay)")
                            StatChip(title: "Record", value: userRecordText)
                        }
                    }

                    GameCard {
                        VStack(spacing: 8) {
                            GameSectionHeader(title: "Team")
                            NavigationLink(value: LeagueMenuDestination.roster) {
                                MenuRow(title: "Roster")
                            }
                            .buttonStyle(.plain)

                            NavigationLink(value: LeagueMenuDestination.schedule) {
                                MenuRow(title: "Schedule")
                            }
                            .buttonStyle(.plain)

                            NavigationLink(value: LeagueMenuDestination.rotation) {
                                MenuRow(title: "Rotation")
                            }
                            .buttonStyle(.plain)

                            NavigationLink(value: LeagueMenuDestination.playerStats) {
                                MenuRow(title: "Player Stats")
                            }
                            .buttonStyle(.plain)

                            NavigationLink(value: LeagueMenuDestination.teamStats) {
                                MenuRow(title: "Team Stats")
                            }
                            .buttonStyle(.plain)

                            NavigationLink(value: LeagueMenuDestination.statLeaders) {
                                MenuRow(title: "Stat Leaders")
                            }
                            .buttonStyle(.plain)

                            NavigationLink(value: LeagueMenuDestination.standings) {
                                MenuRow(title: "Standings")
                            }
                            .buttonStyle(.plain)

                            NavigationLink(value: LeagueMenuDestination.rankings) {
                                MenuRow(title: "Rankings")
                            }
                            .buttonStyle(.plain)

                            NavigationLink(value: LeagueMenuDestination.coachingStaff) {
                                MenuRow(title: "Coaching Staff")
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    GameCard {
                        Text(statusText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Button("Create New Coach") {
                        onCreateNewCoach()
                    }
                    .buttonStyle(GameButtonStyle(variant: .danger, size: .compact))
                    .disabled(isSkipAheadInProgress)
                }
                .padding(20)
            }
            .background(AppTheme.background)
            .navigationDestination(for: LeagueMenuDestination.self) { destination in
                switch destination {
                case .roster:
                    RosterRatingsView(
                        roster: roster,
                        games: completedLeagueGames,
                        userTeamName: summary?.userTeamName ?? teamName
                    )
                case .schedule:
                    ScheduleListView(schedule: schedule, userTeamName: summary?.userTeamName ?? teamName)
                case .rotation:
                    RotationSettingsView(
                        roster: roster,
                        slots: rotationSlots,
                        onSave: { updated in
                            saveRotation(updated)
                        }
                    )
                case .playerStats:
                    PlayerStatsView(
                        schedule: schedule,
                        games: completedLeagueGames,
                        userTeamName: summary?.userTeamName ?? teamName,
                        roster: roster,
                        teamRostersByName: teamRostersByName
                    )
                case .teamStats:
                    TeamStatsView(
                        games: completedLeagueGames,
                        userTeamId: summary?.userTeamId,
                        userConferenceId: userConferenceId,
                        conferenceIdByTeamId: conferenceIdByTeamId
                    )
                case .statLeaders:
                    StatLeadersView(
                        games: completedLeagueGames,
                        userTeamName: summary?.userTeamName ?? teamName,
                        roster: roster,
                        teamRostersByName: teamRostersByName
                    )
                case .standings:
                    ConferenceStandingsView(
                        standingsByConference: conferenceStandings,
                        conferenceNamesById: conferenceNamesById,
                        preferredConferenceId: userConferenceId
                    )
                case .rankings:
                    RankingsView(
                        rankings: rankings,
                        userTeamId: summary?.userTeamId
                    )
                case .coachingStaff:
                    CoachingStaffView(
                        staff: coachingStaff,
                        onSetAssistantFocus: { index, focus in
                            saveAssistantFocus(assistantIndex: index, focus: focus)
                        }
                    )
                case .boxScore(let gameId):
                    if let game = schedule.first(where: { $0.gameId == gameId }) {
                        BoxScoreDetailView(game: game, userTeamName: summary?.userTeamName ?? teamName)
                    }
                }
            }
            .onAppear {
                if league == nil {
                    createLeague()
                }
            }
            .confirmationDialog("Skip Ahead", isPresented: $showingSkipAheadOptions, titleVisibility: .visible) {
                if canSkipToMidseason {
                    Button("Midseason") {
                        startSkipAhead(target: .midseason)
                    }
                }

                if canSkipToEndRegularSeason {
                    Button("End of Regular Season") {
                        startSkipAhead(target: .endOfRegularSeason)
                    }
                }

                Button("Cancel", role: .cancel) {}
            }
            .overlay {
                if isSkipAheadInProgress {
                    SkipAheadOverlayView(
                        title: skipAheadTitle,
                        recaps: skipAheadGameRecaps
                    )
                }
            }
        }
    }

    private var userRecordText: String {
        let completedGames = schedule.filter { $0.completed == true }
        let wins = completedGames.filter {
            guard let result = $0.result else { return false }
            let home = result.intValue(for: "homeScore") ?? 0
            let away = result.intValue(for: "awayScore") ?? 0
            return $0.isHome == true ? home > away : away > home
        }.count
        return "\(wins)-\(max(0, completedGames.count - wins))"
    }

    private var userRanking: Int? {
        guard let userTeamId = summary?.userTeamId else { return nil }
        return rankings?.rankings.first(where: { $0.teamId == userTeamId })?.rank
    }

    private var teamHeaderText: String {
        let rankingPrefix = userRanking.map { "#\($0) " } ?? ""
        return "\(rankingPrefix)\(teamName) (\(userRecordText))"
    }

    private var orderedSchedule: [UserGameSummary] {
        schedule.sorted {
            let lhsDay = $0.day ?? Int.max
            let rhsDay = $1.day ?? Int.max
            if lhsDay != rhsDay {
                return lhsDay < rhsDay
            }
            return ($0.gameId ?? "") < ($1.gameId ?? "")
        }
    }

    private var latestCompletedGame: UserGameSummary? {
        orderedSchedule.last { $0.completed == true && $0.gameId != nil }
    }

    private func gameNumber(for game: UserGameSummary) -> Int {
        if let gameId = game.gameId, let index = orderedSchedule.firstIndex(where: { $0.gameId == gameId }) {
            return index + 1
        }
        if let index = orderedSchedule.firstIndex(of: game) {
            return index + 1
        }
        return max(1, game.day ?? 1)
    }

    private var userConferenceId: String? {
        listCareerTeamOptions().first(where: { $0.teamName == teamName })?.conferenceId
    }

    private var conferenceIdByTeamId: [String: String] {
        var result: [String: String] = [:]
        for rows in conferenceStandings.values {
            for row in rows {
                result[row.teamId] = row.conferenceId
            }
        }
        return result
    }

    private var completedUserGameCount: Int {
        schedule.filter { $0.completed == true }.count
    }

    private var canSkipToMidseason: Bool {
        completedUserGameCount < 15
    }

    private var canSkipToEndRegularSeason: Bool {
        completedUserGameCount < 31
    }

    private func createLeague() {
        do {
            let leagueSeed = "ios-league-\(UUID().uuidString.lowercased())"
            var options = CreateLeagueOptions(userTeamName: teamName, seed: leagueSeed)
            options.userHeadCoachName = profile.fullName
            options.userHeadCoachSkills = profile.archetype.initialSkills
            options.userHeadCoachAlmaMater = profile.almaMater
            options.userHeadCoachPipelineState = profile.pipelineState
            let created = try createD1League(options: options)
            league = created
            refreshFromLeague(created)
            let leagueSummary = summary ?? getLeagueSummary(created)
            statusText = "\(leagueSummary.userTeamName): \(leagueSummary.totalScheduledGames) total games generated"
        } catch {
            statusText = "League error: \(error.localizedDescription)"
        }
    }

    private func playNextGame() {
        guard var currentLeague = league else { return }
        guard let result = advanceToNextUserGame(&currentLeague) else { return }
        league = currentLeague
        refreshFromLeague(currentLeague)
        if result.done == true {
            statusText = "Season complete."
            return
        }
        let userScore = result.score?.numberValue(for: "user")?.roundedInt ?? 0
        let oppScore = result.score?.numberValue(for: "opponent")?.roundedInt ?? 0
        let gameLabel = gameNumber(for: result)
        statusText = "Game \(gameLabel): \(result.opponentName ?? "Unknown") \(userScore)-\(oppScore) (\(result.won == true ? "W" : "L"))"
    }

    private func startSkipAhead(target: SkipAheadTarget) {
        guard !isSkipAheadInProgress else { return }
        guard let startingLeague = league else { return }
        isSkipAheadInProgress = true
        skipAheadTitle = target.overlayTitle
        skipAheadGameRecaps = []

        Task(priority: .userInitiated) {
            let result = await runSkipAhead(from: startingLeague, target: target)
            await MainActor.run {
                league = result.league
                refreshFromLeague(result.league)
                skipAheadGameRecaps = result.recaps
                statusText = result.seasonCompleted ? "Season complete." : target.completionMessage
                isSkipAheadInProgress = false
            }
        }
    }

    private func runSkipAhead(from league: LeagueState, target: SkipAheadTarget) async -> SkipAheadSimulationResult {
        var currentLeague = league
        let userTeamName = getLeagueSummary(league).userTeamName
        var completedGames = getUserSchedule(currentLeague).filter { $0.completed == true }.count
        var seasonCompleted = false
        var recaps: [String] = []

        while completedGames < target.completedGames {
            guard let result = advanceToNextUserGame(&currentLeague) else { break }
            if result.done == true {
                seasonCompleted = true
                break
            }
            completedGames += 1
            let recap = Self.skipAheadGameRecap(
                for: result,
                gameNumber: completedGames,
                userTeamName: userTeamName
            )
            recaps.append(recap)
            if recaps.count % 2 == 0 {
                let snapshot = recaps
                await MainActor.run {
                    skipAheadGameRecaps = snapshot
                }
            }
            await Task.yield()
        }

        return SkipAheadSimulationResult(
            league: currentLeague,
            seasonCompleted: seasonCompleted,
            recaps: recaps
        )
    }

    private static func skipAheadGameRecap(for result: UserGameSummary, gameNumber: Int, userTeamName: String) -> String {
        let userScore = result.score?.numberValue(for: "user")?.roundedInt ?? 0
        let oppScore = result.score?.numberValue(for: "opponent")?.roundedInt ?? 0
        let opponent = result.opponentName ?? "Unknown"
        let resultMarker = result.won == true ? "W" : "L"
        let leaders = userLeadersFromResult(result, userTeamName: userTeamName)
        return "Game \(gameNumber) vs \(opponent): \(userScore)-\(oppScore) (\(resultMarker)) | PTS: \(leaders.points) | REB: \(leaders.rebounds) | AST: \(leaders.assists)"
    }

    private static func userLeadersFromResult(_ result: UserGameSummary, userTeamName: String) -> (points: String, rebounds: String, assists: String) {
        let teamBox = ParsedTeamBoxScore.parse(from: result.result)
        guard let userBox = resolveUserTeamBox(from: teamBox, for: result, userTeamName: userTeamName) else {
            return ("N/A", "N/A", "N/A")
        }

        let pointsLeader = topLeader(in: userBox.players, stat: \.points)
        let reboundsLeader = topLeader(in: userBox.players, stat: \.rebounds)
        let assistsLeader = topLeader(in: userBox.players, stat: \.assists)

        return (
            pointsLeader.map { "\($0.player.playerName) \($0.value)" } ?? "N/A",
            reboundsLeader.map { "\($0.player.playerName) \($0.value)" } ?? "N/A",
            assistsLeader.map { "\($0.player.playerName) \($0.value)" } ?? "N/A"
        )
    }

    private static func resolveUserTeamBox(from teams: [ParsedTeamBoxScore], for result: UserGameSummary, userTeamName: String) -> ParsedTeamBoxScore? {
        guard !teams.isEmpty else { return nil }

        if let exact = teams.first(where: { $0.name.caseInsensitiveCompare(userTeamName) == .orderedSame }) {
            return exact
        }

        if let opponentName = result.opponentName,
           let notOpponent = teams.first(where: { $0.name.caseInsensitiveCompare(opponentName) != .orderedSame }) {
            return notOpponent
        }

        return teams.first
    }

    private static func topLeader(in players: [ParsedPlayerBoxScore], stat: KeyPath<ParsedPlayerBoxScore, Int>) -> (player: ParsedPlayerBoxScore, value: Int)? {
        players
            .map { ($0, $0[keyPath: stat]) }
            .max { lhs, rhs in
                if lhs.1 != rhs.1 { return lhs.1 < rhs.1 }
                return lhs.0.playerName.localizedCaseInsensitiveCompare(rhs.0.playerName) == .orderedDescending
            }
    }

}
