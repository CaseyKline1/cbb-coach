import Foundation
import Testing
@testable import CBBCoachCore

@Test("Rebounding has realistic variance without forcing hard top-share caps")
func reboundingDistributionStaysBalanced() {
    func makePlayer(
        name: String,
        position: PlayerPosition,
        height: String,
        wingspan: String,
        oreb: Int,
        dreb: Int,
        boxout: Int,
        hustle: Int,
        hands: Int,
        burst: Int,
        speed: Int,
        vertical: Int,
        strength: Int,
        close: Int,
        mid: Int,
        three: Int
    ) -> Player {
        var p = createPlayer()
        p.bio.name = name
        p.bio.position = position
        p.size.height = height
        p.size.wingspan = wingspan
        p.rebounding.offensiveRebounding = oreb
        p.rebounding.defensiveRebound = dreb
        p.rebounding.boxouts = boxout
        p.skills.hustle = hustle
        p.skills.hands = hands
        p.athleticism.burst = burst
        p.athleticism.speed = speed
        p.athleticism.vertical = vertical
        p.athleticism.strength = strength
        p.shooting.closeShot = close
        p.shooting.midrangeShot = mid
        p.shooting.threePointShooting = three
        p.shooting.layups = close
        p.skills.shotIQ = 68
        p.condition.energy = 100
        return p
    }

    let crashTeam: [Player] = [
        makePlayer(name: "Crash PG", position: .pg, height: "6-3", wingspan: "6-7", oreb: 74, dreb: 63, boxout: 56, hustle: 90, hands: 82, burst: 90, speed: 89, vertical: 80, strength: 68, close: 66, mid: 64, three: 63),
        makePlayer(name: "Crash SG", position: .sg, height: "6-5", wingspan: "6-9", oreb: 76, dreb: 66, boxout: 58, hustle: 88, hands: 84, burst: 87, speed: 86, vertical: 81, strength: 70, close: 67, mid: 65, three: 64),
        makePlayer(name: "Crash SF", position: .sf, height: "6-7", wingspan: "6-11", oreb: 80, dreb: 72, boxout: 68, hustle: 84, hands: 79, burst: 82, speed: 80, vertical: 84, strength: 76, close: 69, mid: 66, three: 62),
        makePlayer(name: "Crash PF", position: .pf, height: "6-10", wingspan: "7-2", oreb: 95, dreb: 86, boxout: 88, hustle: 84, hands: 78, burst: 73, speed: 70, vertical: 83, strength: 89, close: 70, mid: 64, three: 58),
        makePlayer(name: "Crash C", position: .c, height: "7-0", wingspan: "7-4", oreb: 97, dreb: 90, boxout: 92, hustle: 82, hands: 80, burst: 69, speed: 66, vertical: 82, strength: 92, close: 71, mid: 60, three: 52),
    ]

    let weakBoxTeam: [Player] = [
        makePlayer(name: "Weak PG", position: .pg, height: "6-2", wingspan: "6-5", oreb: 50, dreb: 44, boxout: 42, hustle: 66, hands: 64, burst: 74, speed: 75, vertical: 70, strength: 62, close: 65, mid: 62, three: 61),
        makePlayer(name: "Weak SG", position: .sg, height: "6-4", wingspan: "6-7", oreb: 52, dreb: 45, boxout: 43, hustle: 65, hands: 63, burst: 72, speed: 73, vertical: 70, strength: 63, close: 64, mid: 61, three: 60),
        makePlayer(name: "Weak SF", position: .sf, height: "6-6", wingspan: "6-9", oreb: 53, dreb: 47, boxout: 46, hustle: 64, hands: 64, burst: 70, speed: 70, vertical: 72, strength: 67, close: 66, mid: 62, three: 58),
        makePlayer(name: "Weak PF", position: .pf, height: "6-8", wingspan: "6-11", oreb: 56, dreb: 49, boxout: 48, hustle: 63, hands: 62, burst: 67, speed: 65, vertical: 73, strength: 71, close: 67, mid: 61, three: 54),
        makePlayer(name: "Weak C", position: .c, height: "6-10", wingspan: "7-1", oreb: 58, dreb: 51, boxout: 50, hustle: 62, hands: 63, burst: 65, speed: 62, vertical: 74, strength: 74, close: 68, mid: 60, three: 50),
    ]

    let gameCount = 24
    var topShares: [Double] = []
    var crashOffensiveRebounds = 0
    var weakDefensiveRebounds = 0
    var perimeterCrashRebounds = 0

    for game in 0..<gameCount {
        var random = SeededRandom(seed: UInt64(19000 + game))
        let home = createTeam(options: CreateTeamOptions(name: "Crash U", players: crashTeam), random: &random)
        let away = createTeam(options: CreateTeamOptions(name: "Weak Box State", players: weakBoxTeam), random: &random)
        let result = simulateGame(homeTeam: home, awayTeam: away, random: &random)

        guard
            let homePlayers = result.home.boxScore?.players,
            let awayPlayers = result.away.boxScore?.players
        else {
            Issue.record("Missing box scores in rebound distribution test")
            return
        }

        let homeTeamRebounds = homePlayers.reduce(0) { $0 + $1.rebounds }
        let topHomeRebounds = homePlayers.map(\.rebounds).max() ?? 0
        if homeTeamRebounds > 0 {
            topShares.append(Double(topHomeRebounds) / Double(homeTeamRebounds))
        }

        crashOffensiveRebounds += homePlayers.reduce(0) { $0 + $1.offensiveRebounds }
        weakDefensiveRebounds += awayPlayers.reduce(0) { $0 + $1.defensiveRebounds }
        perimeterCrashRebounds += homePlayers
            .filter { ["Crash PG", "Crash SG", "Crash SF"].contains($0.playerName) }
            .reduce(0) { $0 + $1.offensiveRebounds }
    }

    let avgTopShare = topShares.reduce(0, +) / Double(max(1, topShares.count))
    let topShareVariance = topShares.reduce(0.0) { partial, value in
        let delta = value - avgTopShare
        return partial + delta * delta
    } / Double(max(1, topShares.count))
    let topShareStdDev = Foundation.sqrt(topShareVariance)
    let dominantTopShareGames = topShares.filter { $0 >= 0.5 }.count
    let crashOrbRate = Double(crashOffensiveRebounds) / Double(max(1, crashOffensiveRebounds + weakDefensiveRebounds))

    #expect(topShareStdDev >= 0.05)
    #expect(dominantTopShareGames >= 1)
    #expect(perimeterCrashRebounds >= gameCount)
    #expect(weakDefensiveRebounds >= gameCount * 7)
    #expect(crashOrbRate <= 0.66)
}

@Test("User roster summary includes full player rating payload")
func userRosterIncludesFullAttributeSet() throws {
    let league = try createD1League(options: CreateLeagueOptions(userTeamName: "Duke", seed: "roster-attributes"))
    let roster = getUserRoster(league)
    guard let player = roster.first, let attributes = player.attributes else {
        Issue.record("Expected roster player with attributes payload")
        return
    }

    let expectedKeys: Set<String> = [
        "potential",
        "speed", "agility", "burst", "strength", "vertical", "stamina", "durability",
        "layups", "dunks", "closeShot", "midrangeShot", "threePointShooting", "cornerThrees", "upTopThrees", "drawFoul", "freeThrows",
        "postControl", "postFadeaways", "postHooks",
        "ballHandling", "ballSafety", "passingAccuracy", "passingVision", "passingIQ", "shotIQ", "offballOffense", "hands", "hustle", "clutch",
        "perimeterDefense", "postDefense", "shotBlocking", "shotContest", "steals", "lateralQuickness", "offballDefense", "passPerception", "defensiveControl",
        "offensiveRebounding", "defensiveRebound", "boxouts",
        "tendencyPost", "tendencyInside", "tendencyMidrange", "tendencyThreePoint", "tendencyDrive", "tendencyPickAndRoll", "tendencyPickAndPop", "tendencyShootVsPass",
    ]

    #expect(Set(attributes.keys) == expectedKeys)
}
