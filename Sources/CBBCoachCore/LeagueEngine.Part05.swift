import Foundation

func lastYearResultForTeam(teamId: String, conferenceId: String) -> Double {
    let recent = recentSuccessByTeamId[teamId]
        ?? clamp(recentConferenceBaseline(for: conferenceId) + deterministicSpread(teamId: teamId, salt: "recent", amplitude: 0.18), min: 0.18, max: 0.9)
    let yearToYearForm = deterministicSpread(teamId: teamId, salt: "last-year", amplitude: 0.12)
    return clamp(recent * 0.9 + yearToYearForm, min: 0.12, max: 0.98)
}

func historicalConferenceBaseline(for conferenceId: String) -> Double {
    switch conferenceId {
    case "acc", "big-12", "big-east", "big-ten", "sec":
        return 0.58
    case "atlantic-10", "american", "mountain-west", "mvc", "wcc":
        return 0.47
    case "america-east", "asun", "big-sky", "big-south", "big-west", "caa", "cusa", "horizon", "ivy-league", "maac", "mac", "meac", "nec", "ovc", "patriot", "socon", "southland", "summit-league", "sun-belt", "swac", "wac":
        return 0.36
    default:
        return 0.36
    }
}

func recentConferenceBaseline(for conferenceId: String) -> Double {
    switch conferenceId {
    case "acc", "big-12", "big-east", "big-ten", "sec":
        return 0.56
    case "atlantic-10", "american", "mountain-west", "mvc", "wcc":
        return 0.48
    case "america-east", "asun", "big-sky", "big-south", "big-west", "caa", "cusa", "horizon", "ivy-league", "maac", "mac", "meac", "nec", "ovc", "patriot", "socon", "southland", "summit-league", "sun-belt", "swac", "wac":
        return 0.39
    default:
        return 0.39
    }
}

func deterministicSpread(teamId: String, salt: String, amplitude: Double) -> Double {
    var random = SeededRandom(seed: hashString("\(salt):\(teamId)"))
    let centered = random.nextUnit() - 0.5
    return centered * amplitude
}

let historicalPrestigeByTeamId: [String: Double] = [
    "big-12-kansas": 0.99,
    "sec-kentucky": 0.99,
    "acc-duke": 0.98,
    "acc-north-carolina": 0.98,
    "big-ten-ucla": 0.98,
    "big-ten-indiana": 0.95,
    "big-east-uconn": 0.95,
    "big-east-villanova": 0.92,
    "acc-louisville": 0.91,
    "acc-syracuse": 0.9,
    "big-12-arizona": 0.9,
    "big-ten-michigan-st": 0.9,
    "big-ten-purdue": 0.88,
    "acc-virginia": 0.88,
    "sec-florida": 0.87,
    "big-ten-michigan": 0.87,
    "big-east-georgetown": 0.86,
    "sec-arkansas": 0.85,
    "sec-tennessee": 0.85,
    "sec-alabama": 0.84,
    "big-east-st-john-and-039-s-ny": 0.84,
    "big-12-baylor": 0.84,
    "sec-lsu": 0.84,
    "acc-notre-dame": 0.83,
    "big-east-xavier": 0.83,
    "big-east-providence": 0.82,
    "big-east-seton-hall": 0.81,
    "big-east-marquette": 0.81,
    "big-east-creighton": 0.8,
    "big-12-houston": 0.8,
    "wcc-gonzaga": 0.8,
    "sec-texas": 0.8,
    "sec-texas-a-and-amp-m": 0.8,
    "acc-nc-state": 0.79,
    "big-ten-ohio-st": 0.79,
    "acc-florida-st": 0.78,
    "sec-auburn": 0.78,
    "acc-pittsburgh": 0.77,
    "sec-oklahoma": 0.77,
    "big-12-west-virginia": 0.77,
    "big-12-texas-tech": 0.77,
    "big-12-kansas-st": 0.76,
    "big-12-iowa-st": 0.76,
    "big-ten-illinois": 0.76,
    "big-ten-wisconsin": 0.76,
    "big-ten-maryland": 0.75,
    "sec-mississippi-st": 0.74,
    "sec-ole-miss": 0.73,
    "american-memphis": 0.73,
    "mountain-west-san-diego-st": 0.73,
    "atlantic-10-dayton": 0.72,
    "atlantic-10-vcu": 0.71,
    "mountain-west-utah-st": 0.7,
    "mountain-west-boise-st": 0.7,
    "mountain-west-new-mexico": 0.7,
    "wcc-san-francisco": 0.69,
    "big-east-butler": 0.69,
    "big-12-byu": 0.69,
    "big-12-tcu": 0.68,
    "big-12-utah": 0.66,
]

let recentSuccessByTeamId: [String: Double] = [
    "big-east-uconn": 0.98,
    "big-12-houston": 0.95,
    "sec-alabama": 0.93,
    "big-12-baylor": 0.92,
    "big-12-kansas": 0.92,
    "sec-auburn": 0.91,
    "big-ten-purdue": 0.91,
    "sec-tennessee": 0.9,
    "wcc-gonzaga": 0.9,
    "big-east-marquette": 0.89,
    "big-east-creighton": 0.88,
    "big-12-arizona": 0.88,
    "big-12-iowa-st": 0.88,
    "big-ten-illinois": 0.87,
    "acc-duke": 0.87,
    "acc-north-carolina": 0.87,
    "sec-kentucky": 0.86,
    "sec-florida": 0.86,
    "sec-arkansas": 0.85,
    "big-ten-michigan-st": 0.85,
    "big-ten-ucla": 0.84,
    "big-ten-wisconsin": 0.84,
    "big-12-texas-tech": 0.84,
    "big-12-byu": 0.83,
    "sec-texas-a-and-amp-m": 0.83,
    "acc-clemson": 0.83,
    "acc-louisville": 0.82,
    "acc-virginia": 0.82,
    "acc-miami-fl": 0.82,
    "sec-mississippi-st": 0.82,
    "sec-ole-miss": 0.81,
    "sec-missouri": 0.8,
    "sec-oklahoma": 0.79,
    "sec-texas": 0.79,
    "big-ten-maryland": 0.78,
    "big-ten-oregon": 0.78,
    "big-ten-southern-california": 0.77,
    "big-12-tcu": 0.77,
    "big-12-kansas-st": 0.77,
    "big-12-west-virginia": 0.76,
    "big-east-st-john-and-039-s-ny": 0.76,
    "big-east-xavier": 0.75,
    "big-east-providence": 0.74,
    "big-east-villanova": 0.74,
    "american-memphis": 0.74,
    "american-fla-atlantic": 0.73,
    "mountain-west-san-diego-st": 0.73,
    "mountain-west-utah-st": 0.72,
    "mountain-west-new-mexico": 0.72,
    "mountain-west-boise-st": 0.71,
    "mountain-west-nevada": 0.7,
    "atlantic-10-dayton": 0.7,
    "atlantic-10-vcu": 0.69,
    "atlantic-10-loyola-chicago": 0.67,
    "mvc-drake": 0.67,
    "southland-mcneese": 0.66,
    "mountain-west-grand-canyon": 0.66,
]

let rosterFirstNames: [String] = [
    "Jalen", "Marcus", "Eli", "Noah", "Ty", "Jordan", "Malik", "Darius", "Caleb", "Cameron",
    "Anthony", "Isaiah", "Trey", "Xavier", "Devin", "Brandon", "Tyler", "Kyle", "Jaden", "Amir",
    "Tariq", "Zion", "Khalil", "Keenan", "Jace", "Tristan", "Evan", "Gabe", "Micah", "Elijah",
    "Julian", "Omar", "Rashid", "Desmond", "Terrance", "DeAndre", "Bryce", "Chase", "Grant", "Hunter",
    "Jaxon", "Kai", "Luka", "Mason", "Nate", "Parker", "Quincy", "Reggie", "Silas", "Tobias",
    "Victor", "Wyatt", "Andre", "Bo", "Chris", "Dante", "Emmett", "Finn", "Garrett", "Hakeem",
    "Ivan", "Jamal", "Kendrick", "Lamar", "Miles", "Nico", "Owen", "Preston", "Raheem", "Solomon"
]

let rosterLastNames: [String] = [
    "Carter", "Brooks", "Davis", "Coleman", "Thomas", "Hill", "Moore", "Young", "Turner", "Jenkins",
    "Washington", "Johnson", "Williams", "Jackson", "Harris", "Martin", "Thompson", "Robinson", "Clark", "Lewis",
    "Walker", "Hall", "Allen", "Wright", "Scott", "Green", "Baker", "Adams", "Nelson", "Hill",
    "Mitchell", "Campbell", "Roberts", "Phillips", "Evans", "Parker", "Edwards", "Collins", "Stewart", "Morris",
    "Rogers", "Reed", "Cook", "Bell", "Bailey", "Rivera", "Cooper", "Richardson", "Cox", "Howard",
    "Ward", "Torres", "Peterson", "Gray", "Ramirez", "James", "Watson", "Kim", "Price", "Bennett",
    "Wood", "Barnes", "Ross", "Henderson", "Coleman", "Jenkins", "Perry", "Powell", "Long", "Patterson"
]

func buildTeamRoster(teamName: String, prestige: Double, random: inout SeededRandom) -> [Player] {
    let positionCycle: [PlayerPosition] = [.pg, .sg, .sf, .pf, .c, .cg, .wing, .f, .big, .pg, .sg, .sf, .pf]
    let yearCycle: [PlayerYear] = [.fr, .so, .jr, .sr]
    let normalizedPrestige = clamp(prestige, min: 0, max: 1)
    let teamQualityBaseline = Int((56 + normalizedPrestige * 14).rounded())
    let lowPrestigeLift = Int(((1 - normalizedPrestige) * 2).rounded())
    let teamVariance = random.int(-5, 5)

    var usedNames = Set<String>()
    return (0..<13).map { idx in
        var player = createPlayer()
        var name = ""
        repeat {
            let first = rosterFirstNames[random.int(0, rosterFirstNames.count - 1)]
            let last = rosterLastNames[random.int(0, rosterLastNames.count - 1)]
            name = "\(first) \(last)"
        } while usedNames.contains(name)
        usedNames.insert(name)
        player.bio.name = name
        player.bio.position = positionCycle[idx % positionCycle.count]
        player.bio.year = yearCycle[idx % yearCycle.count]
        player.bio.home = ["CA", "TX", "FL", "NY", "NC", "IL", "GA", "PA"][idx % 8]
        player.bio.redshirtUsed = false
        player.bio.nilDollarsLastYear = 0
        player.greed = Double(clamp(50 + random.int(-30, 32), min: 5, max: 95))
        player.loyalty = Double(clamp(52 + random.int(-34, 34), min: 5, max: 98))

        let tierAdjustment: Int
        switch idx {
        case 0...2: tierAdjustment = random.int(2, 14)
        case 3...7: tierAdjustment = random.int(-6, 8)
        default: tierAdjustment = random.int(-14, 6)
        }
        let base = clamp(teamQualityBaseline + lowPrestigeLift + teamVariance + tierAdjustment + random.int(-14, 14), min: 42, max: 93)
        player.bio.potential = clamp(base + random.int(-7, 15), min: 30, max: 99)
        applyRatings(&player, base: base, random: &random)

        let height = sampleHeightInches(for: player.bio.position, random: &random)
        player.size.height = formatHeight(inches: height)
        player.size.weight = "\(sampleWeightPounds(for: player.bio.position, heightInches: height, random: &random))"
        let wingspan = height + sampleWingspanDelta(for: player.bio.position, random: &random)
        player.size.wingspan = formatHeight(inches: wingspan)

        player.condition.energy = 100
        player.condition.clutchTime = false
        player.condition.fouledOut = false
        player.condition.homeCourtMultiplier = 1
        player.condition.possessionRole = nil
        player.condition.offensiveCoachingModifier = 1
        player.condition.defensiveCoachingModifier = 1
        return player
    }
}

struct HeightBucket {
    let inches: Int
    let weight: Int
}

func sampleHeightInches(for position: PlayerPosition, random: inout SeededRandom) -> Int {
    let minHeight: Int
    let maxHeight: Int
    let buckets: [HeightBucket]

    switch position {
    case .pg:
        minHeight = 69; maxHeight = 77
        buckets = [.init(inches: 71, weight: 2), .init(inches: 72, weight: 4), .init(inches: 73, weight: 4), .init(inches: 74, weight: 3), .init(inches: 75, weight: 1)]
    case .sg:
        minHeight = 70; maxHeight = 79
        buckets = [.init(inches: 72, weight: 2), .init(inches: 73, weight: 3), .init(inches: 74, weight: 4), .init(inches: 75, weight: 3), .init(inches: 76, weight: 2)]
    case .cg:
        minHeight = 70; maxHeight = 78
        buckets = [.init(inches: 72, weight: 2), .init(inches: 73, weight: 4), .init(inches: 74, weight: 4), .init(inches: 75, weight: 3), .init(inches: 76, weight: 1)]
    case .sf, .wing:
        minHeight = 72; maxHeight = 81
        buckets = [.init(inches: 74, weight: 2), .init(inches: 75, weight: 3), .init(inches: 76, weight: 4), .init(inches: 77, weight: 3), .init(inches: 78, weight: 2)]
    case .f:
        minHeight = 74; maxHeight = 82
        buckets = [.init(inches: 76, weight: 2), .init(inches: 77, weight: 3), .init(inches: 78, weight: 4), .init(inches: 79, weight: 3), .init(inches: 80, weight: 1)]
    case .pf:
        minHeight = 75; maxHeight = 84
        buckets = [.init(inches: 77, weight: 2), .init(inches: 78, weight: 3), .init(inches: 79, weight: 4), .init(inches: 80, weight: 3), .init(inches: 81, weight: 1)]
    case .c, .big:
        minHeight = 77; maxHeight = 85
        buckets = [.init(inches: 79, weight: 2), .init(inches: 80, weight: 4), .init(inches: 81, weight: 4), .init(inches: 82, weight: 3), .init(inches: 83, weight: 1)]
    }

    let sampled = sampleWeightedHeight(buckets, random: &random) + random.int(-1, 1)
    return clamp(sampled, min: minHeight, max: maxHeight)
}

func sampleWeightedHeight(_ buckets: [HeightBucket], random: inout SeededRandom) -> Int {
    let total = buckets.reduce(0) { $0 + max(1, $1.weight) }
    guard total > 0 else { return 76 }
    var pick = random.int(1, total)
    for bucket in buckets {
        pick -= max(1, bucket.weight)
        if pick <= 0 { return bucket.inches }
    }
    return buckets.last?.inches ?? 76
}

func sampleWeightPounds(for position: PlayerPosition, heightInches: Int, random: inout SeededRandom) -> Int {
    let weight: Int
    switch position {
    case .pg, .cg:
        weight = 170 + (heightInches - 72) * 8 + random.int(-10, 12)
        return clamp(weight, min: 155, max: 220)
    case .sg:
        weight = 180 + (heightInches - 74) * 9 + random.int(-10, 14)
        return clamp(weight, min: 165, max: 230)
    case .sf, .wing:
        weight = 195 + (heightInches - 76) * 10 + random.int(-12, 14)
        return clamp(weight, min: 180, max: 245)
    case .f, .pf:
        weight = 212 + (heightInches - 78) * 11 + random.int(-12, 16)
        return clamp(weight, min: 195, max: 265)
    case .c, .big:
        weight = 228 + (heightInches - 80) * 12 + random.int(-14, 18)
        return clamp(weight, min: 215, max: 290)
    }
}

func sampleWingspanDelta(for position: PlayerPosition, random: inout SeededRandom) -> Int {
    switch position {
    case .pg, .sg, .cg:
        return random.int(2, 6)
    case .sf, .wing, .f:
        return random.int(3, 7)
    case .pf, .c, .big:
        return random.int(4, 9)
    }
}

func formatHeight(inches: Int) -> String {
    "\(inches / 12)-\(inches % 12)"
}

func applyRatings(_ player: inout Player, base: Int, random: inout SeededRandom) {
    func r(_ delta: Int = 0) -> Int { clamp(base + delta + random.int(-11, 11), min: 25, max: 99) }

    player.athleticism.speed = r(2)
    player.athleticism.agility = r(1)
    player.athleticism.burst = r(1)
    player.athleticism.strength = r(-1)
    player.athleticism.vertical = r(0)
    player.athleticism.stamina = r(4)
    player.athleticism.durability = r(3)

    player.shooting.layups = r(3)
    player.shooting.dunks = r(-1)
    player.shooting.closeShot = r(2)
    player.shooting.midrangeShot = r(1)
    player.shooting.threePointShooting = r(0)
    player.shooting.cornerThrees = r(1)
    player.shooting.upTopThrees = r(0)
    player.shooting.drawFoul = r(-1)
    player.shooting.freeThrows = r(2)

    player.postGame.postControl = r(-1)
    player.postGame.postFadeaways = r(-2)
    player.postGame.postHooks = r(-2)

    player.skills.ballHandling = r(1)
    player.skills.ballSafety = r(0)
    player.skills.passingAccuracy = r(1)
    player.skills.passingVision = r(0)
    player.skills.passingIQ = r(1)
    player.skills.shotIQ = r(2)
    player.skills.offballOffense = r(1)
    player.skills.hands = r(0)
    player.skills.hustle = r(2)
    player.skills.clutch = r(0)

    player.defense.perimeterDefense = r(1)
    player.defense.postDefense = r(0)
    player.defense.shotBlocking = r(-2)
    player.defense.shotContest = r(0)
    player.defense.steals = r(0)
    player.defense.lateralQuickness = r(1)
    player.defense.offballDefense = r(1)
    player.defense.passPerception = r(1)
    player.defense.defensiveControl = r(1)

    player.rebounding.offensiveRebounding = r(-1)
    player.rebounding.defensiveRebound = r(0)
    player.rebounding.boxouts = r(0)

    player.tendencies.post = r(-2)
    player.tendencies.inside = r(2)
    player.tendencies.midrange = r(0)
    player.tendencies.threePoint = r(0)
    player.tendencies.drive = r(1)
    player.tendencies.pickAndRoll = r(1)
    player.tendencies.pickAndPop = r(0)
    let shootVsPassBase: Int
    switch player.bio.position {
    case .pg:
        shootVsPassBase = 43
    case .cg:
        shootVsPassBase = 47
    case .sg:
        shootVsPassBase = 50
    case .sf, .wing:
        shootVsPassBase = 52
    case .f, .pf:
        shootVsPassBase = 54
    case .c, .big:
        shootVsPassBase = 56
    }
    player.tendencies.shootVsPass = clamp(shootVsPassBase + random.int(-8, 8), min: 25, max: 99)
}

func playerOverall(_ player: Player) -> Int {
    let values = [
        player.skills.shotIQ,
        player.skills.ballHandling,
        player.skills.passingIQ,
        player.shooting.threePointShooting,
        player.shooting.midrangeShot,
        player.shooting.closeShot,
        player.defense.perimeterDefense,
        player.defense.postDefense,
        player.rebounding.defensiveRebound,
        player.athleticism.speed,
        player.athleticism.agility,
    ]
    let avg = Double(values.reduce(0, +)) / Double(values.count)
    return clamp(Int(avg.rounded()), min: 1, max: 99)
}

func teamOverall(_ team: Team) -> Double {
    guard !team.players.isEmpty else { return 50 }
    let avg = team.players.map(playerOverall).reduce(0, +) / team.players.count
    return Double(avg)
}

func coachingQuality(_ staff: CoachingStaff) -> Double {
    func coachSkill(_ coach: Coach) -> Double {
        let values = [
            coach.skills.playerDevelopment,
            coach.skills.guardDevelopment,
            coach.skills.wingDevelopment,
            coach.skills.bigDevelopment,
            coach.skills.offensiveCoaching,
            coach.skills.defensiveCoaching,
            coach.skills.scouting,
            coach.skills.recruiting,
        ]
        return Double(values.reduce(0, +)) / Double(values.count)
    }

    let head = coachSkill(staff.headCoach)
    let assistantAvg = staff.assistants.isEmpty ? head : staff.assistants.map(coachSkill).reduce(0, +) / Double(staff.assistants.count)
    return clamp((head * 0.68 + assistantAvg * 0.32) / 100, min: 0, max: 1)
}

func defaultRotationSlots(for team: Team) -> [UserRotationSlot] {
    let starters = Array((team.lineup.isEmpty ? team.players : team.lineup).prefix(5))
    let lineupNames = Set(starters.map { $0.bio.name })

    let benchPairs = Array(team.players.enumerated().filter { !lineupNames.contains($0.element.bio.name) })
    let minutesByRosterIndex = rotationMinuteTargets(for: team, roster: team.players)

    let starterSlots = starters.enumerated().map { idx, player -> UserRotationSlot in
        let playerIndex = team.players.firstIndex(where: { $0.bio.name == player.bio.name })
        let minutes = playerIndex.flatMap { $0 < minutesByRosterIndex.count ? minutesByRosterIndex[$0] : nil } ?? 0
        return UserRotationSlot(slot: idx, playerIndex: playerIndex, position: player.bio.position.rawValue, minutes: minutes)
    }

    let benchSlots = benchPairs.enumerated().map { benchIdx, pair -> UserRotationSlot in
        let minutes = pair.offset < minutesByRosterIndex.count ? minutesByRosterIndex[pair.offset] : 0
        return UserRotationSlot(slot: benchIdx + 5, playerIndex: pair.offset, position: pair.element.bio.position.rawValue, minutes: minutes)
    }

    return starterSlots + benchSlots
}

func rotationMinuteTargets(for team: Team, roster: [Player]) -> [Double] {
    guard !roster.isEmpty else { return [] }

    let totalTarget = min(200.0, Double(roster.count) * 40.0)
    let starterIndices = rotationStarterIndices(for: team, roster: roster)
    var starterIndexSet = Set(starterIndices)
    if starterIndexSet.isEmpty {
        starterIndexSet = Set(roster.indices.prefix(min(5, roster.count)))
    }

    let benchIndicesByRole = roster.indices
        .filter { !starterIndexSet.contains($0) }
        .sorted {
            let leftOverall = playerOverall(roster[$0])
            let rightOverall = playerOverall(roster[$1])
            if leftOverall != rightOverall { return leftOverall > rightOverall }
            return $0 < $1
        }
    let benchRankByIndex = Dictionary(uniqueKeysWithValues: benchIndicesByRole.enumerated().map { ($0.element, $0.offset) })

    let overalls = roster.map { Double(playerOverall($0)) }
    let mean = overalls.reduce(0, +) / Double(overalls.count)
    var values = roster.indices.map { idx -> Double in
        let qualityAdjustment = (overalls[idx] - mean) * 0.16
        if starterIndexSet.contains(idx) {
            return clamp(29 + qualityAdjustment, min: 25, max: 34)
        }

        let rank = benchRankByIndex[idx] ?? benchIndicesByRole.count
        let base: Double
        switch rank {
        case 0: base = 14
        case 1: base = 12
        case 2: base = 10
        case 3: base = 8
        case 4: base = 6
        case 5: base = 3
        case 6: base = 1
        default: base = 0
        }
        return clamp(base + qualityAdjustment * 0.45, min: 0, max: 20)
    }

    values = values.map { ($0 * 2).rounded() / 2 }
    forceTotal(&values, target: totalTarget, hardMin: 0, hardMax: 40, preferredMin: 0, preferredMax: 36, overalls: overalls)
    return values
}

func rotationStarterIndices(for team: Team, roster: [Player]) -> [Int] {
    let listedStarters = Array((team.lineup.isEmpty ? roster : team.lineup).prefix(5))
    var used: Set<Int> = []
    var starterIndices: [Int] = []
    for starter in listedStarters {
        if let idx = roster.enumerated().first(where: { pair in
            !used.contains(pair.offset)
                && pair.element.bio.name == starter.bio.name
                && pair.element.bio.position == starter.bio.position
        })?.offset {
            starterIndices.append(idx)
            used.insert(idx)
        }
    }
    if starterIndices.count < min(5, roster.count) {
        for idx in roster.indices where !used.contains(idx) {
            starterIndices.append(idx)
            used.insert(idx)
            if starterIndices.count == min(5, roster.count) { break }
        }
    }
    return starterIndices
}

func balancedMinutes(overalls: [Double], target: Double, softMin: Double, softMax: Double) -> [Double] {
    guard !overalls.isEmpty, target > 0 else {
        return Array(repeating: 0, count: overalls.count)
    }
    let count = Double(overalls.count)
    let avg = target / count
    let mean = overalls.reduce(0, +) / count
    var values = overalls.map { o -> Double in
        let weighted = avg + (o - mean) * 0.35
        let bounded = min(softMax, max(softMin, weighted))
        return (bounded * 2).rounded() / 2
    }
    forceTotal(&values, target: target, hardMin: 0, hardMax: 40, preferredMin: softMin, preferredMax: softMax, overalls: overalls)
    return values
}

func forceTotal(_ values: inout [Double], target: Double, hardMin: Double, hardMax: Double, preferredMin: Double, preferredMax: Double, overalls: [Double]) {
    guard !values.isEmpty else { return }
    let order = values.indices.sorted { overalls[$0] > overalls[$1] }
    var guardCount = 0
    while abs(values.reduce(0, +) - target) >= 0.25 && guardCount < 4000 {
        guardCount += 1
        let diff = target - values.reduce(0, +)
        let step = diff > 0 ? 0.5 : -0.5
        let preferIndices = diff > 0 ? order : order.reversed()
        var adjusted = false
        for tier in 0..<2 {
            let lower = tier == 0 ? preferredMin : hardMin
            let upper = tier == 0 ? preferredMax : hardMax
            for i in preferIndices {
                let candidate = values[i] + step
                if candidate < lower - 0.001 || candidate > upper + 0.001 { continue }
                values[i] = candidate
                adjusted = true
                break
            }
            if adjusted { break }
        }
        if !adjusted { break }
    }
}

let homeCourtBoost = 1.03

let coachingEdgeMaxMultiplier = 0.055

let headCoachGameImpactWeight = 0.72

let gamePrepAssistantGameImpactWeight = 0.28

func applyPreGameModifiers(team: inout Team, isHome: Bool) {
    let staff = team.coachingStaff
    let head = staff.headCoach
    let prepIdx = staff.gamePrepAssistantIndex
    let prep: Coach? = {
        if let idx = prepIdx, idx >= 0, idx < staff.assistants.count { return staff.assistants[idx] }
        return staff.assistants.first
    }()

    let headOff = Double(head.skills.offensiveCoaching)
    let headDef = Double(head.skills.defensiveCoaching)
    let prepOff = prep.map { Double($0.skills.offensiveCoaching) } ?? headOff
    let prepDef = prep.map { Double($0.skills.defensiveCoaching) } ?? headDef

    let offEdge = (headOff * headCoachGameImpactWeight + prepOff * gamePrepAssistantGameImpactWeight - 50) / 50
    let defEdge = (headDef * headCoachGameImpactWeight + prepDef * gamePrepAssistantGameImpactWeight - 50) / 50
    let offMult = 1 + max(-1, min(1, offEdge)) * coachingEdgeMaxMultiplier
    let defMult = 1 + max(-1, min(1, defEdge)) * coachingEdgeMaxMultiplier
    let homeMult = isHome ? homeCourtBoost : 1.0

    for idx in team.players.indices {
        team.players[idx].condition.offensiveCoachingModifier = offMult
        team.players[idx].condition.defensiveCoachingModifier = defMult
        team.players[idx].condition.homeCourtMultiplier = homeMult
    }
    for idx in team.lineup.indices {
        team.lineup[idx].condition.offensiveCoachingModifier = offMult
        team.lineup[idx].condition.defensiveCoachingModifier = defMult
        team.lineup[idx].condition.homeCourtMultiplier = homeMult
    }
}
