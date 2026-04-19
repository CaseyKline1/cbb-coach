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
                SingleSelectDropdown(
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
                SingleSelectDropdown(
                    label: "Tempo",
                    selection: $selectedPace,
                    options: PaceProfile.allCases,
                    optionLabel: \.label
                )

                SingleSelectDropdown(
                    label: "Base Offense",
                    selection: $selectedOffense,
                    options: OffensiveFormation.allCases,
                    optionLabel: \.label
                )

                SingleSelectDropdown(
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

struct SingleSelectDropdown<Option: Hashable>: View {
    let label: String
    @Binding var selection: Option
    let options: [Option]
    let optionLabel: (Option) -> String

    init(
        label: String,
        selection: Binding<Option>,
        options: [Option],
        optionLabel: @escaping (Option) -> String
    ) {
        self.label = label
        self._selection = selection
        self.options = options
        self.optionLabel = optionLabel
    }

    init(
        label: String,
        selection: Binding<Option>,
        options: [Option],
        optionLabel: KeyPath<Option, String>
    ) {
        self.init(
            label: label,
            selection: selection,
            options: options,
            optionLabel: { $0[keyPath: optionLabel] }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Menu {
                ForEach(options.indices, id: \.self) { index in
                    let option = options[index]
                    Button {
                        selection = option
                    } label: {
                        if option == selection {
                            Label(optionLabel(option), systemImage: "checkmark")
                        } else {
                            Text(optionLabel(option))
                        }
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Text(optionLabel(selection))
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.black.opacity(0.14), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("\(label): \(optionLabel(selection))"))
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
                            StatChip(title: "Day", value: "\(summary.currentDay)")
                            StatChip(title: "Games", value: "\(summary.totalScheduledGames)")
                            StatChip(title: "Record", value: userRecordText)
                        }
                    }

                    Text(statusText)
                        .font(.subheadline)

                    GroupBox("Team") {
                        VStack(spacing: 8) {
                            NavigationLink(value: LeagueMenuDestination.roster) {
                                MenuRow(title: "Roster", subtitle: "Sortable table with all ratings & attributes")
                            }
                            .buttonStyle(.plain)

                            NavigationLink(value: LeagueMenuDestination.schedule) {
                                MenuRow(title: "Schedule", subtitle: "Full schedule and completed game results")
                            }
                            .buttonStyle(.plain)

                            NavigationLink(value: LeagueMenuDestination.playerStats) {
                                MenuRow(title: "Player Stats", subtitle: "Per-game averages from completed games")
                            }
                            .buttonStyle(.plain)

                            NavigationLink(value: LeagueMenuDestination.standings) {
                                MenuRow(title: "Standings", subtitle: "Conference records and point differentials")
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if let lastPlayed = latestCompletedGame {
                        GroupBox("Last Result") {
                            NavigationLink(value: LeagueMenuDestination.boxScore(lastPlayed.gameId ?? "")) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Day \(lastPlayed.day ?? 0): \(lastPlayed.isHome == true ? "vs" : "@") \(lastPlayed.opponentName ?? "Unknown")")
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
                    RosterRatingsView(roster: roster)
                case .schedule:
                    ScheduleListView(schedule: schedule, userTeamName: summary?.userTeamName ?? teamName)
                case .playerStats:
                    PlayerStatsView(schedule: schedule, userTeamName: summary?.userTeamName ?? teamName)
                case .standings:
                    ConferenceStandingsView(
                        standingsByConference: conferenceStandings,
                        preferredConferenceId: userConferenceId
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

    private var latestCompletedGame: UserGameSummary? {
        schedule
            .filter { $0.completed == true && $0.gameId != nil }
            .max { ($0.day ?? 0) < ($1.day ?? 0) }
    }

    private var userConferenceId: String? {
        listCareerTeamOptions().first(where: { $0.teamName == teamName })?.conferenceId
    }

    private func createLeague() {
        do {
            var options = CreateLeagueOptions(userTeamName: teamName, seed: "ios-league-\(profile.fullName)-\(teamName)")
            options.userHeadCoachSkills = profile.archetype.initialSkills
            let created = try createD1League(options: options)
            league = created
            roster = getUserRoster(created)
            schedule = getUserSchedule(created)
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
        summary = getLeagueSummary(currentLeague)
        conferenceStandings = fetchConferenceStandings(currentLeague)
        if result.done == true {
            statusText = "Season complete."
            return
        }
        let userScore = result.score?.numberValue(for: "user")?.roundedInt ?? 0
        let oppScore = result.score?.numberValue(for: "opponent")?.roundedInt ?? 0
        statusText = "Day \(result.day ?? 0): \(result.opponentName ?? "Unknown") \(userScore)-\(oppScore) (\(result.won == true ? "W" : "L"))"
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
}

private enum LeagueMenuDestination: Hashable {
    case roster
    case schedule
    case playerStats
    case standings
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
    let subtitle: String

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
    }
}

private struct RosterRatingsView: View {
    let roster: [UserRosterPlayerSummary]
    @State private var sortColumn: String = "overall"
    @State private var isAscending: Bool = false
    private let headerVerticalPadding: CGFloat = 3
    private let rowVerticalPadding: CGFloat = 2
    private let minimumRowHeight: CGFloat = 20

    private let preferredAttributeOrder: [String] = [
        "potential", "speed", "agility", "burst", "strength", "vertical", "stamina", "durability",
        "layups", "dunks", "closeShot", "midrangeShot", "threePointShooting", "cornerThrees", "upTopThrees", "drawFoul", "freeThrows",
        "postControl", "postFadeaways", "postHooks",
        "ballHandling", "ballSafety", "passingAccuracy", "passingVision", "passingIQ", "shotIQ", "offballOffense", "hands", "hustle", "clutch",
        "perimeterDefense", "postDefense", "shotBlocking", "shotContest", "steals", "lateralQuickness", "offballDefense", "passPerception", "defensiveControl",
        "offensiveRebounding", "defensiveRebound", "boxouts",
        "tendencyPost", "tendencyInside", "tendencyMidrange", "tendencyThreePoint", "tendencyDrive", "tendencyPickAndRoll", "tendencyPickAndPop", "tendencyShootVsPass",
    ]

    private var attributeColumns: [String] {
        let keys = Set(roster.flatMap { Array(($0.attributes ?? [:]).keys) })
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

    var body: some View {
        ScrollView([.horizontal, .vertical], showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: 0) {
                headerRow
                ForEach(Array(sortedRoster.enumerated()), id: \.offset) { _, player in
                    dataRow(player)
                        .background(Color(.systemBackground))
                    Divider()
                }
            }
        }
        .background(Color(.secondarySystemBackground))
        .navigationTitle("Roster")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var headerRow: some View {
        HStack(spacing: 0) {
            sortableHeader("ST", id: "isStarter", width: 30)
            sortableHeader("PLYR", id: "name", width: 132, alignment: .leading)
            sortableHeader("POS", id: "position", width: 42)
            sortableHeader("YR", id: "year", width: 30)
            sortableHeader("OVR", id: "overall", width: 38)
            ForEach(attributeColumns, id: \.self) { column in
                sortableHeader(attributeLabel(column), id: column, width: 44)
            }
        }
        .padding(.vertical, headerVerticalPadding)
        .background(Color(.tertiarySystemBackground))
    }

    private func dataRow(_ player: UserRosterPlayerSummary) -> some View {
        HStack(spacing: 0) {
            textCell(player.isStarter ? "★" : "", width: 30, alignment: .center)
            textCell(player.name, width: 132, alignment: .leading)
            textCell(player.position, width: 42, alignment: .center)
            textCell(player.year, width: 30, alignment: .center)
            textCell("\(player.overall)", width: 38, alignment: .center)
            ForEach(attributeColumns, id: \.self) { key in
                let value = player.attributes?[key] ?? 0
                textCell("\(value)", width: 44, alignment: .center)
            }
        }
        .font(.caption2.monospacedDigit())
        .frame(minHeight: minimumRowHeight)
        .padding(.vertical, rowVerticalPadding)
    }

    private func sortableHeader(_ title: String, id: String, width: CGFloat, alignment: Alignment = .center) -> some View {
        Button {
            if sortColumn == id {
                isAscending.toggle()
            } else {
                sortColumn = id
                isAscending = false
            }
        } label: {
            HStack(spacing: 2) {
                Text(title)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(sortColumn == id ? .primary : .secondary)
                if sortColumn == id {
                    Image(systemName: isAscending ? "chevron.up" : "chevron.down")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(.primary)
                }
            }
            .frame(width: width, alignment: alignment)
        }
        .buttonStyle(.plain)
    }

    private func textCell(_ text: String, width: CGFloat, alignment: Alignment) -> some View {
        Text(text)
            .lineLimit(1)
            .truncationMode(.tail)
            .frame(width: width, alignment: alignment)
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

private struct ScheduleListView: View {
    let schedule: [UserGameSummary]
    let userTeamName: String

    private var groupedByDay: [(Int, [UserGameSummary])] {
        Dictionary(grouping: schedule) { $0.day ?? 0 }
            .map { (key: $0.key, value: $0.value.sorted { ($0.gameId ?? "") < ($1.gameId ?? "") }) }
            .sorted { $0.key < $1.key }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ForEach(groupedByDay, id: \.0) { day, games in
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Day \(day)")
                            .font(.headline)
                        ForEach(Array(games.enumerated()), id: \.offset) { _, game in
                            scheduleRow(game)
                        }
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
        GroupBox(team.name) {
            ScrollView(.horizontal) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 10) {
                        header("Player", width: 140, align: .leading)
                        header("MIN", width: 44)
                        header("PTS", width: 42)
                        header("REB", width: 42)
                        header("AST", width: 42)
                        header("STL", width: 42)
                        header("BLK", width: 42)
                        header("TO", width: 42)
                        header("FG", width: 64)
                        header("3PT", width: 64)
                        header("FT", width: 64)
                        header("PF", width: 42)
                    }
                    ForEach(team.players, id: \.playerName) { player in
                        HStack(spacing: 10) {
                            cell("\(player.playerName) (\(player.position))", width: 140, align: .leading)
                            cell(String(format: "%.1f", player.minutes), width: 44)
                            cell("\(player.points)", width: 42)
                            cell("\(player.rebounds)", width: 42)
                            cell("\(player.assists)", width: 42)
                            cell("\(player.steals)", width: 42)
                            cell("\(player.blocks)", width: 42)
                            cell("\(player.turnovers)", width: 42)
                            cell("\(player.fgMade)-\(player.fgAttempts)", width: 64)
                            cell("\(player.threeMade)-\(player.threeAttempts)", width: 64)
                            cell("\(player.ftMade)-\(player.ftAttempts)", width: 64)
                            cell("\(player.fouls)", width: 42)
                        }
                        .font(.caption.monospacedDigit())
                    }
                }
            }
        }
    }

    private func header(_ text: String, width: CGFloat, align: Alignment = .center) -> some View {
        Text(text)
            .font(.caption2.weight(.bold))
            .frame(width: width, alignment: align)
    }

    private func cell(_ text: String, width: CGFloat, align: Alignment = .center) -> some View {
        Text(text)
            .lineLimit(1)
            .frame(width: width, alignment: align)
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

    private func perGame(_ value: Int) -> Double {
        guard games > 0 else { return 0 }
        return Double(value) / Double(games)
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

    var body: some View {
        ScrollView([.vertical, .horizontal]) {
            LazyVStack(alignment: .leading, spacing: 0) {
                header
                ForEach(rows, id: \.name) { row in
                    rowView(row)
                    Divider()
                }
            }
        }
        .background(Color(.secondarySystemBackground))
        .navigationTitle("Player Stats")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        HStack(spacing: 0) {
            sortHeader("PLAYER", id: "name", width: 170)
            sortHeader("G", id: "games", width: 42)
            sortHeader("PTS", id: "points", width: 48)
            sortHeader("REB", id: "rebounds", width: 48)
            sortHeader("AST", id: "assists", width: 48)
            sortHeader("STL", id: "steals", width: 48)
            sortHeader("BLK", id: "blocks", width: 48)
            sortHeader("TO", id: "turnovers", width: 48)
            sortHeader("FG", id: "fg", width: 78)
            sortHeader("3PT", id: "three", width: 78)
            sortHeader("FT", id: "ft", width: 78)
        }
        .padding(.vertical, 6)
        .background(Color(.tertiarySystemBackground))
    }

    private func rowView(_ row: PlayerStatsRow) -> some View {
        HStack(spacing: 0) {
            cell(row.name, width: 170, align: .leading)
            cell("\(row.games)", width: 42)
            cell(format(row.pointsPerGame), width: 48)
            cell(format(row.reboundsPerGame), width: 48)
            cell(format(row.assistsPerGame), width: 48)
            cell(format(row.stealsPerGame), width: 48)
            cell(format(row.blocksPerGame), width: 48)
            cell(format(row.turnoversPerGame), width: 48)
            cell("\(format(row.fgMadePerGame))-\(format(row.fgAttemptsPerGame))", width: 78)
            cell("\(format(row.threeMadePerGame))-\(format(row.threeAttemptsPerGame))", width: 78)
            cell("\(format(row.ftMadePerGame))-\(format(row.ftAttemptsPerGame))", width: 78)
        }
        .font(.caption.monospacedDigit())
        .padding(.vertical, 5)
        .background(Color(.systemBackground))
    }

    private func sortHeader(_ title: String, id: String, width: CGFloat) -> some View {
        Button {
            if sortColumn == id {
                isAscending.toggle()
            } else {
                sortColumn = id
                isAscending = false
            }
        } label: {
            HStack(spacing: 3) {
                Text(title).font(.caption2.weight(.bold))
                if sortColumn == id {
                    Image(systemName: isAscending ? "arrow.up" : "arrow.down")
                        .font(.caption2.weight(.bold))
                }
            }
            .frame(width: width)
            .foregroundStyle(.primary)
        }
        .buttonStyle(.plain)
    }

    private func cell(_ value: String, width: CGFloat, align: Alignment = .center) -> some View {
        Text(value)
            .lineLimit(1)
            .frame(width: width, alignment: align)
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
            return numeric(lhs.fgMadePerGame, rhs.fgMadePerGame)
        case "three":
            return numeric(lhs.threeMadePerGame, rhs.threeMadePerGame)
        case "ft":
            return numeric(lhs.ftMadePerGame, rhs.ftMadePerGame)
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
                        GroupBox(conferenceTitle(conferenceId)) {
                            VStack(spacing: 0) {
                                HStack {
                                    header("Team", alignment: .leading)
                                    header("Conf")
                                    header("Overall")
                                    header("PF")
                                    header("PA")
                                    header("DIFF")
                                }
                                .padding(.bottom, 6)

                                ForEach(rows, id: \.teamId) { row in
                                    HStack {
                                        Text(row.teamName)
                                            .font(.subheadline.weight(.semibold))
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        value("\(row.conferenceWins)-\(row.conferenceLosses)")
                                        value("\(row.wins)-\(row.losses)")
                                        value("\(row.pointsFor ?? 0)")
                                        value("\(row.pointsAgainst ?? 0)")
                                        value("\((row.pointsFor ?? 0) - (row.pointsAgainst ?? 0))")
                                    }
                                    .padding(.vertical, 4)
                                    Divider()
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

    private func header(_ label: String, alignment: Alignment = .center) -> some View {
        Text(label)
            .font(.caption2.weight(.bold))
            .frame(width: label == "Team" ? 140 : 56, alignment: alignment)
    }

    private func value(_ text: String) -> some View {
        Text(text)
            .font(.caption.monospacedDigit().weight(.medium))
            .frame(width: 56, alignment: .center)
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
