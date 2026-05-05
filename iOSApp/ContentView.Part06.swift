import SwiftUI
import UniformTypeIdentifiers
import CBBCoachCore

struct PlayerCardDetailView: View {
    let player: UserRosterPlayerSummary
    let games: [LeagueGameSummary]
    let teamName: String
    private let combinedThreePointKey = "combinedThreePointShooting"
    private let threePointComponentKeys: Set<String> = ["threePointShooting", "cornerThrees", "upTopThrees"]

    private struct RatingEntry: Hashable {
        let key: String
        let label: String
        let value: Int
    }

    private struct RatingSection: Identifiable {
        let title: String
        let entries: [RatingEntry]
        let grade: String

        var id: String { title }
    }

    private let ratingSectionDefinitions: [(title: String, keys: Set<String>)] = [
        ("Athleticism", ["speed", "agility", "burst", "strength", "vertical", "stamina", "durability"]),
        ("Finishing", ["layups", "dunks", "closeShot", "drawFoul", "freeThrows"]),
        ("Shooting", ["midrangeShot", "combinedThreePointShooting"]),
        ("Post Game", ["postControl", "postFadeaways", "postHooks"]),
        ("Playmaking", ["ballHandling", "ballSafety", "passingAccuracy", "passingVision", "passingIQ", "shotIQ", "offballOffense"]),
        ("Defense", ["perimeterDefense", "postDefense", "shotBlocking", "shotContest", "steals", "lateralQuickness", "offballDefense", "passPerception", "defensiveControl"]),
        ("Rebounding", ["offensiveRebounding", "defensiveRebound", "boxouts"]),
        ("Intangibles", ["hands", "hustle", "clutch", "potential"]),
        ("Tendencies", ["tendencyPost", "tendencyInside", "tendencyMidrange", "tendencyThreePoint", "tendencyDrive", "tendencyPickAndRoll", "tendencyPickAndPop", "tendencyShootVsPass"]),
    ]

    private var normalizedRatings: [String: Int] {
        var ratings = player.attributes ?? [:]
        if let combinedThreePoint = combinedThreePointValue(from: ratings) {
            ratings[combinedThreePointKey] = combinedThreePoint
        }
        for key in threePointComponentKeys {
            ratings.removeValue(forKey: key)
        }
        return ratings
    }

    private var ratingSections: [RatingSection] {
        let ratings = normalizedRatings
        var usedKeys = Set<String>()
        var sections: [RatingSection] = []

        for definition in ratingSectionDefinitions {
            let entries = definition.keys
                .compactMap { key -> RatingEntry? in
                    guard let value = ratings[key] else { return nil }
                    return RatingEntry(key: key, label: ratingLabel(key), value: value)
                }
                .sorted { lhs, rhs in
                    if lhs.value != rhs.value { return lhs.value > rhs.value }
                    return lhs.label < rhs.label
                }
            guard !entries.isEmpty else { continue }
            usedKeys.formUnion(entries.map(\.key))
            sections.append(
                RatingSection(
                    title: definition.title,
                    entries: entries,
                    grade: letterGrade(for: entries.map(\.value))
                )
            )
        }

        let otherEntries = ratings
            .filter { !usedKeys.contains($0.key) }
            .map { RatingEntry(key: $0.key, label: ratingLabel($0.key), value: $0.value) }
            .sorted { lhs, rhs in
                if lhs.value != rhs.value { return lhs.value > rhs.value }
                return lhs.label < rhs.label
            }

        if !otherEntries.isEmpty {
            sections.append(
                RatingSection(
                    title: "Other",
                    entries: otherEntries,
                    grade: letterGrade(for: otherEntries.map(\.value))
                )
            )
        }

        return sections
    }

    private var measurementsLine: String? {
        var parts: [String] = []
        if let height = formattedFeet(player.height) {
            parts.append(height)
        }
        if let weight = trimmedNonEmpty(player.weight) {
            parts.append("\(weight) lbs")
        }
        var line = parts.joined(separator: " ")
        if let wingspan = formattedFeet(player.wingspan) {
            if line.isEmpty {
                line = "wingspan: \(wingspan)"
            } else {
                line += ", wingspan: \(wingspan)"
            }
        }
        return line.isEmpty ? nil : line
    }

    private func trimmedNonEmpty(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func formattedFeet(_ value: String?) -> String? {
        guard let trimmed = trimmedNonEmpty(value) else { return nil }
        let parts = trimmed.split(separator: "-", maxSplits: 1, omittingEmptySubsequences: false)
        if parts.count == 2, let feet = Int(parts[0]), let inches = Int(parts[1]) {
            return "\(feet)'\(inches)\""
        }
        return trimmed
    }

    private struct CareerYearRow {
        let year: String
        let teamAbbreviation: String
        let totals: PlayerCareerTotals
        let isCareerTotal: Bool
    }

    private var awardRows: [(id: AnyHashable, text: String)] {
        (player.awards ?? []).enumerated().map { offset, award in
            let year = award.year.trimmingCharacters(in: .whitespacesAndNewlines)
            let title = award.title.trimmingCharacters(in: .whitespacesAndNewlines)
            let text = year.isEmpty ? title : "\(year): \(title)"
            return (id: AnyHashable("\(offset):\(text)"), text: text)
        }
    }

    private var careerRows: [(id: AnyHashable, data: CareerYearRow)] {
        var rows: [CareerYearRow] = []

        for season in player.careerSeasons ?? [] {
            rows.append(
                CareerYearRow(
                    year: season.year.isEmpty ? "N/A" : season.year,
                    teamAbbreviation: TeamNameAbbreviation.abbreviated(season.teamName),
                    totals: PlayerCareerTotals(
                        games: season.games,
                        minutes: season.minutes,
                        points: season.points,
                        rebounds: season.rebounds,
                        assists: season.assists,
                        steals: season.steals,
                        blocks: season.blocks,
                        turnovers: season.turnovers,
                        fgMade: season.fgMade,
                        fgAttempts: season.fgAttempts,
                        threeMade: season.threeMade,
                        threeAttempts: season.threeAttempts,
                        ftMade: season.ftMade,
                        ftAttempts: season.ftAttempts
                    ),
                    isCareerTotal: false
                )
            )
        }

        var current: PlayerCareerTotals = .zero
        for game in games where game.completed == true {
            guard let line = findPlayerLine(in: game) else { continue }
            current = PlayerCareerTotals(
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

        if current.games > 0 {
            let playerYear = player.year.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "N/A" : player.year
            rows.append(
                CareerYearRow(
                    year: playerYear,
                    teamAbbreviation: TeamNameAbbreviation.abbreviated(teamName),
                    totals: current,
                    isCareerTotal: false
                )
            )
        }

        var seenSeasonKeys = Set<String>()
        let uniqueRows = rows.filter { row in
            let key = careerSeasonDeduplicationKey(for: row)
            return seenSeasonKeys.insert(key).inserted
        }
        let careerTotals = combinedCareerTotals(for: uniqueRows)
        let displayRows = Array(uniqueRows.reversed()) + [
            CareerYearRow(
                year: "Career",
                teamAbbreviation: "",
                totals: careerTotals,
                isCareerTotal: true
            )
        ]

        return displayRows.enumerated().map { offset, row in
            (id: AnyHashable("\(offset):\(row.year):\(row.teamAbbreviation):\(row.isCareerTotal)"), data: row)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                GameCard {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(player.name)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.primary)
                        Text(headerSubtitle)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                        if let draftSlot = player.draftSlot {
                            Text("Draft: #\(draftSlot)")
                                .font(.subheadline.monospacedDigit().weight(.bold))
                                .foregroundStyle(AppTheme.accent)
                        }
                        if let measurements = measurementsLine {
                            Text(measurements)
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                        }
                    }
                }

                GameCard {
                    if ratingSections.isEmpty {
                        Text("No ratings available for this player yet.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(Array(ratingSections.enumerated()), id: \.element.id) { index, section in
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack(alignment: .firstTextBaseline) {
                                        Text(section.title.uppercased())
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(.secondary)
                                            .tracking(0.4)
                                        Spacer()
                                        Text(section.grade)
                                            .font(.subheadline.monospacedDigit().weight(.bold))
                                            .foregroundStyle(.primary)
                                    }
                                    ForEach(Array(twoColumnPairs(from: section.entries).enumerated()), id: \.offset) { _, pair in
                                        HStack(spacing: 10) {
                                            ratingCell(pair.left)
                                            ratingCell(pair.right)
                                        }
                                    }
                                }
                                if index < ratingSections.count - 1 {
                                    Divider()
                                }
                            }
                        }
                    }
                }

                if !awardRows.isEmpty {
                    GameCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Awards")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(AppTheme.ink)

                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(awardRows, id: \.id) { row in
                                    Text(row.text)
                                        .font(.subheadline)
                                        .foregroundStyle(.primary)
                                }
                            }
                        }
                    }
                }

                GameCard {
                    let columns: [AppTableColumn<String>] = [
                        .init(id: "year", title: "YEAR", width: 52, alignment: .leading),
                        .init(id: "team", title: "TEAM", width: 56, alignment: .leading),
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
                        .init(id: "efg", title: "EFG%", width: 64),
                        .init(id: "fgma", title: "FG M/A", width: 72),
                        .init(id: "threeMa", title: "3PT M/A", width: 72),
                        .init(id: "ftma", title: "FT M/A", width: 72),
                    ]
                    AppTable(columns: columns, rows: careerRows) { row in
                        HStack(spacing: 0) {
                            AppTableTextCell(text: row.year, width: 52, alignment: .leading, font: .caption.monospacedDigit())
                            AppTableTextCell(text: row.teamAbbreviation, width: 56, alignment: .leading, font: .caption.monospacedDigit().weight(.semibold))
                            AppTableTextCell(text: "\(row.totals.games)", width: 42, font: .caption.monospacedDigit().weight(.semibold))
                            AppTableTextCell(text: careerStat(row.totals.minutes, perGame: row.totals.minutesPerGame, isCareerTotal: row.isCareerTotal), width: 52, font: .caption.monospacedDigit().weight(.semibold))
                            AppTableTextCell(text: careerStat(row.totals.points, perGame: row.totals.pointsPerGame, isCareerTotal: row.isCareerTotal), width: 52, font: .caption.monospacedDigit().weight(.semibold))
                            AppTableTextCell(text: careerStat(row.totals.rebounds, perGame: row.totals.reboundsPerGame, isCareerTotal: row.isCareerTotal), width: 52, font: .caption.monospacedDigit().weight(.semibold))
                            AppTableTextCell(text: careerStat(row.totals.assists, perGame: row.totals.assistsPerGame, isCareerTotal: row.isCareerTotal), width: 52, font: .caption.monospacedDigit().weight(.semibold))
                            AppTableTextCell(text: careerStat(row.totals.steals, perGame: row.totals.stealsPerGame, isCareerTotal: row.isCareerTotal), width: 52, font: .caption.monospacedDigit().weight(.semibold))
                            AppTableTextCell(text: careerStat(row.totals.blocks, perGame: row.totals.blocksPerGame, isCareerTotal: row.isCareerTotal), width: 52, font: .caption.monospacedDigit().weight(.semibold))
                            AppTableTextCell(text: careerStat(row.totals.turnovers, perGame: row.totals.turnoversPerGame, isCareerTotal: row.isCareerTotal), width: 52, font: .caption.monospacedDigit().weight(.semibold))
                            AppTableTextCell(text: pct(row.totals.fgPct), width: 64, font: .caption.monospacedDigit().weight(.semibold))
                            AppTableTextCell(text: pct(row.totals.threePct), width: 64, font: .caption.monospacedDigit().weight(.semibold))
                            AppTableTextCell(text: pct(row.totals.ftPct), width: 64, font: .caption.monospacedDigit().weight(.semibold))
                            AppTableTextCell(text: pct(row.totals.efgPct), width: 64, font: .caption.monospacedDigit().weight(.semibold))
                            AppTableTextCell(text: madeAttempt(row.totals.fgMade, row.totals.fgAttempts, madePerGame: row.totals.fgMadePerGame, attemptsPerGame: row.totals.fgAttemptsPerGame, isCareerTotal: row.isCareerTotal), width: 72, font: .caption.monospacedDigit().weight(.semibold))
                            AppTableTextCell(text: madeAttempt(row.totals.threeMade, row.totals.threeAttempts, madePerGame: row.totals.threeMadePerGame, attemptsPerGame: row.totals.threeAttemptsPerGame, isCareerTotal: row.isCareerTotal), width: 72, font: .caption.monospacedDigit().weight(.semibold))
                            AppTableTextCell(text: madeAttempt(row.totals.ftMade, row.totals.ftAttempts, madePerGame: row.totals.ftMadePerGame, attemptsPerGame: row.totals.ftAttemptsPerGame, isCareerTotal: row.isCareerTotal), width: 72, font: .caption.monospacedDigit().weight(.semibold))
                        }
                    }
                }
            }
            .padding(16)
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    private var headerSubtitle: String {
        var parts: [String] = []

        if player.overall > 0 {
            parts.append("OVR \(player.overall)")
        }

        let trimmedYear = player.year.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedYear.isEmpty, trimmedYear.caseInsensitiveCompare("N/A") != .orderedSame {
            parts.append(trimmedYear)
        }

        let trimmedPosition = player.position.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedPosition.isEmpty {
            parts.append(trimmedPosition)
        }

        parts.append(teamName)

        if let home = trimmedNonEmpty(player.home) {
            parts.append(home)
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

    private func format(_ value: Double) -> String {
        String(format: "%.1f", value)
    }

    private func pct(_ value: Double) -> String {
        String(format: "%.1f%%", value * 100)
    }

    private func careerStat(_ total: Double, perGame: Double, isCareerTotal: Bool) -> String {
        isCareerTotal ? format(total) : format(perGame)
    }

    private func careerStat(_ total: Int, perGame: Double, isCareerTotal: Bool) -> String {
        isCareerTotal ? "\(total)" : format(perGame)
    }

    private func madeAttempt(
        _ made: Int,
        _ attempts: Int,
        madePerGame: Double,
        attemptsPerGame: Double,
        isCareerTotal: Bool
    ) -> String {
        if isCareerTotal {
            return "\(made)/\(attempts)"
        }
        return "\(format(madePerGame))/\(format(attemptsPerGame))"
    }

    private func careerSeasonDeduplicationKey(for row: CareerYearRow) -> String {
        [
            row.year,
            row.teamAbbreviation,
            "\(row.totals.games)",
            format(row.totals.minutes),
            "\(row.totals.points)",
            "\(row.totals.rebounds)",
            "\(row.totals.assists)",
            "\(row.totals.steals)",
            "\(row.totals.blocks)",
            "\(row.totals.turnovers)",
            "\(row.totals.fgMade)",
            "\(row.totals.fgAttempts)",
            "\(row.totals.threeMade)",
            "\(row.totals.threeAttempts)",
            "\(row.totals.ftMade)",
            "\(row.totals.ftAttempts)",
        ].joined(separator: "|")
    }

    private func combinedCareerTotals(for rows: [CareerYearRow]) -> PlayerCareerTotals {
        rows.reduce(.zero) { total, row in
            PlayerCareerTotals(
                games: total.games + row.totals.games,
                minutes: total.minutes + row.totals.minutes,
                points: total.points + row.totals.points,
                rebounds: total.rebounds + row.totals.rebounds,
                assists: total.assists + row.totals.assists,
                steals: total.steals + row.totals.steals,
                blocks: total.blocks + row.totals.blocks,
                turnovers: total.turnovers + row.totals.turnovers,
                fgMade: total.fgMade + row.totals.fgMade,
                fgAttempts: total.fgAttempts + row.totals.fgAttempts,
                threeMade: total.threeMade + row.totals.threeMade,
                threeAttempts: total.threeAttempts + row.totals.threeAttempts,
                ftMade: total.ftMade + row.totals.ftMade,
                ftAttempts: total.ftAttempts + row.totals.ftAttempts
            )
        }
    }

    private func twoColumnPairs(from entries: [RatingEntry]) -> [(left: RatingEntry?, right: RatingEntry?)] {
        var pairs: [(left: RatingEntry?, right: RatingEntry?)] = []
        var index = 0
        while index < entries.count {
            let left = entries[index]
            let right = (index + 1 < entries.count) ? entries[index + 1] : nil
            pairs.append((left: left, right: right))
            index += 2
        }
        return pairs
    }

    @ViewBuilder
    private func ratingCell(_ entry: RatingEntry?) -> some View {
        if let entry {
            HStack(spacing: 8) {
                Text(entry.label)
                    .font(.caption.monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .foregroundStyle(.primary)
                Spacer(minLength: 4)
                Text("\(entry.value)")
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.primary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.primary.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        } else {
            Color.clear
                .frame(maxWidth: .infinity)
        }
    }

    private func letterGrade(for values: [Int]) -> String {
        guard !values.isEmpty else { return "-" }
        let average = Double(values.reduce(0, +)) / Double(values.count)
        switch average {
        case 97...: return "A+"
        case 93..<97: return "A"
        case 90..<93: return "A-"
        case 87..<90: return "B+"
        case 83..<87: return "B"
        case 80..<83: return "B-"
        case 77..<80: return "C+"
        case 73..<77: return "C"
        case 70..<73: return "C-"
        case 67..<70: return "D+"
        case 63..<67: return "D"
        case 60..<63: return "D-"
        default: return "F"
        }
    }
}
