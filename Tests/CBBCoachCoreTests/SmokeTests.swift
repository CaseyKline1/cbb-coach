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
