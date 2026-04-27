import Foundation
import Testing
@testable import CBBCoachCore

private struct Agg {
    var games: Int = 0
    var pts: Int = 0
    var reb: Int = 0
    var ast: Int = 0
    var fga: Int = 0
    var fgm: Int = 0
    var fta: Int = 0
    var ftm: Int = 0
    var tpa: Int = 0
    var tpm: Int = 0
}

private struct TeamAgg {
    var games: Int = 0
    var fastBreakPoints: Int = 0
}

private struct Report {
    var games: Int = 0
    var minScore: Int = Int.max
    var maxScore: Int = 0
    var maxMargin: Int = 0
    var blowout150to50: Int = 0
    var maxPPG: Double = 0
    var maxRPG: Double = 0
    var maxAPG: Double = 0
    var over30PPG: Int = 0
    var over40PPG: Int = 0
    var topScorers: [(String, Double)] = []
    var topRebounders: [(String, Double)] = []
    var topPassers: [(String, Double)] = []
    var topScorerFGA: Double = 0
    var topScorerFGM: Double = 0
    var topScorer3PA: Double = 0
    var topScorer3PM: Double = 0
    var topScorerFTA: Double = 0
    var topScorerFTM: Double = 0
    var topScorerAPG: Double = 0
    var leagueTwoPtPct: Double = 0
    var leagueThreePtPct: Double = 0
    var leagueFTPct: Double = 0
    var topFastBreakTeams: [(String, Double)] = []
    var topVeryFastFastBreakTeams: [(String, Double)] = []
}

private func clampI(_ value: Int, _ lo: Int, _ hi: Int) -> Int {
    max(lo, min(hi, value))
}

private func makePlayer(name: String, position: PlayerPosition, base: Int, random: inout SeededRandom) -> Player {
    var p = createPlayer()
    p.bio.name = name
    p.bio.position = position
    p.bio.year = .fr
    p.bio.potential = clampI(base + random.int(-8, 10), 45, 95)

    func r(_ spread: Int = 10) -> Int { clampI(base + random.int(-spread, spread), 35, 95) }

    p.athleticism.speed = r(12)
    p.athleticism.agility = r(12)
    p.athleticism.burst = r(12)
    p.athleticism.strength = r(12)
    p.athleticism.vertical = r(12)
    p.athleticism.stamina = r(10)
    p.athleticism.durability = r(10)

    p.shooting.layups = r(11)
    p.shooting.dunks = r(11)
    p.shooting.closeShot = r(11)
    p.shooting.midrangeShot = r(12)
    p.shooting.threePointShooting = r(12)
    p.shooting.cornerThrees = r(12)
    p.shooting.upTopThrees = r(12)
    p.shooting.drawFoul = r(11)
    p.shooting.freeThrows = r(12)

    p.postGame.postControl = r(11)
    p.postGame.postFadeaways = r(11)
    p.postGame.postHooks = r(11)

    p.skills.ballHandling = r(11)
    p.skills.ballSafety = r(11)
    p.skills.passingAccuracy = r(11)
    p.skills.passingVision = r(11)
    p.skills.passingIQ = r(11)
    p.skills.shotIQ = r(11)
    p.skills.offballOffense = r(11)
    p.skills.hands = r(11)
    p.skills.hustle = r(11)
    p.skills.clutch = r(11)

    p.defense.perimeterDefense = r(11)
    p.defense.postDefense = r(11)
    p.defense.shotBlocking = r(11)
    p.defense.shotContest = r(11)
    p.defense.steals = r(11)
    p.defense.lateralQuickness = r(11)
    p.defense.offballDefense = r(11)
    p.defense.passPerception = r(11)
    p.defense.defensiveControl = r(11)

    p.rebounding.offensiveRebounding = r(11)
    p.rebounding.defensiveRebound = r(11)
    p.rebounding.boxouts = r(11)

    p.tendencies.post = r(16)
    p.tendencies.inside = r(16)
    p.tendencies.midrange = r(16)
    p.tendencies.threePoint = r(16)
    p.tendencies.drive = r(16)
    p.tendencies.pickAndRoll = r(16)
    p.tendencies.pickAndPop = r(16)
    p.tendencies.shootVsPass = r(16)

    switch position {
    case .pg, .cg:
        p.skills.passingVision = clampI(p.skills.passingVision + 10, 40, 96)
        p.skills.passingIQ = clampI(p.skills.passingIQ + 10, 40, 96)
        p.skills.ballHandling = clampI(p.skills.ballHandling + 8, 40, 96)
        p.tendencies.shootVsPass = clampI(p.tendencies.shootVsPass - 8, 35, 90)
    case .c, .big, .pf:
        p.rebounding.offensiveRebounding = clampI(p.rebounding.offensiveRebounding + 10, 40, 97)
        p.rebounding.defensiveRebound = clampI(p.rebounding.defensiveRebound + 10, 40, 97)
        p.rebounding.boxouts = clampI(p.rebounding.boxouts + 10, 40, 97)
        p.athleticism.strength = clampI(p.athleticism.strength + 8, 40, 97)
    default:
        break
    }

    return p
}

private func makeTeam(name: String, seed: String) -> Team {
    var random = SeededRandom(seed: hashString(seed))
    let positions: [PlayerPosition] = [.pg, .sg, .sf, .pf, .c, .cg, .wing, .f, .big, .sf]
    let base = random.int(60, 76)
    let players = positions.enumerated().map { i, pos in
        makePlayer(name: "\(name) P\(i + 1)", position: pos, base: clampI(base + random.int(-6, 6), 50, 85), random: &random)
    }

    var options = CreateTeamOptions(name: name, players: players)
    options.lineup = Array(players.prefix(5))
    options.formation = random.choose(OffensiveFormation.allCases) ?? .motion
    options.defenseScheme = random.choose(DefenseScheme.allCases) ?? .manToMan
    options.pace = random.choose(PaceProfile.allCases) ?? .normal
    options.tendencies.fastBreakOffense = Double(random.int(30, 72))
    options.tendencies.crashBoardsOffense = Double(random.int(35, 75))
    options.tendencies.defendFastBreakOffense = Double(random.int(35, 72))
    options.tendencies.crashBoardsDefense = Double(random.int(35, 75))
    options.tendencies.attemptFastBreakDefense = Double(random.int(30, 72))
    options.tendencies.press = Double(random.int(20, 65))
    options.tendencies.trapRate = Double(random.int(20, 65))
    options.tendencies.pressBreakPass = Double(random.int(35, 80))
    options.tendencies.pressBreakAttack = Double(random.int(35, 80))
    return createTeam(options: options, random: &random)
}

private func runAudit(seed: String, teamsCount: Int = 20, gamesPerTeam: Int = 14) -> Report {
    var report = Report()
    var random = SeededRandom(seed: hashString("audit:\(seed)"))
    var teams: [Team] = (0..<teamsCount).map { makeTeam(name: "Team \($0 + 1)", seed: "\(seed):team:\($0)") }
    for idx in teams.indices {
        if idx < max(4, teamsCount / 4) {
            teams[idx].pace = .veryFast
            teams[idx].tendencies.fastBreakOffense = Double(random.int(82, 98))
            teams[idx].tendencies.press = Double(random.int(58, 82))
            teams[idx].tendencies.trapRate = Double(random.int(58, 84))
            teams[idx].tendencies.pressBreakAttack = Double(random.int(72, 95))
        }
    }
    let paceByTeam: [String: PaceProfile] = Dictionary(uniqueKeysWithValues: teams.map { ($0.name, $0.pace) })
    var played = Array(repeating: 0, count: teamsCount)
    var stats: [String: Agg] = [:]
    var teamStats: [String: TeamAgg] = [:]
    var leagueFGA = 0
    var leagueFGM = 0
    var league3PA = 0
    var league3PM = 0
    var leagueFTA = 0
    var leagueFTM = 0

    let targetGames = (teamsCount * gamesPerTeam) / 2
    var gameNo = 0
    while gameNo < targetGames {
        let available = teams.indices.filter { played[$0] < gamesPerTeam }
        if available.count < 2 { break }
        let homeIdx = available[random.int(0, available.count - 1)]
        let awayPool = available.filter { $0 != homeIdx }
        if awayPool.isEmpty { break }
        let awayIdx = awayPool[random.int(0, awayPool.count - 1)]

        var gameRandom = SeededRandom(seed: hashString("\(seed):game:\(gameNo):\(homeIdx):\(awayIdx)"))
        let result = simulateGame(homeTeam: teams[homeIdx], awayTeam: teams[awayIdx], random: &gameRandom, includePlayByPlay: false)

        played[homeIdx] += 1
        played[awayIdx] += 1
        gameNo += 1
        report.games += 1

        let hs = result.home.score
        let awayScore = result.away.score
        report.minScore = min(report.minScore, min(hs, awayScore))
        report.maxScore = max(report.maxScore, max(hs, awayScore))
        report.maxMargin = max(report.maxMargin, abs(hs - awayScore))
        if (hs >= 150 && awayScore <= 50) || (awayScore >= 150 && hs <= 50) {
            report.blowout150to50 += 1
        }

        for teamBox in result.boxScore ?? [] {
            var teamAgg = teamStats[teamBox.name, default: TeamAgg()]
            teamAgg.games += 1
            teamAgg.fastBreakPoints += teamBox.teamExtras?["fastBreakPoints"] ?? 0
            teamStats[teamBox.name] = teamAgg

            for p in teamBox.players {
                let key = "\(teamBox.name)::\(p.playerName)"
                var agg = stats[key, default: Agg()]
                agg.games += 1
                agg.pts += p.points
                agg.reb += p.rebounds
                agg.ast += p.assists
                agg.fga += p.fgAttempts
                agg.fgm += p.fgMade
                agg.fta += p.ftAttempts
                agg.ftm += p.ftMade
                agg.tpa += p.threeAttempts
                agg.tpm += p.threeMade
                stats[key] = agg

                leagueFGA += p.fgAttempts
                leagueFGM += p.fgMade
                league3PA += p.threeAttempts
                league3PM += p.threeMade
                leagueFTA += p.ftAttempts
                leagueFTM += p.ftMade
            }
        }
    }

    if report.minScore == Int.max { report.minScore = 0 }

    var scorers: [(String, Double)] = []
    var rebounders: [(String, Double)] = []
    var passers: [(String, Double)] = []
    for (key, agg) in stats where agg.games > 0 {
        let gp = Double(agg.games)
        let ppg = Double(agg.pts) / gp
        let rpg = Double(agg.reb) / gp
        let apg = Double(agg.ast) / gp
        scorers.append((key, ppg))
        rebounders.append((key, rpg))
        passers.append((key, apg))
        report.maxPPG = max(report.maxPPG, ppg)
        report.maxRPG = max(report.maxRPG, rpg)
        report.maxAPG = max(report.maxAPG, apg)
        if ppg > 30 { report.over30PPG += 1 }
        if ppg > 40 { report.over40PPG += 1 }
    }

    report.topScorers = scorers.sorted { $0.1 > $1.1 }.prefix(5).map { ($0.0, $0.1) }
    report.topRebounders = rebounders.sorted { $0.1 > $1.1 }.prefix(5).map { ($0.0, $0.1) }
    report.topPassers = passers.sorted { $0.1 > $1.1 }.prefix(5).map { ($0.0, $0.1) }
    if let topKey = report.topScorers.first?.0, let agg = stats[topKey], agg.games > 0 {
        let gp = Double(agg.games)
        report.topScorerFGA = Double(agg.fga) / gp
        report.topScorerFGM = Double(agg.fgm) / gp
        report.topScorer3PA = Double(agg.tpa) / gp
        report.topScorer3PM = Double(agg.tpm) / gp
        report.topScorerFTA = Double(agg.fta) / gp
        report.topScorerFTM = Double(agg.ftm) / gp
        report.topScorerAPG = Double(agg.ast) / gp
    }
    let league2PA = max(0, leagueFGA - league3PA)
    let league2PM = max(0, leagueFGM - league3PM)
    if league2PA > 0 { report.leagueTwoPtPct = Double(league2PM) / Double(league2PA) }
    if league3PA > 0 { report.leagueThreePtPct = Double(league3PM) / Double(league3PA) }
    if leagueFTA > 0 { report.leagueFTPct = Double(leagueFTM) / Double(leagueFTA) }
    let teamFastBreakPPG: [(String, Double)] = teamStats.compactMap { name, agg in
        guard agg.games > 0 else { return nil }
        return (name, Double(agg.fastBreakPoints) / Double(agg.games))
    }
    report.topFastBreakTeams = teamFastBreakPPG.sorted { $0.1 > $1.1 }.prefix(5).map { ($0.0, $0.1) }
    report.topVeryFastFastBreakTeams = teamFastBreakPPG
        .filter { paceByTeam[$0.0] == .veryFast }
        .sorted { $0.1 > $1.1 }
        .prefix(5)
        .map { ($0.0, $0.1) }
    return report
}

@Test("Season audit harness (manual)")
func seasonAuditHarness() {
    let seed = ProcessInfo.processInfo.environment["SEASON_AUDIT_SEED"] ?? "tune-a"
    let report = runAudit(seed: seed)
    print("=== Mini-League Audit ===")
    print("Seed: \(seed)")
    print("Games: \(report.games)")
    print("Score range: \(report.minScore)-\(report.maxScore), max margin: \(report.maxMargin)")
    print("150-50 or worse games: \(report.blowout150to50)")
    print(String(format: "Max PPG %.2f | Max RPG %.2f | Max APG %.2f", report.maxPPG, report.maxRPG, report.maxAPG))
    print(
        String(
            format: "League shooting: 2PT%% %.3f | 3PT%% %.3f | FT%% %.3f",
            report.leagueTwoPtPct,
            report.leagueThreePtPct,
            report.leagueFTPct
        )
    )
    print(">30 PPG players: \(report.over30PPG) | >40 PPG players: \(report.over40PPG)")
    print("Top scorers:")
    for (name, value) in report.topScorers {
        print(String(format: "  %.2f - %@", value, name))
    }
    print("Top rebounders:")
    for (name, value) in report.topRebounders {
        print(String(format: "  %.2f - %@", value, name))
    }
    print("Top passers:")
    for (name, value) in report.topPassers {
        print(String(format: "  %.2f - %@", value, name))
    }
    print("Top fast-break offenses (FB PPG):")
    for (name, value) in report.topFastBreakTeams {
        print(String(format: "  %.2f - %@", value, name))
    }
    print("Top very-fast fast-break offenses (FB PPG):")
    for (name, value) in report.topVeryFastFastBreakTeams {
        print(String(format: "  %.2f - %@", value, name))
    }
    if let (name, ppg) = report.topScorers.first {
        print("Top scorer detail:")
        print(
            String(
                format: "  %@ | PPG %.2f | FGA %.2f FGM %.2f | 3PA %.2f 3PM %.2f | FTA %.2f FTM %.2f | APG %.2f",
                name,
                ppg,
                report.topScorerFGA,
                report.topScorerFGM,
                report.topScorer3PA,
                report.topScorer3PM,
                report.topScorerFTA,
                report.topScorerFTM,
                report.topScorerAPG
            )
        )
    }
    #expect(Bool(true))
}

@Test("Debug single game foul mix (manual)")
func debugSingleGameFoulMix() {
    let teamA = makeTeam(name: "Team 3", seed: "tune-a:team:2")
    let teamB = makeTeam(name: "Team 1", seed: "tune-a:team:0")
    var gameRandom = SeededRandom(seed: hashString("tune-a:game:debug"))
    let result = simulateGame(homeTeam: teamA, awayTeam: teamB, random: &gameRandom, includePlayByPlay: true)
    var byType: [String: Int] = [:]
    for event in result.playByPlay {
        byType[event.type, default: 0] += 1
    }
    print("=== Debug Single Game ===")
    print("Score \(result.home.name) \(result.home.score) - \(result.away.score) \(result.away.name)")
    for (type, count) in byType.sorted(by: { $0.key < $1.key }) {
        print("  \(type): \(count)")
    }
    for teamBox in result.boxScore ?? [] {
        let teamFTA = teamBox.players.reduce(0) { $0 + $1.ftAttempts }
        let teamFTM = teamBox.players.reduce(0) { $0 + $1.ftMade }
        print("  \(teamBox.name) FT: \(teamFTM)/\(teamFTA)")
        let leaders = teamBox.players.sorted { $0.ftAttempts > $1.ftAttempts }.prefix(3)
        for p in leaders {
            let minutesText = String(format: "%.1f", p.minutes)
            print("    \(p.playerName): FT \(p.ftMade)/\(p.ftAttempts), PTS \(p.points), MIN \(minutesText)")
        }
    }
    #expect(Bool(true))
}
