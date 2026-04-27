import SwiftUI
import UniformTypeIdentifiers
import CBBCoachCore

struct RosterRatingsView: View {
    let roster: [UserRosterPlayerSummary]
    let games: [LeagueGameSummary]
    let userTeamName: String
    @State private var sortColumn: String = "overall"
    @State private var isAscending: Bool = false
    private let combinedThreePointKey = "combinedThreePointShooting"
    private let threePointComponentKeys: Set<String> = ["threePointShooting", "cornerThrees", "upTopThrees"]

    private let preferredAttributeOrder: [String] = [
        "potential", "speed", "agility", "burst", "strength", "vertical", "stamina", "durability",
        "layups", "dunks", "closeShot", "midrangeShot", "combinedThreePointShooting", "drawFoul", "freeThrows",
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
        let hasThreePointComponents = !keys.intersection(threePointComponentKeys).isEmpty
        var displayKeys = keys.subtracting(threePointComponentKeys)
        if hasThreePointComponents {
            displayKeys.insert(combinedThreePointKey)
        }
        return preferredAttributeOrder.filter { displayKeys.contains($0) } + displayKeys.filter { !preferredAttributeOrder.contains($0) }.sorted()
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
                            games: games,
                            teamName: userTeamName
                        )
                    } label: {
                        AppTableTextCell(
                            text: player.name,
                            width: 132,
                            alignment: .leading,
                            font: .caption.monospacedDigit().weight(.semibold),
                            foreground: AppTheme.accent
                        )
                    }
                    .buttonStyle(.plain)
                    AppTableTextCell(text: player.position, width: 42)
                    AppTableTextCell(text: player.year, width: 30)
                    AppTableTextCell(text: "\(player.overall)", width: 38)
                    ForEach(attributeColumns, id: \.self) { key in
                        let value = attributeValue(for: key, player: player)
                        AppTableTextCell(text: "\(value)", width: 44)
                    }
                }
            }
        }
        .background(AppTheme.background)
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
            return numericCompare(lhs: attributeValue(for: column, player: lhs), rhs: attributeValue(for: column, player: rhs))
        }
    }

    private func numericCompare(lhs: Int, rhs: Int) -> ComparisonResult {
        if lhs == rhs { return .orderedSame }
        return lhs < rhs ? .orderedAscending : .orderedDescending
    }

    private func attributeLabel(_ key: String) -> String {
        switch key {
        case "combinedThreePointShooting": "3PT"
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

    private func attributeValue(for key: String, player: UserRosterPlayerSummary) -> Int {
        let attributes = player.attributes ?? [:]
        if key == combinedThreePointKey {
            return combinedThreePointValue(from: attributes) ?? 0
        }
        return attributes[key] ?? 0
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
}

struct PlayerCareerTotals: Hashable {
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
    var minutesPerGame: Double { games > 0 ? minutes / Double(games) : 0 }
    var stealsPerGame: Double { games > 0 ? Double(steals) / Double(games) : 0 }
    var blocksPerGame: Double { games > 0 ? Double(blocks) / Double(games) : 0 }
    var turnoversPerGame: Double { games > 0 ? Double(turnovers) / Double(games) : 0 }
    var fgPct: Double { fgAttempts > 0 ? Double(fgMade) / Double(fgAttempts) : 0 }
    var threePct: Double { threeAttempts > 0 ? Double(threeMade) / Double(threeAttempts) : 0 }
    var ftPct: Double { ftAttempts > 0 ? Double(ftMade) / Double(ftAttempts) : 0 }
}
