import SwiftUI
import UniformTypeIdentifiers
import CBBCoachCore

struct PlayerCardDetailView: View {
    let player: UserRosterPlayerSummary
    let games: [LeagueGameSummary]
    let teamName: String
    private let combinedThreePointKey = "combinedThreePointShooting"
    private let threePointComponentKeys: Set<String> = ["threePointShooting", "cornerThrees", "upTopThrees"]

    private var sortedRatings: [(key: String, value: Int)] {
        var ratings = player.attributes ?? [:]
        if let combinedThreePoint = combinedThreePointValue(from: ratings) {
            ratings[combinedThreePointKey] = combinedThreePoint
        }
        for key in threePointComponentKeys {
            ratings.removeValue(forKey: key)
        }
        return ratings
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

    private var measurableTraits: [String] {
        let potential = player.attributes?["potential"]
        return [
            traitLabel("Height", value: player.height),
            traitLabel("Weight", value: player.weight),
            traitLabel("Wingspan", value: player.wingspan),
            traitLabel("Home", value: player.home),
            potential.map { "Potential \($0)" },
        ]
        .compactMap { $0 }
    }

    private var allTraits: [String] {
        measurableTraits + topTraits
    }

    private struct CareerYearRow {
        let year: String
        let totals: PlayerCareerTotals
    }

    private var careerRows: [(id: AnyHashable, data: CareerYearRow)] {
        var totalsByYear: [String: PlayerCareerTotals] = [:]
        let playerYear = player.year.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "N/A" : player.year

        for game in games where game.completed == true {
            guard let line = findPlayerLine(in: game) else { continue }
            let current = totalsByYear[playerYear] ?? .zero
            totalsByYear[playerYear] = PlayerCareerTotals(
                games: current.games + 1,
                minutes: current.minutes + line.minutes,
                points: current.points + line.points,
                rebounds: current.rebounds + line.rebounds,
                assists: current.assists + line.assists,
                steals: current.steals + line.steals,
                blocks: current.blocks + line.blocks,
                turnovers: current.turnovers + line.turnovers,
                fgMade: current.fgMade + line.fgMade,
                fgAttempts: current.fgAttempts + line.fgAttempts,
                threeMade: current.threeMade + line.threeMade,
                threeAttempts: current.threeAttempts + line.threeAttempts,
                ftMade: current.ftMade + line.ftMade,
                ftAttempts: current.ftAttempts + line.ftAttempts
            )
        }

        return totalsByYear
            .map { (year: $0.key, totals: $0.value) }
            .sorted { lhs, rhs in
                lhs.year.localizedCaseInsensitiveCompare(rhs.year) == .orderedAscending
            }
            .map { entry in
                (
                    id: AnyHashable(entry.year),
                    data: CareerYearRow(year: entry.year, totals: entry.totals)
                )
            }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                GameCard {
                    GameSectionHeader(title: "Player")
                    VStack(alignment: .leading, spacing: 6) {
                        Text(player.name)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.primary)
                        Text(headerSubtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                GameCard {
                    GameSectionHeader(title: "Traits")
                    if allTraits.isEmpty {
                        Text("No standout traits yet.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(allTraits, id: \.self) { trait in
                                Text(trait)
                                    .font(.caption.monospacedDigit().weight(.semibold))
                                    .foregroundStyle(.primary)
                            }
                        }
                    }
                }

                GameCard {
                    GameSectionHeader(title: "Ratings")
                    if ratingRows.isEmpty {
                        Text("No ratings available for this player yet.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
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
                }

                GameCard {
                    GameSectionHeader(title: "Career Stats")
                    let columns: [AppTableColumn<String>] = [
                        .init(id: "year", title: "YEAR", width: 52, alignment: .leading),
                        .init(id: "games", title: "G", width: 42),
                        .init(id: "minutes", title: "MIN", width: 52),
                        .init(id: "points", title: "PTS", width: 52),
                        .init(id: "rebounds", title: "REB", width: 52),
                        .init(id: "assists", title: "AST", width: 52),
                        .init(id: "steals", title: "STL", width: 52),
                        .init(id: "blocks", title: "BLK", width: 52),
                        .init(id: "turnovers", title: "TO", width: 52),
                        .init(id: "fg", title: "FG%", width: 64),
                        .init(id: "three", title: "3PT%", width: 64),
                        .init(id: "ft", title: "FT%", width: 64),
                        .init(id: "ppg", title: "PPG", width: 56),
                        .init(id: "rpg", title: "RPG", width: 56),
                        .init(id: "apg", title: "APG", width: 56),
                    ]
                    AppTable(columns: columns, rows: careerRows) { row in
                        HStack(spacing: 0) {
                            AppTableTextCell(text: row.year, width: 52, alignment: .leading, font: .caption.monospacedDigit())
                            AppTableTextCell(text: "\(row.totals.games)", width: 42, font: .caption.monospacedDigit().weight(.semibold))
                            AppTableTextCell(text: format(row.totals.minutesPerGame), width: 52, font: .caption.monospacedDigit().weight(.semibold))
                            AppTableTextCell(text: format(row.totals.pointsPerGame), width: 52, font: .caption.monospacedDigit().weight(.semibold))
                            AppTableTextCell(text: format(row.totals.reboundsPerGame), width: 52, font: .caption.monospacedDigit().weight(.semibold))
                            AppTableTextCell(text: format(row.totals.assistsPerGame), width: 52, font: .caption.monospacedDigit().weight(.semibold))
                            AppTableTextCell(text: format(row.totals.stealsPerGame), width: 52, font: .caption.monospacedDigit().weight(.semibold))
                            AppTableTextCell(text: format(row.totals.blocksPerGame), width: 52, font: .caption.monospacedDigit().weight(.semibold))
                            AppTableTextCell(text: format(row.totals.turnoversPerGame), width: 52, font: .caption.monospacedDigit().weight(.semibold))
                            AppTableTextCell(text: pct(row.totals.fgPct), width: 64, font: .caption.monospacedDigit().weight(.semibold))
                            AppTableTextCell(text: pct(row.totals.threePct), width: 64, font: .caption.monospacedDigit().weight(.semibold))
                            AppTableTextCell(text: pct(row.totals.ftPct), width: 64, font: .caption.monospacedDigit().weight(.semibold))
                            AppTableTextCell(text: format(row.totals.pointsPerGame), width: 56, font: .caption.monospacedDigit().weight(.semibold))
                            AppTableTextCell(text: format(row.totals.reboundsPerGame), width: 56, font: .caption.monospacedDigit().weight(.semibold))
                            AppTableTextCell(text: format(row.totals.assistsPerGame), width: 56, font: .caption.monospacedDigit().weight(.semibold))
                        }
                    }
                }
            }
            .padding(16)
        }
        .navigationTitle("Player Card")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var headerSubtitle: String {
        var parts: [String] = [teamName]

        let trimmedPosition = player.position.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedPosition.isEmpty {
            parts.append(trimmedPosition)
        }

        let trimmedYear = player.year.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedYear.isEmpty, trimmedYear.caseInsensitiveCompare("N/A") != .orderedSame {
            parts.append(trimmedYear)
        }

        if player.overall > 0 {
            parts.append("OVR \(player.overall)")
        }
        if player.isStarter {
            parts.append("Starter")
        }

        return parts.joined(separator: " • ")
    }

    private func findPlayerLine(in game: LeagueGameSummary) -> ParsedPlayerBoxScore? {
        guard
            let resultObj = game.result?.objectDictionary,
            let teamBoxes = resultObj["boxScore"]?.arrayValues
        else { return nil }

        guard let targetTeamBox = teamBoxes.first(where: { box in
            box.objectDictionary?["name"]?.stringValue == teamName
        }) else { return nil }

        let players = targetTeamBox.objectDictionary?["players"]?.arrayValues ?? []
        let parsedPlayers = players.compactMap(ParsedPlayerBoxScore.init(value:))
        let sameName = parsedPlayers.filter { $0.playerName == player.name }
        guard !sameName.isEmpty else { return nil }

        let trimmedPosition = player.position.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedPosition.isEmpty {
            return sameName.first
        }

        if let exact = sameName.first(where: { $0.position == trimmedPosition }) {
            return exact
        }

        return sameName.first
    }

    private func ratingLabel(_ key: String) -> String {
        switch key {
        case "combinedThreePointShooting": "3PT Shooting"
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

    private func combinedThreePointValue(from attributes: [String: Int]) -> Int? {
        var weightedTotal = 0
        var totalWeight = 0
        if let threePointShooting = attributes["threePointShooting"] {
            weightedTotal += threePointShooting * 2
            totalWeight += 2
        }
        if let cornerThrees = attributes["cornerThrees"] {
            weightedTotal += cornerThrees
            totalWeight += 1
        }
        if let upTopThrees = attributes["upTopThrees"] {
            weightedTotal += upTopThrees
            totalWeight += 1
        }
        guard totalWeight > 0 else { return nil }
        return Int((Double(weightedTotal) / Double(totalWeight)).rounded())
    }

    private func score(_ values: Int?...) -> Double {
        let valid = values.compactMap { $0 }
        guard !valid.isEmpty else { return 0 }
        return Double(valid.reduce(0, +)) / Double(valid.count)
    }

    private func traitLabel(_ label: String, value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return "\(label): \(trimmed)"
    }

    private func format(_ value: Double) -> String {
        String(format: "%.1f", value)
    }

    private func pct(_ value: Double) -> String {
        String(format: "%.1f%%", value * 100)
    }
}
