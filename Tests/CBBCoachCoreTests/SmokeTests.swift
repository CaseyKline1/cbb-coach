import Testing
@testable import CBBCoachCore

@Test("Can create player and team")
func createPlayerAndTeam() {
    var random = SeededRandom(seed: 1)
    let player = createPlayer()
    let team = createTeam(options: CreateTeamOptions(name: "Test U", players: [player, player, player, player, player]), random: &random)
    #expect(team.name == "Test U")
    #expect(team.players.count == 5)
}

@Test("Coach and staff generation is native and normalized")
func coachAndStaffGeneration() {
    var random = SeededRandom(seed: 7)

    var options = CreateCoachOptions()
    options.role = .assistant
    options.teamName = "Sample U"
    options.skills = nil
    let generated = createCoach(options: options, random: &random)
    #expect(generated.role == .assistant)
    #expect(generated.focus == .recruiting)
    #expect((generated.name ?? "").isEmpty == false)
    #expect(generated.age >= 24 && generated.age <= 80)
    #expect(generated.pressAggressiveness >= 1 && generated.pressAggressiveness <= 100)

    var staffOptions = CreateCoachingStaffOptions()
    staffOptions.teamName = "Sample U"
    staffOptions.assistants = []
    let staff = createCoachingStaff(options: staffOptions, random: &random)
    #expect(staff.assistants.count == 4)
    #expect(staff.coaches.count == 5)
}

@Test("Can simulate a complete game")
func simulateGameSmoke() {
    var random = SeededRandom(seed: 42)
    var player = createPlayer()
    player.bio.name = "Player A"
    player.shooting.threePointShooting = 72
    player.shooting.midrangeShot = 68
    player.shooting.layups = 74

    let home = createTeam(options: CreateTeamOptions(name: "Home U", players: [player, player, player, player, player]), random: &random)
    let away = createTeam(options: CreateTeamOptions(name: "Away State", players: [player, player, player, player, player]), random: &random)
    let result = simulateGame(homeTeam: home, awayTeam: away, random: &random)

    #expect(result.home.score >= 0)
    #expect(result.away.score >= 0)
    #expect(!result.playByPlay.isEmpty)
    #expect(result.home.score <= 140)
    #expect(result.away.score <= 140)
    #expect(result.boxScore?.count == 2)
    if let homeBox = result.home.boxScore {
        #expect(homeBox.players.reduce(0) { $0 + $1.points } == result.home.score)
    }
    if let awayBox = result.away.boxScore {
        #expect(awayBox.players.reduce(0) { $0 + $1.points } == result.away.score)
    }
}

@Test("Native resolveInteraction favors stronger offensive profile")
func resolveInteractionNative() {
    var random = SeededRandom(seed: 99)
    var offense = createPlayer()
    offense.shooting.threePointShooting = 88
    offense.shooting.midrangeShot = 82
    offense.skills.shotIQ = 84
    offense.athleticism.speed = 80
    offense.condition.energy = 96

    var defense = createPlayer()
    defense.defense.perimeterDefense = 58
    defense.defense.lateralQuickness = 60
    defense.skills.clutch = 45
    defense.condition.energy = 90

    let result = resolveInteraction(
        offensePlayer: offense,
        defensePlayer: defense,
        offenseRatings: ["shooting.threePointShooting", "skills.shotIQ", "athleticism.speed"],
        defenseRatings: ["defense.perimeterDefense", "defense.lateralQuickness", "skills.hands"],
        random: &random
    )

    #expect(result.offenseScore > result.defenseScore)
    #expect(result.edge > 0)
}

@Test("Can create, schedule, and advance league state")
func leagueFlowSmoke() throws {
    var league = try createD1League(options: CreateLeagueOptions(userTeamName: "Duke", seed: "tests"))
    autoFillUserNonConferenceOpponents(&league)
    generateSeasonSchedule(&league)
    let before = getLeagueSummary(league)
    #expect(before.scheduleGenerated)
    #expect(before.totalScheduledGames > 0)

    _ = advanceToNextUserGame(&league)
}

@Test("Career team options decode HTML entities")
func careerTeamOptionsDecodeEntities() {
    let options = listCareerTeamOptions()
    #expect(options.contains(where: { $0.teamName == "William & Mary" }))
    #expect(options.contains(where: { $0.teamName == "Saint Joseph's" }))
    #expect(options.allSatisfy { !$0.teamName.contains("&amp;") && !$0.teamName.contains("&#039;") })
}

@Test("User schedule plays non-conference games before conference games")
func nonConferenceBeforeConferenceOrdering() throws {
    var league = try createD1League(options: CreateLeagueOptions(userTeamName: "Duke", seed: "nonconf-before-conf"))
    autoFillUserNonConferenceOpponents(&league)
    generateSeasonSchedule(&league)

    let summary = getLeagueSummary(league)
    let teamOptions = listCareerTeamOptions()
    let conferenceByTeamId = Dictionary(uniqueKeysWithValues: teamOptions.map { ($0.teamId, $0.conferenceId) })
    guard let userConferenceId = conferenceByTeamId[summary.userTeamId] else {
        Issue.record("Missing user conference for schedule ordering test")
        return
    }

    let userSchedule = getUserSchedule(league).sorted {
        let lhsDay = $0.day ?? Int.max
        let rhsDay = $1.day ?? Int.max
        if lhsDay != rhsDay { return lhsDay < rhsDay }
        return ($0.gameId ?? "") < ($1.gameId ?? "")
    }

    var seenConferenceGame = false
    for game in userSchedule {
        guard let opponentId = game.opponentTeamId, let opponentConferenceId = conferenceByTeamId[opponentId] else { continue }
        let isConferenceGame = opponentConferenceId == userConferenceId
        if isConferenceGame {
            seenConferenceGame = true
        } else if seenConferenceGame {
            Issue.record("Found a non-conference game after conference play started")
            break
        }
    }
}

@Test("Advancing user game also simulates CPU-only games on that day")
func advancingUserGameSimulatesLeagueDay() throws {
    var league = try createD1League(options: CreateLeagueOptions(userTeamName: "Duke", seed: "league-day-tests", totalRegularSeasonGames: 3))
    autoFillUserNonConferenceOpponents(&league)
    generateSeasonSchedule(&league)
    let summary = getLeagueSummary(league)
    #expect(summary.totalScheduledGames > 3)

    _ = advanceToNextUserGame(&league)
    let completed = getCompletedLeagueGames(league)
    let cpuOnlyCompleted = completed.filter { game in
        game.homeTeamId != summary.userTeamId && game.awayTeamId != summary.userTeamId
    }
    #expect(!cpuOnlyCompleted.isEmpty)
}

@Test("Completed league games include box score payload for stat views")
func completedLeagueGamesCarryBoxScore() throws {
    var league = try createD1League(options: CreateLeagueOptions(userTeamName: "Duke", seed: "box-score-tests"))
    autoFillUserNonConferenceOpponents(&league)
    generateSeasonSchedule(&league)
    _ = advanceToNextUserGame(&league)

    let completed = getCompletedLeagueGames(league)
    #expect(!completed.isEmpty)
    guard let firstResult = completed.first?.result else {
        Issue.record("Missing result payload on completed game")
        return
    }

    guard case let .object(resultObject) = firstResult else {
        Issue.record("Result payload should be an object")
        return
    }

    guard let boxScoreValue = resultObject["boxScore"], case let .array(boxArray) = boxScoreValue else {
        Issue.record("Missing boxScore array in completed game result")
        return
    }

    #expect(boxArray.count == 2)
}

@Test("Conference tournaments are scheduled after regular season")
func conferenceTournamentsFollowRegularSeason() throws {
    var league = try createD1League(options: CreateLeagueOptions(userTeamName: "Duke", seed: "conference-tourney-smoke", totalRegularSeasonGames: 1))
    autoFillUserNonConferenceOpponents(&league)
    generateSeasonSchedule(&league)

    var safetyCounter = 0
    while safetyCounter < 50 {
        safetyCounter += 1
        let summary = advanceToNextUserGame(&league)
        if summary?.done == true {
            break
        }
    }

    let completed = getCompletedLeagueGames(league)
    let tournamentGames = completed.filter { $0.type == "conference_tournament" }
    #expect(!tournamentGames.isEmpty)
}

@Test("12-team conference tournament gives top 4 seeds a first-round bye")
func conferenceTournamentTwelveTeamByes() throws {
    var league = try createD1League(options: CreateLeagueOptions(userTeamName: "Dayton", seed: "conference-twelve-bye", totalRegularSeasonGames: 1))
    autoFillUserNonConferenceOpponents(&league)
    generateSeasonSchedule(&league)

    _ = advanceToNextUserGame(&league)

    let standings = getConferenceStandings(league, conferenceId: "atlantic-10")
    #expect(standings.count == 14)

    let top4 = Set(standings.prefix(4).map(\.teamId))
    let seeds5to12 = Set(standings.dropFirst(4).prefix(8).map(\.teamId))

    _ = advanceToNextUserGame(&league)

    let completed = getCompletedLeagueGames(league)
    let atlantic10RoundOneGames = completed.filter { ($0.gameId ?? "").hasPrefix("ct_atlantic-10_r1_") }
    #expect(atlantic10RoundOneGames.count == 4)

    for game in atlantic10RoundOneGames {
        guard let homeTeamId = game.homeTeamId, let awayTeamId = game.awayTeamId else {
            Issue.record("Missing team ids for Atlantic 10 tournament game")
            continue
        }
        #expect(seeds5to12.contains(homeTeamId))
        #expect(seeds5to12.contains(awayTeamId))
        #expect(!top4.contains(homeTeamId))
        #expect(!top4.contains(awayTeamId))
    }
}

@Test("Simulation uses substitutions and bench players log minutes")
func substitutionFlowUsesBenchMinutes() {
    var random = SeededRandom(seed: 2026)

    func makeTeam(name: String) -> Team {
        var players: [Player] = []
        for idx in 0..<8 {
            var p = createPlayer()
            p.bio.name = "\(name) P\(idx + 1)"
            p.bio.position = [.pg, .sg, .sf, .pf, .c, .cg, .wing, .big][idx]
            p.condition.energy = idx < 5 ? 85 : 100
            p.skills.shotIQ = 65 + idx
            p.skills.ballHandling = 60 + idx
            p.defense.perimeterDefense = 58 + idx
            p.defense.lateralQuickness = 58 + idx
            p.shooting.closeShot = 62 + idx
            p.shooting.threePointShooting = 60 + idx
            players.append(p)
        }

        var options = CreateTeamOptions(name: name, players: players)
        options.lineup = Array(players.prefix(5))
        options.rotation = TeamRotation(
            minuteTargets: [
                "\(name) P1": 18, "\(name) P2": 18, "\(name) P3": 18, "\(name) P4": 18, "\(name) P5": 18,
                "\(name) P6": 24, "\(name) P7": 24, "\(name) P8": 20,
            ]
        )
        return createTeam(options: options, random: &random)
    }

    let home = makeTeam(name: "Home")
    let away = makeTeam(name: "Away")
    let result = simulateGame(homeTeam: home, awayTeam: away, random: &random)

    let homeBenchMinutes = result.home.boxScore?.players
        .filter { ["Home P6", "Home P7", "Home P8"].contains($0.playerName) }
        .reduce(0.0) { $0 + $1.minutes } ?? 0
    let awayBenchMinutes = result.away.boxScore?.players
        .filter { ["Away P6", "Away P7", "Away P8"].contains($0.playerName) }
        .reduce(0.0) { $0 + $1.minutes } ?? 0

    #expect(homeBenchMinutes > 0)
    #expect(awayBenchMinutes > 0)
}

@Test("Fatigue keeps high-usage scorers out of unrealistic average ranges")
func fatigueSuppressesExtremeScorerAverages() {
    func makePlayer(
        name: String,
        position: PlayerPosition,
        stamina: Int,
        shotIQ: Int,
        handle: Int,
        three: Int,
        mid: Int,
        close: Int,
        pass: Int,
        perimeterDefense: Int,
        lateral: Int
    ) -> Player {
        var p = createPlayer()
        p.bio.name = name
        p.bio.position = position
        p.athleticism.stamina = stamina
        p.skills.shotIQ = shotIQ
        p.skills.ballHandling = handle
        p.skills.passingVision = pass
        p.skills.passingIQ = pass
        p.skills.passingAccuracy = pass
        p.shooting.threePointShooting = three
        p.shooting.midrangeShot = mid
        p.shooting.closeShot = close
        p.shooting.layups = close
        p.defense.perimeterDefense = perimeterDefense
        p.defense.lateralQuickness = lateral
        p.condition.energy = 100
        return p
    }

    let star = makePlayer(
        name: "Star Guard",
        position: .pg,
        stamina: 88,
        shotIQ: 94,
        handle: 95,
        three: 96,
        mid: 93,
        close: 90,
        pass: 90,
        perimeterDefense: 70,
        lateral: 72
    )
    let support1 = makePlayer(name: "Support 1", position: .sg, stamina: 70, shotIQ: 58, handle: 56, three: 52, mid: 54, close: 57, pass: 55, perimeterDefense: 64, lateral: 63)
    let support2 = makePlayer(name: "Support 2", position: .sf, stamina: 72, shotIQ: 56, handle: 54, three: 50, mid: 53, close: 59, pass: 54, perimeterDefense: 63, lateral: 62)
    let support3 = makePlayer(name: "Support 3", position: .pf, stamina: 75, shotIQ: 57, handle: 50, three: 45, mid: 50, close: 62, pass: 52, perimeterDefense: 61, lateral: 58)
    let support4 = makePlayer(name: "Support 4", position: .c, stamina: 78, shotIQ: 58, handle: 48, three: 42, mid: 48, close: 66, pass: 50, perimeterDefense: 60, lateral: 56)

    let weak1 = makePlayer(name: "Weak 1", position: .pg, stamina: 72, shotIQ: 58, handle: 55, three: 53, mid: 54, close: 56, pass: 56, perimeterDefense: 48, lateral: 47)
    let weak2 = makePlayer(name: "Weak 2", position: .sg, stamina: 74, shotIQ: 57, handle: 54, three: 52, mid: 53, close: 55, pass: 54, perimeterDefense: 47, lateral: 46)
    let weak3 = makePlayer(name: "Weak 3", position: .sf, stamina: 75, shotIQ: 57, handle: 53, three: 50, mid: 52, close: 56, pass: 53, perimeterDefense: 46, lateral: 45)
    let weak4 = makePlayer(name: "Weak 4", position: .pf, stamina: 76, shotIQ: 56, handle: 50, three: 45, mid: 49, close: 60, pass: 50, perimeterDefense: 45, lateral: 44)
    let weak5 = makePlayer(name: "Weak 5", position: .c, stamina: 78, shotIQ: 55, handle: 48, three: 42, mid: 47, close: 62, pass: 49, perimeterDefense: 44, lateral: 42)

    let sampleGames = 20
    var totalStarPoints = 0
    var maxSingleGame = 0

    for game in 0..<sampleGames {
        var random = SeededRandom(seed: UInt64(8000 + game))
        let home = createTeam(options: CreateTeamOptions(name: "Star U", players: [star, support1, support2, support3, support4]), random: &random)
        let away = createTeam(options: CreateTeamOptions(name: "Weak State", players: [weak1, weak2, weak3, weak4, weak5]), random: &random)
        let result = simulateGame(homeTeam: home, awayTeam: away, random: &random)
        let starPoints = result.home.boxScore?.players.first(where: { $0.playerName == "Star Guard" })?.points ?? 0
        totalStarPoints += starPoints
        maxSingleGame = max(maxSingleGame, starPoints)
    }

    let average = Double(totalStarPoints) / Double(sampleGames)
    #expect(average < 45)
    #expect(maxSingleGame < 72)
}

@Test("Action initiation share is distributed beyond a single dominant handler")
func actionInitiationShareStaysBalanced() {
    func makePlayer(name: String, position: PlayerPosition, handle: Int, pass: Int, shotIQ: Int, burst: Int, drive: Int) -> Player {
        var p = createPlayer()
        p.bio.name = name
        p.bio.position = position
        p.skills.ballHandling = handle
        p.skills.passingVision = pass
        p.skills.passingIQ = pass
        p.skills.shotIQ = shotIQ
        p.athleticism.burst = burst
        p.tendencies.drive = drive
        p.condition.energy = 100
        return p
    }

    var random = SeededRandom(seed: 4242)
    let star = makePlayer(name: "Primary Guard", position: .pg, handle: 97, pass: 94, shotIQ: 92, burst: 92, drive: 90)
    let wing1 = makePlayer(name: "Wing 1", position: .sg, handle: 74, pass: 72, shotIQ: 71, burst: 73, drive: 69)
    let wing2 = makePlayer(name: "Wing 2", position: .sf, handle: 70, pass: 69, shotIQ: 70, burst: 71, drive: 68)
    let big1 = makePlayer(name: "Big 1", position: .pf, handle: 62, pass: 63, shotIQ: 67, burst: 65, drive: 58)
    let big2 = makePlayer(name: "Big 2", position: .c, handle: 58, pass: 60, shotIQ: 66, burst: 61, drive: 54)

    let opp1 = makePlayer(name: "Opp 1", position: .pg, handle: 72, pass: 71, shotIQ: 70, burst: 72, drive: 70)
    let opp2 = makePlayer(name: "Opp 2", position: .sg, handle: 71, pass: 70, shotIQ: 69, burst: 71, drive: 69)
    let opp3 = makePlayer(name: "Opp 3", position: .sf, handle: 70, pass: 69, shotIQ: 68, burst: 70, drive: 68)
    let opp4 = makePlayer(name: "Opp 4", position: .pf, handle: 64, pass: 64, shotIQ: 67, burst: 66, drive: 60)
    let opp5 = makePlayer(name: "Opp 5", position: .c, handle: 60, pass: 61, shotIQ: 66, burst: 62, drive: 56)

    let home = createTeam(options: CreateTeamOptions(name: "Star U", players: [star, wing1, wing2, big1, big2]), random: &random)
    let away = createTeam(options: CreateTeamOptions(name: "Balanced State", players: [opp1, opp2, opp3, opp4, opp5]), random: &random)
    let qa = simulateGameWithQA(homeTeam: home, awayTeam: away, random: &random)

    let homeInitiators = qa.actions
        .filter { $0.offenseTeam == "Star U" }
        .compactMap { action in
            action.interactions.first(where: { $0.label == "possession_advantage" })?.offensePlayer
        }

    let total = homeInitiators.count
    #expect(total > 30)
    let starInitiations = homeInitiators.filter { $0 == "Primary Guard" }.count
    let starShare = Double(starInitiations) / Double(max(1, total))

    #expect(starShare <= 0.42)
}

@Test("Rebounding stays interaction-based but avoids over-concentration")
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
    var totalTopShare = 0.0
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
            totalTopShare += Double(topHomeRebounds) / Double(homeTeamRebounds)
        }

        crashOffensiveRebounds += homePlayers.reduce(0) { $0 + $1.offensiveRebounds }
        weakDefensiveRebounds += awayPlayers.reduce(0) { $0 + $1.defensiveRebounds }
        perimeterCrashRebounds += homePlayers
            .filter { ["Crash PG", "Crash SG", "Crash SF"].contains($0.playerName) }
            .reduce(0) { $0 + $1.offensiveRebounds }
    }

    let avgTopShare = totalTopShare / Double(gameCount)
    let crashOrbRate = Double(crashOffensiveRebounds) / Double(max(1, crashOffensiveRebounds + weakDefensiveRebounds))

    #expect(avgTopShare <= 0.44)
    #expect(perimeterCrashRebounds >= gameCount)
    #expect(weakDefensiveRebounds >= gameCount * 8)
    #expect(crashOrbRate <= 0.62)
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
