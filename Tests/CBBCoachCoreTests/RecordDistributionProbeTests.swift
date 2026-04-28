import Foundation
import Testing
@testable import CBBCoachCore

@Test("Record distribution probe (manual)")
func recordDistributionProbe() throws {
    guard let seedValue = ProcessInfo.processInfo.environment["RECORD_PROBE_SEEDS"], !seedValue.isEmpty else {
        print("Set RECORD_PROBE_SEEDS=record-a,record-b to run the full-season record distribution probe.")
        return
    }

    let seeds = seedValue
        .split(separator: ",")
        .map { String($0) }

    for seed in seeds {
        var league = try createD1League(options: CreateLeagueOptions(userTeamName: "Duke", seed: seed))
        var safety = 0
        while safety < 80 {
            let batch = advanceUserGames(&league, maxGames: 5)
            safety += 1
            if batch.seasonCompleted { break }
        }

        let top = getRankings(league, topN: 25).rankings
        let losses = top.map(\.losses)
        let wins = top.map(\.wins)
        let teamsAtFiveLossesOrFewer = losses.filter { $0 <= 5 }.count
        let teamsAtEightLossesOrMore = losses.filter { $0 >= 8 }.count
        let averageLosses = Double(losses.reduce(0, +)) / Double(max(1, losses.count))
        let averageWins = Double(wins.reduce(0, +)) / Double(max(1, wins.count))
        let topRecords = top.map { "\($0.rank). \($0.teamName) \($0.record)" }.joined(separator: " | ")

        print("=== Record Distribution Probe ===")
        print("Seed: \(seed)")
        print(String(format: "Top 25 avg %.2f-%.2f | <=5 losses: %d | >=8 losses: %d", averageWins, averageLosses, teamsAtFiveLossesOrFewer, teamsAtEightLossesOrMore))
        print(topRecords)
    }

    #expect(Bool(true))
}
