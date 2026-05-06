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

    @State var league: LeagueState?
    @State var statusText: String = ""
    @State var roster: [UserRosterPlayerSummary] = []
    @State var schedule: [UserGameSummary] = []
    @State var rotationSlots: [UserRotationSlot] = []
    @State var coachingStaff: UserCoachingStaffSummary?
    @State var summary: LeagueSummary?
    @State var conferenceStandings: [String: [ConferenceStanding]] = [:]
    @State var conferenceNamesById: [String: String] = [:]
    @State var rankings: LeagueRankings?
    @State var nationalBracket: NationalTournamentBracket?
    @State var nilBudgetSummary: NILBudgetSummary?
    @State var playersLeavingSummary: PlayersLeavingSummary?
    @State var draftSummary: DraftSummary?
    @State var nilRetentionSummary: NILRetentionSummary?
    @State var transferPortalSummary: TransferPortalSummary?
    @State var hallOfFameSummary: SchoolHallOfFameSummary?
    @State var offseasonProgress: LeagueOffseasonProgress?
    @State var completedLeagueGames: [LeagueGameSummary] = []
    @State var teamRostersByName: [String: [UserRosterPlayerSummary]] = [:]
    @State var teamStatsById: [String: TeamAggregateStats] = [:]
    @State var showingSkipAheadOptions = false
    @State var isSkipAheadInProgress = false
    @State var skipAheadTitle = ""
    @State var skipAheadGameRecaps: [String] = []
    @State var showingSeasonRecap = false
    @State var showingOffseasonSchedule = false
    @State var navigationPath: [LeagueMenuDestination] = []
    @State var offseasonAdvanceLoading: OffseasonAdvanceLoadingContext?
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
        NavigationStack(path: $navigationPath) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(teamHeaderText)
                            .font(.title.bold())
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                            .allowsTightening(true)
                    }

                    if let lastPlayed = latestCompletedGame {
                        GameCard {
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
                        Button(primaryAdvanceButtonTitle) {
                            if seasonIsComplete {
                                navigationPath.append(.seasonRecap)
                            } else {
                                playNextGame()
                            }
                        }
                        .buttonStyle(GameButtonStyle(variant: .primary))
                        .disabled(isSkipAheadInProgress || offseasonAdvanceLoading != nil)

                        if !seasonIsComplete {
                            Button("Skip Ahead") {
                                if hasSkipAheadTargets {
                                    showingSkipAheadOptions = true
                                } else {
                                    statusText = "Already at the offseason checkpoint."
                                }
                            }
                            .buttonStyle(GameButtonStyle(variant: .secondary))
                            .disabled(isSkipAheadInProgress || offseasonAdvanceLoading != nil)
                        }
                    }

                    GameCard {
                        VStack(spacing: 8) {
                            if nationalBracket != nil {
                                NavigationLink(value: LeagueMenuDestination.bracket) {
                                    MenuRow(title: "Bracket")
                                }
                                .buttonStyle(.plain)
                            }

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

                            NavigationLink(value: LeagueMenuDestination.playbook) {
                                MenuRow(title: "Playbook")
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

                            GameSectionHeader(title: "League")
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

                            NavigationLink(value: LeagueMenuDestination.hallOfFame) {
                                MenuRow(title: "Hall of Fame")
                            }
                            .buttonStyle(.plain)

                            NavigationLink(value: LeagueMenuDestination.schoolLegacies) {
                                MenuRow(title: "School Legacies")
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Button("Create New Coach") {
                        onCreateNewCoach()
                    }
                    .buttonStyle(GameButtonStyle(variant: .danger, size: .compact))
                    .disabled(isSkipAheadInProgress || offseasonAdvanceLoading != nil)
                }
                .padding(20)
            }
            .background(AppTheme.background)
            .navigationDestination(for: LeagueMenuDestination.self) { destination in
                Group {
                switch destination {
                case .seasonRecap:
                    SeasonRecapView(
                        games: completedLeagueGames,
                        schedule: schedule,
                        userTeamId: summary?.userTeamId,
                        userTeamName: summary?.userTeamName ?? teamName,
                        userConferenceId: userConferenceId,
                        standingsByConference: conferenceStandings,
                        conferenceNamesById: conferenceNamesById,
                        bracket: nationalBracket,
                        nilBudgetSummary: nilBudgetSummary,
                        playersLeavingSummary: playersLeavingSummary,
                        draftSummary: draftSummary,
                        nilRetentionSummary: nilRetentionSummary,
                        transferPortalSummary: transferPortalSummary,
                        hallOfFameSummary: hallOfFameSummary,
                        roster: roster,
                        teamRostersByName: teamRostersByName,
                        onAdvanceToOffseasonSchedule: advanceToOffseasonScheduleFromRecap
                    )
                case .offseasonSchedule:
                    OffseasonScheduleView(
                        progress: offseasonProgress,
                        nilBudgetSummary: nilBudgetSummary,
                        playersLeavingSummary: playersLeavingSummary,
                        draftSummary: draftSummary,
                        nilRetentionSummary: nilRetentionSummary,
                        transferPortalSummary: transferPortalSummary,
                        hallOfFameSummary: hallOfFameSummary,
                        games: completedLeagueGames,
                        teamRostersByName: teamRostersByName,
                        onAdvance: advanceOffseasonScheduleAndNavigate
                    )
                case .nilBudgets:
                    NILBudgetView(
                        summary: nilBudgetSummary,
                        onAdvance: advanceOffseasonScheduleAndNavigate
                    )
                case .playersLeaving:
                    PlayersLeavingView(
                        summary: playersLeavingSummary,
                        hallOfFameSummary: hallOfFameSummary,
                        games: completedLeagueGames,
                        teamRostersByName: teamRostersByName,
                        onAdvance: advanceOffseasonScheduleAndNavigate
                    )
                case .draft:
                    DraftView(
                        summary: draftSummary,
                        games: completedLeagueGames,
                        onAdvance: advanceOffseasonScheduleAndNavigate
                    )
                case .playerRetention:
                    NILRetentionView(
                        summary: nilRetentionSummary,
                        games: completedLeagueGames,
                        onSetOffer: setNILRetentionOffer,
                        onSubmitOffer: submitNILRetentionOffer,
                        onMeetDemand: meetNILRetentionDemand,
                        onDelegate: delegateNILRetention,
                        onAdvance: advanceOffseasonScheduleAndNavigate
                    )
                case .transferPortal:
                    TransferPortalView(
                        summary: transferPortalSummary,
                        games: completedLeagueGames,
                        roster: retainedRoster,
                        userTeamName: summary?.userTeamName ?? teamName,
                        onSetTargeted: setTransferPortalTargeted,
                        onSetOffer: setTransferPortalOffer,
                        onAdvance: advanceOffseasonScheduleAndNavigate
                    )
                case .roster:
                    RosterRatingsView(
                        roster: roster,
                        games: completedLeagueGames,
                        userTeamName: summary?.userTeamName ?? teamName
                    )
                case .schedule:
                    ScheduleListView(
                        schedule: schedule,
                        userTeamName: summary?.userTeamName ?? teamName,
                        games: completedLeagueGames,
                        roster: roster,
                        teamRostersByName: teamRostersByName
                    )
                case .rotation:
                    RotationSettingsView(
                        roster: roster,
                        slots: rotationSlots,
                        onSave: { updated in
                            saveRotation(updated)
                        }
                    )
                case .playbook:
                    PlaybookView(
                        playbook: league.flatMap { getUserPlaybook($0) },
                        onSave: { pace, defense, weights in
                            savePlaybook(pace: pace, defenseScheme: defense, offenseWeights: weights)
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
                        teamStatsById: teamStatsById,
                        userTeamId: summary?.userTeamId,
                        userConferenceId: userConferenceId,
                        conferenceIdByTeamId: conferenceIdByTeamId,
                        userRank: rankings?.rankings.first(where: { $0.teamId == summary?.userTeamId })?.rank
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
                case .bracket:
                    NationalBracketView(
                        bracket: nationalBracket,
                        userTeamId: summary?.userTeamId
                    )
                case .coachingStaff:
                    CoachingStaffView(
                        staff: coachingStaff,
                        onSetAssistantFocus: { index, focus in
                            saveAssistantFocus(assistantIndex: index, focus: focus)
                        }
                    )
                case .hallOfFame:
                    SchoolHallOfFameView(
                        summary: hallOfFameSummary,
                        games: completedLeagueGames,
                        userTeamName: summary?.userTeamName ?? teamName
                    )
                case .schoolLegacies:
                    SchoolLegaciesView(summary: league.map { getSchoolLegaciesSummary($0) })
                case .boxScore(let gameId):
                    if let game = schedule.first(where: { $0.gameId == gameId }) {
                        BoxScoreDetailView(
                            game: game,
                            userTeamName: summary?.userTeamName ?? teamName,
                            games: completedLeagueGames,
                            roster: roster,
                            teamRostersByName: teamRostersByName
                        )
                    }
                }
                }
                .navigationBarBackButtonHidden(destination.isOffseasonWorkflowDestination)
            }
            .navigationDestination(isPresented: $showingSeasonRecap) {
                SeasonRecapView(
                    games: completedLeagueGames,
                    schedule: schedule,
                    userTeamId: summary?.userTeamId,
                    userTeamName: summary?.userTeamName ?? teamName,
                    userConferenceId: userConferenceId,
                    standingsByConference: conferenceStandings,
                    conferenceNamesById: conferenceNamesById,
                    bracket: nationalBracket,
                    nilBudgetSummary: nilBudgetSummary,
                    playersLeavingSummary: playersLeavingSummary,
                    draftSummary: draftSummary,
                    nilRetentionSummary: nilRetentionSummary,
                    transferPortalSummary: transferPortalSummary,
                    hallOfFameSummary: hallOfFameSummary,
                    roster: roster,
                    teamRostersByName: teamRostersByName,
                    onAdvanceToOffseasonSchedule: advanceToOffseasonScheduleFromRecap
                )
                .navigationBarBackButtonHidden(true)
            }
            .navigationDestination(isPresented: $showingOffseasonSchedule) {
                OffseasonScheduleView(
                    progress: offseasonProgress,
                    nilBudgetSummary: nilBudgetSummary,
                    playersLeavingSummary: playersLeavingSummary,
                    draftSummary: draftSummary,
                    nilRetentionSummary: nilRetentionSummary,
                    transferPortalSummary: transferPortalSummary,
                    hallOfFameSummary: hallOfFameSummary,
                    games: completedLeagueGames,
                    teamRostersByName: teamRostersByName,
                    onAdvance: advanceOffseasonScheduleAndNavigate
                )
                .navigationBarBackButtonHidden(true)
            }
            .onAppear {
                if league == nil {
                    if let restored = LeagueStore.load(expectedTeam: teamName) {
                        league = restored
                        refreshFromLeague(restored)
                        statusText = ""
                    } else {
                        createLeague()
                    }
                }
            }
            .onChange(of: league) { _, newValue in
                if let newValue {
                    LeagueStore.save(newValue, teamName: teamName)
                }
            }
            .onChange(of: scenePhase) { _, phase in
                LeagueSimulationPauseGate.setPaused(phase != .active)
                if phase != .active, let league {
                    LeagueStore.save(league, teamName: teamName)
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

                if canSkipToSelectionSunday {
                    Button("Selection Sunday") {
                        startSkipAhead(target: .selectionSunday)
                    }
                }

                if canSkipToOffseason {
                    Button("Offseason") {
                        startSkipAhead(target: .offseason)
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

            if let offseasonAdvanceLoading {
                OffseasonAdvanceLoadingView(context: offseasonAdvanceLoading)
                    .transition(.opacity)
                    .zIndex(1)
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

    private var seasonIsComplete: Bool {
        summary?.status == "completed"
    }

    private var primaryAdvanceButtonTitle: String {
        seasonIsComplete ? "Start Offseason" : "Sim Next User Game"
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

    private var canSkipToSelectionSunday: Bool {
        nationalBracket == nil && !seasonIsComplete
    }

    private var canSkipToOffseason: Bool {
        !seasonIsComplete
    }

    private var hasSkipAheadTargets: Bool {
        canSkipToMidseason || canSkipToEndRegularSeason || canSkipToSelectionSunday || canSkipToOffseason
    }

    private func createLeague() {
        do {
            let leagueSeed = "ios-league-\(UUID().uuidString.lowercased())"
            var options = CreateLeagueOptions(userTeamName: teamName, seed: leagueSeed)
            options.userHeadCoachName = profile.fullName
            options.userHeadCoachSkills = profile.archetype.initialSkills
            options.userHeadCoachAlmaMater = profile.almaMater
            options.userHeadCoachPipelineState = profile.pipelineState
            options.userPace = (UserDefaults.standard.string(forKey: "coachPace").flatMap(PaceProfile.init(rawValue:))) ?? profile.pace
            options.userDefenseScheme = (UserDefaults.standard.string(forKey: "coachDefense").flatMap(DefenseScheme.init(rawValue:))) ?? profile.defense
            if let data = UserDefaults.standard.data(forKey: "coachOffenseWeights"),
               let dict = try? JSONDecoder().decode([String: Int].self, from: data),
               dict.values.contains(where: { $0 > 0 }) {
                options.userOffenseWeights = dict
            } else {
                options.userOffenseWeights = [profile.offense.rawValue: 100]
            }
            let created = try createD1League(options: options)
            league = created
            refreshFromLeague(created)
            statusText = ""
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
            navigationPath.append(.seasonRecap)
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

        Task(priority: .utility) {
            await Task.yield()
            let result = await Task.detached(priority: .utility) {
                await Self.runSkipAhead(from: startingLeague, target: target) { recaps in
                    await MainActor.run {
                        skipAheadGameRecaps = recaps
                    }
                }
            }.value
            await MainActor.run {
                league = result.league
                refreshFromLeague(result.league, includeDeferredData: false)
                applyDeferredRefresh(result.deferredData)
                skipAheadGameRecaps = result.recaps
                statusText = result.seasonCompleted && target != .offseason ? "Season complete." : target.completionMessage
                isSkipAheadInProgress = false
                if target == .offseason || result.seasonCompleted {
                    navigationPath.append(.seasonRecap)
                }
            }
        }
    }

    private static func runSkipAhead(
        from league: LeagueState,
        target: SkipAheadTarget,
        onRecapsUpdated: @Sendable ([String]) async -> Void
    ) async -> SkipAheadSimulationResult {
        switch target {
        case .selectionSunday, .offseason:
            return await runSeasonCheckpointSkipAhead(from: league, target: target, onRecapsUpdated: onRecapsUpdated)
        case .midseason, .endOfRegularSeason:
            break
        }

        var currentLeague = league
        let userTeamName = getLeagueSummary(league).userTeamName
        let initialCompletedGames = getUserSchedule(currentLeague).filter { $0.completed == true }.count
        let gamesNeeded = max(0, target.completedGames - initialCompletedGames)

        var completedResults: [UserGameSummary] = []
        var allBoxScoresByGameId: [String: [TeamBoxScore]] = [:]
        var liveRecaps: [String] = []
        var seasonCompleted = false
        var remaining = gamesNeeded
        let chunkSize = 5

        while remaining > 0 {
            let request = min(chunkSize, remaining)
            let batch = advanceUserGames(&currentLeague, maxGames: request)
            if batch.results.isEmpty {
                seasonCompleted = seasonCompleted || batch.seasonCompleted
                break
            }
            for (offset, result) in batch.results.enumerated() {
                let gameNumber = initialCompletedGames + completedResults.count + offset + 1
                let boxScore = result.gameId.flatMap { batch.boxScoresByGameId[$0] }
                liveRecaps.append(
                    Self.skipAheadGameRecap(
                        for: result,
                        gameNumber: gameNumber,
                        userTeamName: userTeamName,
                        boxScore: boxScore
                    )
                )
            }
            completedResults.append(contentsOf: batch.results)
            allBoxScoresByGameId.merge(batch.boxScoresByGameId, uniquingKeysWith: { _, new in new })
            remaining -= batch.results.count
            if batch.seasonCompleted {
                seasonCompleted = true
                break
            }
            let snapshot = liveRecaps
            await onRecapsUpdated(snapshot)
            await Task.yield()
        }

        return SkipAheadSimulationResult(
            league: currentLeague,
            seasonCompleted: seasonCompleted,
            recaps: liveRecaps,
            deferredData: Self.buildDeferredRefreshData(for: currentLeague)
        )
    }

    private static func runSeasonCheckpointSkipAhead(
        from league: LeagueState,
        target: SkipAheadTarget,
        onRecapsUpdated: @Sendable ([String]) async -> Void
    ) async -> SkipAheadSimulationResult {
        var currentLeague = league
        let userTeamName = getLeagueSummary(league).userTeamName
        let initialCompletedGames = getUserSchedule(currentLeague).filter { $0.completed == true }.count
        let checkpoint: LeagueSeasonCheckpoint = target == .selectionSunday ? .selectionSunday : .offseason
        let batch = advanceToSeasonCheckpoint(&currentLeague, checkpoint: checkpoint)
        let recaps = batch.results.enumerated().map { offset, result in
            Self.skipAheadGameRecap(
                for: result,
                gameNumber: initialCompletedGames + offset + 1,
                userTeamName: userTeamName,
                boxScore: result.gameId.flatMap { batch.boxScoresByGameId[$0] }
            )
        }

        await onRecapsUpdated(recaps)

        return SkipAheadSimulationResult(
            league: currentLeague,
            seasonCompleted: batch.seasonCompleted,
            recaps: recaps,
            deferredData: Self.buildDeferredRefreshData(for: currentLeague)
        )
    }

    private static func skipAheadGameScoreRecap(for result: UserGameSummary, gameNumber: Int, userTeamName _: String) -> String {
        let userScore = result.score?.numberValue(for: "user")?.roundedInt ?? 0
        let oppScore = result.score?.numberValue(for: "opponent")?.roundedInt ?? 0
        let opponent = result.opponentName ?? "Unknown"
        let resultMarker = result.won == true ? "W" : "L"
        return "Game \(gameNumber) vs \(opponent): \(userScore)-\(oppScore) (\(resultMarker))"
    }

    private static func skipAheadGameRecap(for result: UserGameSummary, gameNumber: Int, userTeamName: String, boxScore: [TeamBoxScore]? = nil) -> String {
        let userScore = result.score?.numberValue(for: "user")?.roundedInt ?? 0
        let oppScore = result.score?.numberValue(for: "opponent")?.roundedInt ?? 0
        let opponent = result.opponentName ?? "Unknown"
        let resultMarker = result.won == true ? "W" : "L"
        let leaders = userLeadersFromResult(result, userTeamName: userTeamName, boxScore: boxScore)
        return "Game \(gameNumber) vs \(opponent): \(userScore)-\(oppScore) (\(resultMarker)) | PTS: \(leaders.points) | REB: \(leaders.rebounds) | AST: \(leaders.assists)"
    }

    private static func userLeadersFromResult(_ result: UserGameSummary, userTeamName: String, boxScore: [TeamBoxScore]? = nil) -> (points: String, rebounds: String, assists: String) {
        if let boxScore,
           let userBox = resolveUserTeamBox(from: boxScore, for: result, userTeamName: userTeamName) {
            let pointsLeader = topLeader(in: userBox.players, stat: \.points)
            let reboundsLeader = topLeader(in: userBox.players, stat: \.rebounds)
            let assistsLeader = topLeader(in: userBox.players, stat: \.assists)
            return (
                pointsLeader.map { "\($0.player.playerName) \($0.value)" } ?? "N/A",
                reboundsLeader.map { "\($0.player.playerName) \($0.value)" } ?? "N/A",
                assistsLeader.map { "\($0.player.playerName) \($0.value)" } ?? "N/A"
            )
        }

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

    private static func resolveUserTeamBox(from teams: [TeamBoxScore], for result: UserGameSummary, userTeamName: String) -> TeamBoxScore? {
        guard !teams.isEmpty else { return nil }

        if let exact = teams.first(where: { $0.name.caseInsensitiveCompare(userTeamName) == .orderedSame }) {
            return exact
        }

        if result.isHome == true {
            return teams.first
        }
        if result.isHome == false, teams.count > 1 {
            return teams[1]
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

    private static func topLeader(in players: [PlayerBoxScore], stat: KeyPath<PlayerBoxScore, Int>) -> (player: PlayerBoxScore, value: Int)? {
        players
            .map { ($0, $0[keyPath: stat]) }
            .max { lhs, rhs in
                if lhs.1 != rhs.1 { return lhs.1 < rhs.1 }
                return lhs.0.playerName.localizedCaseInsensitiveCompare(rhs.0.playerName) == .orderedDescending
            }
    }

}
