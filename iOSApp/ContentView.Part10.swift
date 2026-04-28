import SwiftUI
import UniformTypeIdentifiers
import CBBCoachCore

struct NationalBracketView: View {
    let bracket: NationalTournamentBracket?
    let userTeamId: String?

    private let roundTitles = ["Round of 64", "Round of 32", "Sweet 16", "Elite 8", "Final Four", "Title"]
    private let columnWidth: CGFloat = 184
    private let gameHeight: CGFloat = 74

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            if let bracket {
                ScrollView([.horizontal, .vertical], showsIndicators: true) {
                    HStack(alignment: .top, spacing: 28) {
                        ForEach(Array(bracket.rounds.enumerated()), id: \.offset) { roundIndex, games in
                            VStack(alignment: .leading, spacing: 10) {
                                Text(roundTitles[safe: roundIndex] ?? "Round \(roundIndex + 1)")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.secondary)
                                    .frame(width: columnWidth, alignment: .leading)

                                VStack(spacing: verticalSpacing(for: roundIndex)) {
                                    ForEach(games) { game in
                                        BracketGameCard(
                                            game: game,
                                            userTeamId: userTeamId,
                                            height: gameHeight
                                        )
                                        .frame(width: columnWidth, height: gameHeight)
                                    }
                                }
                                .padding(.top, topInset(for: roundIndex))
                            }
                        }
                    }
                    .padding(16)
                    .frame(minWidth: 1320, minHeight: 1200, alignment: .topLeading)
                }
            } else {
                VStack(spacing: 10) {
                    Text("Bracket")
                        .font(.title2.weight(.black))
                    Text("The national tournament field appears after conference tournaments finish.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
            }
        }
        .navigationTitle("Bracket")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func verticalSpacing(for roundIndex: Int) -> CGFloat {
        switch roundIndex {
        case 0: 10
        case 1: 94
        case 2: 262
        case 3: 598
        case 4: 1270
        default: 0
        }
    }

    private func topInset(for roundIndex: Int) -> CGFloat {
        switch roundIndex {
        case 0: 0
        case 1: 42
        case 2: 126
        case 3: 294
        case 4: 630
        default: 1302
        }
    }
}

private struct BracketGameCard: View {
    let game: NationalTournamentGame
    let userTeamId: String?
    let height: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            teamRow(game.topTeam)
            Divider()
            teamRow(game.bottomTeam)
        }
        .frame(height: height)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(AppTheme.cardBorder, lineWidth: 1)
        )
    }

    private func teamRow(_ team: NationalTournamentTeam?) -> some View {
        let isWinner = team?.teamId == game.winnerTeamId
        let isUser = team?.teamId == userTeamId

        return HStack(spacing: 8) {
            Text(team.map { "\($0.seedLine)" } ?? "-")
                .font(.caption2.monospacedDigit().weight(.black))
                .foregroundStyle(isWinner ? .white : (isUser ? AppTheme.accent : .secondary))
                .frame(width: 22, height: 22)
                .background(isWinner ? AppTheme.success : Color(UIColor.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))

            Text(team?.teamName ?? "TBD")
                .font(.caption.weight(isUser || isWinner ? .bold : .semibold))
                .foregroundStyle(isWinner ? AppTheme.success : (isUser ? AppTheme.accent : AppTheme.ink))
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Spacer(minLength: 4)

            if team?.automaticBid == true {
                Text("AQ")
                    .font(.caption2.weight(.black))
                    .foregroundStyle(AppTheme.warning)
            }
        }
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(isUser ? AppTheme.accent.opacity(0.08) : .clear)
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

struct RankingsView: View {
    let rankings: LeagueRankings?
    let userTeamId: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if let rankings {
                    GameCard {
                        VStack(spacing: 0) {
                            HStack(spacing: 0) {
                                AppTableTextCell(text: "RANK", width: 54, font: .caption2.weight(.bold), foreground: .secondary)
                                AppTableTextCell(text: "TEAM", width: 152, alignment: .leading, font: .caption2.weight(.bold), foreground: .secondary)
                                AppTableTextCell(text: "REC", width: 58, font: .caption2.weight(.bold), foreground: .secondary)
                                AppTableTextCell(text: "NET", width: 56, font: .caption2.weight(.bold), foreground: .secondary)
                                AppTableTextCell(text: "SOS", width: 56, font: .caption2.weight(.bold), foreground: .secondary)
                            }
                            .padding(.vertical, 6)
                            .background(AppTheme.cardBackground)
                            Divider()

                            ForEach(Array(rankings.rankings.enumerated()), id: \.element.id) { index, team in
                                HStack(spacing: 0) {
                                    AppTableTextCell(
                                        text: "#\(team.rank)",
                                        width: 54,
                                        font: .caption.monospacedDigit().weight(.semibold),
                                        foreground: team.teamId == userTeamId ? AppTheme.accent : .primary
                                    )
                                    AppTableTextCell(
                                        text: team.teamName,
                                        width: 152,
                                        alignment: .leading,
                                        font: .caption.weight(team.teamId == userTeamId ? .bold : .semibold),
                                        foreground: team.teamId == userTeamId ? AppTheme.accent : .primary
                                    )
                                    AppTableTextCell(
                                        text: team.record,
                                        width: 58,
                                        font: .caption.monospacedDigit().weight(.medium)
                                    )
                                    AppTableTextCell(
                                        text: String(format: "%.1f", team.pointDifferentialPerGame),
                                        width: 56,
                                        font: .caption.monospacedDigit().weight(.medium)
                                    )
                                    AppTableTextCell(
                                        text: String(format: "%.3f", team.strengthOfSchedule),
                                        width: 56,
                                        font: .caption.monospacedDigit().weight(.medium)
                                    )
                                }
                                .padding(.vertical, 6)
                                .background(team.teamId == userTeamId ? AppTheme.accent.opacity(0.08) : .clear)
                                if index < rankings.rankings.count - 1 {
                                    Divider()
                                }
                            }
                        }
                    }
                } else {
                    Text("Rankings unavailable.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(16)
        }
        .navigationTitle("Rankings")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ParsedTeamBoxScore {
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

struct ParsedPlayerBoxScore {
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
    let offensiveRebounds: Int
    let defensiveRebounds: Int
    let assists: Int
    let steals: Int
    let blocks: Int
    let turnovers: Int
    let fouls: Int
    let plusMinus: Int

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
        let parsedOffensiveRebounds = object["offensiveRebounds"]?.intValue
        let parsedDefensiveRebounds = object["defensiveRebounds"]?.intValue
        if let parsedOffensiveRebounds, let parsedDefensiveRebounds {
            offensiveRebounds = max(0, parsedOffensiveRebounds)
            defensiveRebounds = max(0, parsedDefensiveRebounds)
        } else if let parsedOffensiveRebounds {
            offensiveRebounds = max(0, parsedOffensiveRebounds)
            defensiveRebounds = max(0, rebounds - offensiveRebounds)
        } else if let parsedDefensiveRebounds {
            defensiveRebounds = max(0, parsedDefensiveRebounds)
            offensiveRebounds = max(0, rebounds - defensiveRebounds)
        } else {
            offensiveRebounds = 0
            defensiveRebounds = max(0, rebounds)
        }
        assists = object["assists"]?.intValue ?? 0
        steals = object["steals"]?.intValue ?? 0
        blocks = object["blocks"]?.intValue ?? 0
        turnovers = object["turnovers"]?.intValue ?? 0
        fouls = object["fouls"]?.intValue ?? 0
        plusMinus = object["plusMinus"]?.intValue ?? 0
    }
}

extension PaceProfile {
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

extension CoachArchetype {
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

extension OffensiveFormation {
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

extension DefenseScheme {
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

extension AssistantFocus {
    var label: String {
        switch self {
        case .recruiting: "Recruiting"
        case .development: "Development"
        case .gamePrep: "Game Prep"
        case .scouting: "Scouting"
        }
    }
}

extension Coach {
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

    var bioLine: String {
        let trimmedAlma = almaMater.trimmingCharacters(in: .whitespacesAndNewlines)
        let almaLabel = trimmedAlma.isEmpty ? "Independent" : trimmedAlma

        let trimmedPipeline = pipelineState.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let pipelineLabel = trimmedPipeline.isEmpty ? "--" : trimmedPipeline

        return "Alma: \(almaLabel) · Pipeline: \(pipelineLabel)"
    }
}

extension JSONValue {
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

extension Double {
    var roundedInt: Int {
        Int(self.rounded())
    }
}

#Preview {
    ContentView()
}
