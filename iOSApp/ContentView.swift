import SwiftUI
import UniformTypeIdentifiers
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
    @AppStorage("coachAlmaMater") private var coachAlmaMater: String = "Independent"
    @AppStorage("coachPipelineState") private var coachPipelineState: String = "CA"
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
                        onChooseDifferentTeam: {
                            LeagueStore.clear()
                            coachCareerTeam = ""
                        },
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
            defense: defense,
            almaMater: coachAlmaMater,
            pipelineState: coachPipelineState
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
        coachAlmaMater = profile.almaMater
        coachPipelineState = profile.pipelineState
        coachCreationComplete = true
    }

    private func resetCoachCreation() {
        LeagueStore.clear()
        coachCareerTeam = ""
        coachAlmaMater = "Independent"
        coachPipelineState = "CA"
        coachCreationComplete = false
    }
}

struct CoachCreationFlowView: View {
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
                        path.append(.background(identity, archetype, style))
                    }
                case .background(let identity, let archetype, let style):
                    CoachBackgroundStepView(identity: identity) { background in
                        onComplete(
                            CoachCreationProfile(
                                firstName: identity.firstName,
                                lastName: identity.lastName,
                                age: identity.age,
                                archetype: archetype,
                                pace: style.pace,
                                offense: style.offense,
                                defense: style.defense,
                                almaMater: background.almaMater,
                                pipelineState: background.pipelineState
                            )
                        )
                    }
                }
            }
        }
    }
}

enum CoachCreationStep: Hashable {
    case archetype(CoachIdentitySelection)
    case style(CoachIdentitySelection, CoachArchetype)
    case background(CoachIdentitySelection, CoachArchetype, CoachStyleSelection)
}

struct CoachCreationProfile {
    let firstName: String
    let lastName: String
    let age: Int
    let archetype: CoachArchetype
    let pace: PaceProfile
    let offense: OffensiveFormation
    let defense: DefenseScheme
    let almaMater: String
    let pipelineState: String

    var fullName: String {
        "\(firstName) \(lastName)"
    }
}

struct CoachIdentitySelection: Hashable {
    let firstName: String
    let lastName: String
    let age: Int
}

struct CoachStyleSelection: Hashable {
    let pace: PaceProfile
    let offense: OffensiveFormation
    let defense: DefenseScheme
}

struct CoachBackgroundSelection: Hashable {
    let almaMater: String
    let pipelineState: String
}

enum CoachArchetype: String, CaseIterable, Hashable {
    case recruiting
    case offense
    case defense
    case playerDevelopment = "player_development"
    case fundraising
}

struct CoachIdentityStepView: View {
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
            subtitle: "Step 1 of 4",
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
            GameCard {
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
                            .tint(AppTheme.accent)
                    }
                }
            }
        }
    }
}

struct CoachArchetypeStepView: View {
    let identity: CoachIdentitySelection
    let onNext: (CoachArchetype) -> Void

    @State private var selectedArchetype: CoachArchetype = .recruiting

    var body: some View {
        OnboardingStepScaffold(
            title: "Choose Your Archetype",
            subtitle: "Step 2 of 4",
            navTitle: "Coach Setup",
            nextLabel: "Next: Style",
            nextDisabled: false,
            onNext: { onNext(selectedArchetype) }
        ) {
            GameCard {
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
            }
        }
    }
}

struct CoachStyleStepView: View {
    let identity: CoachIdentitySelection
    let onNext: (CoachStyleSelection) -> Void

    @State private var selectedPace: PaceProfile = .normal
    @State private var selectedOffense: OffensiveFormation = .motion
    @State private var selectedDefense: DefenseScheme = .manToMan

    var body: some View {
        OnboardingStepScaffold(
            title: "Define Your Style",
            subtitle: "Step 3 of 4",
            navTitle: "Coach Setup",
            nextLabel: "Next: Background",
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
            GameCard {
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
            }
        }
    }
}

struct CoachBackgroundStepView: View {
    let identity: CoachIdentitySelection
    let onNext: (CoachBackgroundSelection) -> Void

    @State private var almaMater: String = "Independent"
    @State private var pipelineState: String = "CA"

    private var trimmedAlma: String {
        almaMater.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var normalizedPipeline: String {
        pipelineState.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    private var pipelineIsValid: Bool {
        let code = normalizedPipeline
        guard code.count == 2 else { return false }
        return code.unicodeScalars.allSatisfy { CharacterSet.uppercaseLetters.contains($0) }
    }

    private var isValid: Bool {
        !trimmedAlma.isEmpty && pipelineIsValid
    }

    var body: some View {
        OnboardingStepScaffold(
            title: "Set Coach Background",
            subtitle: "Step 4 of 4",
            navTitle: "Coach Setup",
            nextLabel: "Finish Coach",
            nextDisabled: !isValid,
            onNext: {
                onNext(
                    CoachBackgroundSelection(
                        almaMater: trimmedAlma,
                        pipelineState: normalizedPipeline
                    )
                )
            }
        ) {
            GameCard {
                VStack(alignment: .leading, spacing: 16) {
                    TextField("Alma Mater", text: $almaMater)
                        .textInputAutocapitalization(.words)
                        .textFieldStyle(.roundedBorder)

                    VStack(alignment: .leading, spacing: 6) {
                        TextField("Pipeline State (2-letter code)", text: $pipelineState)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .textFieldStyle(.roundedBorder)

                        Text("Example: CA, TX, FL")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if !pipelineState.isEmpty, !pipelineIsValid {
                            Text("Use a valid 2-letter state code.")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }

                    Text("\(identity.firstName) \(identity.lastName), age \(identity.age)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct CareerTeamSelectionView: View {
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
                                GameCard {
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
                                                .foregroundStyle(AppTheme.accent)
                                        }
                                    }
                                }
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
                .buttonStyle(GameButtonStyle(variant: .primary))
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
