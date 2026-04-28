import Foundation
import CBBCoachCore

struct TimerBucket {
    let label: String
    let seconds: Double
}

@discardableResult
func measure<T>(_ label: String, buckets: inout [TimerBucket], _ body: () throws -> T) rethrows -> T {
    let start = DispatchTime.now().uptimeNanoseconds
    let value = try body()
    let end = DispatchTime.now().uptimeNanoseconds
    buckets.append(TimerBucket(label: label, seconds: Double(end - start) / 1_000_000_000))
    return value
}

func optionValue(_ name: String, default defaultValue: String) -> String {
    let args = Array(CommandLine.arguments.dropFirst())
    guard let index = args.firstIndex(of: name), index + 1 < args.count else { return defaultValue }
    return args[index + 1]
}

func optionInt(_ name: String, default defaultValue: Int) -> Int {
    Int(optionValue(name, default: "\(defaultValue)")) ?? defaultValue
}

let iterations = max(1, optionInt("--iterations", default: 3))
let games = max(1, optionInt("--games", default: 15))
let seed = optionValue("--seed", default: "skip-ahead-benchmark")
let teamName = optionValue("--team", default: "Duke")

var runTotals: [String: Double] = [:]
var simulatedGameCounts: [Int] = []
var simulatedCountryGameCounts: [Int] = []

print("CBBCoach skip-ahead benchmark")
print("team=\(teamName) games=\(games) iterations=\(iterations) seed=\(seed)")

for iteration in 1...iterations {
    var buckets: [TimerBucket] = []
    var league = try measure("create league", buckets: &buckets) {
        try createD1League(options: CreateLeagueOptions(userTeamName: teamName, seed: "\(seed)-\(iteration)"))
    }
    let completedLeagueGamesBeforeAdvance = getCompletedLeagueGames(league).count

    let batch = measure("advance user games", buckets: &buckets) {
        advanceUserGames(&league, maxGames: games)
    }
    simulatedGameCounts.append(batch.results.count)
    let completedLeagueGamesAfterAdvance = getCompletedLeagueGames(league).count
    let simulatedCountryGames = max(0, completedLeagueGamesAfterAdvance - completedLeagueGamesBeforeAdvance)
    simulatedCountryGameCounts.append(simulatedCountryGames)

    let tempURL = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("cbb-coach-bench-\(UUID().uuidString).json")
    let saveInfo = try measure("compact save", buckets: &buckets) {
        try saveLeagueStateForAutosave(league, destinationPath: tempURL.path)
    }
    try? FileManager.default.removeItem(at: tempURL)

    measure("refresh queries", buckets: &buckets) {
        _ = getUserRoster(league)
        _ = getUserSchedule(league)
        _ = getUserRotation(league)
        _ = getUserCoachingStaff(league)
        _ = getLeagueSummary(league)
        for option in listCareerTeamOptions() {
            _ = getConferenceStandings(league, conferenceId: option.conferenceId)
        }
        _ = getRankings(league)
        _ = getCompletedLeagueGames(league)
        _ = getTeamRosters(league)
    }

    let total = buckets.reduce(0) { $0 + $1.seconds }
    runTotals["total", default: 0] += total
    for bucket in buckets {
        runTotals[bucket.label, default: 0] += bucket.seconds
    }

    let formattedBuckets = buckets
        .map { "\($0.label)=\(String(format: "%.3f", $0.seconds))s" }
        .joined(separator: " ")
    print("run \(iteration): total=\(String(format: "%.3f", total))s userGames=\(batch.results.count) countryGames=\(simulatedCountryGames) saveBytes=\(saveInfo.bytes) \(formattedBuckets)")
}

print("averages:")
for label in ["total", "create league", "advance user games", "compact save", "refresh queries"] {
    let average = (runTotals[label] ?? 0) / Double(iterations)
    print("  \(label): \(String(format: "%.3f", average))s")
}
let avgGames = Double(simulatedGameCounts.reduce(0, +)) / Double(max(1, simulatedGameCounts.count))
let avgCountryGames = Double(simulatedCountryGameCounts.reduce(0, +)) / Double(max(1, simulatedCountryGameCounts.count))
let avgAdvance = (runTotals["advance user games"] ?? 0) / Double(iterations)
print("  simulated user games: \(String(format: "%.1f", avgGames))")
print("  simulated country games: \(String(format: "%.1f", avgCountryGames))")
print("  advance seconds/game: \(String(format: "%.3f", avgAdvance / max(1, avgGames)))s")
print("  advance seconds/country game: \(String(format: "%.4f", avgAdvance / max(1, avgCountryGames)))s")
