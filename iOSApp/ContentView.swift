import SwiftUI
import CBBCoachCore

struct ContentView: View {
    @AppStorage("coachCreationComplete") private var coachCreationComplete: Bool = false
    @AppStorage("coachFirstName") private var coachFirstName: String = ""
    @AppStorage("coachLastName") private var coachLastName: String = ""
    @AppStorage("coachAge") private var coachAge: Int = 42
    @AppStorage("coachPace") private var coachPaceRaw: String = PaceProfile.normal.rawValue
    @AppStorage("coachOffense") private var coachOffenseRaw: String = OffensiveFormation.motion.rawValue
    @AppStorage("coachDefense") private var coachDefenseRaw: String = DefenseScheme.manToMan.rawValue
    @AppStorage("coachArchetype") private var coachArchetypeRaw: String = CoachArchetype.recruiting.rawValue
    @AppStorage("coachCareerTeam") private var coachCareerTeam: String = ""

    var body: some View {
        Group {
            if coachCreationComplete, let profile = loadedProfile {
                if coachCareerTeam.isEmpty {
                    CareerTeamSelectionView { selectedTeam in
                        coachCareerTeam = selectedTeam
                    }
                } else {
                    CollegeLeagueHomeView(
                        profile: profile,
                        teamName: coachCareerTeam,
                        onChooseDifferentTeam: { coachCareerTeam = "" },
                        onCreateNewCoach: resetCoachCreation
                    )
                }
            } else {
                CoachCreationFlowView(onComplete: saveProfile)
            }
        }
    }

    private var loadedProfile: CoachCreationProfile? {
        guard
            let pace = PaceProfile(rawValue: coachPaceRaw),
            let offense = OffensiveFormation(rawValue: coachOffenseRaw),
            let defense = DefenseScheme(rawValue: coachDefenseRaw),
            let archetype = CoachArchetype(rawValue: coachArchetypeRaw),
            !coachFirstName.isEmpty,
            !coachLastName.isEmpty
        else {
            return nil
        }

        return CoachCreationProfile(
            firstName: coachFirstName,
            lastName: coachLastName,
            age: coachAge,
            archetype: archetype,
            pace: pace,
            offense: offense,
            defense: defense
        )
    }

    private func saveProfile(_ profile: CoachCreationProfile) {
        coachFirstName = profile.firstName
        coachLastName = profile.lastName
        coachAge = profile.age
        coachPaceRaw = profile.pace.rawValue
        coachOffenseRaw = profile.offense.rawValue
        coachDefenseRaw = profile.defense.rawValue
        coachArchetypeRaw = profile.archetype.rawValue
        coachCreationComplete = true
    }

    private func resetCoachCreation() {
        coachCareerTeam = ""
        coachCreationComplete = false
    }
}

private struct CoachCreationFlowView: View {
    let onComplete: (CoachCreationProfile) -> Void

    @State private var path: [CoachCreationStep] = []

    var body: some View {
        NavigationStack(path: $path) {
            CoachIdentityStepView { identity in
                path.append(.archetype(identity))
            }
            .navigationDestination(for: CoachCreationStep.self) { step in
                switch step {
                case .archetype(let identity):
                    CoachArchetypeStepView(identity: identity) { archetype in
                        path.append(.style(identity, archetype))
                    }
                case .style(let identity, let archetype):
                    CoachStyleStepView(identity: identity) { style in
                        onComplete(
                            CoachCreationProfile(
                                firstName: identity.firstName,
                                lastName: identity.lastName,
                                age: identity.age,
                                archetype: archetype,
                                pace: style.pace,
                                offense: style.offense,
                                defense: style.defense
                            )
                        )
                    }
                }
            }
        }
    }
}

private enum CoachCreationStep: Hashable {
    case archetype(CoachIdentitySelection)
    case style(CoachIdentitySelection, CoachArchetype)
}

private struct CoachCreationProfile {
    let firstName: String
    let lastName: String
    let age: Int
    let archetype: CoachArchetype
    let pace: PaceProfile
    let offense: OffensiveFormation
    let defense: DefenseScheme

    var fullName: String {
        "\(firstName) \(lastName)"
    }
}

private struct CoachIdentitySelection: Hashable {
    let firstName: String
    let lastName: String
    let age: Int
}

private struct CoachStyleSelection: Hashable {
    let pace: PaceProfile
    let offense: OffensiveFormation
    let defense: DefenseScheme
}

private enum CoachArchetype: String, CaseIterable, Hashable {
    case recruiting
    case offense
    case defense
    case playerDevelopment = "player_development"
    case fundraising
}

private struct CoachIdentityStepView: View {
    let onNext: (CoachIdentitySelection) -> Void

    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var age: Double = 42

    private var isValid: Bool {
        !firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !lastName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        OnboardingStepScaffold(
            title: "Create Your Coach",
            subtitle: "Step 1 of 3",
            navTitle: "Coach Setup",
            nextLabel: "Next: Archetype",
            nextDisabled: !isValid,
            onNext: {
                onNext(
                    CoachIdentitySelection(
                        firstName: firstName.trimmingCharacters(in: .whitespacesAndNewlines),
                        lastName: lastName.trimmingCharacters(in: .whitespacesAndNewlines),
                        age: Int(age.rounded())
                    )
                )
            }
        ) {
            VStack(alignment: .leading, spacing: 16) {
                Text("CBB Coach")
                    .font(.system(size: 36, weight: .black))

                TextField("First Name", text: $firstName)
                    .textInputAutocapitalization(.words)
                    .textFieldStyle(.roundedBorder)

                TextField("Last Name", text: $lastName)
                    .textInputAutocapitalization(.words)
                    .textFieldStyle(.roundedBorder)

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Age")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Text("\(Int(age.rounded()))")
                            .font(.subheadline.monospacedDigit().weight(.bold))
                    }
                    Slider(value: $age, in: 25...75, step: 1)
                        .tint(.orange)
                }
            }
            .padding(18)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }
}

private struct CoachArchetypeStepView: View {
    let identity: CoachIdentitySelection
    let onNext: (CoachArchetype) -> Void

    @State private var selectedArchetype: CoachArchetype = .recruiting

    var body: some View {
        OnboardingStepScaffold(
            title: "Choose Your Archetype",
            subtitle: "Step 2 of 3",
            navTitle: "Coach Setup",
            nextLabel: "Next: Style",
            nextDisabled: false,
            onNext: { onNext(selectedArchetype) }
        ) {
            VStack(alignment: .leading, spacing: 16) {
                FilterDropdown(
                    label: "Archetype",
                    selection: $selectedArchetype,
                    options: CoachArchetype.allCases,
                    optionLabel: \.label
                )

                Text(selectedArchetype.summary)
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Text("\(identity.firstName) \(identity.lastName), age \(identity.age)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(18)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }
}

private struct CoachStyleStepView: View {
    let identity: CoachIdentitySelection
    let onNext: (CoachStyleSelection) -> Void

    @State private var selectedPace: PaceProfile = .normal
    @State private var selectedOffense: OffensiveFormation = .motion
    @State private var selectedDefense: DefenseScheme = .manToMan

    var body: some View {
        OnboardingStepScaffold(
            title: "Define Your Style",
            subtitle: "Step 3 of 3",
            navTitle: "Coach Setup",
            nextLabel: "Finish Coach",
            nextDisabled: false,
            onNext: {
                onNext(
                    CoachStyleSelection(
                        pace: selectedPace,
                        offense: selectedOffense,
                        defense: selectedDefense
                    )
                )
            }
        ) {
            VStack(alignment: .leading, spacing: 16) {
                FilterDropdown(
                    label: "Tempo",
                    selection: $selectedPace,
                    options: PaceProfile.allCases,
                    optionLabel: \.label
                )

                FilterDropdown(
                    label: "Base Offense",
                    selection: $selectedOffense,
                    options: OffensiveFormation.allCases,
                    optionLabel: \.label
                )

                FilterDropdown(
                    label: "Base Defense",
                    selection: $selectedDefense,
                    options: DefenseScheme.allCases,
                    optionLabel: \.label
                )

                Text("\(identity.firstName) \(identity.lastName), age \(identity.age)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(18)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }
}

private struct CareerTeamSelectionView: View {
    let onTeamSelected: (String) -> Void

    @State private var teams: [CareerTeamOption] = []
    @State private var selectedTeamId: String?

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Choose Your Program")
                    .font(.title2.weight(.black))
                Text("Pick any team in the ACC, SEC, Big Ten, Big 12, or Big East.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(teams, id: \.teamId) { team in
                            Button {
                                selectedTeamId = team.teamId
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(team.teamName)
                                            .font(.subheadline.weight(.semibold))
                                        Text(team.conferenceName)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    if selectedTeamId == team.teamId {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.orange)
                                    }
                                }
                                .padding(12)
                                .background(selectedTeamId == team.teamId ? Color.orange.opacity(0.1) : Color.clear)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .stroke(selectedTeamId == team.teamId ? Color.orange.opacity(0.5) : Color.black.opacity(0.08), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Button("Start With Selected Team") {
                    guard
                        let selectedTeamId,
                        let selected = teams.first(where: { $0.teamId == selectedTeamId })
                    else { return }
                    onTeamSelected(selected.teamName)
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedTeamId == nil)
            }
            .padding(16)
            .navigationTitle("Team Selection")
            .onAppear {
                if teams.isEmpty {
                    teams = listCareerTeamOptions()
                    selectedTeamId = teams.first?.teamId
                }
            }
        }
    }
}

private struct OnboardingStepScaffold<Content: View>: View {
    let title: String
    let subtitle: String
    let navTitle: String
    let nextLabel: String
    let nextDisabled: Bool
    let onNext: () -> Void
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.96, green: 0.97, blue: 0.99), Color(red: 0.92, green: 0.94, blue: 0.97)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

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
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.plain)
                    .background(nextDisabled ? Color.gray.opacity(0.5) : Color.orange)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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

private struct CollegeLeagueHomeView: View {
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

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Coach \(profile.fullName)")
                            .font(.largeTitle.bold())
                        Text("\(teamName) | \(profile.archetype.label) Archetype | Pace: \(profile.pace.label)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    if let summary {
                        HStack(spacing: 14) {
                            StatChip(title: "Game", value: "\(summary.currentDay)")
                            StatChip(title: "Games", value: "\(summary.totalScheduledGames)")
                            StatChip(title: "Record", value: userRecordText)
                        }
                    }

                    Text(statusText)
                        .font(.subheadline)

                    GroupBox("Team") {
                        VStack(spacing: 8) {
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

                            NavigationLink(value: LeagueMenuDestination.standings) {
                                MenuRow(title: "Standings")
                            }
                            .buttonStyle(.plain)

                            NavigationLink(value: LeagueMenuDestination.coachingStaff) {
                                MenuRow(title: "Coaching Staff")
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if let lastPlayed = latestCompletedGame {
                        GroupBox("Last Result") {
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
                        .buttonStyle(.borderedProminent)

                        Button("Choose Team") {
                            onChooseDifferentTeam()
                        }
                        .buttonStyle(.bordered)
                    }

                    Button("Create New Coach") {
                        onCreateNewCoach()
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.orange)
                }
                .padding(20)
            }
            .navigationTitle("College League")
            .navigationDestination(for: LeagueMenuDestination.self) { destination in
                switch destination {
                case .roster:
                    RosterRatingsView(
                        roster: roster,
                        schedule: schedule,
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
                    PlayerStatsView(schedule: schedule, userTeamName: summary?.userTeamName ?? teamName)
                case .standings:
                    ConferenceStandingsView(
                        standingsByConference: conferenceStandings,
                        preferredConferenceId: userConferenceId
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

    private func createLeague() {
        do {
            var options = CreateLeagueOptions(userTeamName: teamName, seed: "ios-league-\(profile.fullName)-\(teamName)")
            options.userHeadCoachName = profile.fullName
            options.userHeadCoachSkills = profile.archetype.initialSkills
            let created = try createD1League(options: options)
            league = created
            roster = getUserRoster(created)
            schedule = getUserSchedule(created)
            rotationSlots = getUserRotation(created)
            coachingStaff = getUserCoachingStaff(created)
            let leagueSummary = getLeagueSummary(created)
            summary = leagueSummary
            conferenceStandings = fetchConferenceStandings(created)
            statusText = "\(leagueSummary.userTeamName): \(leagueSummary.totalScheduledGames) total games generated"
        } catch {
            statusText = "League error: \(error.localizedDescription)"
        }
    }

    private func playNextGame() {
        guard var currentLeague = league else { return }
        guard let result = advanceToNextUserGame(&currentLeague) else { return }
        league = currentLeague
        roster = getUserRoster(currentLeague)
        schedule = getUserSchedule(currentLeague)
        rotationSlots = getUserRotation(currentLeague)
        coachingStaff = getUserCoachingStaff(currentLeague)
        summary = getLeagueSummary(currentLeague)
        conferenceStandings = fetchConferenceStandings(currentLeague)
        if result.done == true {
            statusText = "Season complete."
            return
        }
        let userScore = result.score?.numberValue(for: "user")?.roundedInt ?? 0
        let oppScore = result.score?.numberValue(for: "opponent")?.roundedInt ?? 0
        let gameLabel = gameNumber(for: result)
        statusText = "Game \(gameLabel): \(result.opponentName ?? "Unknown") \(userScore)-\(oppScore) (\(result.won == true ? "W" : "L"))"
    }

    private func resultSummaryText(for game: UserGameSummary) -> String {
        guard let result = game.result else { return "No result" }
        let home = result.intValue(for: "homeScore") ?? 0
        let away = result.intValue(for: "awayScore") ?? 0
        let userScore = game.isHome == true ? home : away
        let opponentScore = game.isHome == true ? away : home
        return "\(userScore > opponentScore ? "W" : "L") \(userScore)-\(opponentScore)"
    }

    private func fetchConferenceStandings(_ league: LeagueState) -> [String: [ConferenceStanding]] {
        let conferenceIds = ["acc", "sec", "big-ten", "big-12", "big-east"]
        var result: [String: [ConferenceStanding]] = [:]
        for id in conferenceIds {
            let rows = getConferenceStandings(league, conferenceId: id)
            if !rows.isEmpty {
                result[id] = rows
            }
        }
        return result
    }

    private func saveRotation(_ updated: [UserRotationSlot]) {
        guard var currentLeague = league else { return }
        rotationSlots = setUserRotation(&currentLeague, slots: updated)
        league = currentLeague
        roster = getUserRoster(currentLeague)
    }

    private func saveAssistantFocus(assistantIndex: Int, focus: AssistantFocus) {
        guard var currentLeague = league else { return }
        setUserAssistantFocus(&currentLeague, assistantIndex: assistantIndex, focus: focus)
        league = currentLeague
        coachingStaff = getUserCoachingStaff(currentLeague)
    }
}

private enum LeagueMenuDestination: Hashable {
    case roster
    case schedule
    case rotation
    case playerStats
    case standings
    case coachingStaff
    case boxScore(String)
}

private struct StatChip: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 3) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.monospacedDigit().weight(.bold))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct MenuRow: View {
    let title: String

    var body: some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
    }
}

private struct CoachingStaffView: View {
    let staff: UserCoachingStaffSummary?
    let onSetAssistantFocus: (Int, AssistantFocus) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Assistant focus affects organization priorities. Game Prep selection also marks the lead scout for opponent prep.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let staff {
                    GroupBox("Head Coach") {
                        CoachTraitRowView(
                            title: staff.headCoach.displayName,
                            subtitle: "Program Leader",
                            coach: staff.headCoach
                        )
                    }

                    GroupBox("Assistants") {
                        VStack(spacing: 12) {
                            ForEach(Array(staff.assistants.enumerated()), id: \.offset) { index, assistant in
                                VStack(alignment: .leading, spacing: 8) {
                                    CoachTraitRowView(
                                        title: assistant.displayName,
                                        subtitle: "Assistant \(index + 1) · \(assistant.focus?.label ?? AssistantFocus.recruiting.label)",
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

private struct CoachTraitRowView: View {
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

private struct TraitPill: View {
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
        .background(Color(.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct RotationSettingsView: View {
    let roster: [UserRosterPlayerSummary]
    let slots: [UserRotationSlot]
    let onSave: ([UserRotationSlot]) -> Void

    @State private var editedSlots: [UserRotationSlot] = []
    @State private var isApplyingIncomingSlots: Bool = false
    @State private var statusText: String = "Set starters (1-5), then rank bench (6+). Team minutes are normalized to 200."

    private let starterPositions = ["PG", "SG", "SF", "PF", "C"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Starters are slots 1-5 with assigned positions. Bench order drives substitution priority and role-fit checks.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ForEach(Array(editedSlots.enumerated()), id: \.element.id) { index, slot in
                    GroupBox {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text(slotTitle(for: index))
                                    .font(.subheadline.weight(.semibold))
                                Spacer()
                                HStack(spacing: 8) {
                                    Button(action: { moveSlot(from: index, delta: -1) }) {
                                        Image(systemName: "arrow.up.circle.fill")
                                    }
                                    .buttonStyle(.plain)
                                    .foregroundStyle(index > 0 ? .secondary : .tertiary)
                                    .disabled(index == 0)
                                    .accessibilityLabel("Move up")

                                    Button(action: { moveSlot(from: index, delta: 1) }) {
                                        Image(systemName: "arrow.down.circle.fill")
                                    }
                                    .buttonStyle(.plain)
                                    .foregroundStyle(index < editedSlots.count - 1 ? .secondary : .tertiary)
                                    .disabled(index >= editedSlots.count - 1)
                                    .accessibilityLabel("Move down")
                                }
                            }

                            RotationPlayerPicker(
                                label: "Player",
                                roster: roster,
                                selectedIndex: Binding(
                                    get: { editedSlots[index].playerIndex },
                                    set: { editedSlots[index].playerIndex = $0 }
                                )
                            )

                            if index < min(5, editedSlots.count) {
                                FilterDropdown(
                                    label: "Starter Position",
                                    selection: Binding(
                                        get: { editedSlots[index].position ?? starterPositions[min(index, starterPositions.count - 1)] },
                                        set: { editedSlots[index].position = $0 }
                                    ),
                                    options: starterPositions,
                                    optionLabel: { $0 }
                                )
                            }

                            RotationMinuteControl(
                                label: "Minutes",
                                value: Binding(
                                    get: { editedSlots[index].minutes },
                                    set: { editedSlots[index].minutes = $0 }
                                ),
                                step: 1
                            )
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(statusText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Total minutes: \(Int(totalMinutes.rounded()))")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            .padding(16)
        }
        .navigationTitle("Rotation")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            applyIncomingSlots(slots)
        }
        .onChange(of: slots) { _, updated in
            applyIncomingSlots(updated)
        }
        .onChange(of: editedSlots) { _, updated in
            if isApplyingIncomingSlots { return }
            let normalizedUpdated = normalized(updated)
            if !areSlotsEqual(updated, normalizedUpdated) {
                editedSlots = normalizedUpdated
                return
            }
            onSave(normalizedUpdated)
            statusText = "Rotation auto-saved."
        }
    }

    private func applyIncomingSlots(_ source: [UserRotationSlot]) {
        isApplyingIncomingSlots = true
        editedSlots = normalized(source)
        isApplyingIncomingSlots = false
    }

    private func areSlotsEqual(_ lhs: [UserRotationSlot], _ rhs: [UserRotationSlot]) -> Bool {
        guard lhs.count == rhs.count else { return false }
        for index in lhs.indices {
            let left = lhs[index]
            let right = rhs[index]
            if left.slot != right.slot { return false }
            if left.playerIndex != right.playerIndex { return false }
            if left.position != right.position { return false }
            if left.minutes != right.minutes { return false }
        }
        return true
    }

    private func normalized(_ source: [UserRotationSlot]) -> [UserRotationSlot] {
        let targetCount = max(source.count, roster.count)
        if targetCount == 0 { return [] }

        var base = source.sorted { $0.slot < $1.slot }
        if base.count < targetCount {
            for slot in (base.count + 1)...targetCount {
                base.append(UserRotationSlot(slot: slot, playerIndex: nil, position: nil, minutes: 0))
            }
        }

        let rosterIndexes = Set(roster.map(\.playerIndex))
        var used: Set<Int> = []
        for index in base.indices {
            let candidate = base[index].playerIndex
            if let candidate, rosterIndexes.contains(candidate), !used.contains(candidate) {
                used.insert(candidate)
            } else {
                base[index].playerIndex = nil
            }
        }
        let remaining = roster.map(\.playerIndex).filter { !used.contains($0) }
        var remainingCursor = 0
        for index in base.indices {
            if base[index].playerIndex != nil { continue }
            guard remainingCursor < remaining.count else { break }
            base[index].playerIndex = remaining[remainingCursor]
            remainingCursor += 1
        }

        for index in base.indices {
            base[index].slot = index + 1
            base[index].minutes = clampMinutes(base[index].minutes)
            if index < min(5, base.count) {
                let fallback = starterPositions[min(index, starterPositions.count - 1)]
                let current = (base[index].position ?? "").uppercased()
                base[index].position = starterPositions.contains(current) ? current : fallback
            } else {
                base[index].position = nil
            }
        }

        return normalizeMinutes(base)
    }

    private func clampMinutes(_ value: Double) -> Double {
        min(40, max(0, (value * 2).rounded() / 2))
    }

    private func normalizeMinutes(_ source: [UserRotationSlot]) -> [UserRotationSlot] {
        guard !source.isEmpty else { return source }
        var normalized = source
        let targetTotal = min(200.0, Double(source.count * 40))
        let currentTotal = normalized.reduce(0) { $0 + $1.minutes }
        if currentTotal <= 0 {
            let even = clampMinutes(targetTotal / Double(max(1, normalized.count)))
            for index in normalized.indices {
                normalized[index].minutes = even
            }
        } else {
            let scale = targetTotal / currentTotal
            for index in normalized.indices {
                normalized[index].minutes = clampMinutes(normalized[index].minutes * scale)
            }
        }

        var diff = targetTotal - normalized.reduce(0) { $0 + $1.minutes }
        var guardCount = 0
        while abs(diff) >= 0.49 && guardCount < 1000 {
            guardCount += 1
            let step = diff > 0 ? 0.5 : -0.5
            var adjusted = false
            for index in normalized.indices {
                let candidate = normalized[index].minutes + step
                if candidate < 0 || candidate > 40 { continue }
                normalized[index].minutes = candidate
                adjusted = true
                break
            }
            if !adjusted { break }
            diff = targetTotal - normalized.reduce(0) { $0 + $1.minutes }
        }

        return normalized
    }

    private func moveSlot(from index: Int, delta: Int) {
        let destination = index + delta
        guard editedSlots.indices.contains(index), editedSlots.indices.contains(destination) else { return }
        let moved = editedSlots.remove(at: index)
        editedSlots.insert(moved, at: destination)
        for idx in editedSlots.indices {
            editedSlots[idx].slot = idx + 1
        }
    }

    private func slotTitle(for index: Int) -> String {
        if index < 5 { return "\(index + 1). Starter" }
        return "\(index + 1). Bench"
    }

    private var totalMinutes: Double {
        editedSlots.reduce(0) { $0 + $1.minutes }
    }
}

private struct RotationPlayerPicker: View {
    let label: String
    let roster: [UserRosterPlayerSummary]
    @Binding var selectedIndex: Int?

    var body: some View {
        FilterDropdown(
            label: label,
            selection: Binding<Int>(
                get: { selectedIndex ?? -1 },
                set: { selectedIndex = $0 >= 0 ? $0 : nil }
            ),
            options: [-1] + roster.map(\.playerIndex),
            optionLabel: { index in
                if index < 0 { return "Auto" }
                guard let player = roster.first(where: { $0.playerIndex == index }) else { return "Auto" }
                return "\(player.name) (\(player.position))"
            }
        )
    }
}

private struct RotationMinuteControl: View {
    let label: String
    @Binding var value: Double
    let step: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                Button(action: decrement) {
                    Image(systemName: "minus.circle.fill")
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .accessibilityLabel("Decrease \(label)")

                Text("\(Int(value.rounded()))")
                    .font(.body.monospacedDigit().weight(.semibold))
                    .frame(width: 36)

                Button(action: increment) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .accessibilityLabel("Increase \(label)")
            }
        }
    }

    private func decrement() {
        value = min(40, max(0, value - step))
    }

    private func increment() {
        value = min(40, max(0, value + step))
    }
}

private struct RosterRatingsView: View {
    let roster: [UserRosterPlayerSummary]
    let schedule: [UserGameSummary]
    let userTeamName: String
    @State private var sortColumn: String = "overall"
    @State private var isAscending: Bool = false

    private let preferredAttributeOrder: [String] = [
        "potential", "speed", "agility", "burst", "strength", "vertical", "stamina", "durability",
        "layups", "dunks", "closeShot", "midrangeShot", "threePointShooting", "cornerThrees", "upTopThrees", "drawFoul", "freeThrows",
        "postControl", "postFadeaways", "postHooks",
        "ballHandling", "ballSafety", "passingAccuracy", "passingVision", "passingIQ", "shotIQ", "offballOffense", "hands", "hustle", "clutch",
        "perimeterDefense", "postDefense", "shotBlocking", "shotContest", "steals", "lateralQuickness", "offballDefense", "passPerception", "defensiveControl",
        "offensiveRebounding", "defensiveRebound", "boxouts",
        "tendencyPost", "tendencyInside", "tendencyMidrange", "tendencyThreePoint", "tendencyDrive", "tendencyPickAndRoll", "tendencyPickAndPop", "tendencyShootVsPass",
    ]

    private let visibleTendencyKeys: Set<String> = [
        "tendencyThreePoint", "tendencyDrive", "tendencyShootVsPass"
    ]

    private var attributeColumns: [String] {
        let keys = Set(roster.flatMap { Array(($0.attributes ?? [:]).keys) })
            .filter { key in
                !key.hasPrefix("tendency") || visibleTendencyKeys.contains(key)
            }
        return preferredAttributeOrder.filter { keys.contains($0) } + keys.filter { !preferredAttributeOrder.contains($0) }.sorted()
    }

    private var sortedRoster: [UserRosterPlayerSummary] {
        roster.sorted { lhs, rhs in
            let comparison = compare(lhs: lhs, rhs: rhs, column: sortColumn)
            if comparison == .orderedSame {
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
            return isAscending ? (comparison == .orderedAscending) : (comparison == .orderedDescending)
        }
    }

    private var columns: [AppTableColumn<String>] {
        [
            .init(id: "isStarter", title: "ST", width: 30),
            .init(id: "name", title: "PLYR", width: 132, alignment: .leading),
            .init(id: "position", title: "POS", width: 42),
            .init(id: "year", title: "YR", width: 30),
            .init(id: "overall", title: "OVR", width: 38),
        ] + attributeColumns.map { .init(id: $0, title: attributeLabel($0), width: 44) }
    }

    private var tableRows: [(id: AnyHashable, data: UserRosterPlayerSummary)] {
        Array(sortedRoster.enumerated()).map { (id: AnyHashable($0.offset), data: $0.element) }
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            AppTable(
                columns: columns,
                rows: tableRows,
                sortState: .init(column: sortColumn, ascending: isAscending),
                onSort: toggleSort
            ) { player in
                HStack(spacing: 0) {
                    AppTableTextCell(text: player.isStarter ? "★" : "", width: 30)
                    NavigationLink {
                        PlayerCardDetailView(
                            player: player,
                            schedule: schedule,
                            userTeamName: userTeamName
                        )
                    } label: {
                        AppTableTextCell(
                            text: player.name,
                            width: 132,
                            alignment: .leading,
                            font: .caption.monospacedDigit().weight(.semibold),
                            foreground: .blue
                        )
                    }
                    .buttonStyle(.plain)
                    AppTableTextCell(text: player.position, width: 42)
                    AppTableTextCell(text: player.year, width: 30)
                    AppTableTextCell(text: "\(player.overall)", width: 38)
                    ForEach(attributeColumns, id: \.self) { key in
                        let value = player.attributes?[key] ?? 0
                        AppTableTextCell(text: "\(value)", width: 44)
                    }
                }
            }
        }
        .background(Color(.secondarySystemBackground))
        .navigationTitle("Roster")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func toggleSort(_ id: String) {
        if sortColumn == id {
            isAscending.toggle()
        } else {
            sortColumn = id
            isAscending = false
        }
    }

    private func compare(lhs: UserRosterPlayerSummary, rhs: UserRosterPlayerSummary, column: String) -> ComparisonResult {
        switch column {
        case "name":
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name)
        case "position":
            return lhs.position.localizedCaseInsensitiveCompare(rhs.position)
        case "year":
            return lhs.year.localizedCaseInsensitiveCompare(rhs.year)
        case "isStarter":
            return numericCompare(lhs: lhs.isStarter ? 1 : 0, rhs: rhs.isStarter ? 1 : 0)
        case "overall":
            return numericCompare(lhs: lhs.overall, rhs: rhs.overall)
        default:
            return numericCompare(lhs: lhs.attributes?[column] ?? 0, rhs: rhs.attributes?[column] ?? 0)
        }
    }

    private func numericCompare(lhs: Int, rhs: Int) -> ComparisonResult {
        if lhs == rhs { return .orderedSame }
        return lhs < rhs ? .orderedAscending : .orderedDescending
    }

    private func attributeLabel(_ key: String) -> String {
        switch key {
        case "potential": "POT"
        case "speed": "SPD"
        case "agility": "AGI"
        case "burst": "BST"
        case "strength": "STR"
        case "vertical": "VERT"
        case "stamina": "STA"
        case "durability": "DUR"
        case "layups": "LAY"
        case "dunks": "DNK"
        case "threePointShooting": "3PT"
        case "midrangeShot": "MID"
        case "closeShot": "CLS"
        case "cornerThrees": "C3"
        case "upTopThrees": "U3"
        case "drawFoul": "DRF"
        case "freeThrows": "FT"
        case "postControl": "POST"
        case "postFadeaways": "FADE"
        case "postHooks": "HOOK"
        case "ballHandling": "BH"
        case "ballSafety": "BSAF"
        case "passingAccuracy": "PACC"
        case "passingVision": "PVIS"
        case "passingIQ": "PIQ"
        case "shotIQ": "SIQ"
        case "offballOffense": "OFFB"
        case "hands": "HND"
        case "hustle": "HUS"
        case "clutch": "CLT"
        case "perimeterDefense": "PERD"
        case "postDefense": "POSTD"
        case "shotBlocking": "BLK"
        case "shotContest": "SCON"
        case "steals": "STL"
        case "lateralQuickness": "LATQ"
        case "offballDefense": "OFFD"
        case "passPerception": "PERC"
        case "defensiveControl": "DCTL"
        case "offensiveRebounding": "OREB"
        case "defensiveRebound": "DREB"
        case "boxouts": "BOX"
        case "tendencyThreePoint": "T3"
        case "tendencyMidrange": "TMID"
        case "tendencyInside": "TIN"
        case "tendencyPost": "TPOST"
        case "tendencyDrive": "TDRV"
        case "tendencyPickAndRoll": "TPNR"
        case "tendencyPickAndPop": "TPNP"
        case "tendencyShootVsPass": "TSVP"
        default:
            compactFallbackLabel(for: key)
        }
    }

    private func compactFallbackLabel(for key: String) -> String {
        let condensed = key.replacingOccurrences(of: "tendency", with: "T")
        var result = ""
        for character in condensed {
            if character.isUppercase || character.isNumber {
                result.append(character)
            }
        }
        if result.isEmpty {
            result = condensed.uppercased()
        }
        return String(result.prefix(4))
    }
}

private struct PlayerCareerTotals: Hashable {
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

    static let zero = PlayerCareerTotals(
        games: 0,
        minutes: 0,
        points: 0,
        rebounds: 0,
        assists: 0,
        steals: 0,
        blocks: 0,
        turnovers: 0,
        fgMade: 0,
        fgAttempts: 0,
        threeMade: 0,
        threeAttempts: 0,
        ftMade: 0,
        ftAttempts: 0
    )

    var pointsPerGame: Double { games > 0 ? Double(points) / Double(games) : 0 }
    var reboundsPerGame: Double { games > 0 ? Double(rebounds) / Double(games) : 0 }
    var assistsPerGame: Double { games > 0 ? Double(assists) / Double(games) : 0 }
    var fgPct: Double { fgAttempts > 0 ? Double(fgMade) / Double(fgAttempts) : 0 }
    var threePct: Double { threeAttempts > 0 ? Double(threeMade) / Double(threeAttempts) : 0 }
    var ftPct: Double { ftAttempts > 0 ? Double(ftMade) / Double(ftAttempts) : 0 }
}

private struct PlayerCardDetailView: View {
    let player: UserRosterPlayerSummary
    let schedule: [UserGameSummary]
    let userTeamName: String

    private var sortedRatings: [(key: String, value: Int)] {
        (player.attributes ?? [:])
            .map { ($0.key, $0.value) }
            .sorted { lhs, rhs in
                if lhs.1 != rhs.1 { return lhs.1 > rhs.1 }
                return lhs.0 < rhs.0
            }
    }

    private var ratingRows: [(id: AnyHashable, data: (label: String, value: Int))] {
        sortedRatings.map {
            (
                id: AnyHashable($0.key),
                data: (label: ratingLabel($0.key), value: $0.value)
            )
        }
    }

    private var topTraits: [String] {
        let attributes = player.attributes ?? [:]
        let scored: [(name: String, score: Double)] = [
            (
                "Sharpshooter",
                score(
                    attributes["threePointShooting"],
                    attributes["cornerThrees"],
                    attributes["upTopThrees"],
                    attributes["tendencyThreePoint"]
                )
            ),
            (
                "Playmaker",
                score(
                    attributes["passingVision"],
                    attributes["passingIQ"],
                    attributes["passingAccuracy"],
                    attributes["shotIQ"]
                )
            ),
            (
                "Rim Protector",
                score(
                    attributes["shotBlocking"],
                    attributes["shotContest"],
                    attributes["vertical"],
                    attributes["postDefense"]
                )
            ),
            (
                "Lockdown Defender",
                score(
                    attributes["perimeterDefense"],
                    attributes["lateralQuickness"],
                    attributes["offballDefense"],
                    attributes["steals"]
                )
            ),
            (
                "Glass Cleaner",
                score(
                    attributes["offensiveRebounding"],
                    attributes["defensiveRebound"],
                    attributes["boxouts"],
                    attributes["strength"]
                )
            ),
            (
                "Slasher",
                score(
                    attributes["layups"],
                    attributes["burst"],
                    attributes["ballHandling"],
                    attributes["tendencyDrive"]
                )
            ),
            (
                "Post Scorer",
                score(
                    attributes["postControl"],
                    attributes["postHooks"],
                    attributes["postFadeaways"],
                    attributes["tendencyPost"]
                )
            ),
            (
                "Floor General",
                score(
                    attributes["ballHandling"],
                    attributes["passingVision"],
                    attributes["passingIQ"],
                    attributes["tendencyShootVsPass"].map { 100 - $0 }
                )
            ),
        ]
        return scored
            .filter { $0.score >= 68 }
            .sorted { lhs, rhs in
                if lhs.score != rhs.score { return lhs.score > rhs.score }
                return lhs.name < rhs.name
            }
            .prefix(4)
            .map(\.name)
    }

    private var careerTotals: PlayerCareerTotals {
        var totals = PlayerCareerTotals.zero

        for game in schedule where game.completed == true {
            guard
                let line = findPlayerLine(in: game)
            else { continue }

            totals = PlayerCareerTotals(
                games: totals.games + 1,
                minutes: totals.minutes + line.minutes,
                points: totals.points + line.points,
                rebounds: totals.rebounds + line.rebounds,
                assists: totals.assists + line.assists,
                steals: totals.steals + line.steals,
                blocks: totals.blocks + line.blocks,
                turnovers: totals.turnovers + line.turnovers,
                fgMade: totals.fgMade + line.fgMade,
                fgAttempts: totals.fgAttempts + line.fgAttempts,
                threeMade: totals.threeMade + line.threeMade,
                threeAttempts: totals.threeAttempts + line.threeAttempts,
                ftMade: totals.ftMade + line.ftMade,
                ftAttempts: totals.ftAttempts + line.ftAttempts
            )
        }
        return totals
    }

    private var careerRows: [(id: AnyHashable, data: (label: String, value: String))] {
        let totals = careerTotals
        return [
            (id: AnyHashable("gp"), data: ("GP", "\(totals.games)")),
            (id: AnyHashable("min"), data: ("MIN", format(totals.minutes))),
            (id: AnyHashable("pts"), data: ("PTS", "\(totals.points)")),
            (id: AnyHashable("reb"), data: ("REB", "\(totals.rebounds)")),
            (id: AnyHashable("ast"), data: ("AST", "\(totals.assists)")),
            (id: AnyHashable("stl"), data: ("STL", "\(totals.steals)")),
            (id: AnyHashable("blk"), data: ("BLK", "\(totals.blocks)")),
            (id: AnyHashable("to"), data: ("TO", "\(totals.turnovers)")),
            (id: AnyHashable("fg"), data: ("FG%", pct(totals.fgPct))),
            (id: AnyHashable("three"), data: ("3PT%", pct(totals.threePct))),
            (id: AnyHashable("ft"), data: ("FT%", pct(totals.ftPct))),
            (id: AnyHashable("ppg"), data: ("PPG", format(totals.pointsPerGame))),
            (id: AnyHashable("rpg"), data: ("RPG", format(totals.reboundsPerGame))),
            (id: AnyHashable("apg"), data: ("APG", format(totals.assistsPerGame))),
        ]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                GroupBox("Player") {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(player.name)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.primary)
                        Text("\(player.position) • \(player.year) • OVR \(player.overall)\(player.isStarter ? " • Starter" : "")")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                GroupBox("Traits") {
                    if topTraits.isEmpty {
                        Text("No standout traits yet.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(topTraits, id: \.self) { trait in
                                Text(trait)
                                    .font(.caption.monospacedDigit().weight(.semibold))
                                    .foregroundStyle(.primary)
                            }
                        }
                    }
                }

                GroupBox("Ratings") {
                    let columns: [AppTableColumn<String>] = [
                        .init(id: "rating", title: "RATING", width: 180, alignment: .leading),
                        .init(id: "value", title: "VALUE", width: 60),
                    ]
                    AppTable(columns: columns, rows: ratingRows) { row in
                        HStack(spacing: 0) {
                            AppTableTextCell(
                                text: row.label,
                                width: 180,
                                alignment: .leading,
                                font: .caption.monospacedDigit()
                            )
                            AppTableTextCell(
                                text: "\(row.value)",
                                width: 60,
                                font: .caption.monospacedDigit().weight(.semibold)
                            )
                        }
                    }
                }

                GroupBox("Career Stats") {
                    let columns: [AppTableColumn<String>] = [
                        .init(id: "stat", title: "STAT", width: 90, alignment: .leading),
                        .init(id: "value", title: "VALUE", width: 80),
                    ]
                    AppTable(columns: columns, rows: careerRows) { row in
                        HStack(spacing: 0) {
                            AppTableTextCell(text: row.label, width: 90, alignment: .leading, font: .caption.monospacedDigit())
                            AppTableTextCell(text: row.value, width: 80, font: .caption.monospacedDigit().weight(.semibold))
                        }
                    }
                }
            }
            .padding(16)
        }
        .navigationTitle("Player Card")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func findPlayerLine(in game: UserGameSummary) -> ParsedPlayerBoxScore? {
        guard
            let resultObj = game.result?.objectDictionary,
            let teamBoxes = resultObj["boxScore"]?.arrayValues
        else { return nil }

        guard let userTeamBox = teamBoxes.first(where: { box in
            box.objectDictionary?["name"]?.stringValue == userTeamName
        }) else { return nil }

        let players = userTeamBox.objectDictionary?["players"]?.arrayValues ?? []
        return players
            .compactMap(ParsedPlayerBoxScore.init(value:))
            .first(where: { line in
                line.playerName == player.name && line.position == player.position
            })
    }

    private func ratingLabel(_ key: String) -> String {
        switch key {
        case "potential": "Potential"
        case "speed": "Speed"
        case "agility": "Agility"
        case "burst": "Burst"
        case "strength": "Strength"
        case "vertical": "Vertical"
        case "stamina": "Stamina"
        case "durability": "Durability"
        case "layups": "Layups"
        case "dunks": "Dunks"
        case "closeShot": "Close Shot"
        case "midrangeShot": "Midrange Shot"
        case "threePointShooting": "Three Point"
        case "cornerThrees": "Corner Threes"
        case "upTopThrees": "Above-the-Break 3"
        case "drawFoul": "Draw Foul"
        case "freeThrows": "Free Throws"
        case "postControl": "Post Control"
        case "postFadeaways": "Post Fadeaways"
        case "postHooks": "Post Hooks"
        case "ballHandling": "Ball Handling"
        case "ballSafety": "Ball Safety"
        case "passingAccuracy": "Passing Accuracy"
        case "passingVision": "Passing Vision"
        case "passingIQ": "Passing IQ"
        case "shotIQ": "Shot IQ"
        case "offballOffense": "Off-Ball Offense"
        case "hands": "Hands"
        case "hustle": "Hustle"
        case "clutch": "Clutch"
        case "perimeterDefense": "Perimeter Defense"
        case "postDefense": "Post Defense"
        case "shotBlocking": "Shot Blocking"
        case "shotContest": "Shot Contest"
        case "steals": "Steals"
        case "lateralQuickness": "Lateral Quickness"
        case "offballDefense": "Off-Ball Defense"
        case "passPerception": "Pass Perception"
        case "defensiveControl": "Defensive Control"
        case "offensiveRebounding": "Offensive Rebounding"
        case "defensiveRebound": "Defensive Rebound"
        case "boxouts": "Boxouts"
        case "tendencyPost": "Tendency: Post"
        case "tendencyInside": "Tendency: Inside"
        case "tendencyMidrange": "Tendency: Midrange"
        case "tendencyThreePoint": "Tendency: Three"
        case "tendencyDrive": "Tendency: Drive"
        case "tendencyPickAndRoll": "Tendency: Pick & Roll"
        case "tendencyPickAndPop": "Tendency: Pick & Pop"
        case "tendencyShootVsPass": "Tendency: Shoot vs Pass"
        default:
            key
        }
    }

    private func score(_ values: Int?...) -> Double {
        let valid = values.compactMap { $0 }
        guard !valid.isEmpty else { return 0 }
        return Double(valid.reduce(0, +)) / Double(valid.count)
    }

    private func format(_ value: Double) -> String {
        String(format: "%.1f", value)
    }

    private func pct(_ value: Double) -> String {
        String(format: "%.1f%%", value * 100)
    }
}

private struct ScheduleListView: View {
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
                    Text(userScore > oppScore ? "W" : "L")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(userScore > oppScore ? .green : .red)
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
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct BoxScoreDetailView: View {
    let game: UserGameSummary
    let userTeamName: String

    private var homeScore: Int { game.result?.intValue(for: "homeScore") ?? 0 }
    private var awayScore: Int { game.result?.intValue(for: "awayScore") ?? 0 }
    private var overtime: Bool { game.result?.boolValue(for: "wentToOvertime") ?? false }
    private var boxTeams: [ParsedTeamBoxScore] { ParsedTeamBoxScore.parse(from: game.result) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                GroupBox("Final") {
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
            .init(id: "player", title: "PLYR", width: 140, alignment: .leading),
            .init(id: "min", title: "MIN", width: 44),
            .init(id: "pts", title: "PTS", width: 42),
            .init(id: "reb", title: "REB", width: 42),
            .init(id: "ast", title: "AST", width: 42),
            .init(id: "stl", title: "STL", width: 42),
            .init(id: "blk", title: "BLK", width: 42),
            .init(id: "to", title: "TO", width: 42),
            .init(id: "fg", title: "FG", width: 64),
            .init(id: "three", title: "3PT", width: 64),
            .init(id: "ft", title: "FT", width: 64),
            .init(id: "pf", title: "PF", width: 42),
        ]
        let tableRows = Array(team.players.enumerated()).map {
            (id: AnyHashable("\($0.offset)-\($0.element.playerName)"), data: $0.element)
        }

        return GroupBox(team.name) {
            AppTable(columns: columns, rows: tableRows) { player in
                HStack(spacing: 0) {
                    AppTableTextCell(
                        text: "\(player.playerName) (\(player.position))",
                        width: 140,
                        alignment: .leading,
                        font: .caption.monospacedDigit()
                    )
                    AppTableTextCell(text: "\(Int(player.minutes.rounded()))", width: 44, font: .caption.monospacedDigit())
                    AppTableTextCell(text: "\(player.points)", width: 42, font: .caption.monospacedDigit())
                    AppTableTextCell(text: "\(player.rebounds)", width: 42, font: .caption.monospacedDigit())
                    AppTableTextCell(text: "\(player.assists)", width: 42, font: .caption.monospacedDigit())
                    AppTableTextCell(text: "\(player.steals)", width: 42, font: .caption.monospacedDigit())
                    AppTableTextCell(text: "\(player.blocks)", width: 42, font: .caption.monospacedDigit())
                    AppTableTextCell(text: "\(player.turnovers)", width: 42, font: .caption.monospacedDigit())
                    AppTableTextCell(text: "\(player.fgMade)-\(player.fgAttempts)", width: 64, font: .caption.monospacedDigit())
                    AppTableTextCell(text: "\(player.threeMade)-\(player.threeAttempts)", width: 64, font: .caption.monospacedDigit())
                    AppTableTextCell(text: "\(player.ftMade)-\(player.ftAttempts)", width: 64, font: .caption.monospacedDigit())
                    AppTableTextCell(text: "\(player.fouls)", width: 42, font: .caption.monospacedDigit())
                }
            }
        }
    }
}

private struct PlayerStatsRow: Hashable {
    let name: String
    let games: Int
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

    private func perGame(_ value: Int) -> Double {
        guard games > 0 else { return 0 }
        return Double(value) / Double(games)
    }

    private func percentage(made: Int, attempts: Int) -> Double {
        guard attempts > 0 else { return 0 }
        return (Double(made) / Double(attempts)) * 100
    }
}

private struct PlayerStatsView: View {
    let schedule: [UserGameSummary]
    let userTeamName: String
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
            .init(id: "name", title: "PLYR", width: 170, alignment: .leading),
            .init(id: "games", title: "G", width: 42),
            .init(id: "points", title: "PTS", width: 48),
            .init(id: "rebounds", title: "REB", width: 48),
            .init(id: "assists", title: "AST", width: 48),
            .init(id: "steals", title: "STL", width: 48),
            .init(id: "blocks", title: "BLK", width: 48),
            .init(id: "turnovers", title: "TO", width: 48),
            .init(id: "fg", title: "FG%", width: 64),
            .init(id: "three", title: "3PT%", width: 64),
            .init(id: "ft", title: "FT%", width: 64),
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
                    AppTableTextCell(text: row.name, width: 170, alignment: .leading)
                    AppTableTextCell(text: "\(row.games)", width: 42)
                    AppTableTextCell(text: format(row.pointsPerGame), width: 48)
                    AppTableTextCell(text: format(row.reboundsPerGame), width: 48)
                    AppTableTextCell(text: format(row.assistsPerGame), width: 48)
                    AppTableTextCell(text: format(row.stealsPerGame), width: 48)
                    AppTableTextCell(text: format(row.blocksPerGame), width: 48)
                    AppTableTextCell(text: format(row.turnoversPerGame), width: 48)
                    AppTableTextCell(text: formatPercentage(row.fgPercentage, attempts: row.fgAttempts), width: 64)
                    AppTableTextCell(text: formatPercentage(row.threePercentage, attempts: row.threeAttempts), width: 64)
                    AppTableTextCell(text: formatPercentage(row.ftPercentage, attempts: row.ftAttempts), width: 64)
                }
            }
        }
        .background(Color(.secondarySystemBackground))
        .navigationTitle("Player Stats")
        .navigationBarTitleDisplayMode(.inline)
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

private struct ConferenceStandingsView: View {
    let standingsByConference: [String: [ConferenceStanding]]
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

                        GroupBox(conferenceTitle(conferenceId)) {
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
        switch id {
        case "acc": "ACC"
        case "sec": "SEC"
        case "big-ten": "Big Ten"
        case "big-12": "Big 12"
        case "big-east": "Big East"
        default: id.uppercased()
        }
    }

    private func formatPerGame(points: Int, wins: Int, losses: Int) -> String {
        let gamesPlayed = wins + losses
        guard gamesPlayed > 0 else { return "0.0" }
        return String(format: "%.1f", Double(points) / Double(gamesPlayed))
    }
}

private struct ParsedTeamBoxScore {
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

private struct ParsedPlayerBoxScore {
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
    let assists: Int
    let steals: Int
    let blocks: Int
    let turnovers: Int
    let fouls: Int

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
        assists = object["assists"]?.intValue ?? 0
        steals = object["steals"]?.intValue ?? 0
        blocks = object["blocks"]?.intValue ?? 0
        turnovers = object["turnovers"]?.intValue ?? 0
        fouls = object["fouls"]?.intValue ?? 0
    }
}

private extension PaceProfile {
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

private extension CoachArchetype {
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

private extension OffensiveFormation {
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

private extension DefenseScheme {
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

private extension AssistantFocus {
    var label: String {
        switch self {
        case .recruiting: "Recruiting"
        case .development: "Development"
        case .gamePrep: "Game Prep"
        case .scouting: "Scouting"
        }
    }
}

private extension Coach {
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
}

private extension JSONValue {
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

private extension Double {
    var roundedInt: Int {
        Int(self.rounded())
    }
}

#Preview {
    ContentView()
}
