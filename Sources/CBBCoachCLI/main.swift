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

for team in result.boxScore ?? [] {
    let total3a = team.players.reduce(0) { $0 + $1.threeAttempts }
    let total3m = team.players.reduce(0) { $0 + $1.threeMade }
    let totalFga = team.players.reduce(0) { $0 + $1.fgAttempts }
    let totalFgm = team.players.reduce(0) { $0 + $1.fgMade }
    let tov = team.teamExtras?["turnovers"] ?? 0
    let blocks = team.players.reduce(0) { $0 + $1.blocks }
    let steals = team.players.reduce(0) { $0 + $1.steals }
    let reb = team.players.reduce(0) { $0 + $1.rebounds }
    let ast = team.players.reduce(0) { $0 + $1.assists }
    let pf = team.players.reduce(0) { $0 + $1.fouls }
    print("\(team.name): FG \(totalFgm)/\(totalFga) 3PT \(total3m)/\(total3a) AST \(ast) REB \(reb) STL \(steals) BLK \(blocks) TO \(tov) PF \(pf)")
}

print("Recent events:")
for event in result.playByPlay.suffix(10) {
    let half = event.half ?? -1
    let mark = event.clockRemaining ?? event.elapsedSecondsInHalf ?? -1
    print("[H\(half) \(mark)s] \(event.type)")
}

print("")
var league = try createD1League(options: CreateLeagueOptions(userTeamName: "Duke", seed: "cli-demo"))
autoFillUserNonConferenceOpponents(&league)
generateSeasonSchedule(&league)

if let nextGame = advanceToNextUserGame(&league) {
    print("Next completed user game: Game \(nextGame.day ?? 0) vs \(nextGame.opponentName ?? "Unknown")")
}

let summary = getLeagueSummary(league)
print("League: \(summary.userTeamName), schedule games: \(summary.totalScheduledGames)")
