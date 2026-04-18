import SwiftUI
import CBBCoachCore

struct ContentView: View {
    @State private var gameSummary: String = "Tap simulate to run a game"
    @State private var leagueSummary: String = ""

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Text("CBB Coach")
                    .font(.largeTitle.bold())

                Text(gameSummary)
                    .font(.headline)

                if !leagueSummary.isEmpty {
                    Text(leagueSummary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 12) {
                    Button("Simulate Game") {
                        runGame()
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Start Duke League") {
                        runLeague()
                    }
                    .buttonStyle(.bordered)
                }

                Spacer()
            }
            .padding(20)
            .navigationTitle("Simulator")
        }
    }

    private func makeLineup(prefix: String, three: Int, mid: Int, layup: Int, random: inout SeededRandom) -> [Player] {
        (0..<5).map { i in
            var p = createPlayer()
            p.bio.name = "\(prefix) Player \(i + 1)"
            p.bio.position = [.pg, .sg, .sf, .pf, .c][i]
            p.shooting.threePointShooting = clamp(three + i - 2, min: 35, max: 99)
            p.shooting.midrangeShot = clamp(mid + i - 2, min: 35, max: 99)
            p.shooting.layups = clamp(layup + i - 2, min: 35, max: 99)
            p.skills.shotIQ = clamp(65 + i * 3, min: 35, max: 99)
            p.defense.perimeterDefense = clamp(62 + i * 2, min: 35, max: 99)
            p.defense.shotContest = clamp(60 + i * 3, min: 35, max: 99)
            return p
        }
    }

    private func runGame() {
        var random = SeededRandom(seed: hashString("ios-sim"))
        let homePlayers = makeLineup(prefix: "Home", three: 74, mid: 70, layup: 72, random: &random)
        let awayPlayers = makeLineup(prefix: "Away", three: 71, mid: 68, layup: 73, random: &random)

        let home = createTeam(options: CreateTeamOptions(name: "Home U", players: homePlayers), random: &random)
        let away = createTeam(options: CreateTeamOptions(name: "Away State", players: awayPlayers), random: &random)

        let result = simulateGame(homeTeam: home, awayTeam: away, random: &random)
        gameSummary = "\(result.away.name) \(result.away.score) - \(result.home.name) \(result.home.score)"
    }

    private func runLeague() {
        do {
            var league = try createD1League(options: CreateLeagueOptions(userTeamName: "Duke", seed: "ios-league"))
            autoFillUserNonConferenceOpponents(&league)
            generateSeasonSchedule(&league)
            _ = advanceToNextUserGame(&league)
            let summary = getLeagueSummary(league)
            leagueSummary = "\(summary.userTeamName): \(summary.totalScheduledGames) games scheduled"
        } catch {
            leagueSummary = "League error: \(error.localizedDescription)"
        }
    }
}

#Preview {
    ContentView()
}
