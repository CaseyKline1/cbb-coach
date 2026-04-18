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
}

@Test("Can create, schedule, and advance league state")
func leagueFlowSmoke() throws {
    var league = try createD1League(options: CreateLeagueOptions(userTeamName: "Duke", seed: "tests"))
    autoFillUserNonConferenceOpponents(&league, seed: "tests-autofill")
    generateSeasonSchedule(&league, seed: "tests-schedule")
    let before = getLeagueSummary(league)
    #expect(before.scheduleGenerated)
    #expect(before.totalScheduledGames > 0)

    let maybeGame = advanceToNextUserGame(&league, seed: "tests-advance")
    #expect(maybeGame != nil)
}
