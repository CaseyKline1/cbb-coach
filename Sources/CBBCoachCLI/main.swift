import Foundation
import CBBCoachCore

var random = SeededRandom(seed: hashString("cbb-coach"))
var p1 = createPlayer()
p1.bio.name = "Home Guard"
p1.bio.position = .pg
p1.shooting.threePointShooting = 78

var p2 = createPlayer()
p2.bio.name = "Away Guard"
p2.bio.position = .pg
p2.shooting.threePointShooting = 74

let home = createTeam(options: CreateTeamOptions(name: "Home U", players: [p1, p1, p1, p1, p1]), random: &random)
let away = createTeam(options: CreateTeamOptions(name: "Away State", players: [p2, p2, p2, p2, p2]), random: &random)

print("Swift core initialized: \(home.name) vs \(away.name)")
