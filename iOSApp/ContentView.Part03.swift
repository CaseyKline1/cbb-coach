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

extension CollegeLeagueHomeView {
    func refreshFromLeague(_ league: LeagueState, includeDeferredData: Bool = true) {
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
        hallOfFameSummary = getSchoolHallOfFameSummary(league)
        offseasonProgress = getOffseasonProgress(league)
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
        return DeferredLeagueRefreshData(
            conferenceStandings: standingsData.standings,
            conferenceNamesById: standingsData.conferenceNames,
            completedLeagueGames: completedGames,
            teamRostersByName: teamRosters,
            teamStatsById: TeamStatsView.aggregateTeamStats(from: completedGames)
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
        let progress = advanceOffseasonSchedule(refreshLeague: false)
        if progress?.stage == .schedule {
            navigationPath.append(.offseasonSchedule)
        }
    }

    func advanceOffseasonScheduleAndNavigate() {
        guard let progress = advanceOffseasonSchedule() else { return }
        if let destination = destination(forOffseasonStage: progress.stage) {
            navigationPath.append(destination)
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
    case playerStats
    case teamStats
    case statLeaders
    case standings
    case rankings
    case coachingStaff
    case hallOfFame
    case boxScore(String)
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
