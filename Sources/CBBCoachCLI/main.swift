import Foundation
import CBBCoachCore

var random = SeededRandom(seed: hashString("cbb-coach"))

func makeLineup(prefix: String, three: Int, mid: Int, layup: Int, seedOffset: Int) -> [Player] {
    (0..<5).map { i in
        var p = createPlayer()
        p.bio.name = "\(prefix) Player \(i + 1)"
        p.bio.position = [.pg, .sg, .sf, .pf, .c][i]
        p.shooting.threePointShooting = clamp(three + ((i + seedOffset) % 5) - 2, min: 35, max: 99)
        p.shooting.midrangeShot = clamp(mid + ((i + seedOffset) % 5) - 2, min: 35, max: 99)
        p.shooting.layups = clamp(layup + ((i + seedOffset) % 5) - 2, min: 35, max: 99)
        p.skills.shotIQ = clamp(65 + i * 3, min: 35, max: 99)
        p.defense.perimeterDefense = clamp(62 + i * 2, min: 35, max: 99)
        p.defense.shotContest = clamp(60 + i * 3, min: 35, max: 99)
        return p
    }
}

let homePlayers = makeLineup(prefix: "Home", three: 74, mid: 70, layup: 72, seedOffset: 2)
let awayPlayers = makeLineup(prefix: "Away", three: 71, mid: 68, layup: 73, seedOffset: 5)

let home = createTeam(options: CreateTeamOptions(name: "Home U", players: homePlayers), random: &random)
let away = createTeam(options: CreateTeamOptions(name: "Away State", players: awayPlayers), random: &random)
let result = simulateGame(homeTeam: home, awayTeam: away, random: &random)

print("\(result.away.name) \(result.away.score) - \(result.home.name) \(result.home.score)")
print("Winner: \(result.winner ?? "Tie")")
print("Recent events:")
for event in result.playByPlay.suffix(10) {
    print("[H\(event.half) \(event.clockRemaining)s] \(event.type)")
}
