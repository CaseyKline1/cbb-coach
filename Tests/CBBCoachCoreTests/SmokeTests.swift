import Foundation
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

@Test("Batched user advancement matches repeated single-game advancement")
func batchedUserAdvanceMatchesSequentialAdvance() throws {
    let options = CreateLeagueOptions(userTeamName: "Duke", seed: "batch-vs-sequential", totalRegularSeasonGames: 4)
    var batchedLeague = try createD1League(options: options)
    var sequentialLeague = try createD1League(options: options)

    let batched = advanceUserGames(&batchedLeague, maxGames: 3)
    var sequentialResults: [UserGameSummary] = []
    for _ in 0..<3 {
        if let result = advanceToNextUserGame(&sequentialLeague), result.done != true {
            sequentialResults.append(result)
        }
    }

    func scoreSignature(_ games: [LeagueGameSummary]) -> [String] {
        games.map { game in
            let object: [String: JSONValue]
            if case let .object(resultObject) = game.result {
                object = resultObject
            } else {
                object = [:]
            }
            let home: Int
            if case let .number(value) = object["homeScore"] { home = Int(value) } else { home = -1 }
            let away: Int
            if case let .number(value) = object["awayScore"] { away = Int(value) } else { away = -1 }
            let winner: String
            if case let .string(value) = object["winnerTeamId"] { winner = value } else { winner = "tie" }
            return "\(game.gameId ?? "unknown"):\(home)-\(away):\(winner)"
        }
    }

    #expect(batched.results.map(\.gameId) == sequentialResults.map(\.gameId))
    #expect(batched.results.map(\.score) == sequentialResults.map(\.score))
    #expect(batched.results.map(\.record) == sequentialResults.map(\.record))
    #expect(scoreSignature(getCompletedLeagueGames(batchedLeague)) == scoreSignature(getCompletedLeagueGames(sequentialLeague)))
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

@Test("Team efficiency ratings populate after completed games")
func teamEfficiencyRatingsPopulate() throws {
    var league = try createD1League(options: CreateLeagueOptions(userTeamName: "Duke", seed: "team-efficiency-tests", totalRegularSeasonGames: 1))
    autoFillUserNonConferenceOpponents(&league)
    generateSeasonSchedule(&league)
    _ = advanceToNextUserGame(&league)

    let summary = getLeagueSummary(league)
    let ratings = getTeamEfficiencyRatings(league)
    guard let userRating = ratings.first(where: { $0.teamId == summary.userTeamId }) else {
        Issue.record("Missing user team efficiency rating")
        return
    }

    #expect(userRating.gamesPlayed > 0)
    #expect(userRating.rawOffensiveEfficiency > 0)
    #expect(userRating.rawDefensiveEfficiency > 0)
    #expect(userRating.adjustedOffensiveEfficiency > 0)
    #expect(userRating.adjustedDefensiveEfficiency > 0)
    #expect(userRating.pythagoreanExpectation >= 0)
    #expect(userRating.pythagoreanExpectation <= 1)
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

@Test("National tournament follows conference tournaments with 64 seeded teams")
func nationalTournamentFollowsConferenceTournaments() throws {
    var league = try createD1League(options: CreateLeagueOptions(userTeamName: "Duke", seed: "national-tourney-smoke", totalRegularSeasonGames: 1))
    autoFillUserNonConferenceOpponents(&league)
    generateSeasonSchedule(&league)

    var safetyCounter = 0
    while safetyCounter < 250 {
        safetyCounter += 1
        let summary = advanceToNextUserGame(&league)
        if summary?.done == true {
            break
        }
    }

    guard let bracket = getNationalTournamentBracket(league) else {
        Issue.record("Missing national tournament bracket")
        return
    }

    let completed = getCompletedLeagueGames(league)
    let conferenceGames = completed.filter { $0.type == "conference_tournament" }
    let nationalGames = completed.filter { $0.type == "national_tournament" }
    let summary = getLeagueSummary(league)

    #expect(bracket.teams.count == 64)
    #expect(bracket.rounds.map(\.count) == [32, 16, 8, 4, 2, 1])
    #expect(Set(bracket.teams.map(\.seedLine)) == Set(1...16))
    #expect(bracket.rounds.first?.allSatisfy { game in
        guard let top = game.topTeam, let bottom = game.bottomTeam else { return false }
        return top.seedLine + bottom.seedLine == 17
    } == true)
    #expect(bracket.teams.filter(\.automaticBid).count == summary.totalConferences)
    #expect(!conferenceGames.isEmpty)
    #expect(nationalGames.count == 63)
    #expect((nationalGames.compactMap(\.day).min() ?? 0) > (conferenceGames.compactMap(\.day).max() ?? 0))
}

@Test("Season checkpoint skip can stop at Selection Sunday or offseason")
func seasonCheckpointSkipTargets() throws {
    var selectionLeague = try createD1League(options: CreateLeagueOptions(userTeamName: "Duke", seed: "selection-sunday-skip", totalRegularSeasonGames: 1))
    LeagueStore.update(selectionLeague.handle) { state in
        state.scheduleGenerated = true
        state.schedule = []
        state.remainingRegularSeasonGames = 0
        state.conferenceTournaments = state.conferences.compactMap { conference in
            let teamIds = state.teams.filter { $0.conferenceId == conference.id }.map(\.teamId)
            guard teamIds.count >= 2, let champion = teamIds.first else { return nil }
            return LeagueStore.ConferenceTournamentState(
                conferenceId: conference.id,
                conferenceName: conference.name,
                entrantTeamIds: teamIds,
                rounds: [[.init(top: .init(seed: 1, fromRound: nil, fromGame: nil), bottom: .init(seed: 2, fromRound: nil, fromGame: nil))]],
                winnersByRound: [[champion]],
                scheduledRoundCount: 1
            )
        }
    }

    let selectionBatch = advanceToSeasonCheckpoint(&selectionLeague, checkpoint: .selectionSunday)
    let selectionCompleted = getCompletedLeagueGames(selectionLeague)
    let selectionNationalGames = selectionCompleted.filter { $0.type == "national_tournament" }

    #expect(selectionBatch.seasonCompleted == false)
    #expect(getNationalTournamentBracket(selectionLeague) != nil)
    #expect(selectionNationalGames.isEmpty)

    var offseasonLeague = try createD1League(options: CreateLeagueOptions(userTeamName: "Duke", seed: "offseason-skip", totalRegularSeasonGames: 1))
    LeagueStore.update(offseasonLeague.handle) { state in
        let teams = Array(state.teams.prefix(2))
        guard teams.count == 2 else { return }
        state.scheduleGenerated = true
        state.schedule = [
            LeagueStore.ScheduledGame(
                gameId: "nt_final_test",
                day: state.totalRegularSeasonGames + 1,
                type: "national_tournament",
                siteType: "neutral",
                neutralSite: true,
                homeTeamId: teams[0].teamId,
                homeTeamName: teams[0].teamName,
                awayTeamId: teams[1].teamId,
                awayTeamName: teams[1].teamName,
                conferenceId: nil,
                tournamentRound: 0,
                tournamentGameIndex: 0,
                completed: false,
                result: nil
            )
        ]
        state.remainingRegularSeasonGames = 0
        state.conferenceTournaments = []
        state.nationalTournament = LeagueStore.NationalTournamentState(
            entrants: teams.enumerated().map { offset, team in
                .init(teamId: team.teamId, overallSeed: offset + 1, seedLine: offset + 1, automaticBid: offset == 0)
            },
            rounds: [[.init(top: .init(overallSeed: 1, fromRound: nil, fromGame: nil), bottom: .init(overallSeed: 2, fromRound: nil, fromGame: nil))]],
            winnersByRound: [[nil]],
            scheduledRoundCount: 1
        )
    }

    let offseasonBatch = advanceToSeasonCheckpoint(&offseasonLeague, checkpoint: .offseason)
    let offseasonNationalGames = getCompletedLeagueGames(offseasonLeague).filter { $0.type == "national_tournament" }

    #expect(offseasonBatch.seasonCompleted == true)
    #expect(getLeagueSummary(offseasonLeague).status == "completed")
    #expect(offseasonNationalGames.count == 1)
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

@Test("Default CPU rotations use full roster without flattening minutes")
func defaultCPURotationUsesFullRosterWithoutFlatteningMinutes() {
    var random = SeededRandom(seed: 5150)
    var players: [Player] = []
    for idx in 0..<13 {
        var p = createPlayer()
        p.bio.name = "Rotation P\(idx + 1)"
        p.bio.position = [.pg, .sg, .sf, .pf, .c, .cg, .wing, .f, .big, .pg, .sg, .sf, .pf][idx]
        let rating = 82 - idx * 2
        p.skills.shotIQ = rating
        p.skills.ballHandling = rating
        p.skills.passingIQ = rating
        p.shooting.threePointShooting = rating
        p.shooting.midrangeShot = rating
        p.shooting.closeShot = rating
        p.defense.perimeterDefense = rating
        p.defense.postDefense = rating
        p.rebounding.defensiveRebound = rating
        p.athleticism.speed = rating
        p.athleticism.agility = rating
        players.append(p)
    }

    var options = CreateTeamOptions(name: "Rotation U", players: players)
    options.lineup = Array(players.prefix(5))
    let team = createTeam(options: options, random: &random)
    let slots = defaultRotationSlots(for: team)
    let minutes = slots.map(\.minutes)

    #expect(slots.count == players.count)
    #expect(abs(minutes.reduce(0, +) - 200) < 0.01)
    #expect(minutes.prefix(5).allSatisfy { $0 >= 25 && $0 <= 36 })
    #expect(minutes.dropFirst(5).filter { $0 > 0 }.count >= 5)
    #expect(minutes.dropFirst(5).max() ?? 0 < minutes.prefix(5).min() ?? 0)
    #expect(Set(minutes).count > 4)
}

@Test("Default rotation ranks bench rows by role minutes")
func defaultRotationRanksBenchRowsByRoleMinutes() {
    var random = SeededRandom(seed: 6161)
    var players: [Player] = []
    for idx in 0..<13 {
        var p = createPlayer()
        p.bio.name = "Role P\(idx + 1)"
        p.bio.position = [.pg, .sg, .sf, .pf, .c, .cg, .wing, .f, .big, .pg, .sg, .sf, .pf][idx]
        let rating: Int
        switch idx {
        case 5: rating = 50
        case 6: rating = 78
        default: rating = 82 - idx
        }
        p.skills.shotIQ = rating
        p.skills.ballHandling = rating
        p.skills.passingIQ = rating
        p.shooting.threePointShooting = rating
        p.shooting.midrangeShot = rating
        p.shooting.closeShot = rating
        p.defense.perimeterDefense = rating
        p.defense.postDefense = rating
        p.rebounding.defensiveRebound = rating
        p.athleticism.speed = rating
        p.athleticism.agility = rating
        players.append(p)
    }

    var options = CreateTeamOptions(name: "Role U", players: players)
    options.lineup = Array(players.prefix(5))
    let team = createTeam(options: options, random: &random)
    let slots = defaultRotationSlots(for: team)

    #expect(slots.count == players.count)
    #expect(slots[5].playerIndex == 6)
    #expect(slots[5].minutes > slots.first(where: { $0.playerIndex == 5 })?.minutes ?? 0)
    #expect(slots.dropFirst(5).map(\.minutes) == slots.dropFirst(5).map(\.minutes).sorted(by: >))
}

@Test("Saved rotation order breaks substitution ranking ties")
func savedRotationOrderBreaksSubstitutionRankingTies() {
    var random = SeededRandom(seed: 7171)
    var players: [Player] = []
    for idx in 0..<7 {
        var p = createPlayer()
        p.bio.name = "Tie P\(idx + 1)"
        p.bio.position = [.pg, .sg, .sf, .pf, .c, .cg, .wing][idx]
        players.append(p)
    }

    var options = CreateTeamOptions(name: "Tie U", players: players)
    options.lineup = Array(players.prefix(5))
    options.rotation = TeamRotation(
        minuteTargets: Dictionary(uniqueKeysWithValues: players.map { ($0.bio.name, 10.0) }),
        slotPlayerNames: ["Tie P7", "Tie P6", "Tie P1", "Tie P2", "Tie P3", "Tie P4", "Tie P5"]
    )
    let team = createTeam(options: options, random: &random)
    let boxPlayers = players.map { player in
        PlayerBoxScore(
            playerName: player.bio.name,
            position: player.bio.position.rawValue,
            minutes: 0,
            points: 0,
            fgMade: 0,
            fgAttempts: 0,
            threeMade: 0,
            threeAttempts: 0,
            ftMade: 0,
            ftAttempts: 0,
            rebounds: 0,
            offensiveRebounds: 0,
            defensiveRebounds: 0,
            assists: 0,
            steals: 0,
            blocks: 0,
            turnovers: 0,
            fouls: 0,
            plusMinus: 0,
            energy: 100
        )
    }
    let tracker = NativeGameStateStore.TeamTracker(
        team: team,
        score: 0,
        activeLineup: Array(players.prefix(5)),
        activeLineupBoxIndices: Array(0..<5),
        boxPlayers: boxPlayers,
        teamExtras: [:],
        gameForm: 0,
        reboundFocusBoxIndex: nil,
        reboundFocusBoost: 0,
        targetMinutesByRosterIndex: Array(repeating: 10, count: players.count),
        baseSkillByRosterIndex: Array(repeating: 70, count: players.count),
        initiatedActionCount: 0,
        initiatedActionCountByBoxIndex: [:]
    )

    let rankedBench = rankSubCandidates(tracker: tracker, blowoutMode: .none)
        .filter { !tracker.activeLineupBoxIndices.contains($0.rosterIndex) }

    #expect(rankedBench.map(\.rosterIndex).prefix(2) == [6, 5])
}

@Test("Simulation fallback minute targets give CPU bench real roles")
func simulationFallbackMinuteTargetsGiveCPUBenchRealRoles() {
    var random = SeededRandom(seed: 6262)
    var players: [Player] = []
    for idx in 0..<12 {
        var p = createPlayer()
        p.bio.name = "CPU P\(idx + 1)"
        p.bio.position = [.pg, .sg, .sf, .pf, .c, .cg, .wing, .f, .big, .pg, .sg, .sf][idx]
        let rating = 80 - idx
        p.skills.shotIQ = rating
        p.shooting.threePointShooting = rating
        p.shooting.midrangeShot = rating
        p.shooting.closeShot = rating
        p.skills.ballHandling = rating
        p.defense.perimeterDefense = rating
        p.defense.shotContest = rating
        p.rebounding.defensiveRebound = rating
        players.append(p)
    }

    var options = CreateTeamOptions(name: "CPU Rotation", players: players)
    options.lineup = Array(players.prefix(5))
    let team = createTeam(options: options, random: &random)
    let targets = computeTargetMinutesByRosterIndex(team: team, roster: team.players)

    #expect(abs(targets.reduce(0, +) - 200) < 0.01)
    #expect(targets.prefix(5).allSatisfy { $0 < 40 && $0 >= 25 })
    #expect(targets.dropFirst(5).reduce(0, +) >= 40)
    #expect(targets.dropFirst(5).filter { $0 > 0 }.count >= 5)
}

@Test("Saved user rotation order survives reopening")
func savedUserRotationOrderSurvivesReopening() throws {
    var league = try createD1League(options: CreateLeagueOptions(userTeamName: "Duke", seed: "saved-rotation-order", totalRegularSeasonGames: 1))
    let original = getUserRotation(league)
    #expect(original.count >= 7)

    var edited = original.enumerated().map { index, slot in
        UserRotationSlot(slot: index + 1, playerIndex: slot.playerIndex, position: slot.position, minutes: slot.minutes)
    }
    let firstPlayer = edited[0].playerIndex
    edited[0].playerIndex = edited[6].playerIndex
    edited[6].playerIndex = firstPlayer
    edited[0].minutes = 12
    edited[6].minutes = 30

    let saved = setUserRotation(&league, slots: edited)
    let reopened = getUserRotation(league)

    #expect(saved.prefix(edited.count).map(\.playerIndex) == edited.map(\.playerIndex))
    #expect(reopened.map(\.playerIndex) == saved.map(\.playerIndex))
    #expect(reopened[0].minutes == 12)
    #expect(reopened[6].minutes == 30)
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

@Test("NIL budgets apply revenue sharing tiers and service academy exception")
func nilBudgetRevenueSharingRules() throws {
    let uconn = try createD1League(options: CreateLeagueOptions(userTeamName: "UConn", seed: "nil-uconn"))
    let uconnBudget = try #require(getNILBudgetSummary(uconn).userTeam)
    #expect(uconnBudget.revenueSharing == 8_000_000)
    #expect(uconnBudget.total >= uconnBudget.revenueSharing)

    let duke = try createD1League(options: CreateLeagueOptions(userTeamName: "Duke", seed: "nil-duke"))
    let dukeBudget = try #require(getNILBudgetSummary(duke).userTeam)
    #expect(dukeBudget.revenueSharing == 6_000_000)

    let alabama = try createD1League(options: CreateLeagueOptions(userTeamName: "Alabama", seed: "nil-alabama"))
    let alabamaBudget = try #require(getNILBudgetSummary(alabama).userTeam)
    #expect(alabamaBudget.revenueSharing == 3_000_000)

    let airForce = try createD1League(options: CreateLeagueOptions(userTeamName: "Air Force", seed: "nil-air-force"))
    let airForceBudget = try #require(getNILBudgetSummary(airForce).userTeam)
    #expect(airForceBudget.serviceAcademy)
    #expect(airForceBudget.revenueSharing == 0)
    #expect(airForceBudget.donations == 0)
    #expect(airForceBudget.total == 0)
}

@Test("NIL donations are strongly shaped by school prestige")
func nilDonationsFavorPrestige() throws {
    let league = try createD1League(options: CreateLeagueOptions(userTeamName: "Duke", seed: "nil-prestige-factor"))

    let serviceAcademies = Set(["Air Force", "Army", "Navy"])
    let selectedIndexes = LeagueStore.update(league.handle) { state -> [Int] in
        let candidates = state.teams.indices.filter { !serviceAcademies.contains(state.teams[$0].teamName) }
        let highPrestigeIndex = candidates[0]
        let lowPrestigeIndex = candidates[1]

        for index in [highPrestigeIndex, lowPrestigeIndex] {
            state.teams[index].wins = 18
            state.teams[index].losses = 16
            state.teams[index].conferenceWins = 9
            state.teams[index].conferenceLosses = 9
            state.teams[index].teamModel.coachingStaff.headCoach.skills.fundraising = 50
        }

        state.teams[highPrestigeIndex].prestige = 0.95
        state.teams[lowPrestigeIndex].prestige = 0.25
        return [highPrestigeIndex, lowPrestigeIndex]
    }

    let indexes = try #require(selectedIndexes)
    let state = try #require(LeagueStore.get(league.handle))
    let highPrestigeTeamId = state.teams[indexes[0]].teamId
    let lowPrestigeTeamId = state.teams[indexes[1]].teamId

    let summary = getNILBudgetSummary(league)
    let highPrestigeBudget = try #require(summary.teams.first { $0.teamId == highPrestigeTeamId })
    let lowPrestigeBudget = try #require(summary.teams.first { $0.teamId == lowPrestigeTeamId })

    #expect(highPrestigeBudget.donations >= lowPrestigeBudget.donations * 2.5)
}

@Test("Players leaving phase includes graduates and personality-weighted transfers")
func playersLeavingPhaseIncludesGraduatesAndTransfers() throws {
    let league = try createD1League(options: CreateLeagueOptions(userTeamName: "UConn", seed: "leaving-phase", totalRegularSeasonGames: 1))

    _ = LeagueStore.update(league.handle) { state in
        guard let userIndex = state.teams.firstIndex(where: { $0.teamId == state.userTeamId }) else { return }
        state.playersLeaving = nil
        state.status = "completed"
        state.offseasonStage = .playersLeaving
        state.teams[userIndex].wins = 1

        for idx in state.teams[userIndex].teamModel.players.indices {
            state.teams[userIndex].teamModel.players[idx].bio.year = idx == 0 ? .sr : .so
            state.teams[userIndex].teamModel.players[idx].bio.redshirtUsed = idx == 0
            state.teams[userIndex].teamModel.players[idx].bio.potential = 96
            state.teams[userIndex].teamModel.players[idx].bio.nilDollarsLastYear = idx >= 5 ? 500_000 : 0
            state.teams[userIndex].teamModel.players[idx].greed = idx >= 5 ? 96 : 50
            state.teams[userIndex].teamModel.players[idx].loyalty = idx >= 5 ? 4 : 50
            makePlayerElite(&state.teams[userIndex].teamModel.players[idx])
        }

        let userTeam = state.teams[userIndex]
        let opponent = state.teams.first { $0.teamId != userTeam.teamId } ?? userTeam
        let boxPlayers = userTeam.teamModel.players.enumerated().map { idx, player in
            PlayerBoxScore(
                playerName: player.bio.name,
                position: player.bio.position.rawValue,
                minutes: idx < 5 ? 40 : 0,
                points: idx < 5 ? 10 : 0,
                fgMade: 0,
                fgAttempts: 0,
                threeMade: 0,
                threeAttempts: 0,
                ftMade: 0,
                ftAttempts: 0,
                rebounds: 0,
                offensiveRebounds: 0,
                defensiveRebounds: 0,
                assists: 0,
                steals: 0,
                blocks: 0,
                turnovers: 0,
                fouls: 0,
                plusMinus: nil,
                energy: nil
            )
        }
        let opponentBox = opponent.teamModel.players.prefix(5).map { player in
            PlayerBoxScore(
                playerName: player.bio.name,
                position: player.bio.position.rawValue,
                minutes: 40,
                points: 0,
                fgMade: 0,
                fgAttempts: 0,
                threeMade: 0,
                threeAttempts: 0,
                ftMade: 0,
                ftAttempts: 0,
                rebounds: 0,
                offensiveRebounds: 0,
                defensiveRebounds: 0,
                assists: 0,
                steals: 0,
                blocks: 0,
                turnovers: 0,
                fouls: 0,
                plusMinus: nil,
                energy: nil
            )
        }

        if state.schedule.isEmpty {
            state.schedule.append(
                LeagueStore.ScheduledGame(
                    gameId: "leaving-test",
                    day: 1,
                    type: "regular_season",
                    siteType: "home",
                    neutralSite: false,
                    homeTeamId: userTeam.teamId,
                    homeTeamName: userTeam.teamName,
                    awayTeamId: opponent.teamId,
                    awayTeamName: opponent.teamName,
                    conferenceId: nil,
                    tournamentRound: nil,
                    tournamentGameIndex: nil,
                    completed: false,
                    result: nil
                )
            )
        }
        state.schedule[0].completed = true
        state.schedule[0].homeTeamId = userTeam.teamId
        state.schedule[0].homeTeamName = userTeam.teamName
        state.schedule[0].awayTeamId = opponent.teamId
        state.schedule[0].awayTeamName = opponent.teamName
        state.schedule[0].result = LeagueStore.GameResult(
            homeScore: 80,
            awayScore: 60,
            winnerTeamId: userTeam.teamId,
            wentToOvertime: false,
            boxScore: [
                TeamBoxScore(name: userTeam.teamName, players: boxPlayers, teamExtras: nil),
                TeamBoxScore(name: opponent.teamName, players: opponentBox, teamExtras: nil),
            ]
        )
    }

    let summary = getPlayersLeavingSummary(league)
    let userRows = summary.userEntries
    #expect(userRows.contains { $0.outcome == .graduated })
    #expect(userRows.contains { $0.outcome == .transfer })
    #expect(userRows.filter { $0.outcome == .transfer }.allSatisfy { $0.greed > $0.loyalty })
}

@Test("Draft selects up to 60 entrants and annotates player cards")
func draftSelectsTopEntrantsAndAnnotatesPlayers() throws {
    let league = try createD1League(options: CreateLeagueOptions(userTeamName: "UConn", seed: "draft-phase", totalRegularSeasonGames: 1))

    _ = LeagueStore.update(league.handle) { state in
        state.status = "completed"
        state.offseasonStage = .draft
        state.playersLeaving = nil
        state.draftPicks = nil
        state.schoolHallOfFame = nil
        for teamIdx in state.teams.indices {
            state.teams[teamIdx].wins = 1
            for idx in state.teams[teamIdx].teamModel.players.indices {
                if idx < 3 {
                    state.teams[teamIdx].teamModel.players[idx].bio.year = .sr
                    state.teams[teamIdx].teamModel.players[idx].bio.redshirtUsed = true
                    state.teams[teamIdx].teamModel.players[idx].bio.potential = 88 + (idx % 3)
                } else {
                    state.teams[teamIdx].teamModel.players[idx].bio.year = .so
                }
            }
        }
    }

    let draft = getDraftSummary(league)
    #expect(draft.picks.count == 60)
    #expect(draft.picks.map(\.slot) == Array(1...60))
    #expect(draft.picks.allSatisfy { $0.player.draftSlot == $0.slot })
}

@Test("Draft production does not overvalue point guard assist volume")
func draftProductionDoesNotOvervaluePointGuardAssistVolume() throws {
    let league = try createD1League(options: CreateLeagueOptions(userTeamName: "UConn", seed: "draft-position-balance", totalRegularSeasonGames: 1))

    _ = LeagueStore.update(league.handle) { state in
        guard let userIndex = state.teams.firstIndex(where: { $0.teamId == state.userTeamId }) else { return }
        let userTeam = state.teams[userIndex]
        let opponent = state.teams.first { $0.teamId != userTeam.teamId } ?? userTeam

        let guardSummary = UserRosterPlayerSummary(
            playerIndex: 0,
            name: "Assist Lead",
            position: "PG",
            year: "SR",
            home: nil,
            height: "6-2",
            weight: nil,
            wingspan: "6-5",
            overall: 84,
            isStarter: true,
            attributes: ["potential": 88]
        )
        let centerSummary = UserRosterPlayerSummary(
            playerIndex: 1,
            name: "Interior Anchor",
            position: "C",
            year: "SR",
            home: nil,
            height: "7-0",
            weight: nil,
            wingspan: "7-4",
            overall: 84,
            isStarter: true,
            attributes: ["potential": 88]
        )

        state.status = "completed"
        state.offseasonStage = .draft
        state.playersLeaving = [
            PlayerLeavingEntry(
                id: "\(userTeam.teamId):0:Assist Lead:Draft",
                teamId: userTeam.teamId,
                teamName: userTeam.teamName,
                player: guardSummary,
                playerName: guardSummary.name,
                position: guardSummary.position,
                year: guardSummary.year,
                overall: guardSummary.overall,
                potential: 88,
                outcome: .draft,
                reason: "Test prospect.",
                minutesShare: 0.2,
                expectedMinutesShare: 0.2,
                transferRisk: 0,
                loyalty: 50,
                greed: 50,
                nilDollarsLastYear: 0
            ),
            PlayerLeavingEntry(
                id: "\(userTeam.teamId):1:Interior Anchor:Draft",
                teamId: userTeam.teamId,
                teamName: userTeam.teamName,
                player: centerSummary,
                playerName: centerSummary.name,
                position: centerSummary.position,
                year: centerSummary.year,
                overall: centerSummary.overall,
                potential: 88,
                outcome: .draft,
                reason: "Test prospect.",
                minutesShare: 0.2,
                expectedMinutesShare: 0.2,
                transferRisk: 0,
                loyalty: 50,
                greed: 50,
                nilDollarsLastYear: 0
            ),
        ]
        state.draftPicks = nil
        state.schedule = [
            LeagueStore.ScheduledGame(
                gameId: "draft-balance-game",
                day: 1,
                type: "regular_season",
                siteType: "home",
                neutralSite: false,
                homeTeamId: userTeam.teamId,
                homeTeamName: userTeam.teamName,
                awayTeamId: opponent.teamId,
                awayTeamName: opponent.teamName,
                conferenceId: nil,
                tournamentRound: nil,
                tournamentGameIndex: nil,
                completed: true,
                result: LeagueStore.GameResult(
                    homeScore: 80,
                    awayScore: 60,
                    winnerTeamId: userTeam.teamId,
                    wentToOvertime: false,
                    boxScore: [
                        TeamBoxScore(
                            name: userTeam.teamName,
                            players: [
                                PlayerBoxScore(playerName: "Assist Lead", position: "PG", minutes: 35, points: 10, fgMade: 4, fgAttempts: 9, threeMade: 1, threeAttempts: 3, ftMade: 1, ftAttempts: 2, rebounds: 2, offensiveRebounds: 0, defensiveRebounds: 2, assists: 9, steals: 1, blocks: 0, turnovers: 2, fouls: 1, plusMinus: nil, energy: nil),
                                PlayerBoxScore(playerName: "Interior Anchor", position: "C", minutes: 35, points: 24, fgMade: 12, fgAttempts: 20, threeMade: 0, threeAttempts: 0, ftMade: 0, ftAttempts: 2, rebounds: 14, offensiveRebounds: 4, defensiveRebounds: 10, assists: 1, steals: 0, blocks: 5, turnovers: 2, fouls: 2, plusMinus: nil, energy: nil),
                            ],
                            teamExtras: nil
                        ),
                        TeamBoxScore(name: opponent.teamName, players: [], teamExtras: nil),
                    ]
                )
            ),
        ]
    }

    let draft = getDraftSummary(league)
    let guardPick = try #require(draft.picks.first { $0.player.name == "Assist Lead" })
    let centerPick = try #require(draft.picks.first { $0.player.name == "Interior Anchor" })
    #expect(centerPick.draftScore > guardPick.draftScore)
}

@Test("Elite underclass draft prospects enter during players leaving")
func eliteUnderclassDraftProspectsEnterDuringPlayersLeaving() throws {
    let league = try createD1League(options: CreateLeagueOptions(userTeamName: "UConn", seed: "early-draft", totalRegularSeasonGames: 1))

    _ = LeagueStore.update(league.handle) { state in
        state.status = "completed"
        state.offseasonStage = .playersLeaving
        state.playersLeaving = nil
        for teamIdx in state.teams.indices {
            for idx in state.teams[teamIdx].teamModel.players.indices {
                state.teams[teamIdx].teamModel.players[idx].bio.year = .so
                state.teams[teamIdx].teamModel.players[idx].bio.potential = 45
                makePlayerReplacementLevel(&state.teams[teamIdx].teamModel.players[idx])
            }
        }

        guard let userIndex = state.teams.firstIndex(where: { $0.teamId == state.userTeamId }) else { return }
        for idx in 0..<min(7, state.teams[userIndex].teamModel.players.count) {
            state.teams[userIndex].teamModel.players[idx].bio.year = .fr
            state.teams[userIndex].teamModel.players[idx].bio.potential = 99
            state.teams[userIndex].teamModel.players[idx].loyalty = 0
            state.teams[userIndex].teamModel.players[idx].greed = 100
            makePlayerElite(&state.teams[userIndex].teamModel.players[idx])
        }
    }

    let draftEntrants = getPlayersLeavingSummary(league).userEntries.filter { $0.outcome == .draft }
    #expect(draftEntrants.count >= 6)
    #expect(draftEntrants.allSatisfy { $0.reason.contains("draft prospect") })
}

@Test("NIL retention generates realistic spend and portal volume")
func nilRetentionBalanceSimulation() throws {
    var portalPerTeam: [Double] = []
    var spendRates: [Double] = []
    var majorBudgets: [Double] = []
    var topAsks: [Double] = []
    var absoluteTopAsk = 0.0

    for iteration in 1...12 {
        var league = try createD1League(options: CreateLeagueOptions(
            userTeamName: ["Duke", "UConn", "Kansas", "Kentucky"][iteration % 4],
            seed: "nil-balance-\(iteration)",
            totalRegularSeasonGames: 1
        ))

        _ = LeagueStore.update(league.handle) { state in
            state.status = "completed"
            state.offseasonStage = .playerRetention
            state.playersLeaving = nil
            state.draftPicks = nil
            state.nilRetention = nil
            state.transferPortal = nil
            state.nilRetentionFinalized = false

            for teamIndex in state.teams.indices {
                let roll = deterministicTestRoll(seed: "\(state.optionsSeed):record:\(state.teams[teamIndex].teamId)")
                state.teams[teamIndex].wins = Int((12 + roll * 21).rounded())
                state.teams[teamIndex].losses = max(1, 34 - state.teams[teamIndex].wins)
                state.teams[teamIndex].conferenceWins = max(0, state.teams[teamIndex].wins - 10)
                state.teams[teamIndex].conferenceLosses = max(1, state.teams[teamIndex].losses - 4)
            }
        }

        _ = delegateNILRetentionToAssistants(&league)
        _ = advanceOffseason(&league)

        let budgets = getNILBudgetSummary(league)
        let retention = getNILRetentionSummary(league)
        let portal = getTransferPortalSummary(league)
        let nationalBudget = budgets.teams.reduce(0.0) { $0 + $1.total }
        let acceptedSpend = retention.entries.filter { $0.status == .accepted }.reduce(0.0) { $0 + $1.offer }
        let majors = budgets.teams
            .filter { ["acc", "big-ten", "big-12", "sec"].contains($0.conferenceId) || $0.total >= 5_000_000 }
            .map(\.total)

        portalPerTeam.append(Double(portal.entries.count) / Double(max(1, budgets.teams.count)))
        spendRates.append(acceptedSpend / max(1, nationalBudget))
        majorBudgets.append(average(majors))
        topAsks.append(portal.entries.map(\.askingPrice).max() ?? 0)
        absoluteTopAsk = max(absoluteTopAsk, portal.entries.map(\.askingPrice).max() ?? 0)
    }

    let avgPortalPerTeam = average(portalPerTeam)
    let avgSpendRate = average(spendRates)
    let avgMajorBudget = average(majorBudgets)
    let avgTopAsk = average(topAsks)
    print("NIL balance avg: portal/team=\(avgPortalPerTeam), retentionSpend=\(avgSpendRate), majorBudget=\(avgMajorBudget), topAsk=\(avgTopAsk), absoluteTopAsk=\(absoluteTopAsk)")

    #expect(avgPortalPerTeam >= 1.0)
    #expect(avgPortalPerTeam <= 6.5)
    #expect(avgSpendRate >= 0.20)
    #expect(avgSpendRate <= 0.95)
    #expect(avgMajorBudget >= 2_000_000)
    #expect(avgMajorBudget <= 9_000_000)
    #expect(avgTopAsk >= 2_200_000)
    #expect(avgTopAsk <= 4_600_000)
    #expect(absoluteTopAsk >= 4_000_000)
}

@Test("NIL asks fall off sharply below true superstar tier")
func nilAsksFallOffBelowSuperstarTier() throws {
    let league = try createD1League(options: CreateLeagueOptions(userTeamName: "UConn", seed: "nil-tier-curve", totalRegularSeasonGames: 1))

    _ = LeagueStore.update(league.handle) { state in
        state.status = "completed"
        state.offseasonStage = .playerRetention
        state.playersLeaving = []
        state.draftPicks = []
        state.nilRetention = nil
        state.transferPortal = nil
        state.nilRetentionFinalized = false

        guard let userIndex = state.teams.firstIndex(where: { $0.teamId == state.userTeamId }) else { return }
        var random = SeededRandom(seed: 822)

        state.teams[userIndex].teamModel.players[0].bio.name = "Good Starter"
        state.teams[userIndex].teamModel.players[0].bio.year = .so
        state.teams[userIndex].teamModel.players[0].bio.potential = 84
        state.teams[userIndex].teamModel.players[0].greed = 50
        state.teams[userIndex].teamModel.players[0].loyalty = 50
        state.teams[userIndex].teamModel.players[0].bio.nilDollarsLastYear = 0
        applyRatings(&state.teams[userIndex].teamModel.players[0], base: 82, random: &random)

        state.teams[userIndex].teamModel.players[1].bio.name = "National Superstar"
        state.teams[userIndex].teamModel.players[1].bio.year = .so
        state.teams[userIndex].teamModel.players[1].bio.potential = 99
        state.teams[userIndex].teamModel.players[1].greed = 70
        state.teams[userIndex].teamModel.players[1].loyalty = 30
        state.teams[userIndex].teamModel.players[1].bio.nilDollarsLastYear = 0
        makePlayerElite(&state.teams[userIndex].teamModel.players[1])

        state.teams[userIndex].teamModel.lineup = state.teams[userIndex].teamModel.players
    }

    let retention = getNILRetentionSummary(league)
    let goodStarter = try #require(retention.userEntries.first { $0.playerName == "Good Starter" })
    let superstar = try #require(retention.userEntries.first { $0.playerName == "National Superstar" })

    #expect(goodStarter.overall >= 78)
    #expect(goodStarter.overall < 88)
    #expect(goodStarter.demand >= 350_000)
    #expect(goodStarter.demand <= 1_250_000)
    #expect(superstar.overall >= 94)
    #expect(superstar.demand >= 2_000_000)
    #expect(superstar.demand >= goodStarter.demand * 2.4)
}

@Test("Walk-on level players have zero NIL value and asks")
func walkOnLevelPlayersHaveZeroNILValueAndAsks() throws {
    let league = try createD1League(options: CreateLeagueOptions(userTeamName: "UConn", seed: "walkon-nil", totalRegularSeasonGames: 1))

    _ = LeagueStore.update(league.handle) { state in
        state.status = "completed"
        state.offseasonStage = .playerRetention
        state.playersLeaving = []
        state.draftPicks = []
        state.nilRetention = nil
        state.transferPortal = nil
        state.nilRetentionFinalized = false

        guard let userIndex = state.teams.firstIndex(where: { $0.teamId == state.userTeamId }) else { return }
        state.teams[userIndex].teamModel.players[0].bio.name = "Walk On Guard"
        state.teams[userIndex].teamModel.players[0].bio.year = .so
        state.teams[userIndex].teamModel.players[0].bio.potential = 45
        state.teams[userIndex].teamModel.players[0].bio.nilDollarsLastYear = 0
        state.teams[userIndex].teamModel.players[0].greed = 100
        state.teams[userIndex].teamModel.players[0].loyalty = 0
        makePlayerReplacementLevel(&state.teams[userIndex].teamModel.players[0])
        state.teams[userIndex].teamModel.lineup = state.teams[userIndex].teamModel.players
    }

    let retention = getNILRetentionSummary(league)
    let row = try #require(retention.userEntries.first { $0.playerName == "Walk On Guard" })
    #expect(row.overall <= 50)
    #expect(row.intrinsicValue == 0)
    #expect(row.demand == 0)
    #expect(row.offer == 0)

    _ = LeagueStore.update(league.handle) { state in
        state.offseasonStage = .transferPortal
        state.nilRetentionFinalized = false
    }

    let portalEntry = try #require(getTransferPortalSummary(league).entries.first { $0.playerName == "Walk On Guard" })
    #expect(portalEntry.intrinsicValue == 0)
    #expect(portalEntry.askingPrice == 0)
}

@Test("Manual NIL retention offers at or above ask accept like meet ask")
func manualNILRetentionOfferAtOrAboveAskAcceptsLikeMeetAsk() throws {
    var league = try createD1League(options: CreateLeagueOptions(userTeamName: "UConn", seed: "nil-manual-meet-ask", totalRegularSeasonGames: 1))

    _ = LeagueStore.update(league.handle) { state in
        state.status = "completed"
        state.offseasonStage = .playerRetention
        state.playersLeaving = []
        state.draftPicks = []
        state.transferPortal = nil
        state.nilRetentionFinalized = false

        guard let userIndex = state.teams.firstIndex(where: { $0.teamId == state.userTeamId }) else { return }
        state.teams[userIndex].teamModel.players[0].bio.name = "Exact Ask Guard"
        state.teams[userIndex].teamModel.players[0].bio.nilDollarsLastYear = 0
        state.teams[userIndex].teamModel.players[1].bio.name = "Above Ask Wing"
        state.teams[userIndex].teamModel.players[1].bio.nilDollarsLastYear = 0

        let teamId = state.userTeamId
        let teamName = state.teams[userIndex].teamName
        state.nilRetention = [
            NILNegotiationEntry(
                id: "exact-ask",
                teamId: teamId,
                teamName: teamName,
                player: nil,
                playerIndex: 0,
                playerName: "Exact Ask Guard",
                position: "PG",
                year: "SO",
                overall: 82,
                potential: 86,
                intrinsicValue: 120_000,
                demand: 100_000,
                offer: 100_000,
                lastYearAmount: 0,
                rounds: 0,
                status: .open,
                responseText: "",
                loyalty: 0,
                greed: 100,
                returningDiscount: 0,
                priority: 1
            ),
            NILNegotiationEntry(
                id: "above-ask",
                teamId: teamId,
                teamName: teamName,
                player: nil,
                playerIndex: 1,
                playerName: "Above Ask Wing",
                position: "SF",
                year: "JR",
                overall: 83,
                potential: 87,
                intrinsicValue: 120_000,
                demand: 100_000,
                offer: 150_000,
                lastYearAmount: 0,
                rounds: 0,
                status: .open,
                responseText: "",
                loyalty: 0,
                greed: 100,
                returningDiscount: 0,
                priority: 1
            )
        ]
    }

    let exact = try #require(submitNILRetentionOffer(&league, negotiationId: "exact-ask"))
    let above = try #require(submitNILRetentionOffer(&league, negotiationId: "above-ask"))

    #expect(exact.status == .accepted)
    #expect(exact.offer == 100_000)
    #expect(exact.responseText == "Accepted.")
    #expect(above.status == .accepted)
    #expect(above.offer == 100_000)
    #expect(above.responseText == "Accepted.")

    let state = try #require(LeagueStore.get(league.handle))
    let userTeam = try #require(state.teams.first { $0.teamId == state.userTeamId })
    #expect(userTeam.teamModel.players[0].bio.nilDollarsLastYear == 100_000)
    #expect(userTeam.teamModel.players[1].bio.nilDollarsLastYear == 100_000)
}

@Test("Manual NIL retention offers clamp to remaining budget")
func manualNILRetentionOffersClampToRemainingBudget() throws {
    var league = try createD1League(options: CreateLeagueOptions(userTeamName: "UConn", seed: "nil-offer-cap", totalRegularSeasonGames: 1))

    _ = LeagueStore.update(league.handle) { state in
        state.status = "completed"
        state.offseasonStage = .playerRetention
        state.playersLeaving = []
        state.draftPicks = []
        state.transferPortal = nil
        state.nilRetentionFinalized = false
        state.nilRetention = []
    }

    let budget = getNILRetentionSummary(league).budget
    let remaining = 50_000.0
    #expect(budget.total > remaining)

    _ = LeagueStore.update(league.handle) { state in
        guard let userIndex = state.teams.firstIndex(where: { $0.teamId == state.userTeamId }) else { return }
        let teamId = state.userTeamId
        let teamName = state.teams[userIndex].teamName
        state.nilRetention = [
            NILNegotiationEntry(
                id: "signed-budget",
                teamId: teamId,
                teamName: teamName,
                player: nil,
                playerIndex: 0,
                playerName: "Signed Budget",
                position: "PG",
                year: "SR",
                overall: 84,
                potential: 84,
                intrinsicValue: budget.total - remaining,
                demand: budget.total - remaining,
                offer: budget.total - remaining,
                lastYearAmount: 0,
                rounds: 1,
                status: .accepted,
                responseText: "Accepted.",
                loyalty: 50,
                greed: 50,
                returningDiscount: 0,
                priority: 1
            ),
            NILNegotiationEntry(
                id: "capped-offer",
                teamId: teamId,
                teamName: teamName,
                player: nil,
                playerIndex: 1,
                playerName: "Capped Offer",
                position: "SG",
                year: "JR",
                overall: 82,
                potential: 86,
                intrinsicValue: 150_000,
                demand: 150_000,
                offer: 0,
                lastYearAmount: 0,
                rounds: 0,
                status: .open,
                responseText: "",
                loyalty: 50,
                greed: 50,
                returningDiscount: 0,
                priority: 1
            )
        ]
    }

    let updated = try #require(setNILRetentionOffer(&league, negotiationId: "capped-offer", offer: 200_000))

    #expect(updated.offer == remaining)
    #expect(getNILRetentionSummary(league).entries.first { $0.id == "capped-offer" }?.offer == remaining)
}

@Test("Completing transfer portal starts next year and fills walk-ons")
func transferPortalCompletionStartsNextYearAndFillsWalkOns() throws {
    var league = try createD1League(options: CreateLeagueOptions(userTeamName: "UConn", seed: "portal-new-year", totalRegularSeasonGames: 1))

    _ = LeagueStore.update(league.handle) { state in
        state.status = "completed"
        state.offseasonStage = .transferPortal
        state.playersLeaving = nil
        state.nilRetention = []
        state.transferPortal = []
        state.nilRetentionFinalized = true
        for teamIndex in state.teams.indices {
            state.teams[teamIndex].wins = teamIndex % 2 == 0 ? 20 : 8
            state.teams[teamIndex].losses = teamIndex % 2 == 0 ? 10 : 22
            state.teams[teamIndex].teamModel.players = Array(state.teams[teamIndex].teamModel.players.prefix(4))
            state.teams[teamIndex].teamModel.lineup = state.teams[teamIndex].teamModel.players
        }
    }

    let progress = advanceOffseason(&league)
    #expect(progress?.stage == .complete)

    let state = try #require(LeagueStore.get(league.handle))
    #expect(state.status == "in_progress")
    #expect(state.currentDay == 0)
    #expect(state.scheduleGenerated)
    #expect(state.schedule.isEmpty == false)
    #expect(state.teams.allSatisfy { $0.teamModel.players.count >= 13 })
    #expect(state.teams.contains { team in
        team.teamModel.players.contains { player in
            player.bio.nilDollarsLastYear == 0 && playerOverall(player) <= 50
        }
    })
}

@Test("Transfer portal entrants commit to new schools before next season")
func transferPortalEntrantsCommitToNewSchoolsBeforeNextSeason() throws {
    var league = try createD1League(options: CreateLeagueOptions(userTeamName: "UConn", seed: "portal-commit", totalRegularSeasonGames: 1))
    var portalPlayer = createPlayer()
    portalPlayer.bio.name = "Portal Guard"
    portalPlayer.bio.position = .pg
    portalPlayer.bio.year = .so
    portalPlayer.bio.potential = 74
    var random = SeededRandom(seed: 44)
    applyRatings(&portalPlayer, base: 70, random: &random)

    _ = LeagueStore.update(league.handle) { state in
        state.status = "completed"
        state.offseasonStage = .transferPortal
        state.playersLeaving = nil
        state.nilRetention = []
        state.nilRetentionFinalized = true
        let previousTeam = state.teams[0]
        state.transferPortal = [
            TransferPortalEntry(
                id: "synthetic:portal-guard",
                previousTeamId: previousTeam.teamId,
                previousTeamName: previousTeam.teamName,
                playerModel: portalPlayer,
                playerName: portalPlayer.bio.name,
                position: portalPlayer.bio.position.rawValue,
                year: portalPlayer.bio.year.rawValue,
                overall: playerOverall(portalPlayer),
                potential: portalPlayer.bio.potential,
                askingPrice: 125_000,
                intrinsicValue: 115_000,
                reason: "Testing portal commit.",
                loyalty: 40,
                greed: 55
            )
        ]
    }

    let initialPortal = getTransferPortalSummary(league)
    #expect(initialPortal.week == 1)
    #expect(initialPortal.entries.contains { $0.playerName == "Portal Guard" })

    let firstWeek = advanceOffseason(&league)
    #expect(firstWeek?.stage == .transferPortal)
    #expect(getTransferPortalSummary(league).week == 2)

    while getOffseasonProgress(league)?.stage == .transferPortal {
        _ = advanceOffseason(&league)
    }

    let state = try #require(LeagueStore.get(league.handle))
    let destination = try #require(state.teams.first { team in
        team.teamId != state.teams[0].teamId && team.teamModel.players.contains { $0.bio.name == "Portal Guard" }
    })
    let committed = try #require(destination.teamModel.players.first { $0.bio.name == "Portal Guard" })
    #expect(committed.bio.year == .jr)
    let committedNIL = committed.bio.nilDollarsLastYear ?? 0
    #expect(committedNIL > 0)
    #expect(committedNIL <= 125_000 * 1.10)
}

@Test("D1-sized transfer portal advances to week two")
func d1SizedTransferPortalAdvancesToWeekTwo() throws {
    var league = try createD1League(options: CreateLeagueOptions(userTeamName: "Duke", seed: "portal-week-two", totalRegularSeasonGames: 1))

    _ = LeagueStore.update(league.handle) { state in
        state.status = "completed"
        state.offseasonStage = .playerRetention
        state.playersLeaving = nil
        state.draftPicks = nil
        state.nilRetention = nil
        state.transferPortal = nil
        state.nilRetentionFinalized = false

        for teamIndex in state.teams.indices {
            let roll = deterministicTestRoll(seed: "\(state.optionsSeed):record:\(state.teams[teamIndex].teamId)")
            state.teams[teamIndex].wins = Int((12 + roll * 21).rounded())
            state.teams[teamIndex].losses = max(1, 34 - state.teams[teamIndex].wins)
            state.teams[teamIndex].conferenceWins = max(0, state.teams[teamIndex].wins - 10)
            state.teams[teamIndex].conferenceLosses = max(1, state.teams[teamIndex].losses - 4)
        }
    }

    _ = delegateNILRetentionToAssistants(&league)
    _ = advanceOffseason(&league)

    let weekOne = getTransferPortalSummary(league)
    #expect(weekOne.week == 1)
    #expect(weekOne.entries.count > 400)

    let progress = advanceOffseason(&league)
    let weekTwo = getTransferPortalSummary(league)

    #expect(progress?.stage == .transferPortal)
    #expect(weekTwo.week == 2)
}

private func makePlayerElite(_ player: inout Player) {
    player.skills.shotIQ = 95
    player.skills.ballHandling = 95
    player.skills.passingIQ = 95
    player.shooting.threePointShooting = 95
    player.shooting.midrangeShot = 95
    player.shooting.closeShot = 95
    player.defense.perimeterDefense = 95
    player.defense.postDefense = 95
    player.rebounding.defensiveRebound = 95
    player.athleticism.speed = 95
    player.athleticism.agility = 95
}

private func makePlayerReplacementLevel(_ player: inout Player) {
    player.skills.shotIQ = 40
    player.skills.ballHandling = 40
    player.skills.passingIQ = 40
    player.shooting.threePointShooting = 40
    player.shooting.midrangeShot = 40
    player.shooting.closeShot = 40
    player.defense.perimeterDefense = 40
    player.defense.postDefense = 40
    player.rebounding.defensiveRebound = 40
    player.athleticism.speed = 40
    player.athleticism.agility = 40
}

private func deterministicTestRoll(seed: String) -> Double {
    var random = SeededRandom(seed: hashString(seed))
    return random.nextUnit()
}

private func average(_ values: [Double]) -> Double {
    guard !values.isEmpty else { return 0 }
    return values.reduce(0, +) / Double(values.count)
}
