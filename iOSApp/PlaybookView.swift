import SwiftUI
import CBBCoachCore

struct PlaybookView: View {
    let playbook: UserPlaybookSummary?
    let onSave: (PaceProfile, DefenseScheme, [String: Int]) -> Void

    @State private var pace: PaceProfile = .normal
    @State private var defenseScheme: DefenseScheme = .manToMan
    @State private var weights: [OffensiveFormation: Double] = [:]
    @State private var didLoad = false
    @State private var statusText: String = ""

    private var totalWeight: Int {
        OffensiveFormation.allCases.reduce(0) { $0 + Int((weights[$1] ?? 0).rounded()) }
    }

    private var canSave: Bool { totalWeight > 0 }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Set the pace, defensive base, and the offensive distribution your team will run. Offense weights are relative — they don't need to sum to 100.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                GameCard {
                    VStack(alignment: .leading, spacing: 14) {
                        GameSectionHeader(title: "Tempo & Defense")
                        FilterDropdown(
                            label: "Pace",
                            selection: $pace,
                            options: PaceProfile.allCases,
                            optionLabel: \.label
                        )
                        FilterDropdown(
                            label: "Base Defense",
                            selection: $defenseScheme,
                            options: DefenseScheme.allCases,
                            optionLabel: \.label
                        )
                    }
                }

                GameCard {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            GameSectionHeader(title: "Offense Distribution")
                            Spacer()
                            Text("Total: \(totalWeight)")
                                .font(.caption.monospacedDigit().weight(.semibold))
                                .foregroundStyle(.secondary)
                        }

                        ForEach(OffensiveFormation.allCases, id: \.self) { formation in
                            offenseRow(formation)
                        }

                        if !canSave {
                            Text("Set at least one offense above zero.")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                }

                Button("Save Playbook") {
                    let normalized = normalizedWeights()
                    onSave(pace, defenseScheme, normalized)
                    statusText = "Saved."
                }
                .buttonStyle(GameButtonStyle(variant: .primary))
                .disabled(!canSave)

                if !statusText.isEmpty {
                    Text(statusText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(16)
        }
        .navigationTitle("Playbook")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            guard !didLoad else { return }
            didLoad = true
            loadInitial()
        }
    }

    @ViewBuilder
    private func offenseRow(_ formation: OffensiveFormation) -> some View {
        let value = weights[formation] ?? 0
        let pct: Int = {
            let total = totalWeight
            guard total > 0 else { return 0 }
            return Int((value / Double(total) * 100).rounded())
        }()

        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(formation.label)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(Int(value.rounded())) (\(pct)%)")
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            Slider(
                value: Binding(
                    get: { weights[formation] ?? 0 },
                    set: { weights[formation] = $0; statusText = "" }
                ),
                in: 0...100,
                step: 5
            )
            .tint(AppTheme.accent)
        }
    }

    private func loadInitial() {
        if let playbook {
            pace = playbook.pace
            defenseScheme = playbook.defenseScheme
            for formation in OffensiveFormation.allCases {
                weights[formation] = Double(playbook.offenseWeights[formation.rawValue] ?? 0)
            }
            return
        }

        if let raw = UserDefaults.standard.string(forKey: "coachPace"),
           let value = PaceProfile(rawValue: raw) {
            pace = value
        }
        if let raw = UserDefaults.standard.string(forKey: "coachDefense"),
           let value = DefenseScheme(rawValue: raw) {
            defenseScheme = value
        }
        if let data = UserDefaults.standard.data(forKey: "coachOffenseWeights"),
           let dict = try? JSONDecoder().decode([String: Int].self, from: data) {
            for formation in OffensiveFormation.allCases {
                weights[formation] = Double(dict[formation.rawValue] ?? 0)
            }
        } else {
            let dominantRaw = UserDefaults.standard.string(forKey: "coachOffense") ?? OffensiveFormation.motion.rawValue
            for formation in OffensiveFormation.allCases {
                weights[formation] = formation.rawValue == dominantRaw ? 100 : 0
            }
        }
    }

    private func normalizedWeights() -> [String: Int] {
        var result: [String: Int] = [:]
        for formation in OffensiveFormation.allCases {
            result[formation.rawValue] = max(0, Int((weights[formation] ?? 0).rounded()))
        }
        return result
    }
}
