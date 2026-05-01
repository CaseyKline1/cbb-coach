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
let args = Array(CommandLine.arguments.dropFirst())

if args.contains("--nil-balance") {
    struct NILBalanceRun {
        let portalCount: Int
        let teams: Int
        let nationalBudget: Double
        let acceptedSpend: Double
        let openDemand: Double
        let userBudget: Double
        let userSpend: Double
        let userRemaining: Double
        let topPortalAsk: Double
        let majorTeamAverageBudget: Double
    }

    let teamCycle = ["Duke", "UConn", "Kansas", "Kentucky", "North Carolina", "Alabama", "Gonzaga", "Memphis"]
    var runs: [NILBalanceRun] = []
    print("CBBCoach NIL balance simulation")
    print("iterations=\(iterations) games=\(games) seed=\(seed)")

    for iteration in 1...iterations {
        let simTeam = teamCycle[(iteration - 1) % teamCycle.count]
        var league = try createD1League(options: CreateLeagueOptions(userTeamName: simTeam, seed: "\(seed)-nil-\(iteration)", totalRegularSeasonGames: games))
        _ = advanceToSeasonCheckpoint(&league, checkpoint: .offseason)

        while let progress = getOffseasonProgress(league), progress.stage != .playerRetention {
            _ = advanceOffseason(&league)
        }
        _ = delegateNILRetentionToAssistants(&league)
        _ = advanceOffseason(&league)

        let budgets = getNILBudgetSummary(league)
        let retention = getNILRetentionSummary(league)
        let portal = getTransferPortalSummary(league)
        let acceptedSpend = retention.entries.filter { $0.status == .accepted }.reduce(0.0) { $0 + $1.offer }
        let openDemand = retention.entries.reduce(0.0) { $0 + $1.demand }
        let userSpend = retention.userEntries.filter { $0.status == .accepted }.reduce(0.0) { $0 + $1.offer }
        let majorBudgets = budgets.teams
            .filter { ["acc", "big-ten", "big-12", "sec"].contains($0.conferenceId) || $0.total >= 5_000_000 }
            .map(\.total)
        let run = NILBalanceRun(
            portalCount: portal.entries.count,
            teams: budgets.teams.count,
            nationalBudget: budgets.teams.reduce(0.0) { $0 + $1.total },
            acceptedSpend: acceptedSpend,
            openDemand: openDemand,
            userBudget: retention.budget.total,
            userSpend: userSpend,
            userRemaining: retention.budget.remaining,
            topPortalAsk: portal.entries.map(\.askingPrice).max() ?? 0,
            majorTeamAverageBudget: majorBudgets.isEmpty ? 0 : majorBudgets.reduce(0, +) / Double(majorBudgets.count)
        )
        runs.append(run)
        print("run \(iteration): team=\(simTeam) portal=\(run.portalCount) portal/team=\(String(format: "%.2f", Double(run.portalCount) / Double(max(1, run.teams)))) spend=\(String(format: "%.1f", run.acceptedSpend / 1_000_000))M budget=\(String(format: "%.1f", run.nationalBudget / 1_000_000))M userLeft=\(String(format: "%.1f", run.userRemaining / 1_000_000))M topAsk=\(String(format: "%.1f", run.topPortalAsk / 1_000_000))M")
    }

    func avg(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }

    let avgPortal = avg(runs.map { Double($0.portalCount) })
    let avgTeams = avg(runs.map { Double($0.teams) })
    let avgBudget = avg(runs.map(\.nationalBudget))
    let avgSpend = avg(runs.map(\.acceptedSpend))
    let avgDemand = avg(runs.map(\.openDemand))
    let avgMajorBudget = avg(runs.map(\.majorTeamAverageBudget))
    let avgTopAsk = avg(runs.map(\.topPortalAsk))
    print("averages:")
    print("  portal players: \(String(format: "%.0f", avgPortal)) (\(String(format: "%.2f", avgPortal / max(1, avgTeams))) per team)")
    print("  national budget: \(String(format: "%.1f", avgBudget / 1_000_000))M")
    print("  accepted retention spend: \(String(format: "%.1f", avgSpend / 1_000_000))M (\(String(format: "%.0f", (avgSpend / max(1, avgBudget)) * 100))% of budget)")
    print("  total retention demand: \(String(format: "%.1f", avgDemand / 1_000_000))M")
    print("  major-team avg budget: \(String(format: "%.1f", avgMajorBudget / 1_000_000))M")
    print("  top portal ask avg: \(String(format: "%.1f", avgTopAsk / 1_000_000))M")
    exit(0)
}

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
