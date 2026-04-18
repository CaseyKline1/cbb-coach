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
