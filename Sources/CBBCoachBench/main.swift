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
        let portalCommitted: Int
        let teams: Int
        let nationalBudget: Double
        let retentionSpend: Double
        let portalSpend: Double
        let openDemand: Double
        let userBudget: Double
        let userSpend: Double
        let userRemaining: Double
        let topPortalAsk: Double
        let majorTeamAverageBudget: Double
        let teamSpendShares: [Double]
        let pctTeamsAbove80: Double
        let pctTeamsAbove60: Double
        let pctTeamsAbove40: Double
        let pctTeamsBelow20: Double
        let medianShare: Double
        let majorMedianShare: Double
        let minorMedianShare: Double
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

        let budgets = getNILBudgetSummary(league)
        let retention = getNILRetentionSummary(league)
        var portalSnapshot: TransferPortalSummary? = nil
        var loopGuard = 0
        while loopGuard < 64 {
            let summary = getTransferPortalSummary(league)
            if !summary.entries.isEmpty {
                portalSnapshot = summary
            }
            guard let progress = getOffseasonProgress(league), progress.stage != .complete else { break }
            _ = advanceOffseason(&league)
            loopGuard += 1
        }

        let spendSummary = getTeamNILSpendSummary(league)
        let portal = portalSnapshot ?? TransferPortalSummary(userTeamId: retention.userTeamId, entries: [])
        let spendByTeam = Dictionary(
            uniqueKeysWithValues: spendSummary.teams.map { ($0.teamId, $0.totalCommitted) }
        )
        let retentionSpend = retention.entries.filter { $0.status == .accepted }.reduce(0.0) { $0 + $1.offer }
        let totalSpend = spendByTeam.values.reduce(0, +)
        let portalSpend = max(0, totalSpend - retentionSpend)
        let openDemand = retention.entries.reduce(0.0) { $0 + $1.demand }
        let userSpend = spendByTeam[retention.userTeamId] ?? 0
        let userRemaining = max(0, retention.budget.total - userSpend)
        let totalCommitted = totalSpend

        let majorConferences: Set<String> = ["acc", "big-ten", "big-12", "sec"]
        var teamShares: [Double] = []
        var majorShares: [Double] = []
        var minorShares: [Double] = []
        for team in budgets.teams where team.total > 0 {
            let spend = spendByTeam[team.teamId] ?? 0
            let share = min(2.0, spend / team.total)
            teamShares.append(share)
            if majorConferences.contains(team.conferenceId) {
                majorShares.append(share)
            } else {
                minorShares.append(share)
            }
        }

        func percent(_ shares: [Double], satisfying predicate: (Double) -> Bool) -> Double {
            guard !shares.isEmpty else { return 0 }
            let count = shares.filter(predicate).count
            return Double(count) / Double(shares.count) * 100
        }

        func median(_ shares: [Double]) -> Double {
            guard !shares.isEmpty else { return 0 }
            let sorted = shares.sorted()
            if sorted.count % 2 == 1 {
                return sorted[sorted.count / 2]
            }
            return (sorted[sorted.count / 2 - 1] + sorted[sorted.count / 2]) / 2.0
        }

        let majorBudgets = budgets.teams
            .filter { majorConferences.contains($0.conferenceId) || $0.total >= 5_000_000 }
            .map(\.total)
        let run = NILBalanceRun(
            portalCount: portal.entries.count,
            portalCommitted: portal.entries.filter { $0.committedTeamId != nil }.count,
            teams: budgets.teams.count,
            nationalBudget: budgets.teams.reduce(0.0) { $0 + $1.total },
            retentionSpend: retentionSpend,
            portalSpend: portalSpend,
            openDemand: openDemand,
            userBudget: retention.budget.total,
            userSpend: userSpend,
            userRemaining: userRemaining,
            topPortalAsk: portal.entries.map(\.askingPrice).max() ?? 0,
            majorTeamAverageBudget: majorBudgets.isEmpty ? 0 : majorBudgets.reduce(0, +) / Double(majorBudgets.count),
            teamSpendShares: teamShares,
            pctTeamsAbove80: percent(teamShares, satisfying: { $0 >= 0.80 }),
            pctTeamsAbove60: percent(teamShares, satisfying: { $0 >= 0.60 }),
            pctTeamsAbove40: percent(teamShares, satisfying: { $0 >= 0.40 }),
            pctTeamsBelow20: percent(teamShares, satisfying: { $0 < 0.20 }),
            medianShare: median(teamShares),
            majorMedianShare: median(majorShares),
            minorMedianShare: median(minorShares)
        )
        runs.append(run)
        let runTotalSpend = run.retentionSpend + run.portalSpend
        print("run \(iteration): team=\(simTeam) portal=\(run.portalCount) committed=\(run.portalCommitted) retention=\(String(format: "%.1f", run.retentionSpend / 1_000_000))M portal=\(String(format: "%.1f", run.portalSpend / 1_000_000))M spend/budget=\(String(format: "%.0f", (runTotalSpend / max(1, run.nationalBudget)) * 100))% medianShare=\(String(format: "%.0f", run.medianShare * 100))% >=80%:\(String(format: "%.0f", run.pctTeamsAbove80))% >=60%:\(String(format: "%.0f", run.pctTeamsAbove60))% <20%:\(String(format: "%.0f", run.pctTeamsBelow20))%")
        _ = totalCommitted
    }

    func avg(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }

    let avgPortal = avg(runs.map { Double($0.portalCount) })
    let avgCommitted = avg(runs.map { Double($0.portalCommitted) })
    let avgTeams = avg(runs.map { Double($0.teams) })
    let avgBudget = avg(runs.map(\.nationalBudget))
    let avgRetention = avg(runs.map(\.retentionSpend))
    let avgPortalSpend = avg(runs.map(\.portalSpend))
    let avgDemand = avg(runs.map(\.openDemand))
    let avgMajorBudget = avg(runs.map(\.majorTeamAverageBudget))
    let avgTopAsk = avg(runs.map(\.topPortalAsk))
    let avgAbove80 = avg(runs.map(\.pctTeamsAbove80))
    let avgAbove60 = avg(runs.map(\.pctTeamsAbove60))
    let avgAbove40 = avg(runs.map(\.pctTeamsAbove40))
    let avgBelow20 = avg(runs.map(\.pctTeamsBelow20))
    let avgMedianShare = avg(runs.map(\.medianShare))
    let avgMajorMedian = avg(runs.map(\.majorMedianShare))
    let avgMinorMedian = avg(runs.map(\.minorMedianShare))
    let avgTotalSpend = avgRetention + avgPortalSpend
    print("averages:")
    print("  portal players: \(String(format: "%.0f", avgPortal)) (\(String(format: "%.2f", avgPortal / max(1, avgTeams))) per team), committed: \(String(format: "%.0f", avgCommitted))")
    print("  national budget: \(String(format: "%.1f", avgBudget / 1_000_000))M")
    print("  retention spend: \(String(format: "%.1f", avgRetention / 1_000_000))M (\(String(format: "%.0f", (avgRetention / max(1, avgBudget)) * 100))% of budget)")
    print("  portal commit spend: \(String(format: "%.1f", avgPortalSpend / 1_000_000))M (\(String(format: "%.0f", (avgPortalSpend / max(1, avgBudget)) * 100))% of budget)")
    print("  combined NIL spend: \(String(format: "%.1f", avgTotalSpend / 1_000_000))M (\(String(format: "%.0f", (avgTotalSpend / max(1, avgBudget)) * 100))% of budget)")
    print("  total retention demand: \(String(format: "%.1f", avgDemand / 1_000_000))M")
    print("  major-team avg budget: \(String(format: "%.1f", avgMajorBudget / 1_000_000))M")
    print("  top portal ask avg: \(String(format: "%.1f", avgTopAsk / 1_000_000))M")
    print("per-team NIL utilization (share of budget actually spent):")
    print("  median share: \(String(format: "%.0f", avgMedianShare * 100))% (majors \(String(format: "%.0f", avgMajorMedian * 100))%, mid/lows \(String(format: "%.0f", avgMinorMedian * 100))%)")
    print("  teams >=80%: \(String(format: "%.0f", avgAbove80))%  >=60%: \(String(format: "%.0f", avgAbove60))%  >=40%: \(String(format: "%.0f", avgAbove40))%  <20%: \(String(format: "%.0f", avgBelow20))%")
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
