import Foundation

func computeTargetMinutesByRosterIndex(team: Team, roster: [Player]) -> [Double] {
    guard !roster.isEmpty else { return [] }
    let totalTeamMinutes: Double = 200

    if let namedTargets = team.rotation?.minuteTargets {
        var raw = Array(repeating: 0.0, count: roster.count)
        var hasNamedTarget = false
        for (idx, player) in roster.enumerated() {
            if let value = namedTargets[player.bio.name], value.isFinite, value >= 0 {
                raw[idx] = value
                hasNamedTarget = true
            }
        }
        if hasNamedTarget {
            let sum = raw.reduce(0, +)
            guard sum > 0 else { return raw.map { _ in 0 } }
            let scale = totalTeamMinutes / sum
            return raw.map { clamp($0 * scale, min: 0, max: 40) }
        }
    }

    // Default CPU-style pattern: 10-man rotation (5 starters ~40, 5 backups ~0).
    // If roster size differs, preserve this shape and scale to 200 team minutes.
    let listedStarters = Array((team.lineup.isEmpty ? roster : team.lineup).prefix(5))
    var used: Set<Int> = []
    var starterIndices: [Int] = []
    for starter in listedStarters {
        if let idx = roster.enumerated().first(where: { pair in
            !used.contains(pair.offset)
                && pair.element.bio.name == starter.bio.name
                && pair.element.bio.position == starter.bio.position
        })?.offset {
            starterIndices.append(idx)
            used.insert(idx)
        }
    }
    if starterIndices.count < 5 {
        for idx in roster.indices where !used.contains(idx) {
            starterIndices.append(idx)
            used.insert(idx)
            if starterIndices.count == 5 { break }
        }
    }

    let benchIndices = roster.indices.filter { !used.contains($0) }.prefix(5)
    var rawTargets = Array(repeating: 0.0, count: roster.count)
    for idx in starterIndices { rawTargets[idx] = 40 }
    for idx in benchIndices { rawTargets[idx] = 0 }

    let rawTotal = rawTargets.reduce(0, +)
    guard rawTotal > 0 else { return rawTargets }

    let scale = totalTeamMinutes / rawTotal
    return rawTargets.map { clamp($0 * scale, min: 0, max: 40) }
}

func computeTargetMinutesMap(tracker: NativeGameStateStore.TeamTracker) -> [Int: Double] {
    Dictionary(uniqueKeysWithValues: tracker.targetMinutesByRosterIndex.enumerated().map { ($0.offset, $0.element) })
}

func rankSubCandidates(tracker: NativeGameStateStore.TeamTracker, blowoutMode: BlowoutRotationMode) -> [SubCandidate] {
    let roster = tracker.team.players
    return roster.indices.map { idx in
        let box = idx < tracker.boxPlayers.count ? tracker.boxPlayers[idx] : PlayerBoxScore(playerName: "", position: "", minutes: 0, points: 0, fgMade: 0, fgAttempts: 0, threeMade: 0, threeAttempts: 0, ftMade: 0, ftAttempts: 0, rebounds: 0, offensiveRebounds: 0, defensiveRebounds: 0, assists: 0, steals: 0, blocks: 0, turnovers: 0, fouls: 0, plusMinus: 0, energy: 100)
        let energy = box.energy ?? 100
        let skill = idx < tracker.baseSkillByRosterIndex.count ? tracker.baseSkillByRosterIndex[idx] : playerOverallSkill(roster[idx])
        let minutesPlayed = box.minutes
        let target = idx < tracker.targetMinutesByRosterIndex.count ? tracker.targetMinutesByRosterIndex[idx] : 0
        let rotationNeed = clamp(target - minutesPlayed, min: -12, max: 20)
        var score = skill * 0.62 + energy * 0.3 + rotationNeed * 1.9
        if blowoutMode != .none {
            // In blowouts, rest high-target rotation players and surface deeper bench options.
            let deepBenchBias = clamp(20 - target, min: 0, max: 20)
            score += deepBenchBias * (blowoutMode == .deepBench ? 2.2 : 1.2)
            score += clamp(72 - skill, min: 0, max: 28) * (blowoutMode == .deepBench ? 0.35 : 0.18)
            if minutesPlayed > target {
                score -= (minutesPlayed - target) * (blowoutMode == .deepBench ? 2.0 : 1.0)
            }
        }
        let fouledOut = box.fouls >= 5
        if fouledOut { score = -1e9 }
        return SubCandidate(
            rosterIndex: idx,
            score: score,
            energy: energy,
            minutesPlayed: minutesPlayed,
            target: target,
            rotationNeed: rotationNeed,
            fouls: box.fouls,
            fouledOut: fouledOut
        )
    }.sorted { $0.score > $1.score }
}

func isInFoulTrouble(stored: NativeGameStateStore.StoredState, fouls: Int) -> Bool {
    // Early-/mid-game: bench at 4. Final 5 minutes: allow 4 fouls on the floor.
    let inClutchWindow = stored.currentHalf >= 2 && stored.gameClockRemaining <= 300
    if fouls >= 5 { return true }
    if fouls >= 4 && !inClutchWindow { return true }
    return false
}

func runAutoSubstitutions(stored: inout NativeGameStateStore.StoredState, teamId: Int, random: inout SeededRandom) {
    guard teamId >= 0, teamId < stored.teams.count else { return }
    guard stored.teams[teamId].activeLineup.count == 5 else { return }
    let rosterCount = stored.teams[teamId].team.players.count
    guard rosterCount > 5 else { return }

    let elapsed = elapsedGameSecondsTotal(stored: stored)
    if elapsed - stored.lastSubElapsedGameSeconds[teamId] < 25 {
        return
    }

    let blowoutMode = blowoutRotationMode(stored: stored, teamId: teamId)
    let tracker = stored.teams[teamId]
    let ranked = rankSubCandidates(tracker: tracker, blowoutMode: blowoutMode)
    var current = tracker.activeLineupBoxIndices

    var swaps = 0
    let maxSwaps: Int
    switch blowoutMode {
    case .none: maxSwaps = 2
    case .bench: maxSwaps = 3
    case .deepBench: maxSwaps = 5
    }
    var bench = ranked.filter { !current.contains($0.rosterIndex) }
    let scoreByRoster: [Int: SubCandidate] = Dictionary(uniqueKeysWithValues: ranked.map { ($0.rosterIndex, $0) })

    // Force-sub fouled-out or foul-trouble players first.
    for slot in current.indices {
        let rosterIdx = current[slot]
        guard let info = scoreByRoster[rosterIdx] else { continue }
        let mustBench = info.fouledOut || isInFoulTrouble(stored: stored, fouls: info.fouls)
        guard mustBench else { continue }
        guard let replacement = bench.first(where: { !$0.fouledOut && !isInFoulTrouble(stored: stored, fouls: $0.fouls) }) else { continue }
        current[slot] = replacement.rosterIndex
        swaps += 1
        bench = ranked.filter { !current.contains($0.rosterIndex) }
    }

    while swaps < maxSwaps {
        guard !bench.isEmpty else { break }
        let onCourt = current.enumerated().compactMap { (slot, idx) -> (slot: Int, info: SubCandidate)? in
            guard let info = scoreByRoster[idx] else { return nil }
            return (slot, info)
        }.sorted { $0.info.score < $1.info.score }
        guard let weakest = onCourt.first, let best = bench.first else { break }

        let betterBy = best.score - weakest.info.score
        let fatigueUpgrade = weakest.info.energy < 42 && best.energy > weakest.info.energy + 8
        let rotationUpgrade = best.rotationNeed > 2.5 && (weakest.info.minutesPlayed - weakest.info.target > 1.5)
        let blowoutUpgrade = blowoutMode != .none && best.target + 0.5 < weakest.info.target
        let deepBenchUpgrade = blowoutMode == .deepBench && best.target + 2 < weakest.info.target
        let incoming = stored.teams[teamId].team.players[best.rosterIndex]
        let outgoing = stored.teams[teamId].team.players[weakest.info.rosterIndex]
        let swapInteraction = resolveInteractionWithTrace(
            stored: &stored,
            label: "rotation_swap",
            offensePlayer: incoming,
            defensePlayer: outgoing,
            offenseRatings: ["skills.hustle", "athleticism.stamina", "defense.offballDefense", "skills.shotIQ"],
            defenseRatings: ["skills.hustle", "athleticism.stamina", "defense.offballDefense", "skills.shotIQ"],
            random: &random
        )
        let swapConfidence = logistic(swapInteraction.edge)

        if !(swapConfidence > 0.56 || betterBy > 6 || fatigueUpgrade || rotationUpgrade || blowoutUpgrade || deepBenchUpgrade) { break }

        current[weakest.slot] = best.rosterIndex
        swaps += 1
        bench = ranked.filter { !current.contains($0.rosterIndex) }
    }

    if swaps > 0 {
        stored.teams[teamId].activeLineupBoxIndices = current
        stored.teams[teamId].activeLineup = current.map { stored.teams[teamId].team.players[$0] }
        stored.teams[teamId].team.lineup = stored.teams[teamId].activeLineup
        stored.lastSubElapsedGameSeconds[teamId] = elapsed
    }
}

func elapsedGameSecondsTotal(stored: NativeGameStateStore.StoredState) -> Int {
    let periodLength = stored.currentHalf <= 2 ? HALF_SECONDS : OVERTIME_SECONDS
    let elapsedInPeriod = periodLength - stored.gameClockRemaining
    if stored.currentHalf <= 2 {
        return (stored.currentHalf - 1) * HALF_SECONDS + elapsedInPeriod
    }
    return 2 * HALF_SECONDS + (stored.currentHalf - 3) * OVERTIME_SECONDS + elapsedInPeriod
}

func minuteTarget(for tracker: NativeGameStateStore.TeamTracker, rosterIndex: Int, isStarterSlot: Bool) -> Double {
    guard rosterIndex >= 0, rosterIndex < tracker.team.players.count else { return isStarterSlot ? 28 : 12 }
    let playerName = tracker.team.players[rosterIndex].bio.name
    if let target = tracker.team.rotation?.minuteTargets[playerName], target.isFinite {
        return clamp(target, min: 4, max: 40)
    }
    let position = tracker.team.players[rosterIndex].bio.position
    if isStarterSlot {
        switch position {
        case .pg, .cg:
            return 33
        case .sg:
            return 30
        default:
            return 28
        }
    }
    switch position {
    case .pg, .cg:
        return 14
    default:
        return 11
    }
}

func addTeamExtra(stored: inout NativeGameStateStore.StoredState, teamId: Int, key: String, amount: Int) {
    guard teamId >= 0, teamId < stored.teams.count else { return }
    let teamName = stored.teams[teamId].team.name
    let before = stored.teams[teamId].teamExtras[key, default: 0]
    stored.teams[teamId].teamExtras[key, default: 0] += amount
    if stored.traceEnabled {
        let after = stored.teams[teamId].teamExtras[key, default: 0]
        let delta = after - before
        if delta != 0 {
            stored.currentActionStatRecords.append(
                QAStatRecord(
                    entityType: "team_extra",
                    teamIndex: teamId,
                    teamName: teamName,
                    playerName: nil,
                    stat: key,
                    before: Double(before),
                    after: Double(after),
                    delta: Double(delta)
                )
            )
        }
    }
}

func applyPlusMinus(stored: inout NativeGameStateStore.StoredState, scoringTeamId: Int, points: Int) {
    guard points != 0 else { return }
    let otherTeamId = scoringTeamId == 0 ? 1 : 0
    for lineupIndex in stored.teams[scoringTeamId].activeLineup.indices {
        addPlayerStat(stored: &stored, teamId: scoringTeamId, lineupIndex: lineupIndex) { line in
            let current = line.plusMinus ?? 0
            line.plusMinus = current + points
        }
    }
    for lineupIndex in stored.teams[otherTeamId].activeLineup.indices {
        addPlayerStat(stored: &stored, teamId: otherTeamId, lineupIndex: lineupIndex) { line in
            let current = line.plusMinus ?? 0
            line.plusMinus = current - points
        }
    }
}

func applyPlayerUsageEnergyCost(
    stored: inout NativeGameStateStore.StoredState,
    teamId: Int,
    lineupIndex: Int,
    energyCost: Double
) {
    guard energyCost > 0 else { return }
    guard teamId >= 0, teamId < stored.teams.count else { return }
    guard lineupIndex >= 0, lineupIndex < stored.teams[teamId].activeLineupBoxIndices.count else { return }
    let boxIndex = stored.teams[teamId].activeLineupBoxIndices[lineupIndex]
    guard boxIndex >= 0, boxIndex < stored.teams[teamId].boxPlayers.count else { return }
    let scaledCost = energyCost * 0.68
    let next = max(0, (stored.teams[teamId].boxPlayers[boxIndex].energy ?? 100) - scaledCost)
    stored.teams[teamId].boxPlayers[boxIndex].energy = next
    stored.teams[teamId].activeLineup[lineupIndex].condition.energy = next
    if boxIndex < stored.teams[teamId].team.players.count {
        stored.teams[teamId].team.players[boxIndex].condition.energy = next
    }
}

func addPlayerStat(
    stored: inout NativeGameStateStore.StoredState,
    teamId: Int,
    lineupIndex: Int,
    mutate: (inout PlayerBoxScore) -> Void
) {
    guard teamId >= 0, teamId < stored.teams.count else { return }
    guard lineupIndex >= 0, lineupIndex < stored.teams[teamId].activeLineupBoxIndices.count else { return }
    let boxIndex = stored.teams[teamId].activeLineupBoxIndices[lineupIndex]
    guard boxIndex >= 0, boxIndex < stored.teams[teamId].boxPlayers.count else { return }
    guard stored.traceEnabled else {
        mutate(&stored.teams[teamId].boxPlayers[boxIndex])
        return
    }
    let before = stored.teams[teamId].boxPlayers[boxIndex]
    mutate(&stored.teams[teamId].boxPlayers[boxIndex])
    let after = stored.teams[teamId].boxPlayers[boxIndex]
    let teamName = stored.teams[teamId].team.name
    appendPlayerStatDeltaRecords(
        stored: &stored,
        teamId: teamId,
        teamName: teamName,
        playerName: after.playerName,
        before: before,
        after: after
    )
}

func appendPlayerStatDeltaRecords(
    stored: inout NativeGameStateStore.StoredState,
    teamId: Int,
    teamName: String,
    playerName: String,
    before: PlayerBoxScore,
    after: PlayerBoxScore
) {
    func appendIfChanged(_ stat: String, _ old: Double, _ new: Double) {
        let delta = new - old
        if abs(delta) < 0.000_001 { return }
        stored.currentActionStatRecords.append(
            QAStatRecord(
                entityType: "player",
                teamIndex: teamId,
                teamName: teamName,
                playerName: playerName,
                stat: stat,
                before: old,
                after: new,
                delta: delta
            )
        )
    }

    appendIfChanged("points", Double(before.points), Double(after.points))
    appendIfChanged("fgMade", Double(before.fgMade), Double(after.fgMade))
    appendIfChanged("fgAttempts", Double(before.fgAttempts), Double(after.fgAttempts))
    appendIfChanged("threeMade", Double(before.threeMade), Double(after.threeMade))
    appendIfChanged("threeAttempts", Double(before.threeAttempts), Double(after.threeAttempts))
    appendIfChanged("ftMade", Double(before.ftMade), Double(after.ftMade))
    appendIfChanged("ftAttempts", Double(before.ftAttempts), Double(after.ftAttempts))
    appendIfChanged("rebounds", Double(before.rebounds), Double(after.rebounds))
    appendIfChanged("offensiveRebounds", Double(before.offensiveRebounds), Double(after.offensiveRebounds))
    appendIfChanged("defensiveRebounds", Double(before.defensiveRebounds), Double(after.defensiveRebounds))
    appendIfChanged("assists", Double(before.assists), Double(after.assists))
    appendIfChanged("steals", Double(before.steals), Double(after.steals))
    appendIfChanged("blocks", Double(before.blocks), Double(after.blocks))
    appendIfChanged("turnovers", Double(before.turnovers), Double(after.turnovers))
    appendIfChanged("fouls", Double(before.fouls), Double(after.fouls))
    appendIfChanged("plusMinus", Double(before.plusMinus ?? 0), Double(after.plusMinus ?? 0))
}

func eventDescription(eventType: String, offenseTeam: String, defenseTeam: String, lineup: [Player], playerIndex: Int) -> String? {
    let playerName: String
    if playerIndex >= 0, playerIndex < lineup.count {
        playerName = lineup[playerIndex].bio.name
    } else {
        playerName = "Unknown"
    }
    switch eventType {
    case "made_shot":
        return "\(playerName) scores for \(offenseTeam)"
    case "missed_shot":
        return "\(playerName) misses for \(offenseTeam)"
    case "turnover":
        return "\(playerName) turns it over against \(defenseTeam)"
    case "turnover_shot_clock":
        return "\(offenseTeam) shot clock violation"
    case "foul":
        return "\(playerName) draws free throws"
    case "setup":
        return "\(offenseTeam) runs half-court offense"
    default:
        return nil
    }
}

public func simulateHalf(state: inout GameState, random: inout SeededRandom) {
    guard NativeGameStateStore.snapshot(state.handle) != nil else {
        fatalError("simulateHalf failed: unknown game handle \(state.handle)")
    }
    while resolveActionChunk(state: &state, random: &random) != "period_end" {
        // `resolveActionChunk` advances one interaction chunk and reports period end.
    }
}

func simulateHalf(stored: inout NativeGameStateStore.StoredState, random: inout SeededRandom) {
    while resolveActionChunk(stored: &stored, random: &random) != "period_end" {
        // Same interaction-by-interaction engine as the public GameState path, minus store lookup overhead.
    }
}

func advanceStoredGameToNextPeriod(_ stored: inout NativeGameStateStore.StoredState, half: Int, seconds: Int) {
    stored.currentHalf = half
    stored.gameClockRemaining = seconds
    stored.shotClockRemaining = SHOT_CLOCK_SECONDS
    stored.teamFoulsInHalf = Array(repeating: 0, count: stored.teamFoulsInHalf.count)
    recoverAllPlayersForHalftime(stored: &stored)
}

func simulatedGameResult(from final: NativeGameStateStore.StoredState, overtimeNumber: Int) -> SimulatedGameResult {
    let homeBox = TeamBoxScore(
        name: final.teams[0].team.name,
        players: final.teams[0].boxPlayers.filter { $0.minutes > 0 || $0.points > 0 || $0.fgAttempts > 0 || $0.ftAttempts > 0 },
        teamExtras: final.teams[0].teamExtras
    )
    let awayBox = TeamBoxScore(
        name: final.teams[1].team.name,
        players: final.teams[1].boxPlayers.filter { $0.minutes > 0 || $0.points > 0 || $0.fgAttempts > 0 || $0.ftAttempts > 0 },
        teamExtras: final.teams[1].teamExtras
    )
    let boxScores = [homeBox, awayBox]

    return SimulatedGameResult(
        home: SimulatedTeamResult(name: final.teams[0].team.name, score: final.teams[0].score, boxScore: homeBox),
        away: SimulatedTeamResult(name: final.teams[1].team.name, score: final.teams[1].score, boxScore: awayBox),
        winner: final.teams[0].score == final.teams[1].score ? nil : (final.teams[0].score > final.teams[1].score ? final.teams[0].team.name : final.teams[1].team.name),
        wentToOvertime: overtimeNumber > 0,
        playByPlay: final.playByPlay,
        boxScore: boxScores
    )
}

func simulateGameForBatch(
    homeTeam: Team,
    awayTeam: Team,
    random: inout SeededRandom,
    includePlayByPlay: Bool = false
) -> SimulatedGameResult {
    var stored = NativeGameStateStore.makeInitialState(
        home: homeTeam,
        away: awayTeam,
        random: &random,
        includePlayByPlay: includePlayByPlay
    )
    simulateHalf(stored: &stored, random: &random)
    advanceStoredGameToNextPeriod(&stored, half: 2, seconds: HALF_SECONDS)
    simulateHalf(stored: &stored, random: &random)

    var overtimeNumber = 0
    while stored.teams[0].score == stored.teams[1].score {
        overtimeNumber += 1
        advanceStoredGameToNextPeriod(&stored, half: 2 + overtimeNumber, seconds: OVERTIME_SECONDS)
        simulateHalf(stored: &stored, random: &random)
    }

    return simulatedGameResult(from: stored, overtimeNumber: overtimeNumber)
}

public func simulateGame(
    homeTeam: Team,
    awayTeam: Team,
    random: inout SeededRandom,
    includePlayByPlay: Bool = true
) -> SimulatedGameResult {
    var state = createInitialGameState(
        homeTeam: homeTeam,
        awayTeam: awayTeam,
        random: &random,
        includePlayByPlay: includePlayByPlay
    )
    defer { _ = NativeGameStateStore.remove(state.handle) }
    simulateHalf(state: &state, random: &random)

    _ = NativeGameStateStore.withState(state.handle) { stored in
        stored.currentHalf = 2
        stored.gameClockRemaining = HALF_SECONDS
        stored.shotClockRemaining = SHOT_CLOCK_SECONDS
        stored.teamFoulsInHalf = Array(repeating: 0, count: stored.teamFoulsInHalf.count)
        recoverAllPlayersForHalftime(stored: &stored)
    }
    simulateHalf(state: &state, random: &random)

    var overtimeNumber = 0
    while true {
        guard let snapshot = NativeGameStateStore.snapshot(state.handle) else {
            fatalError("simulateGame failed: missing game state \(state.handle)")
        }
        if snapshot.teams[0].score != snapshot.teams[1].score {
            break
        }
        overtimeNumber += 1
        _ = NativeGameStateStore.withState(state.handle) { stored in
            stored.currentHalf = 2 + overtimeNumber
            stored.gameClockRemaining = OVERTIME_SECONDS
            stored.shotClockRemaining = SHOT_CLOCK_SECONDS
            stored.teamFoulsInHalf = Array(repeating: 0, count: stored.teamFoulsInHalf.count)
            recoverAllPlayersForHalftime(stored: &stored)
        }
        simulateHalf(state: &state, random: &random)
    }

    guard let final = NativeGameStateStore.snapshot(state.handle) else {
        fatalError("simulateGame failed: missing game state \(state.handle)")
    }

    let homeBox = TeamBoxScore(
        name: final.teams[0].team.name,
        players: final.teams[0].boxPlayers.filter { $0.minutes > 0 || $0.points > 0 || $0.fgAttempts > 0 || $0.ftAttempts > 0 },
        teamExtras: final.teams[0].teamExtras
    )
    let awayBox = TeamBoxScore(
        name: final.teams[1].team.name,
        players: final.teams[1].boxPlayers.filter { $0.minutes > 0 || $0.points > 0 || $0.fgAttempts > 0 || $0.ftAttempts > 0 },
        teamExtras: final.teams[1].teamExtras
    )
    let boxScores = [homeBox, awayBox]

    return SimulatedGameResult(
        home: SimulatedTeamResult(name: final.teams[0].team.name, score: final.teams[0].score, boxScore: homeBox),
        away: SimulatedTeamResult(name: final.teams[1].team.name, score: final.teams[1].score, boxScore: awayBox),
        winner: final.teams[0].score == final.teams[1].score ? nil : (final.teams[0].score > final.teams[1].score ? final.teams[0].team.name : final.teams[1].team.name),
        wentToOvertime: overtimeNumber > 0,
        playByPlay: final.playByPlay,
        boxScore: boxScores
    )
}
