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

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Coach \(profile.fullName)")
                        .font(.largeTitle.bold())
                    Text("\(teamName) | \(profile.archetype.label) Archetype | Pace: \(profile.pace.label)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Text(statusText)
                    .font(.subheadline)

                GroupBox("Roster") {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(roster, id: \.name) { player in
                                HStack {
                                    Text("\(player.isStarter ? "⭐" : "•") \(player.name)")
                                        .font(.subheadline)
                                    Spacer()
                                    Text("\(player.position) \(player.year) OVR \(player.overall)")
                                        .font(.caption.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .frame(maxHeight: 170)
                }

                GroupBox("Schedule") {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(schedule.prefix(18), id: \.gameId) { game in
                                let marker = game.completed == true ? "✓" : "•"
                                Text("\(marker) Day \(game.day ?? 0): \(game.isHome == true ? "vs" : "@") \(game.opponentName ?? "Unknown")")
                                    .font(.subheadline)
                            }
                        }
                    }
                    .frame(maxHeight: 220)
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

                Spacer()
            }
            .padding(20)
            .navigationTitle("College League")
            .onAppear {
                if league == nil {
                    createLeague()
                }
            }
        }
    }

    private func createLeague() {
        do {
            var options = CreateLeagueOptions(userTeamName: teamName, seed: "ios-league-\(profile.fullName)-\(teamName)")
            options.userHeadCoachSkills = profile.archetype.initialSkills
            let created = try createD1League(options: options)
            league = created
            roster = getUserRoster(created)
            schedule = getUserSchedule(created)
            let summary = getLeagueSummary(created)
            statusText = "\(summary.userTeamName): \(summary.totalScheduledGames) total games generated"
        } catch {
            statusText = "League error: \(error.localizedDescription)"
        }
    }

    private func playNextGame() {
        guard var currentLeague = league else { return }
        guard let result = advanceToNextUserGame(&currentLeague) else { return }
        league = currentLeague
        schedule = getUserSchedule(currentLeague)
        if result.done == true {
            statusText = "Season complete."
            return
        }
        let userScore = result.score?.numberValue(for: "user")?.roundedInt ?? 0
        let oppScore = result.score?.numberValue(for: "opponent")?.roundedInt ?? 0
        statusText = "Day \(result.day ?? 0): \(result.opponentName ?? "Unknown") \(userScore)-\(oppScore) (\(result.won == true ? "W" : "L"))"
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
    func numberValue(for key: String) -> Double? {
        guard case let .object(values) = self, let value = values[key], case let .number(number) = value else {
            return nil
        }
        return number
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
