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
    @AppStorage("coachTeam") private var coachTeam: String = "Duke"

    var body: some View {
        Group {
            if coachCreationComplete, let profile = loadedProfile {
                SimulatorHubView(profile: profile, onCreateNewCoach: resetCoachCreation)
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
            !coachFirstName.isEmpty,
            !coachLastName.isEmpty,
            !coachTeam.isEmpty
        else {
            return nil
        }

        return CoachCreationProfile(
            firstName: coachFirstName,
            lastName: coachLastName,
            age: coachAge,
            pace: pace,
            offense: offense,
            defense: defense,
            teamName: coachTeam
        )
    }

    private func saveProfile(_ profile: CoachCreationProfile) {
        coachFirstName = profile.firstName
        coachLastName = profile.lastName
        coachAge = profile.age
        coachPaceRaw = profile.pace.rawValue
        coachOffenseRaw = profile.offense.rawValue
        coachDefenseRaw = profile.defense.rawValue
        coachTeam = profile.teamName
        coachCreationComplete = true
    }

    private func resetCoachCreation() {
        coachCreationComplete = false
    }
}

private struct CoachCreationFlowView: View {
    let onComplete: (CoachCreationProfile) -> Void

    @State private var path: [CoachCreationStep] = []

    var body: some View {
        NavigationStack(path: $path) {
            CoachIdentityStepView { identity in
                path.append(.style(identity))
            }
            .navigationDestination(for: CoachCreationStep.self) { step in
                switch step {
                case .style(let identity):
                    CoachStyleStepView(identity: identity) { style in
                        path.append(.team(identity, style))
                    }
                case .team(let identity, let style):
                    CoachTeamStepView(identity: identity, style: style, onComplete: onComplete)
                }
            }
        }
    }
}

private enum CoachCreationStep: Hashable {
    case style(CoachIdentitySelection)
    case team(CoachIdentitySelection, CoachStyleSelection)
}

private struct CoachCreationProfile {
    let firstName: String
    let lastName: String
    let age: Int
    let pace: PaceProfile
    let offense: OffensiveFormation
    let defense: DefenseScheme
    let teamName: String

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
            nextLabel: "Next: Style",
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

private struct CoachStyleStepView: View {
    let identity: CoachIdentitySelection
    let onNext: (CoachStyleSelection) -> Void

    @State private var selectedPace: PaceProfile = .normal
    @State private var selectedOffense: OffensiveFormation = .motion
    @State private var selectedDefense: DefenseScheme = .manToMan

    var body: some View {
        OnboardingStepScaffold(
            title: "Define Your Style",
            subtitle: "Step 2 of 3",
            navTitle: "Coach Setup",
            nextLabel: "Next: Team",
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
                Picker("Tempo", selection: $selectedPace) {
                    ForEach(PaceProfile.allCases, id: \.self) { pace in
                        Text(pace.label).tag(pace)
                    }
                }
                .pickerStyle(.menu)

                Picker("Base Offense", selection: $selectedOffense) {
                    ForEach(OffensiveFormation.allCases, id: \.self) { formation in
                        Text(formation.label).tag(formation)
                    }
                }
                .pickerStyle(.menu)

                Picker("Base Defense", selection: $selectedDefense) {
                    ForEach(DefenseScheme.allCases, id: \.self) { defense in
                        Text(defense.label).tag(defense)
                    }
                }
                .pickerStyle(.menu)

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

private struct CoachTeamStepView: View {
    let identity: CoachIdentitySelection
    let style: CoachStyleSelection
    let onComplete: (CoachCreationProfile) -> Void

    @State private var selectedTeam: String = featuredTeams[0]

    var body: some View {
        OnboardingStepScaffold(
            title: "Choose Your Program",
            subtitle: "Step 3 of 3",
            navTitle: "Coach Setup",
            nextLabel: "Start Career",
            nextDisabled: false,
            onNext: {
                onComplete(
                    CoachCreationProfile(
                        firstName: identity.firstName,
                        lastName: identity.lastName,
                        age: identity.age,
                        pace: style.pace,
                        offense: style.offense,
                        defense: style.defense,
                        teamName: selectedTeam
                    )
                )
            }
        ) {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Self.featuredTeams, id: \.self) { team in
                    Button {
                        selectedTeam = team
                    } label: {
                        HStack {
                            Text(team)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                            Spacer()
                            if selectedTeam == team {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.orange)
                            }
                        }
                        .padding(12)
                        .background(selectedTeam == team ? Color.orange.opacity(0.1) : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(selectedTeam == team ? Color.orange.opacity(0.5) : Color.black.opacity(0.08), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(18)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private static let featuredTeams: [String] = [
        "Duke",
        "North Carolina",
        "UConn",
        "Kansas",
        "Kentucky",
        "UCLA",
        "Gonzaga",
        "Villanova",
        "Michigan State",
        "Baylor"
    ]
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

private struct SimulatorHubView: View {
    let profile: CoachCreationProfile
    let onCreateNewCoach: () -> Void

    @State private var gameSummary: String = "Tap simulate to run a game"
    @State private var leagueSummary: String = ""

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Coach \(profile.fullName)")
                        .font(.largeTitle.bold())
                    Text("\(profile.teamName) | Pace: \(profile.pace.label)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Text(gameSummary)
                    .font(.headline)

                if !leagueSummary.isEmpty {
                    Text(leagueSummary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 12) {
                    Button("Simulate Game") {
                        runGame()
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Start \(profile.teamName) League") {
                        runLeague()
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
            .navigationTitle("Simulator")
        }
    }

    private func makeLineup(prefix: String, three: Int, mid: Int, layup: Int, random: inout SeededRandom) -> [Player] {
        (0..<5).map { i in
            var p = createPlayer()
            p.bio.name = "\(prefix) Player \(i + 1)"
            p.bio.position = [.pg, .sg, .sf, .pf, .c][i]
            p.shooting.threePointShooting = clamp(three + i - 2, min: 35, max: 99)
            p.shooting.midrangeShot = clamp(mid + i - 2, min: 35, max: 99)
            p.shooting.layups = clamp(layup + i - 2, min: 35, max: 99)
            p.skills.shotIQ = clamp(65 + i * 3, min: 35, max: 99)
            p.defense.perimeterDefense = clamp(62 + i * 2, min: 35, max: 99)
            p.defense.shotContest = clamp(60 + i * 3, min: 35, max: 99)
            return p
        }
    }

    private func runGame() {
        var random = SeededRandom(seed: hashString("ios-sim-\(profile.teamName)-\(profile.fullName)"))
        let homePlayers = makeLineup(prefix: profile.teamName, three: 74, mid: 70, layup: 72, random: &random)
        let awayPlayers = makeLineup(prefix: "Rival", three: 71, mid: 68, layup: 73, random: &random)

        let home = createTeam(options: CreateTeamOptions(name: profile.teamName, players: homePlayers), random: &random)
        let away = createTeam(options: CreateTeamOptions(name: "Away State", players: awayPlayers), random: &random)

        let result = simulateGame(homeTeam: home, awayTeam: away, random: &random)
        gameSummary = "\(result.away.name) \(result.away.score) - \(result.home.name) \(result.home.score)"
    }

    private func runLeague() {
        do {
            var league = try createD1League(options: CreateLeagueOptions(userTeamName: profile.teamName, seed: "ios-league-\(profile.fullName)"))
            autoFillUserNonConferenceOpponents(&league)
            generateSeasonSchedule(&league)
            _ = advanceToNextUserGame(&league)
            let summary = getLeagueSummary(league)
            leagueSummary = "\(summary.userTeamName): \(summary.totalScheduledGames) games scheduled"
        } catch {
            leagueSummary = "League error: \(error.localizedDescription)"
        }
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

#Preview {
    ContentView()
}
