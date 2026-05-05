import SwiftUI
import UniformTypeIdentifiers
import CBBCoachCore

struct DeferredLeagueRefreshData: Sendable {
    let conferenceStandings: [String: [ConferenceStanding]]
    let conferenceNamesById: [String: String]
    let completedLeagueGames: [LeagueGameSummary]
    let teamRostersByName: [String: [UserRosterPlayerSummary]]
    let teamStatsById: [String: TeamAggregateStats]
}

struct OffseasonAdvanceLoadingContext: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let detail: String
    let roster: [UserRosterPlayerSummary]
    let portalPlayerCount: Int?
}

enum OffseasonAdvanceNavigationMode: Sendable {
    case scheduleFromRecap
    case stageDestination
}

struct OffseasonAdvanceLoadingView: View {
    let context: OffseasonAdvanceLoadingContext

    private var rosterRows: [UserRosterPlayerSummary] {
        Array(context.roster.sorted { lhs, rhs in
            if lhs.isStarter != rhs.isStarter { return lhs.isStarter && !rhs.isStarter }
            if lhs.overall != rhs.overall { return lhs.overall > rhs.overall }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }.prefix(8))
    }

    private var portalCountText: String {
        context.portalPlayerCount.map { $0.formatted() } ?? "Calculating"
    }

    var body: some View {
        ZStack {
            AppTheme.background
                .opacity(0.96)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    ProgressView()
                        .controlSize(.large)
                        .tint(AppTheme.accent)

                    Text(context.title)
                        .font(.title3.weight(.black))
                        .foregroundStyle(AppTheme.ink)

                    Text(context.detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 8) {
                    loadingMetric(title: "ROSTER", value: "\(context.roster.count)")
                    loadingMetric(title: "PORTAL", value: portalCountText)
                }

                rosterCard
            }
            .padding(18)
        }
    }

    private var rosterCard: some View {
        GameCard {
            VStack(alignment: .leading, spacing: 10) {
                GameSectionHeader(title: "Current Roster")

                VStack(spacing: 0) {
                    rosterHeader
                    ForEach(rosterRows, id: \.playerIndex) { player in
                        rosterRow(player)
                        if player.playerIndex != rosterRows.last?.playerIndex {
                            Divider().opacity(0.45)
                        }
                    }
                }
            }
        }
    }

    private var rosterHeader: some View {
        HStack(spacing: 0) {
            loadingHeader("Player", width: nil, alignment: .leading)
            loadingHeader("POS", width: 42)
            loadingHeader("YR", width: 42)
            loadingHeader("OVR", width: 46)
        }
        .padding(.bottom, 6)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    private func rosterRow(_ player: UserRosterPlayerSummary) -> some View {
        HStack(spacing: 0) {
            HStack(spacing: 6) {
                Text(player.name)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.ink)
                    .lineLimit(1)
                    .truncationMode(.tail)
                if player.isStarter {
                    Text("S")
                        .font(.caption2.weight(.black))
                        .foregroundStyle(AppTheme.accent)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(player.position)
                .font(.caption.monospacedDigit())
                .frame(width: 42)
            Text(player.year)
                .font(.caption.monospacedDigit())
                .frame(width: 42)
            Text("\(player.overall)")
                .font(.caption.monospacedDigit().weight(.bold))
                .frame(width: 46)
        }
        .padding(.vertical, 6)
    }

    private func loadingHeader(_ title: String, width: CGFloat?, alignment: Alignment = .center) -> some View {
        Text(title)
            .font(.caption2.weight(.bold))
            .foregroundStyle(.secondary)
            .frame(width: width, alignment: alignment)
            .frame(maxWidth: width == nil ? .infinity : nil, alignment: alignment)
    }

    private func loadingMetric(title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.monospacedDigit().weight(.black))
                .foregroundStyle(AppTheme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(AppTheme.cardBorder, lineWidth: 1)
        )
    }
}

extension CollegeLeagueHomeView {
    func refreshFromLeague(
        _ league: LeagueState,
        includeDeferredData: Bool = true,
        includeHallOfFame: Bool = true
    ) {
        let currentOffseasonProgress = getOffseasonProgress(league)
        roster = getUserRoster(league)
        schedule = getUserSchedule(league)
        rotationSlots = getUserRotation(league)
        coachingStaff = getUserCoachingStaff(league)
        summary = getLeagueSummary(league)
        rankings = getRankings(league)
        nationalBracket = getNationalTournamentBracket(league)
        nilBudgetSummary = getNILBudgetSummary(league)
        playersLeavingSummary = getPlayersLeavingSummary(league)
        draftSummary = getDraftSummary(league)
        nilRetentionSummary = getNILRetentionSummary(league)
        transferPortalSummary = getTransferPortalSummary(league)
        if includeHallOfFame {
            hallOfFameSummary = getSchoolHallOfFameSummary(league)
        }
        offseasonProgress = currentOffseasonProgress
        if includeDeferredData {
            applyDeferredRefresh(Self.buildDeferredRefreshData(for: league))
        }
    }

    func refreshDeferredDataFromLeague(_ league: LeagueState) {
        let targetHandle = league.handle
        Task.detached(priority: .utility) {
            let data = Self.buildDeferredRefreshData(for: league)
            await MainActor.run {
                guard self.league?.handle == targetHandle else { return }
                applyDeferredRefresh(data)
            }
        }
    }

    func applyDeferredRefresh(_ data: DeferredLeagueRefreshData) {
        conferenceStandings = data.conferenceStandings
        conferenceNamesById = data.conferenceNamesById
        completedLeagueGames = data.completedLeagueGames
        teamRostersByName = data.teamRostersByName
        teamStatsById = data.teamStatsById
    }

    nonisolated static func buildDeferredRefreshData(for league: LeagueState) -> DeferredLeagueRefreshData {
        let standingsData = fetchConferenceStandings(for: league)
        let teamRosters = Dictionary(
            getTeamRosters(league).map { ($0.teamName, $0.players) },
            uniquingKeysWith: { first, _ in first }
        )
        let completedGames = getCompletedLeagueGames(league)
        let efficiencyRatingsByTeamId = Dictionary(
            getTeamEfficiencyRatings(league).map { ($0.teamId, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        var teamStats = TeamStatsView.aggregateTeamStats(from: completedGames)
        for (teamId, rating) in efficiencyRatingsByTeamId {
            guard var stats = teamStats[teamId] else { continue }
            stats.adjustedOffensiveEfficiency = rating.adjustedOffensiveEfficiency
            stats.adjustedDefensiveEfficiency = rating.adjustedDefensiveEfficiency
            teamStats[teamId] = stats
        }
        return DeferredLeagueRefreshData(
            conferenceStandings: standingsData.standings,
            conferenceNamesById: standingsData.conferenceNames,
            completedLeagueGames: completedGames,
            teamRostersByName: teamRosters,
            teamStatsById: teamStats
        )
    }

    func resultSummaryText(for game: UserGameSummary) -> String {
        guard let result = game.result else { return "No result" }
        let home = result.intValue(for: "homeScore") ?? 0
        let away = result.intValue(for: "awayScore") ?? 0
        let userScore = game.isHome == true ? home : away
        let opponentScore = game.isHome == true ? away : home
        return "\(userScore > opponentScore ? "W" : "L") \(userScore)-\(opponentScore)"
    }

    func fetchConferenceStandings(_ league: LeagueState) -> (standings: [String: [ConferenceStanding]], conferenceNames: [String: String]) {
        Self.fetchConferenceStandings(for: league)
    }

    nonisolated static func fetchConferenceStandings(for league: LeagueState) -> (standings: [String: [ConferenceStanding]], conferenceNames: [String: String]) {
        let conferenceOptions = listCareerTeamOptions()
        let conferenceNames = Dictionary(
            conferenceOptions.map { ($0.conferenceId, $0.conferenceName) },
            uniquingKeysWith: { first, _ in first }
        )
        let conferenceIds = Array(conferenceNames.keys).sorted {
            let lhsName = conferenceNames[$0] ?? $0
            let rhsName = conferenceNames[$1] ?? $1
            return lhsName.localizedCaseInsensitiveCompare(rhsName) == .orderedAscending
        }
        var result: [String: [ConferenceStanding]] = [:]
        for id in conferenceIds {
            let rows = getConferenceStandings(league, conferenceId: id)
            if !rows.isEmpty {
                result[id] = rows
            }
        }
        return (standings: result, conferenceNames: conferenceNames)
    }

    func saveRotation(_ updated: [UserRotationSlot]) {
        guard var currentLeague = league else { return }
        rotationSlots = setUserRotation(&currentLeague, slots: updated)
        league = currentLeague
        roster = getUserRoster(currentLeague)
        teamRostersByName = Dictionary(
            getTeamRosters(currentLeague).map { ($0.teamName, $0.players) },
            uniquingKeysWith: { first, _ in first }
        )
    }

    func saveAssistantFocus(assistantIndex: Int, focus: AssistantFocus) {
        guard var currentLeague = league else { return }
        setUserAssistantFocus(&currentLeague, assistantIndex: assistantIndex, focus: focus)
        league = currentLeague
        coachingStaff = getUserCoachingStaff(currentLeague)
    }

    func savePlaybook(pace: PaceProfile, defenseScheme: DefenseScheme, offenseWeights: [String: Int]) {
        guard var currentLeague = league else { return }
        setUserPlaybook(&currentLeague, pace: pace, defenseScheme: defenseScheme, offenseWeights: offenseWeights)
        league = currentLeague

        UserDefaults.standard.set(pace.rawValue, forKey: "coachPace")
        UserDefaults.standard.set(defenseScheme.rawValue, forKey: "coachDefense")
        if let data = try? JSONEncoder().encode(offenseWeights) {
            UserDefaults.standard.set(data, forKey: "coachOffenseWeights")
        }
        if let dominant = offenseWeights.max(by: { $0.value < $1.value })?.key {
            UserDefaults.standard.set(dominant, forKey: "coachOffense")
        }
    }

    @discardableResult
    func advanceOffseasonSchedule(refreshLeague: Bool = true) -> LeagueOffseasonProgress? {
        guard var currentLeague = league else { return nil }
        guard let progress = advanceOffseason(&currentLeague) else { return nil }
        league = currentLeague
        offseasonProgress = progress
        if refreshLeague {
            refreshAfterOffseasonAdvance(currentLeague, progress: progress)
        }
        statusText = offseasonStatusText(for: progress.stage)
        return progress
    }

    private func refreshAfterOffseasonAdvance(_ league: LeagueState, progress: LeagueOffseasonProgress) {
        switch progress.stage {
        case .seasonRecap, .schedule:
            break
        case .nilBudgets:
            nilBudgetSummary = getNILBudgetSummary(league)
        case .playersLeaving:
            playersLeavingSummary = getPlayersLeavingSummary(league)
        case .draft:
            draftSummary = getDraftSummary(league)
            hallOfFameSummary = getSchoolHallOfFameSummary(league)
        case .playerRetention:
            nilRetentionSummary = getNILRetentionSummary(league)
        case .transferPortal:
            nilRetentionSummary = getNILRetentionSummary(league)
            transferPortalSummary = getTransferPortalSummary(league)
        case .complete:
            refreshFromLeague(league, includeDeferredData: false)
            refreshDeferredDataFromLeague(league)
        }
    }

    func advanceToOffseasonScheduleFromRecap() {
        startOffseasonAdvance(refreshLeague: false, navigationMode: .scheduleFromRecap)
    }

    func advanceOffseasonScheduleAndNavigate() {
        startOffseasonAdvance(refreshLeague: true, navigationMode: .stageDestination)
    }

    private func startOffseasonAdvance(refreshLeague: Bool, navigationMode: OffseasonAdvanceNavigationMode) {
        guard offseasonAdvanceLoading == nil else { return }
        guard let startingLeague = league else { return }

        offseasonAdvanceLoading = offseasonLoadingContext()

        Task(priority: .userInitiated) {
            await Task.yield()
            let result = await Self.runOffseasonAdvance(from: startingLeague)
            await MainActor.run {
                guard let result else {
                    offseasonAdvanceLoading = nil
                    return
                }

                league = result.league
                offseasonProgress = result.progress
                if refreshLeague {
                    refreshAfterOffseasonAdvance(result.league, progress: result.progress)
                }
                statusText = offseasonStatusText(for: result.progress.stage)

                switch navigationMode {
                case .scheduleFromRecap:
                    if result.progress.stage == .schedule {
                        navigationPath.append(.offseasonSchedule)
                    }
                case .stageDestination:
                    if let destination = destination(forOffseasonStage: result.progress.stage) {
                        replaceCurrentOffseasonDestination(with: destination)
                    } else if result.progress.stage == .complete {
                        popOffseasonWorkflowDestinations()
                    }
                }

                offseasonAdvanceLoading = nil
            }
        }
    }

    private static func runOffseasonAdvance(from league: LeagueState) async -> (league: LeagueState, progress: LeagueOffseasonProgress)? {
        await Task.detached(priority: .userInitiated) {
            var currentLeague = league
            guard let progress = advanceOffseason(&currentLeague) else { return nil }
            return (currentLeague, progress)
        }.value
    }

    var retainedRoster: [UserRosterPlayerSummary] {
        var departedNames = Set<String>()

        if let retention = nilRetentionSummary {
            let userTeamId = retention.userTeamId
            for entry in retention.entries where entry.teamId == userTeamId && entry.status != .accepted {
                departedNames.insert(entry.playerName)
            }
        }

        if let leaving = playersLeavingSummary {
            for entry in leaving.userEntries {
                departedNames.insert(entry.playerName)
            }
        }

        if let portal = transferPortalSummary {
            let userTeamId = portal.userTeamId
            for entry in portal.entries where entry.previousTeamId == userTeamId {
                departedNames.insert(entry.playerName)
            }
        }

        guard !departedNames.isEmpty else { return roster }
        return roster.filter { !departedNames.contains($0.name) }
    }

    private func offseasonLoadingContext() -> OffseasonAdvanceLoadingContext {
        let currentStage = offseasonProgress?.stage ?? .seasonRecap
        let title: String
        let detail: String
        let portalPlayerCount: Int?

        switch currentStage {
        case .seasonRecap:
            title = "Building Offseason Schedule"
            detail = "Lining up the offseason calendar."
            portalPlayerCount = nil
        case .schedule:
            title = "Calculating NIL Budgets"
            detail = "Revenue sharing and donor interest are being processed."
            portalPlayerCount = nil
        case .nilBudgets:
            title = "Processing Departures"
            detail = "Graduations, draft decisions, and transfer risks are being settled."
            portalPlayerCount = nil
        case .playersLeaving:
            title = "Running Draft Phase"
            detail = "Draft entrants are being evaluated."
            portalPlayerCount = nil
        case .draft:
            title = "Preparing Retention"
            detail = "Returning-player NIL negotiations are being initialized."
            portalPlayerCount = nil
        case .playerRetention:
            title = "Setting Up Transfer Portal"
            detail = "National transfer entries, asking prices, and team interest are being generated."
            portalPlayerCount = nil
        case .transferPortal:
            title = "Advancing Transfer Portal"
            detail = "Offers, finalists, commitments, and the next portal week are being resolved."
            portalPlayerCount = transferPortalSummary?.entries.count
        case .complete:
            title = "Completing Offseason"
            detail = "Finalizing rosters and opening the next season."
            portalPlayerCount = transferPortalSummary?.entries.count
        }

        return OffseasonAdvanceLoadingContext(
            title: title,
            detail: detail,
            roster: retainedRoster,
            portalPlayerCount: portalPlayerCount
        )
    }

    private func popOffseasonWorkflowDestinations() {
        while let last = navigationPath.last, last.isOffseasonWorkflowDestination {
            navigationPath.removeLast()
        }
    }

    private func replaceCurrentOffseasonDestination(with destination: LeagueMenuDestination) {
        guard let currentDestination = navigationPath.last,
              currentDestination.isOffseasonWorkflowDestination
        else {
            navigationPath.append(destination)
            return
        }

        if currentDestination != destination {
            navigationPath[navigationPath.count - 1] = destination
        }
    }

    private func destination(forOffseasonStage stage: LeagueOffseasonStage) -> LeagueMenuDestination? {
        switch stage {
        case .seasonRecap:
            return .seasonRecap
        case .nilBudgets:
            return .nilBudgets
        case .playersLeaving:
            return .playersLeaving
        case .draft:
            return .draft
        case .playerRetention:
            return .playerRetention
        case .transferPortal:
            return .transferPortal
        case .schedule, .complete:
            return nil
        }
    }

    private func offseasonStatusText(for stage: LeagueOffseasonStage) -> String {
        switch stage {
        case .schedule:
            return "Advanced to offseason schedule."
        case .seasonRecap:
            return "Advanced to season recap."
        case .nilBudgets:
            return "Advanced to NIL budgets."
        case .playersLeaving:
            return "Advanced to players leaving."
        case .draft:
            return "Advanced to draft."
        case .playerRetention:
            return "Advanced to player retention."
        case .transferPortal:
            return "Advanced to transfer portal."
        case .complete:
            return "Offseason schedule complete."
        }
    }

    func setNILRetentionOffer(negotiationId: String, offer: Double) {
        guard var currentLeague = league else { return }
        _ = CBBCoachCore.setNILRetentionOffer(&currentLeague, negotiationId: negotiationId, offer: offer)
        league = currentLeague
        nilRetentionSummary = getNILRetentionSummary(currentLeague)
    }

    func submitNILRetentionOffer(negotiationId: String) {
        guard var currentLeague = league else { return }
        _ = CBBCoachCore.submitNILRetentionOffer(&currentLeague, negotiationId: negotiationId)
        league = currentLeague
        nilRetentionSummary = getNILRetentionSummary(currentLeague)
    }

    func meetNILRetentionDemand(negotiationId: String) {
        guard var currentLeague = league else { return }
        _ = CBBCoachCore.meetNILRetentionDemand(&currentLeague, negotiationId: negotiationId)
        league = currentLeague
        nilRetentionSummary = getNILRetentionSummary(currentLeague)
    }

    func delegateNILRetention() {
        guard var currentLeague = league else { return }
        nilRetentionSummary = CBBCoachCore.delegateNILRetentionToAssistants(&currentLeague)
        league = currentLeague
    }

    func setTransferPortalTargeted(entryId: String, targeted: Bool) {
        guard var currentLeague = league else { return }
        transferPortalSummary = CBBCoachCore.setTransferPortalTargeted(&currentLeague, entryId: entryId, targeted: targeted)
        league = currentLeague
    }

    func setTransferPortalOffer(entryId: String, offer: Double) {
        guard var currentLeague = league else { return }
        transferPortalSummary = CBBCoachCore.setTransferPortalOffer(&currentLeague, entryId: entryId, offer: offer)
        league = currentLeague
    }
}

enum SkipAheadTarget {
    case midseason
    case endOfRegularSeason
    case selectionSunday
    case offseason

    var completedGames: Int {
        switch self {
        case .midseason: 15
        case .endOfRegularSeason: 31
        case .selectionSunday, .offseason: Int.max
        }
    }

    var overlayTitle: String {
        switch self {
        case .midseason: "Simulating to Midseason..."
        case .endOfRegularSeason: "Simulating to End of Regular Season..."
        case .selectionSunday: "Simulating to Selection Sunday..."
        case .offseason: "Simulating to Offseason..."
        }
    }

    var completionMessage: String {
        switch self {
        case .midseason: "Advanced to midseason (between Weeks 15 and 16)."
        case .endOfRegularSeason: "Advanced to end of regular season (after Game 31)."
        case .selectionSunday: "Advanced to Selection Sunday."
        case .offseason: "Advanced to offseason."
        }
    }
}

struct SkipAheadSimulationResult {
    let league: LeagueState
    let seasonCompleted: Bool
    let recaps: [String]
    let deferredData: DeferredLeagueRefreshData
}

struct SkipAheadOverlayView: View {
    let title: String
    let recaps: [String]

    var body: some View {
        ZStack {
            AppTheme.background.opacity(0.95)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    ProgressView()
                    Text(title)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(AppTheme.ink)
                }

                Text("User game results will appear here as they finish.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if recaps.isEmpty {
                    Text("Simulating...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 8)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(Array(recaps.enumerated()), id: \.offset) { _, recap in
                                Text(recap)
                                    .font(.footnote.monospacedDigit())
                                    .foregroundStyle(.primary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding(18)
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(AppTheme.cardBorder, lineWidth: 1)
            )
            .padding(20)
        }
    }
}

enum LeagueMenuDestination: Hashable {
    case seasonRecap
    case offseasonSchedule
    case nilBudgets
    case playersLeaving
    case draft
    case playerRetention
    case transferPortal
    case bracket
    case roster
    case schedule
    case rotation
    case playbook
    case playerStats
    case teamStats
    case statLeaders
    case standings
    case rankings
    case coachingStaff
    case hallOfFame
    case boxScore(String)

    var isOffseasonWorkflowDestination: Bool {
        switch self {
        case .seasonRecap, .offseasonSchedule, .nilBudgets, .playersLeaving, .draft, .playerRetention, .transferPortal:
            return true
        case .bracket, .roster, .schedule, .rotation, .playbook, .playerStats, .teamStats, .statLeaders, .standings, .rankings, .coachingStaff, .hallOfFame, .boxScore:
            return false
        }
    }
}

struct StatChip: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 3) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.monospacedDigit().weight(.bold))
                .foregroundStyle(AppTheme.ink)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(AppTheme.cardBorder, lineWidth: 1)
        )
    }
}

struct MenuRow: View {
    let title: String
    var subtitle: String = ""

    var body: some View {
        GameCard {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.ink)
                    if !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct CoachingStaffView: View {
    let staff: UserCoachingStaffSummary?
    let onSetAssistantFocus: (Int, AssistantFocus) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Assistant focus affects organization priorities. Game Prep selection also marks the lead scout for opponent prep.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let staff {
                    GameCard {
                        GameSectionHeader(title: "Head Coach")
                        CoachTraitRowView(
                            title: staff.headCoach.displayName,
                            subtitle: "Program Leader · \(staff.headCoach.bioLine)",
                            coach: staff.headCoach
                        )
                    }

                    GameCard {
                        GameSectionHeader(title: "Assistants")
                        VStack(spacing: 12) {
                            ForEach(Array(staff.assistants.enumerated()), id: \.offset) { index, assistant in
                                VStack(alignment: .leading, spacing: 8) {
                                    CoachTraitRowView(
                                        title: assistant.displayName,
                                        subtitle: "Assistant \(index + 1) · \(assistant.focus?.label ?? AssistantFocus.recruiting.label) · \(assistant.bioLine)",
                                        coach: assistant
                                    )
                                    FilterDropdown(
                                        label: "Focus",
                                        selection: Binding(
                                            get: { assistant.focus ?? .recruiting },
                                            set: { onSetAssistantFocus(index, $0) }
                                        ),
                                        options: AssistantFocus.allCases,
                                        optionLabel: \.label
                                    )
                                }

                                if index < staff.assistants.count - 1 {
                                    Divider()
                                }
                            }
                        }
                    }
                } else {
                    Text("No coaching staff available yet.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(16)
        }
        .navigationTitle("Coaching Staff")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct CoachTraitRowView: View {
    let title: String
    let subtitle: String
    let coach: Coach
    private let traitColumns = [
        GridItem(.flexible(minimum: 120), spacing: 8),
        GridItem(.flexible(minimum: 120), spacing: 8),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(columns: traitColumns, alignment: .leading, spacing: 8) {
                ForEach(Array(coach.allTraitValues.enumerated()), id: \.offset) { _, item in
                    TraitPill(title: item.title, value: item.value)
                }
            }
        }
    }
}

struct TraitPill: View {
    let title: String
    let value: Int

    var body: some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text("\(value)")
                .font(.caption.monospacedDigit().weight(.bold))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(AppTheme.cardBorder.opacity(0.8), lineWidth: 1)
        )
    }
}
