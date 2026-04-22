import Foundation

public struct InteractionResult: Codable, Equatable, Sendable {
    public var offenseScore: Double
    public var defenseScore: Double
    public var edge: Double
    public var offenseWon: Bool

    public init(offenseScore: Double, defenseScore: Double, edge: Double, offenseWon: Bool) {
        self.offenseScore = offenseScore
        self.defenseScore = defenseScore
        self.edge = edge
        self.offenseWon = offenseWon
    }
}

public struct PlayByPlayEvent: Codable, Equatable, Sendable {
    public var half: Int?
    public var elapsedSecondsInHalf: Int?
    public var elapsedGameSeconds: Int?
    public var clockRemaining: Int?
    public var type: String
    public var teamIndex: Int?
    public var offenseTeam: String?
    public var defenseTeam: String?
    public var points: Int?
    public var description: String?
    public var detail: String?
}

public struct PlayerBoxScore: Codable, Equatable, Sendable {
    public var playerName: String
    public var position: String
    public var minutes: Double
    public var points: Int
    public var fgMade: Int
    public var fgAttempts: Int
    public var threeMade: Int
    public var threeAttempts: Int
    public var ftMade: Int
    public var ftAttempts: Int
    public var rebounds: Int
    public var offensiveRebounds: Int
    public var defensiveRebounds: Int
    public var assists: Int
    public var steals: Int
    public var blocks: Int
    public var turnovers: Int
    public var fouls: Int
    public var plusMinus: Int?
    public var energy: Double?
}

public struct TeamBoxScore: Codable, Equatable, Sendable {
    public var name: String
    public var players: [PlayerBoxScore]
    public var teamExtras: [String: Int]?
}

public struct SimulatedTeamResult: Codable, Equatable, Sendable {
    public var name: String
    public var score: Int
    public var boxScore: TeamBoxScore?
}

public struct SimulatedGameResult: Codable, Equatable, Sendable {
    public var home: SimulatedTeamResult
    public var away: SimulatedTeamResult
    public var winner: String?
    public var wentToOvertime: Bool
    public var playByPlay: [PlayByPlayEvent]
    public var boxScore: [TeamBoxScore]?
}

public struct QAInteractionTrace: Codable, Equatable, Sendable {
    public var label: String
    public var offensePlayer: String
    public var defensePlayer: String
    public var offenseRatings: [String]
    public var defenseRatings: [String]
    public var offenseRatingValues: [String: Double]
    public var defenseRatingValues: [String: Double]
    public var offenseScore: Double
    public var defenseScore: Double
    public var edge: Double
    public var successProbability: Double
    public var offenseWon: Bool
}

public struct QAStatRecord: Codable, Equatable, Sendable {
    public var entityType: String
    public var teamIndex: Int
    public var teamName: String
    public var playerName: String?
    public var stat: String
    public var before: Double
    public var after: Double
    public var delta: Double
}

public struct QAActionTrace: Codable, Equatable, Sendable {
    public var actionNumber: Int
    public var half: Int
    public var gameClockRemaining: Int
    public var shotClockRemaining: Int
    public var offenseTeam: String
    public var defenseTeam: String
    public var eventType: String
    public var points: Int
    public var playByPlayDescription: String?
    public var interactions: [QAInteractionTrace]
    public var statRecords: [QAStatRecord]
}

public struct SimulatedGameQAResult: Codable, Equatable, Sendable {
    public var game: SimulatedGameResult
    public var actions: [QAActionTrace]
}

public struct GameState: Codable, Equatable, Sendable {
    public var handle: String

    public init(handle: String) {
        self.handle = handle
    }
}

private let mobilityInteractionRatings: Set<String> = [
    "athleticism.burst",
    "athleticism.speed",
    "athleticism.agility",
    "defense.lateralQuickness",
]

private let clutchRatingImpact = 0.08
private let interactionVarianceJitter = 0.14

private enum BlowoutRotationMode {
    case none
    case bench
    case deepBench
}

private struct NativeGameStateStore {
    struct TeamTracker {
        var team: Team
        var score: Int
        var activeLineup: [Player]
        var activeLineupBoxIndices: [Int]
        var boxPlayers: [PlayerBoxScore]
        var teamExtras: [String: Int]
    }

    struct PendingTransition: Sendable {
        var source: String
    }

    struct StoredState {
        var teams: [TeamTracker]
        var currentHalf: Int
        var gameClockRemaining: Int
        var shotClockRemaining: Int
        var possessionTeamId: Int
        var playByPlayEnabled: Bool
        var playByPlay: [PlayByPlayEvent]
        var teamFoulsInHalf: [Int]
        var formationCycleIndex: [Int]
        var pendingTransition: PendingTransition?
        var lastSubElapsedGameSeconds: [Int]
        var traceEnabled: Bool
        var actionCounter: Int
        var currentActionInteractions: [QAInteractionTrace]
        var currentActionStatRecords: [QAStatRecord]
        var actionTraces: [QAActionTrace]
    }

    private static let lock = NSLock()
    private static nonisolated(unsafe) var nextId = 1
    private static nonisolated(unsafe) var states: [String: StoredState] = [:]

    static func create(home: Team, away: Team, random: inout SeededRandom, includePlayByPlay: Bool) -> String {
        lock.lock()
        defer { lock.unlock() }
        let handle = "swift_g_\(nextId)"
        nextId += 1

        let initialPossession = random.nextUnit() < 0.5 ? 0 : 1
        states[handle] = StoredState(
            teams: [
                makeTeamTracker(home),
                makeTeamTracker(away),
            ],
            currentHalf: 1,
            gameClockRemaining: HALF_SECONDS,
            shotClockRemaining: SHOT_CLOCK_SECONDS,
            possessionTeamId: initialPossession,
            playByPlayEnabled: includePlayByPlay,
            playByPlay: [],
            teamFoulsInHalf: [0, 0],
            formationCycleIndex: [0, 0],
            pendingTransition: nil,
            lastSubElapsedGameSeconds: [-9999, -9999],
            traceEnabled: false,
            actionCounter: 0,
            currentActionInteractions: [],
            currentActionStatRecords: [],
            actionTraces: []
        )
        return handle
    }

    static func withState<T>(_ handle: String, _ body: (inout StoredState) -> T) -> T? {
        lock.lock()
        defer { lock.unlock() }
        guard var state = states[handle] else { return nil }
        let result = body(&state)
        states[handle] = state
        return result
    }

    static func snapshot(_ handle: String) -> StoredState? {
        lock.lock()
        defer { lock.unlock() }
        return states[handle]
    }

    private static func makeTeamTracker(_ team: Team) -> TeamTracker {
        let roster = team.players.isEmpty ? team.lineup : team.players
        let starters = Array((team.lineup.isEmpty ? roster : team.lineup).prefix(5))
        var usedRosterIndexes: Set<Int> = []

        func lookupRosterIndex(for player: Player) -> Int {
            if let idx = roster.enumerated().first(where: { element in
                let sameIdentity = element.element.bio.name == player.bio.name && element.element.bio.position == player.bio.position
                return sameIdentity && !usedRosterIndexes.contains(element.offset)
            })?.offset {
                usedRosterIndexes.insert(idx)
                return idx
            }
            if let fallback = roster.indices.first(where: { !usedRosterIndexes.contains($0) }) {
                usedRosterIndexes.insert(fallback)
                return fallback
            }
            return 0
        }

        let boxPlayers = roster.enumerated().map { idx, player in
            PlayerBoxScore(
                playerName: player.bio.name.isEmpty ? "Player \(idx + 1)" : player.bio.name,
                position: player.bio.position.rawValue,
                minutes: 0,
                points: 0,
                fgMade: 0,
                fgAttempts: 0,
                threeMade: 0,
                threeAttempts: 0,
                ftMade: 0,
                ftAttempts: 0,
                rebounds: 0,
                offensiveRebounds: 0,
                defensiveRebounds: 0,
                assists: 0,
                steals: 0,
                blocks: 0,
                turnovers: 0,
                fouls: 0,
                plusMinus: 0,
                energy: player.condition.energy
            )
        }

        let lineupBoxIndices = starters.map { lookupRosterIndex(for: $0) }
        return TeamTracker(
            team: team,
            score: 0,
            activeLineup: starters,
            activeLineupBoxIndices: lineupBoxIndices,
            boxPlayers: boxPlayers,
            teamExtras: [
                "turnovers": 0,
                "fastBreakPoints": 0,
                "pointsInPaint": 0,
            ]
        )
    }
}

private struct WeightedSkill: Sendable {
    var score: Double
}

public func createInitialGameState(
    homeTeam: Team,
    awayTeam: Team,
    random: inout SeededRandom,
    includePlayByPlay: Bool = true
) -> GameState {
    let handle = NativeGameStateStore.create(
        home: homeTeam,
        away: awayTeam,
        random: &random,
        includePlayByPlay: includePlayByPlay
    )
    return GameState(handle: handle)
}

public func resolveInteraction(
    offensePlayer: Player,
    defensePlayer: Player,
    offenseRatings: [String],
    defenseRatings: [String],
    random: inout SeededRandom
) -> InteractionResult {
    let offense = weightedSkillScore(player: offensePlayer, ratingPaths: offenseRatings, random: &random)
    let defense = weightedSkillScore(player: defensePlayer, ratingPaths: defenseRatings, random: &random)
    let offenseUsesMobility = offenseRatings.contains { mobilityInteractionRatings.contains($0) }
    let defenseUsesMobility = defenseRatings.contains { mobilityInteractionRatings.contains($0) }
    let mobilitySizeEdge = getMobilitySizeEdge(
        offensePlayer: offensePlayer,
        defensePlayer: defensePlayer,
        offenseUsesMobility: offenseUsesMobility,
        defenseUsesMobility: defenseUsesMobility
    )
    let interactionJitter = (random.nextUnit() + random.nextUnit() + random.nextUnit() - 1.5) * interactionVarianceJitter
    let edge = (offense.score - defense.score) / 14 + mobilitySizeEdge + interactionJitter
    let successProbability = clamp(logistic(edge), min: 0.03, max: 0.97)
    let offenseWon = random.nextUnit() < successProbability

    return InteractionResult(
        offenseScore: offense.score,
        defenseScore: defense.score,
        edge: edge,
        offenseWon: offenseWon
    )
}

private func resolveInteractionWithTrace(
    stored: inout NativeGameStateStore.StoredState,
    label: String,
    offensePlayer: Player,
    defensePlayer: Player,
    offenseRatings: [String],
    defenseRatings: [String],
    random: inout SeededRandom
) -> InteractionResult {
    let result = resolveInteraction(
        offensePlayer: offensePlayer,
        defensePlayer: defensePlayer,
        offenseRatings: offenseRatings,
        defenseRatings: defenseRatings,
        random: &random
    )
    guard stored.traceEnabled else { return result }
    let offenseRatingValues = offenseRatings.reduce(into: [String: Double]()) { values, path in
        values[path] = getRating(offensePlayer, path: path)
    }
    let defenseRatingValues = defenseRatings.reduce(into: [String: Double]()) { values, path in
        values[path] = getRating(defensePlayer, path: path)
    }
    stored.currentActionInteractions.append(
        QAInteractionTrace(
            label: label,
            offensePlayer: offensePlayer.bio.name,
            defensePlayer: defensePlayer.bio.name,
            offenseRatings: offenseRatings,
            defenseRatings: defenseRatings,
            offenseRatingValues: offenseRatingValues,
            defenseRatingValues: defenseRatingValues,
            offenseScore: result.offenseScore,
            defenseScore: result.defenseScore,
            edge: result.edge,
            successProbability: clamp(logistic(result.edge), min: 0.03, max: 0.97),
            offenseWon: result.offenseWon
        )
    )
    return result
}

@discardableResult
public func resolveActionChunk(state: inout GameState, random: inout SeededRandom) -> String {
    guard let chunkType = NativeGameStateStore.withState(state.handle, { stored in
        if stored.gameClockRemaining <= 0 {
            return "period_end"
        }

        let offenseTeamId = stored.possessionTeamId
        let defenseTeamId = offenseTeamId == 0 ? 1 : 0
        if stored.teams[offenseTeamId].activeLineup.isEmpty || stored.teams[defenseTeamId].activeLineup.isEmpty {
            return "period_end"
        }
        if stored.traceEnabled {
            stored.actionCounter += 1
            stored.currentActionInteractions = []
            stored.currentActionStatRecords = []
        }

        syncPossessionRoles(stored: &stored)
        syncClutchTime(stored: &stored)
        advanceOffensiveFormation(stored: &stored, teamId: offenseTeamId)

        let blowoutMode = blowoutRotationMode(stored: stored, teamId: offenseTeamId)
        let effectivePace: PaceProfile = blowoutMode == .none ? stored.teams[offenseTeamId].team.pace : .verySlow
        let possessionSeconds = possessionDurationSeconds(for: effectivePace, random: &random)
        applyChunkMinutesAndEnergy(stored: &stored, possessionSeconds: possessionSeconds)

        let ballHandlerIdx = pickLineupIndexForBallHandler(
            lineup: stored.teams[offenseTeamId].activeLineup,
            random: &random
        )
        let defenderIdx = min(ballHandlerIdx, stored.teams[defenseTeamId].activeLineup.count - 1)
        let ballHandler = stored.teams[offenseTeamId].activeLineup[ballHandlerIdx]
        let primaryDefender = stored.teams[defenseTeamId].activeLineup[defenderIdx]

        let shotClockPressure = clamp(
            Double(SHOT_CLOCK_SECONDS - stored.shotClockRemaining) / Double(max(1, SHOT_CLOCK_SECONDS - CHUNK_SECONDS)),
            min: 0,
            max: 1
        )
        let paceBias = paceShotBias(for: effectivePace)
        let possessionInteraction = resolveInteractionWithTrace(
            stored: &stored,
            label: "possession_advantage",
            offensePlayer: ballHandler,
            defensePlayer: primaryDefender,
            offenseRatings: ["skills.ballHandling", "skills.shotIQ", "skills.passingIQ", "tendencies.shootVsPass"],
            defenseRatings: ["defense.perimeterDefense", "defense.lateralQuickness", "defense.offballDefense", "defense.defensiveControl"],
            random: &random
        )
        let possessionControl = logistic(possessionInteraction.edge)
        let shooterTendency = getBaseRating(ballHandler, path: "tendencies.shootVsPass")
        let intentBias = clamp((shooterTendency - 55) / 280, min: -0.14, max: 0.16)
        let attemptShotChance = clamp(
            0.035
                + Foundation.pow(shotClockPressure, 1.35) * 0.5
                + (possessionControl - 0.5) * 0.34
                + intentBias
                + paceBias,
            min: 0.06,
            max: 0.75
        )
        let forcedShot = stored.shotClockRemaining <= CHUNK_SECONDS
        let willAttemptAction = forcedShot || random.nextUnit() < attemptShotChance

        var eventType: String
        var points = 0
        var switchedPossession = false
        var handledByFastBreak = false

        if let press = maybeResolvePress(
            stored: &stored,
            offenseTeamId: offenseTeamId,
            defenseTeamId: defenseTeamId,
            random: &random
        ) {
            eventType = press.event
            points = press.points
            switchedPossession = press.switchedPossession
            handledByFastBreak = true
        } else if let fb = maybeResolveFastBreak(
            stored: &stored,
            offenseTeamId: offenseTeamId,
            defenseTeamId: defenseTeamId,
            random: &random
        ) {
            eventType = fb.event
            points = fb.points
            switchedPossession = fb.switchedPossession
            handledByFastBreak = true
        } else {
            eventType = "setup"
        }

        if handledByFastBreak {
            // fast break resolved the whole possession
        } else if !willAttemptAction {
            if stored.shotClockRemaining <= possessionSeconds {
                addPlayerStat(stored: &stored, teamId: offenseTeamId, lineupIndex: ballHandlerIdx) { $0.turnovers += 1 }
                addTeamExtra(stored: &stored, teamId: offenseTeamId, key: "turnovers", amount: 1)
                eventType = "turnover_shot_clock"
                switchedPossession = true
            } else {
                eventType = "setup"
            }
        } else {
            let turnoverInteraction = resolveInteractionWithTrace(
                stored: &stored,
                label: "turnover_check",
                offensePlayer: ballHandler,
                defensePlayer: primaryDefender,
                offenseRatings: ["skills.ballHandling", "skills.ballSafety", "skills.passingIQ"],
                defenseRatings: ["defense.steals", "defense.passPerception", "skills.hands"],
                random: &random
            )
            let handlerControl = getBaseRating(ballHandler, path: "skills.ballHandling") * 0.48
                + getBaseRating(ballHandler, path: "skills.ballSafety") * 0.32
                + getBaseRating(ballHandler, path: "skills.passingIQ") * 0.2
            let pressure = getBaseRating(primaryDefender, path: "defense.steals") * 0.45
                + getBaseRating(primaryDefender, path: "defense.passPerception") * 0.33
                + getBaseRating(primaryDefender, path: "skills.hands") * 0.22
            let pressureEdge = (pressure - handlerControl) / 220
            let turnoverBase = clamp(0.1 + pressureEdge * 0.08, min: 0.06, max: 0.18)
            let turnoverBoost = clamp((0.5 - logistic(turnoverInteraction.edge)) * 0.12, min: -0.04, max: 0.08)
            let isTurnover = random.nextUnit() < clamp(turnoverBase + turnoverBoost, min: 0.04, max: 0.24)

            if isTurnover {
                addPlayerStat(stored: &stored, teamId: offenseTeamId, lineupIndex: ballHandlerIdx) { $0.turnovers += 1 }
                addPlayerStat(stored: &stored, teamId: defenseTeamId, lineupIndex: defenderIdx) { $0.steals += 1 }
                addTeamExtra(stored: &stored, teamId: offenseTeamId, key: "turnovers", amount: 1)
                eventType = "turnover"
                switchedPossession = true
                stored.pendingTransition = NativeGameStateStore.PendingTransition(source: "steal")
            } else {
                let play = resolvePlay(
                    stored: &stored,
                    offenseLineup: stored.teams[offenseTeamId].activeLineup,
                    defenseLineup: stored.teams[defenseTeamId].activeLineup,
                    ballHandlerIdx: ballHandlerIdx,
                    defenderIdx: defenderIdx,
                    team: stored.teams[offenseTeamId].team,
                    random: &random
                )
                if let forcedStealerIdx = play.forcedTurnoverStealerLineupIndex {
                    addPlayerStat(stored: &stored, teamId: offenseTeamId, lineupIndex: ballHandlerIdx) { $0.turnovers += 1 }
                    addPlayerStat(stored: &stored, teamId: defenseTeamId, lineupIndex: forcedStealerIdx) { $0.steals += 1 }
                    addTeamExtra(stored: &stored, teamId: offenseTeamId, key: "turnovers", amount: 1)
                    eventType = "turnover"
                    switchedPossession = true
                    stored.pendingTransition = NativeGameStateStore.PendingTransition(source: "steal")
                } else {
                let shooter = stored.teams[offenseTeamId].activeLineup[play.shooterLineupIndex]
                let shotDefender = stored.teams[defenseTeamId].activeLineup[play.defenderLineupIndex]

                // Pass delivery: if shooter differs from ball handler, the ball has to get there.
                var passIntercepted = false
                if play.shooterLineupIndex != ballHandlerIdx {
                    applyPlayerUsageEnergyCost(stored: &stored, teamId: offenseTeamId, lineupIndex: ballHandlerIdx, energyCost: 0.18)
                    if let stealerIdx = resolvePassInterception(
                        stored: &stored,
                        passer: ballHandler,
                        receiver: shooter,
                        defenseLineup: stored.teams[defenseTeamId].activeLineup,
                        riskShift: play.passInterceptionRiskShift,
                        random: &random
                    ) {
                        addPlayerStat(stored: &stored, teamId: offenseTeamId, lineupIndex: ballHandlerIdx) { $0.turnovers += 1 }
                        addPlayerStat(stored: &stored, teamId: defenseTeamId, lineupIndex: stealerIdx) { $0.steals += 1 }
                        addTeamExtra(stored: &stored, teamId: offenseTeamId, key: "turnovers", amount: 1)
                        eventType = "turnover"
                        switchedPossession = true
                        stored.pendingTransition = NativeGameStateStore.PendingTransition(source: "steal")
                        passIntercepted = true
                    }
                }

                // Offensive charge: only on drives. Depends on defender positioning.
                var tookCharge = false
                if !passIntercepted {
                applyPlayerUsageEnergyCost(stored: &stored, teamId: offenseTeamId, lineupIndex: play.shooterLineupIndex, energyCost: 0.34)
                if play.isDrive {
                    applyPlayerUsageEnergyCost(stored: &stored, teamId: offenseTeamId, lineupIndex: ballHandlerIdx, energyCost: 0.18)
                    let chargeInteraction = resolveInteractionWithTrace(
                        stored: &stored,
                        label: "charge_call",
                        offensePlayer: shooter,
                        defensePlayer: shotDefender,
                        offenseRatings: ["skills.ballHandling", "skills.shotIQ", "athleticism.burst"],
                        defenseRatings: ["defense.defensiveControl", "defense.offballDefense", "skills.hustle"],
                        random: &random
                    )
                    let chargeDefenseControl = 1 - logistic(chargeInteraction.edge)
                    let chargeChance = clamp(0.004 + chargeDefenseControl * 0.043, min: 0.004, max: 0.045)
                    if random.nextUnit() < chargeChance {
                        addPlayerStat(stored: &stored, teamId: offenseTeamId, lineupIndex: play.shooterLineupIndex) { line in
                            line.fouls += 1
                            line.turnovers += 1
                        }
                        addTeamExtra(stored: &stored, teamId: offenseTeamId, key: "turnovers", amount: 1)
                        eventType = "charge"
                        switchedPossession = true
                        tookCharge = true
                    }
                }

                if !tookCharge {

                let shotType = play.shotType
                let isThree = shotType == .three
                let profile = shotProfile(for: shotType)
                let offenseRatingsForShot: [String]
                if isThree {
                    let specialty = isCornerSpot(play.spot) ? "shooting.cornerThrees" : "shooting.upTopThrees"
                    offenseRatingsForShot = ["shooting.threePointShooting", specialty]
                } else {
                    offenseRatingsForShot = profile.offenseRatings
                }
                let shotInteraction = resolveInteractionWithTrace(
                    stored: &stored,
                    label: "half_court_shot",
                    offensePlayer: shooter,
                    defensePlayer: shotDefender,
                    offenseRatings: offenseRatingsForShot,
                    defenseRatings: profile.defenseRatings,
                    random: &random
                )

                let shotMakeBase = baseMakeProbability(for: shotType)
                let shotMakeScale = makeScale(for: shotType)
                let shotTypeEdgeBonus = shotTypeEdge(for: shotType)
                let zoneMod = zoneDistanceAdvantage(spot: play.spot, scheme: stored.teams[defenseTeamId].team.defenseScheme)
                let madeProbability = clamp(
                    shotMakeBase + shotTypeEdgeBonus + play.makeBonus + zoneMod
                        + (logistic(shotInteraction.edge + play.edgeBonus) - 0.5) * shotMakeScale,
                    min: minMakeProbability(for: shotType),
                    max: maxMakeProbability(for: shotType)
                )
                let made = random.nextUnit() < madeProbability

                addPlayerStat(stored: &stored, teamId: offenseTeamId, lineupIndex: play.shooterLineupIndex) { line in
                    line.fgAttempts += 1
                    if made { line.fgMade += 1 }
                    if isThree {
                        line.threeAttempts += 1
                        if made { line.threeMade += 1 }
                    }
                }

                if !made && isRimShot(shotType) {
                    let blockInteraction = resolveInteractionWithTrace(
                        stored: &stored,
                        label: "rim_block_attempt",
                        offensePlayer: shooter,
                        defensePlayer: shotDefender,
                        offenseRatings: ["shooting.layups", "shooting.closeShot", "athleticism.vertical", "skills.hands"],
                        defenseRatings: ["defense.shotBlocking", "defense.shotContest", "athleticism.vertical", "athleticism.strength"],
                        random: &random
                    )
                    let blockDefenseControl = 1 - logistic(blockInteraction.edge)
                    // Keep interior contests meaningful with a slightly higher block environment.
                    let blockChance = clamp(0.09 + blockDefenseControl * 0.66, min: 0.08, max: 0.76)
                    if random.nextUnit() < blockChance {
                        addPlayerStat(stored: &stored, teamId: defenseTeamId, lineupIndex: play.defenderLineupIndex) { $0.blocks += 1 }
                    }
                }

                if made {
                    points = profile.basePoints
                    stored.teams[offenseTeamId].score += points
                    applyPlusMinus(stored: &stored, scoringTeamId: offenseTeamId, points: points)
                    addPlayerStat(stored: &stored, teamId: offenseTeamId, lineupIndex: play.shooterLineupIndex) { $0.points += points }
                    if isPointsInPaintScore(shotType: shotType, spot: play.spot) {
                        addTeamExtra(stored: &stored, teamId: offenseTeamId, key: "pointsInPaint", amount: points)
                    }
                    switchedPossession = true

                    let assistPool: [Int]
                    if let explicitCandidates = play.assistCandidateIndices {
                        assistPool = explicitCandidates
                    } else if play.shooterLineupIndex != ballHandlerIdx {
                        // Direct pass-to-shot chain with no explicit override.
                        assistPool = [ballHandlerIdx]
                    } else {
                        // Self-created shot with no pass interaction.
                        assistPool = []
                    }
                    if let assistIdx = resolveAssistLineupIndex(
                        stored: &stored,
                        offenseLineup: stored.teams[offenseTeamId].activeLineup,
                        defenseLineup: stored.teams[defenseTeamId].activeLineup,
                        shooterIndex: play.shooterLineupIndex,
                        shooterDefenderIndex: play.defenderLineupIndex,
                        candidates: assistPool,
                        creationBias: play.assistForceChance,
                        shotType: shotType,
                        random: &random
                    ) {
                        addPlayerStat(stored: &stored, teamId: offenseTeamId, lineupIndex: assistIdx) { $0.assists += 1 }
                    }

                    let andOneInteraction = resolveInteractionWithTrace(
                        stored: &stored,
                        label: "and_one_contact",
                        offensePlayer: shooter,
                        defensePlayer: shotDefender,
                        offenseRatings: ["shooting.drawFoul", "athleticism.strength", "athleticism.vertical", "skills.ballHandling"],
                        defenseRatings: ["defense.shotContest", "defense.defensiveControl", "skills.hustle"],
                        random: &random
                    )
                    let andOneDefenseControl = 1 - logistic(andOneInteraction.edge)
                    let andOneChance = clamp(0.018 + andOneDefenseControl * 0.15 + play.foulBonus * 0.6, min: 0.02, max: 0.2)
                    if random.nextUnit() < andOneChance {
                        registerDefensiveFoul(stored: &stored, defenseTeamId: defenseTeamId, lineupIndex: play.defenderLineupIndex, shooting: true)
                        let ftProb = freeThrowMakeProbability(
                            stored: &stored,
                            shooter: shooter,
                            defenseTeamId: defenseTeamId,
                            label: "free_throw_focus_and_one",
                            random: &random
                        )
                        let ftMade = random.nextUnit() < ftProb ? 1 : 0
                        addPlayerStat(stored: &stored, teamId: offenseTeamId, lineupIndex: play.shooterLineupIndex) { line in
                            line.ftAttempts += 1
                            line.ftMade += ftMade
                            line.points += ftMade
                        }
                        if ftMade > 0 {
                            points += ftMade
                            stored.teams[offenseTeamId].score += ftMade
                            applyPlusMinus(stored: &stored, scoringTeamId: offenseTeamId, points: ftMade)
                        }
                    }
                    eventType = "made_shot"
                } else {
                    let shootingFoulInteraction = resolveInteractionWithTrace(
                        stored: &stored,
                        label: "shooting_foul_contact",
                        offensePlayer: shooter,
                        defensePlayer: shotDefender,
                        offenseRatings: ["shooting.drawFoul", "athleticism.burst", "skills.ballHandling", "skills.shotIQ"],
                        defenseRatings: ["defense.shotContest", "defense.defensiveControl", "defense.lateralQuickness", "skills.hustle"],
                        random: &random
                    )
                    let foulDefenseControl = 1 - logistic(shootingFoulInteraction.edge)
                    let shootingFoulChance = clamp(0.035 + foulDefenseControl * 0.24 + play.foulBonus * 0.7, min: 0.04, max: 0.32)
                    if random.nextUnit() < shootingFoulChance {
                        registerDefensiveFoul(stored: &stored, defenseTeamId: defenseTeamId, lineupIndex: play.defenderLineupIndex, shooting: true)
                        let ftAttempts = isThree ? 3 : 2
                        var ftMade = 0
                        for _ in 0..<ftAttempts {
                            let ftProb = freeThrowMakeProbability(
                                stored: &stored,
                                shooter: shooter,
                                defenseTeamId: defenseTeamId,
                                label: "free_throw_focus_shooting_foul",
                                random: &random
                            )
                            if random.nextUnit() < ftProb {
                                ftMade += 1
                            }
                        }
                        addPlayerStat(stored: &stored, teamId: offenseTeamId, lineupIndex: play.shooterLineupIndex) { line in
                            line.ftAttempts += ftAttempts
                            line.ftMade += ftMade
                            line.points += ftMade
                        }
                        if ftMade > 0 {
                            points = ftMade
                            stored.teams[offenseTeamId].score += ftMade
                            applyPlusMinus(stored: &stored, scoringTeamId: offenseTeamId, points: ftMade)
                        }
                        eventType = "foul"
                        switchedPossession = true
                    } else {
                        // Loose-ball foul: rare, called on whichever side didn't secure the rebound.
                        let reboundLocationHints = buildHalfCourtReboundLocationHints(
                            play: play,
                            ballHandlerIdx: ballHandlerIdx,
                            offenseCount: stored.teams[offenseTeamId].activeLineup.count,
                            defenseCount: stored.teams[defenseTeamId].activeLineup.count
                        )
                        let zone = resolveReboundLandingZone(
                            stored: &stored,
                            offenseLineup: stored.teams[offenseTeamId].activeLineup,
                            defenseLineup: stored.teams[defenseTeamId].activeLineup,
                            shotType: shotType,
                            spot: play.spot,
                            shooterIndex: play.shooterLineupIndex,
                            shotDefenderIndex: play.defenderLineupIndex,
                            random: &random
                        )
                        let offenseCrashPreference = teamReboundCrashPreference(
                            crashBoards: stored.teams[offenseTeamId].team.tendencies.crashBoardsOffense,
                            fastBreakBias: stored.teams[offenseTeamId].team.tendencies.defendFastBreakOffense
                        )
                        let defenseCrashPreference = teamReboundCrashPreference(
                            crashBoards: stored.teams[defenseTeamId].team.tendencies.crashBoardsDefense,
                            fastBreakBias: stored.teams[defenseTeamId].team.tendencies.attemptFastBreakDefense
                        )
                        let scramblePair = selectReboundScrambleParticipants(
                            stored: &stored,
                            offenseLineup: stored.teams[offenseTeamId].activeLineup,
                            defenseLineup: stored.teams[defenseTeamId].activeLineup,
                            zone: zone,
                            offenseCrashPreference: offenseCrashPreference,
                            defenseCrashPreference: defenseCrashPreference,
                            offenseLocationHints: reboundLocationHints.offense,
                            defenseLocationHints: reboundLocationHints.defense,
                            random: &random
                        )
                        let offenseScrambleIdx = scramblePair.offenseIdx
                        let foulerIdx = scramblePair.defenseIdx
                        let looseBallInteraction = resolveInteractionWithTrace(
                            stored: &stored,
                            label: "loose_ball_scramble",
                            offensePlayer: stored.teams[offenseTeamId].activeLineup[offenseScrambleIdx],
                            defensePlayer: stored.teams[defenseTeamId].activeLineup[foulerIdx],
                            offenseRatings: ["rebounding.offensiveRebounding", "skills.hustle", "skills.hands", "athleticism.burst"],
                            defenseRatings: ["rebounding.boxouts", "skills.hustle", "defense.defensiveControl", "athleticism.strength"],
                            random: &random
                        )
                        let looseBallDefenseControl = 1 - logistic(looseBallInteraction.edge)
                        let looseBallFoulChance = clamp(0.004 + looseBallDefenseControl * 0.03, min: 0.003, max: 0.04)
                        if random.nextUnit() < looseBallFoulChance {
                            // Call it on a likely nearby defender in the rebound zone (they were boxing out); offense keeps ball.
                            registerDefensiveFoul(stored: &stored, defenseTeamId: defenseTeamId, lineupIndex: foulerIdx, shooting: false)
                            eventType = "loose_ball_foul"
                            switchedPossession = false
                        } else {
                            let rebound = resolveReboundOutcome(
                                stored: &stored,
                                offenseLineup: stored.teams[offenseTeamId].activeLineup,
                                defenseLineup: stored.teams[defenseTeamId].activeLineup,
                                shotType: shotType,
                                spot: play.spot,
                                shooterIndex: play.shooterLineupIndex,
                                shotDefenderIndex: play.defenderLineupIndex,
                                offenseCrashPreference: offenseCrashPreference,
                                defenseCrashPreference: defenseCrashPreference,
                                // In half-court misses, defenders usually hold inside boxout position.
                                offensePositioning: 0.8,
                                defensePositioning: 1.2,
                                offenseLocationHints: reboundLocationHints.offense,
                                defenseLocationHints: reboundLocationHints.defense,
                                random: &random
                            )
                            if rebound.offensive {
                                addPlayerStat(stored: &stored, teamId: offenseTeamId, lineupIndex: rebound.lineupIndex) { line in
                                    line.rebounds += 1
                                    line.offensiveRebounds += 1
                                }
                                switchedPossession = false
                            } else {
                                addPlayerStat(stored: &stored, teamId: defenseTeamId, lineupIndex: rebound.lineupIndex) { line in
                                    line.rebounds += 1
                                    line.defensiveRebounds += 1
                                }
                                switchedPossession = true
                                stored.pendingTransition = NativeGameStateStore.PendingTransition(source: "def_rebound")
                            }
                            eventType = "missed_shot"
                        } // close: loose-ball else
                    }
	                }
                } // close: if !tookCharge
                } // close: if !passIntercepted
                } // close: forced drive-turnover branch
            }
        }

        maybeCallNonShootingFoul(
            stored: &stored,
            offenseTeamId: offenseTeamId,
            defenseTeamId: defenseTeamId,
            ballHandlerIdx: ballHandlerIdx,
            defenderIdx: defenderIdx,
            willEndPossession: switchedPossession,
            eventType: &eventType,
            switchedPossession: &switchedPossession,
            points: &points,
            random: &random
        )

        let shouldRecordPlayByPlay = stored.playByPlayEnabled
        let shouldComputeDescription = shouldRecordPlayByPlay || stored.traceEnabled
        let description = shouldComputeDescription ? eventDescription(
            eventType: eventType,
            offenseTeam: stored.teams[offenseTeamId].team.name,
            defenseTeam: stored.teams[defenseTeamId].team.name,
            lineup: stored.teams[offenseTeamId].activeLineup,
            playerIndex: ballHandlerIdx
        ) : nil

        if shouldRecordPlayByPlay {
            let periodLength = stored.currentHalf <= 2 ? HALF_SECONDS : OVERTIME_SECONDS
            let elapsedInPeriod = periodLength - stored.gameClockRemaining
            let elapsedGameSeconds: Int
            if stored.currentHalf <= 2 {
                elapsedGameSeconds = (stored.currentHalf - 1) * HALF_SECONDS + elapsedInPeriod
            } else {
                elapsedGameSeconds = 2 * HALF_SECONDS + (stored.currentHalf - 3) * OVERTIME_SECONDS + elapsedInPeriod
            }

            stored.playByPlay.append(
                PlayByPlayEvent(
                    half: stored.currentHalf,
                    elapsedSecondsInHalf: elapsedInPeriod,
                    elapsedGameSeconds: elapsedGameSeconds,
                    clockRemaining: stored.gameClockRemaining,
                    type: eventType,
                    teamIndex: offenseTeamId,
                    offenseTeam: stored.teams[offenseTeamId].team.name,
                    defenseTeam: stored.teams[defenseTeamId].team.name,
                    points: points,
                    description: description,
                    detail: nil
                )
            )
        }

        if stored.traceEnabled {
            stored.actionTraces.append(
                QAActionTrace(
                    actionNumber: stored.actionCounter,
                    half: stored.currentHalf,
                    gameClockRemaining: stored.gameClockRemaining,
                    shotClockRemaining: stored.shotClockRemaining,
                    offenseTeam: stored.teams[offenseTeamId].team.name,
                    defenseTeam: stored.teams[defenseTeamId].team.name,
                    eventType: eventType,
                    points: points,
                    playByPlayDescription: description,
                    interactions: stored.currentActionInteractions,
                    statRecords: stored.currentActionStatRecords
                )
            )
        }

        stored.gameClockRemaining = max(0, stored.gameClockRemaining - possessionSeconds)
        if switchedPossession {
            stored.possessionTeamId = defenseTeamId
            stored.shotClockRemaining = SHOT_CLOCK_SECONDS
        } else {
            stored.shotClockRemaining = max(0, stored.shotClockRemaining - possessionSeconds)
        }
        if isDeadBall(eventType: eventType) {
            runAutoSubstitutions(stored: &stored, teamId: offenseTeamId, random: &random)
            runAutoSubstitutions(stored: &stored, teamId: defenseTeamId, random: &random)
            maybeCallTimeout(stored: &stored, teamId: defenseTeamId, random: &random)
            maybeCallTechnicalFoul(stored: &stored, random: &random)
        }
        return eventType
    }) else {
        fatalError("resolveActionChunk failed: unknown game handle \(state.handle)")
    }

    return chunkType
}

private func possessionDurationSeconds(for pace: PaceProfile, random: inout SeededRandom) -> Int {
    let roll = random.nextUnit()
    switch pace {
    case .verySlow:
        return roll < 0.5 ? 7 : 8
    case .slow:
        return roll < 0.7 ? 6 : 7
    case .slightlySlow:
        return roll < 0.75 ? 6 : 5
    case .normal:
        return CHUNK_SECONDS
    case .slightlyFast:
        return roll < 0.7 ? 4 : 5
    case .fast:
        return roll < 0.85 ? 4 : 5
    case .veryFast:
        return roll < 0.9 ? 4 : 5
    }
}

private func paceShotBias(for pace: PaceProfile) -> Double {
    switch pace {
    case .verySlow: return -0.15
    case .slow: return -0.11
    case .slightlySlow: return -0.075
    case .normal: return -0.05
    case .slightlyFast: return -0.02
    case .fast: return 0
    case .veryFast: return 0.02
    }
}

private func blowoutRotationMode(stored: NativeGameStateStore.StoredState, teamId: Int) -> BlowoutRotationMode {
    guard teamId >= 0, teamId < stored.teams.count else { return .none }
    guard stored.currentHalf >= 2 else { return .none }
    let oppId = teamId == 0 ? 1 : 0
    let lead = stored.teams[teamId].score - stored.teams[oppId].score
    let inFinalTenRegulation = stored.currentHalf == 2 && stored.gameClockRemaining <= 600
    let inFinalFiveRegulation = stored.currentHalf == 2 && stored.gameClockRemaining <= 300
    let inOvertime = stored.currentHalf > 2

    if lead >= 50 {
        return .deepBench
    }
    if inFinalFiveRegulation && lead >= 20 {
        return .deepBench
    }
    // Existing deep-bench behavior for 30+ in final 10 and all overtime.
    if (inFinalTenRegulation && lead >= 30) || (inOvertime && lead >= 30) {
        return .deepBench
    }
    guard lead >= 30 else { return .none }
    return .bench
}

private func syncPossessionRoles(stored: inout NativeGameStateStore.StoredState) {
    let offenseTeamId = stored.possessionTeamId
    let defenseTeamId = offenseTeamId == 0 ? 1 : 0
    for teamId in stored.teams.indices {
        let role = teamId == offenseTeamId ? "offense" : teamId == defenseTeamId ? "defense" : nil
        for idx in stored.teams[teamId].activeLineup.indices {
            stored.teams[teamId].activeLineup[idx].condition.possessionRole = role
        }
    }
}

private func pickLineupIndexForBallHandler(
    lineup: [Player],
    random: inout SeededRandom
) -> Int {
    guard !lineup.isEmpty else { return 0 }
    let weights = lineup.enumerated().map { _, player -> Double in
        let base = getBaseRating(player, path: "skills.ballHandling") * 0.33
            + getBaseRating(player, path: "skills.passingVision") * 0.2
            + getBaseRating(player, path: "skills.passingIQ") * 0.15
            + (100 - getBaseRating(player, path: "tendencies.shootVsPass")) * 0.14
            + getBaseRating(player, path: "skills.shotIQ") * 0.1
            + getBaseRating(player, path: "athleticism.burst") * 0.08
            + getBaseRating(player, path: "tendencies.drive") * 0.12
        let stamina = getBaseRating(player, path: "athleticism.stamina")
        let energy = clamp(player.condition.energy, min: 0, max: 100)
        let fatigue = clamp((100 - energy) / 100, min: 0, max: 0.9)
        let staminaProtection = clamp((stamina - 50) / 100, min: -0.2, max: 0.45)
        let fatigueTax = clamp(1 - fatigue * (0.72 - staminaProtection * 0.32), min: 0.32, max: 1)
        let positionMultiplier: Double
        switch player.bio.position {
        case .pg, .cg:
            positionMultiplier = 1.02
        case .sg:
            positionMultiplier = 1.01
        case .sf, .wing, .f:
            positionMultiplier = 1.0
        case .pf, .c, .big:
            positionMultiplier = 0.99
        }
        let skillWeighted = max(1, base * positionMultiplier * fatigueTax)
        let softenedSkill = min(skillWeighted, 95) + max(0, skillWeighted - 95) * 0.35
        let compressed = Foundation.pow(softenedSkill, 0.58)
        let equalTouchFloor = 34.0
        return max(1, compressed + equalTouchFloor)
    }
    return weightedChoiceIndex(weights: weights, random: &random)
}

private func isPointGuardLike(_ player: Player) -> Bool {
    switch player.bio.position {
    case .pg: return true
    case .cg: return true
    default: return false
    }
}

private func isFourFiveLike(_ player: Player) -> Bool {
    switch player.bio.position {
    case .pf, .c, .big: return true
    default: return false
    }
}

private func pickLineupIndexForPickActionBallHandler(
    lineup: [Player],
    random: inout SeededRandom
) -> Int {
    guard !lineup.isEmpty else { return 0 }
    let weights = lineup.enumerated().map { _, player -> Double in
        let base = getBaseRating(player, path: "skills.ballHandling") * 0.34
            + getBaseRating(player, path: "skills.passingVision") * 0.16
            + getBaseRating(player, path: "skills.passingIQ") * 0.14
            + getBaseRating(player, path: "skills.shotIQ") * 0.1
            + getBaseRating(player, path: "athleticism.burst") * 0.08
            + getBaseRating(player, path: "tendencies.pickAndRoll") * 0.1
            + getBaseRating(player, path: "tendencies.pickAndPop") * 0.08
        let stamina = getBaseRating(player, path: "athleticism.stamina")
        let energy = clamp(player.condition.energy, min: 0, max: 100)
        let fatigue = clamp((100 - energy) / 100, min: 0, max: 0.9)
        let staminaProtection = clamp((stamina - 50) / 100, min: -0.2, max: 0.45)
        let fatigueTax = clamp(1 - fatigue * (0.78 - staminaProtection * 0.32), min: 0.3, max: 1)
        let positionMultiplier: Double
        switch player.bio.position {
        case .pg, .cg:
            positionMultiplier = 1.04
        case .sg:
            positionMultiplier = 1.02
        case .sf, .wing, .f:
            positionMultiplier = 1.0
        case .pf, .c, .big:
            positionMultiplier = 0.99
        }
        let skillWeighted = max(1, base * positionMultiplier * fatigueTax)
        let softenedSkill = min(skillWeighted, 95) + max(0, skillWeighted - 95) * 0.38
        let compressed = Foundation.pow(softenedSkill, 0.56)
        let equalTouchFloor = 36.0
        return max(1, compressed + equalTouchFloor)
    }
    return weightedChoiceIndex(weights: weights, random: &random)
}

private func resolveAssistLineupIndex(
    stored: inout NativeGameStateStore.StoredState,
    offenseLineup: [Player],
    defenseLineup: [Player],
    shooterIndex: Int,
    shooterDefenderIndex: Int,
    candidates: [Int],
    creationBias: Double?,
    shotType: ShotType,
    random: inout SeededRandom
) -> Int? {
    let filtered = Array(Set(candidates.filter { $0 != shooterIndex && $0 >= 0 && $0 < offenseLineup.count })).sorted()
    guard !filtered.isEmpty, !defenseLineup.isEmpty else { return nil }

    let shooter = offenseLineup[shooterIndex]
    let shotDefender = defenseLineup[min(max(0, shooterDefenderIndex), defenseLineup.count - 1)]
    var bestIndex: Int?
    var bestScore = -Double.infinity

    for candidateIdx in filtered {
        let passer = offenseLineup[candidateIdx]
        let laneDefender = defenseLineup[min(candidateIdx, defenseLineup.count - 1)]
        let passWindow = resolveInteractionWithTrace(
            stored: &stored,
            label: "assist_pass_window",
            offensePlayer: passer,
            defensePlayer: laneDefender,
            offenseRatings: ["skills.passingVision", "skills.passingIQ", "skills.passingAccuracy", "skills.ballHandling"],
            defenseRatings: ["defense.passPerception", "defense.offballDefense", "defense.lateralQuickness", "skills.hands"],
            random: &random
        )
        let timingWindow = resolveInteractionWithTrace(
            stored: &stored,
            label: "assist_receiver_timing",
            offensePlayer: shooter,
            defensePlayer: shotDefender,
            offenseRatings: ["skills.offballOffense", "skills.shotIQ", "skills.hands", "athleticism.burst"],
            defenseRatings: ["defense.offballDefense", "defense.shotContest", "defense.defensiveControl", "defense.lateralQuickness"],
            random: &random
        )
        let passControl = logistic(passWindow.edge)
        let timingControl = logistic(timingWindow.edge)
        let shotContextBonus: Double = {
            switch shotType {
            case .three:
                return 0.08
            case .midrange, .fadeaway:
                return 0.04
            case .hook:
                return 0.01
            case .layup, .dunk, .close:
                return 0
            }
        }()
        let biasBonus = ((creationBias ?? 0.5) - 0.5) * 0.16
        let score = (passControl - 0.5) * 0.9 + (timingControl - 0.5) * 0.7 + shotContextBonus + biasBonus
        if score > bestScore {
            bestScore = score
            bestIndex = candidateIdx
        }
    }

    guard let assistIdx = bestIndex else { return nil }
    let threshold = 0.06
    return bestScore >= threshold ? assistIdx : nil
}

private enum ReboundZone {
    case paint, leftBlock, rightBlock, leftPerimeter, rightPerimeter, topPerimeter
}

private struct ReboundLocationHints {
    var offense: [OffensiveSpot?]
    var defense: [OffensiveSpot?]
}

private struct ReboundOutcome {
    var offensive: Bool
    var lineupIndex: Int
}

private func reboundZone(for shotType: ShotType, spot: OffensiveSpot) -> ReboundZone {
    switch shotType {
    case .three:
        switch spot {
        case .leftCorner: return .leftPerimeter
        case .rightCorner: return .rightPerimeter
        case .topLeft: return .leftPerimeter
        case .topRight: return .rightPerimeter
        default: return .topPerimeter
        }
    case .midrange, .fadeaway:
        switch spot {
        case .leftElbow, .leftPost: return .leftBlock
        case .rightElbow, .rightPost: return .rightBlock
        default: return .paint
        }
    default:
        switch spot {
        case .leftPost: return .leftBlock
        case .rightPost: return .rightBlock
        default: return .paint
        }
    }
}

private func resolveReboundLandingZone(
    stored: inout NativeGameStateStore.StoredState,
    offenseLineup: [Player],
    defenseLineup: [Player],
    shotType: ShotType,
    spot: OffensiveSpot,
    shooterIndex: Int,
    shotDefenderIndex: Int,
    random: inout SeededRandom
) -> ReboundZone {
    let initialZone = reboundZone(for: shotType, spot: spot)
    guard !offenseLineup.isEmpty, !defenseLineup.isEmpty else { return initialZone }
    let shooter = offenseLineup[min(max(0, shooterIndex), offenseLineup.count - 1)]
    let defender = defenseLineup[min(max(0, shotDefenderIndex), defenseLineup.count - 1)]
    let caromControl = resolveInteractionWithTrace(
        stored: &stored,
        label: "rebound_carom_direction",
        offensePlayer: shooter,
        defensePlayer: defender,
        offenseRatings: ["skills.shotIQ", "skills.hands", "shooting.threePointShooting", "shooting.midrangeShot", "shooting.closeShot"],
        defenseRatings: ["defense.shotContest", "defense.shotBlocking", "defense.defensiveControl", "skills.hustle"],
        random: &random
    )
    let offenseCaromControl = logistic(caromControl.edge)

    switch initialZone {
    case .leftPerimeter:
        return offenseCaromControl >= 0.52 ? .leftPerimeter : .leftBlock
    case .rightPerimeter:
        return offenseCaromControl >= 0.52 ? .rightPerimeter : .rightBlock
    case .topPerimeter:
        return offenseCaromControl >= 0.58 ? .topPerimeter : .paint
    case .leftBlock:
        return offenseCaromControl >= 0.5 ? .leftBlock : .paint
    case .rightBlock:
        return offenseCaromControl >= 0.5 ? .rightBlock : .paint
    case .paint:
        return .paint
    }
}

private func postSideAffinity(_ player: Player, isLeft: Bool) -> Double {
    switch player.bio.position {
    case .pf:
        return isLeft ? 1.0 : 0.75
    case .c, .big:
        return isLeft ? 0.25 : 1.0
    case .sf, .f, .wing:
        return isLeft ? 0.8 : 0.45
    case .sg, .cg:
        return 0.2
    case .pg:
        return 0.1
    }
}

private func zonePresenceAffinity(_ player: Player, zone: ReboundZone) -> Double {
    switch zone {
    case .paint:
        switch player.bio.position {
        case .c, .big:
            return 1.0
        case .pf, .f:
            return 0.85
        case .sf, .wing:
            return 0.45
        case .sg, .cg:
            return 0.18
        case .pg:
            return 0.1
        }
    case .leftBlock:
        return postSideAffinity(player, isLeft: true)
    case .rightBlock:
        return postSideAffinity(player, isLeft: false)
    case .leftPerimeter, .rightPerimeter, .topPerimeter:
        return 0
    }
}

private func positionProximity(_ player: Player, zone: ReboundZone) -> Double {
    let positionTag = player.bio.position.rawValue.uppercased()
    let isBig = positionTag.contains("C") || positionTag.contains("PF") || positionTag.contains("F")
    let isGuard = positionTag.contains("PG") || positionTag.contains("SG") || positionTag.contains("G")
    switch zone {
    case .paint:
        return isBig ? 1.25 : (isGuard ? 0.75 : 1.0)
    case .leftBlock, .rightBlock:
        return isBig ? 1.18 : 0.85
    case .leftPerimeter, .rightPerimeter:
        return isGuard ? 1.2 : 0.85
    case .topPerimeter:
        return isGuard ? 1.15 : 0.9
    }
}

private func defaultReboundSpot(forLineupIndex index: Int) -> OffensiveSpot {
    switch index % 5 {
    case 0: return .topMiddle
    case 1: return .topLeft
    case 2: return .topRight
    case 3: return .leftPost
    default: return .rightPost
    }
}

private func locationProximityToReboundZone(spot: OffensiveSpot, zone: ReboundZone) -> Double {
    switch zone {
    case .paint:
        switch spot {
        case .middlePaint: return 1.36
        case .leftPost, .rightPost: return 1.24
        case .ftLine: return 1.04
        case .leftElbow, .rightElbow: return 0.94
        case .leftSlot, .rightSlot: return 0.82
        case .topMiddle: return 0.74
        case .topLeft, .topRight: return 0.66
        case .leftCorner, .rightCorner: return 0.52
        }
    case .leftBlock:
        switch spot {
        case .leftPost: return 1.36
        case .middlePaint: return 1.22
        case .leftElbow: return 1.04
        case .leftCorner: return 0.92
        case .leftSlot: return 0.9
        case .ftLine: return 0.86
        case .topLeft: return 0.78
        case .topMiddle: return 0.7
        case .rightPost: return 0.64
        case .rightElbow: return 0.58
        case .topRight: return 0.52
        case .rightSlot: return 0.48
        case .rightCorner: return 0.42
        }
    case .rightBlock:
        switch spot {
        case .rightPost: return 1.36
        case .middlePaint: return 1.22
        case .rightElbow: return 1.04
        case .rightCorner: return 0.92
        case .rightSlot: return 0.9
        case .ftLine: return 0.86
        case .topRight: return 0.78
        case .topMiddle: return 0.7
        case .leftPost: return 0.64
        case .leftElbow: return 0.58
        case .topLeft: return 0.52
        case .leftSlot: return 0.48
        case .leftCorner: return 0.42
        }
    case .leftPerimeter:
        switch spot {
        case .leftCorner: return 1.3
        case .topLeft: return 1.2
        case .leftSlot: return 1.1
        case .leftElbow: return 0.92
        case .topMiddle: return 0.84
        case .ftLine: return 0.8
        case .middlePaint: return 0.72
        case .leftPost: return 0.7
        case .rightPost: return 0.54
        case .topRight: return 0.52
        case .rightSlot: return 0.46
        case .rightElbow: return 0.44
        case .rightCorner: return 0.38
        }
    case .rightPerimeter:
        switch spot {
        case .rightCorner: return 1.3
        case .topRight: return 1.2
        case .rightSlot: return 1.1
        case .rightElbow: return 0.92
        case .topMiddle: return 0.84
        case .ftLine: return 0.8
        case .middlePaint: return 0.72
        case .rightPost: return 0.7
        case .leftPost: return 0.54
        case .topLeft: return 0.52
        case .leftSlot: return 0.46
        case .leftElbow: return 0.44
        case .leftCorner: return 0.38
        }
    case .topPerimeter:
        switch spot {
        case .topMiddle: return 1.28
        case .topLeft, .topRight: return 1.12
        case .leftSlot, .rightSlot: return 1.0
        case .ftLine: return 0.86
        case .leftElbow, .rightElbow: return 0.8
        case .middlePaint: return 0.7
        case .leftCorner, .rightCorner: return 0.68
        case .leftPost, .rightPost: return 0.62
        }
    }
}

private func reboundNearbyWeight(
    _ player: Player,
    lineupIndex: Int,
    zone: ReboundZone,
    locationHints: [OffensiveSpot?]? = nil
) -> Double {
    let fallbackAffinity = zonePresenceAffinity(player, zone: zone)
    let fallbackProximity = positionProximity(player, zone: zone)
    let fallback = max(0.12, fallbackAffinity * 0.9 + fallbackProximity * 0.45)
    guard let locationHints, lineupIndex >= 0, lineupIndex < locationHints.count, let spot = locationHints[lineupIndex] else {
        return fallback
    }
    let location = locationProximityToReboundZone(spot: spot, zone: zone)
    return max(0.12, location * 0.72 + fallback * 0.4)
}

private func teamReboundCrashPreference(crashBoards: Double, fastBreakBias: Double) -> Double {
    let crash = clamp(crashBoards, min: 0, max: 100)
    let leakOut = clamp(fastBreakBias, min: 0, max: 100)
    return clamp(0.5 + (crash - leakOut) / 200, min: 0.05, max: 0.95)
}

private func reboundCrashParticipationWeight(
    _ player: Player,
    lineupIndex: Int,
    zone: ReboundZone,
    crashPreference: Double,
    locationHints: [OffensiveSpot?]? = nil
) -> Double {
    let crash = clamp(crashPreference, min: 0, max: 1)
    let location: Double? = {
        guard let locationHints, lineupIndex >= 0, lineupIndex < locationHints.count, let spot = locationHints[lineupIndex] else {
            return nil
        }
        return locationProximityToReboundZone(spot: spot, zone: zone)
    }()
    if let location {
        // Location-first crash model: players farther from the landing zone gain more from high crash intent.
        let base = 0.68 + location * 0.28
        let distance = clamp(1.35 - location, min: 0, max: 1)
        let crashGain = 0.32 + distance * 0.78
        return max(0.2, base + crash * crashGain)
    }
    let mobility = getBaseRating(player, path: "athleticism.burst") * 0.42
        + getBaseRating(player, path: "athleticism.speed") * 0.3
        + getBaseRating(player, path: "skills.hustle") * 0.28
    let mobilityScale = clamp((mobility - 50) / 100, min: -0.18, max: 0.24)
    return max(0.2, 0.84 + crash * (0.34 + mobilityScale))
}

private func reboundCandidateCount(crashPreference: Double) -> Int {
    let crash = clamp(crashPreference, min: 0, max: 1)
    if crash > 0.72 { return 5 }
    if crash > 0.56 { return 4 }
    if crash < 0.28 { return 2 }
    return 3
}

private func heightReboundRating(_ player: Player) -> Double {
    let heightInches = getHeightInches(player)
    return clamp((heightInches - 76) * 4 + 56, min: 34, max: 98)
}

private func wingspanReboundRating(_ player: Player) -> Double {
    let wingspanInches = getWingspanInches(player)
    return clamp((wingspanInches - 80) * 4 + 56, min: 34, max: 100)
}

private func offensiveReboundSkillScore(_ player: Player, zone: ReboundZone) -> Double {
    let oreb = getBaseRating(player, path: "rebounding.offensiveRebounding")
    let box = getBaseRating(player, path: "rebounding.boxouts")
    let hustle = getBaseRating(player, path: "skills.hustle")
    let hands = getBaseRating(player, path: "skills.hands")
    let vertical = getBaseRating(player, path: "athleticism.vertical")
    let strength = getBaseRating(player, path: "athleticism.strength")
    let burst = getBaseRating(player, path: "athleticism.burst")
    let speed = getBaseRating(player, path: "athleticism.speed")
    let height = heightReboundRating(player)
    let wingspan = wingspanReboundRating(player)
    let core = oreb * 0.48 + box * 0.16 + hustle * 0.12 + hands * 0.08 + strength * 0.08 + vertical * 0.08
    let movement: Double
    switch zone {
    case .paint, .leftBlock, .rightBlock:
        movement = vertical * 0.52 + strength * 0.34 + burst * 0.14
    case .leftPerimeter, .rightPerimeter, .topPerimeter:
        movement = burst * 0.44 + speed * 0.38 + hands * 0.18
    }
    let size = height * 0.45 + wingspan * 0.55
    return core * 0.72 + movement * 0.14 + size * 0.14
}

private func defensiveReboundSkillScore(_ player: Player, zone: ReboundZone) -> Double {
    let dreb = getBaseRating(player, path: "rebounding.defensiveRebound")
    let box = getBaseRating(player, path: "rebounding.boxouts")
    let hustle = getBaseRating(player, path: "skills.hustle")
    let hands = getBaseRating(player, path: "skills.hands")
    let vertical = getBaseRating(player, path: "athleticism.vertical")
    let strength = getBaseRating(player, path: "athleticism.strength")
    let burst = getBaseRating(player, path: "athleticism.burst")
    let speed = getBaseRating(player, path: "athleticism.speed")
    let height = heightReboundRating(player)
    let wingspan = wingspanReboundRating(player)
    let core = dreb * 0.46 + box * 0.24 + hustle * 0.12 + hands * 0.08 + strength * 0.06 + vertical * 0.04
    let movement: Double
    switch zone {
    case .paint, .leftBlock, .rightBlock:
        movement = vertical * 0.48 + strength * 0.32 + burst * 0.2
    case .leftPerimeter, .rightPerimeter, .topPerimeter:
        movement = burst * 0.4 + speed * 0.36 + hands * 0.24
    }
    let size = height * 0.4 + wingspan * 0.6
    return core * 0.72 + movement * 0.12 + size * 0.16
}

private func topReboundCandidateIndices(
    lineup: [Player],
    offensive: Bool,
    zone: ReboundZone,
    crashPreference: Double,
    count: Int = 2,
    locationHints: [OffensiveSpot?]? = nil
) -> [Int] {
    guard !lineup.isEmpty else { return [0] }
    let ranked = lineup.enumerated().map { idx, player in
        let base = offensive ? offensiveReboundSkillScore(player, zone: zone) : defensiveReboundSkillScore(player, zone: zone)
        let nearby = reboundNearbyWeight(player, lineupIndex: idx, zone: zone, locationHints: locationHints)
        let crashWeight = reboundCrashParticipationWeight(player, lineupIndex: idx, zone: zone, crashPreference: crashPreference, locationHints: locationHints)
        let score = max(0.1, base * nearby * crashWeight)
        return (idx, score)
    }
    return ranked.sorted { $0.1 > $1.1 }.prefix(max(1, count)).map(\.0)
}

private func selectReboundScrambleParticipants(
    stored: inout NativeGameStateStore.StoredState,
    offenseLineup: [Player],
    defenseLineup: [Player],
    zone: ReboundZone,
    offenseCrashPreference: Double,
    defenseCrashPreference: Double,
    offenseLocationHints: [OffensiveSpot?]? = nil,
    defenseLocationHints: [OffensiveSpot?]? = nil,
    random: inout SeededRandom
) -> (offenseIdx: Int, defenseIdx: Int) {
    guard !offenseLineup.isEmpty, !defenseLineup.isEmpty else { return (0, 0) }
    let offenseCandidates = topReboundCandidateIndices(
        lineup: offenseLineup,
        offensive: true,
        zone: zone,
        crashPreference: offenseCrashPreference,
        count: reboundCandidateCount(crashPreference: offenseCrashPreference),
        locationHints: offenseLocationHints
    )
    let defenseCandidates = topReboundCandidateIndices(
        lineup: defenseLineup,
        offensive: false,
        zone: zone,
        crashPreference: defenseCrashPreference,
        count: reboundCandidateCount(crashPreference: defenseCrashPreference),
        locationHints: defenseLocationHints
    )

    var bestPair: (Int, Int)?
    var bestEdge = -Double.infinity
    for offenseIdx in offenseCandidates {
        for defenseIdx in defenseCandidates {
            let interaction = resolveInteractionWithTrace(
                stored: &stored,
                label: "rebound_scramble_matchup",
                offensePlayer: offenseLineup[offenseIdx],
                defensePlayer: defenseLineup[defenseIdx],
                offenseRatings: ["rebounding.offensiveRebounding", "skills.hustle", "skills.hands", "athleticism.burst", "athleticism.vertical"],
                defenseRatings: ["rebounding.boxouts", "rebounding.defensiveRebound", "skills.hustle", "athleticism.strength", "athleticism.vertical"],
                random: &random
            )
            let sizeEdge = (heightReboundRating(offenseLineup[offenseIdx]) - heightReboundRating(defenseLineup[defenseIdx])) * 0.011
                + (wingspanReboundRating(offenseLineup[offenseIdx]) - wingspanReboundRating(defenseLineup[defenseIdx])) * 0.013
            let adjusted = interaction.edge + sizeEdge
            if adjusted > bestEdge {
                bestEdge = adjusted
                bestPair = (offenseIdx, defenseIdx)
            }
        }
    }
    return bestPair ?? (offenseCandidates[0], defenseCandidates[0])
}

private func resolveReboundOutcome(
    stored: inout NativeGameStateStore.StoredState,
    offenseLineup: [Player],
    defenseLineup: [Player],
    shotType: ShotType,
    spot: OffensiveSpot,
    shooterIndex: Int,
    shotDefenderIndex: Int,
    offenseCrashPreference: Double,
    defenseCrashPreference: Double,
    offensePositioning: Double,
    defensePositioning: Double,
    offenseLocationHints: [OffensiveSpot?]? = nil,
    defenseLocationHints: [OffensiveSpot?]? = nil,
    random: inout SeededRandom
) -> ReboundOutcome {
    guard !offenseLineup.isEmpty else { return ReboundOutcome(offensive: false, lineupIndex: 0) }
    guard !defenseLineup.isEmpty else { return ReboundOutcome(offensive: true, lineupIndex: 0) }
    let zone = resolveReboundLandingZone(
        stored: &stored,
        offenseLineup: offenseLineup,
        defenseLineup: defenseLineup,
        shotType: shotType,
        spot: spot,
        shooterIndex: shooterIndex,
        shotDefenderIndex: shotDefenderIndex,
        random: &random
    )
    let offenseCandidates = topReboundCandidateIndices(
        lineup: offenseLineup,
        offensive: true,
        zone: zone,
        crashPreference: offenseCrashPreference,
        count: reboundCandidateCount(crashPreference: offenseCrashPreference),
        locationHints: offenseLocationHints
    )
    let defenseCandidates = topReboundCandidateIndices(
        lineup: defenseLineup,
        offensive: false,
        zone: zone,
        crashPreference: defenseCrashPreference,
        count: reboundCandidateCount(crashPreference: defenseCrashPreference),
        locationHints: defenseLocationHints
    )

    var bestOffenseIdx = offenseCandidates[0]
    var bestDefenseIdx = defenseCandidates[0]
    var bestSlipEdge = -Double.infinity
    for offenseIdx in offenseCandidates {
        for defenseIdx in defenseCandidates {
            let boxoutBattle = resolveInteractionWithTrace(
                stored: &stored,
                label: "rebound_boxout_battle",
                offensePlayer: offenseLineup[offenseIdx],
                defensePlayer: defenseLineup[defenseIdx],
                offenseRatings: ["rebounding.offensiveRebounding", "skills.hustle", "athleticism.vertical", "athleticism.strength", "skills.hands"],
                defenseRatings: ["rebounding.boxouts", "rebounding.defensiveRebound", "athleticism.strength", "athleticism.vertical", "defense.defensiveControl"],
                random: &random
            )
            let sizeEdge = (heightReboundRating(offenseLineup[offenseIdx]) - heightReboundRating(defenseLineup[defenseIdx])) * 0.012
                + (wingspanReboundRating(offenseLineup[offenseIdx]) - wingspanReboundRating(defenseLineup[defenseIdx])) * 0.014
            let positioningEdge = (offensePositioning - defensePositioning) * 0.18
            let adjustedSlipEdge = boxoutBattle.edge + sizeEdge + positioningEdge
            if adjustedSlipEdge > bestSlipEdge {
                bestSlipEdge = adjustedSlipEdge
                bestOffenseIdx = offenseIdx
                bestDefenseIdx = defenseIdx
            }
        }
    }

    let gatherBattle = resolveInteractionWithTrace(
        stored: &stored,
        label: "rebound_gather_battle",
        offensePlayer: offenseLineup[bestOffenseIdx],
        defensePlayer: defenseLineup[bestDefenseIdx],
        offenseRatings: ["rebounding.offensiveRebounding", "skills.hands", "skills.hustle", "athleticism.vertical", "athleticism.burst"],
        defenseRatings: ["rebounding.defensiveRebound", "rebounding.boxouts", "skills.hands", "skills.hustle", "athleticism.vertical"],
        random: &random
    )
    let gatherSizeEdge = (heightReboundRating(offenseLineup[bestOffenseIdx]) - heightReboundRating(defenseLineup[bestDefenseIdx])) * 0.012
        + (wingspanReboundRating(offenseLineup[bestOffenseIdx]) - wingspanReboundRating(defenseLineup[bestDefenseIdx])) * 0.015
    let finalEdge = gatherBattle.edge + gatherSizeEdge + (offensePositioning - defensePositioning) * 0.15 + bestSlipEdge * 0.35
    if finalEdge >= 0 {
        return ReboundOutcome(offensive: true, lineupIndex: bestOffenseIdx)
    }
    return ReboundOutcome(offensive: false, lineupIndex: bestDefenseIdx)
}

private func weightedRandomIndex(lineup: [Player], random: inout SeededRandom, weight: (Player) -> Double) -> Int {
    let weights = lineup.map { max(0.1, weight($0)) }
    return weightedChoiceIndex(weights: weights, random: &random)
}

private func weightedChoiceIndex(weights: [Double], random: inout SeededRandom) -> Int {
    guard !weights.isEmpty else { return 0 }
    let total = weights.reduce(0, +)
    guard total > 0 else { return 0 }
    var pick = random.nextUnit() * total
    for (idx, value) in weights.enumerated() {
        pick -= value
        if pick <= 0 {
            return idx
        }
    }
    return weights.count - 1
}

private func applyChunkMinutesAndEnergy(stored: inout NativeGameStateStore.StoredState, possessionSeconds: Int) {
    let minuteDelta = Double(possessionSeconds) / 60
    let energyDelta = Double(possessionSeconds) * 0.04
    for teamId in stored.teams.indices {
        for lineupIndex in stored.teams[teamId].activeLineup.indices {
            addPlayerStat(stored: &stored, teamId: teamId, lineupIndex: lineupIndex) { line in
                line.minutes += minuteDelta
                if let energy = line.energy {
                    line.energy = max(0, energy - energyDelta)
                }
            }
            let boxIndex = stored.teams[teamId].activeLineupBoxIndices[lineupIndex]
            guard boxIndex >= 0, boxIndex < stored.teams[teamId].boxPlayers.count else { continue }
            let latestEnergy = stored.teams[teamId].boxPlayers[boxIndex].energy ?? 100
            stored.teams[teamId].activeLineup[lineupIndex].condition.energy = latestEnergy
            if boxIndex < stored.teams[teamId].team.players.count {
                stored.teams[teamId].team.players[boxIndex].condition.energy = latestEnergy
            }
        }
        stored.teams[teamId].team.lineup = stored.teams[teamId].activeLineup
    }
}

private struct SubCandidate {
    var rosterIndex: Int
    var score: Double
    var energy: Double
    var minutesPlayed: Double
    var target: Double
    var rotationNeed: Double
    var fouls: Int
    var fouledOut: Bool
}

private func playerOverallSkill(_ player: Player) -> Double {
    average([
        getBaseRating(player, path: "skills.shotIQ"),
        getBaseRating(player, path: "shooting.threePointShooting"),
        getBaseRating(player, path: "shooting.midrangeShot"),
        getBaseRating(player, path: "shooting.closeShot"),
        getBaseRating(player, path: "skills.ballHandling"),
        getBaseRating(player, path: "defense.perimeterDefense"),
        getBaseRating(player, path: "defense.shotContest"),
        getBaseRating(player, path: "rebounding.defensiveRebound"),
    ])
}

private func computeTargetMinutesMap(tracker: NativeGameStateStore.TeamTracker) -> [Int: Double] {
    let roster = tracker.team.players
    guard !roster.isEmpty else { return [:] }
    let totalTeamMinutes: Double = 200

    if let namedTargets = tracker.team.rotation?.minuteTargets {
        var raw: [Int: Double] = [:]
        for (idx, player) in roster.enumerated() {
            if let value = namedTargets[player.bio.name], value.isFinite, value >= 0 {
                raw[idx] = value
            }
        }
        if !raw.isEmpty {
            let sum = raw.values.reduce(0, +)
            var map: [Int: Double] = [:]
            if sum > 0 {
                let scale = totalTeamMinutes / sum
                for (idx, value) in raw {
                    map[idx] = clamp(value * scale, min: 0, max: 40)
                }
            }
            for idx in roster.indices where map[idx] == nil {
                map[idx] = 0
            }
            return map
        }
    }

    // Default CPU-style pattern: 10-man rotation (5 starters ~28, 5 backups ~12).
    // If roster size differs, preserve this shape and scale to 200 team minutes.
    let listedStarters = Array((tracker.team.lineup.isEmpty ? roster : tracker.team.lineup).prefix(5))
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

    var rawTargets: [Int: Double] = [:]
    for idx in starterIndices { rawTargets[idx] = 28 }
    for idx in benchIndices { rawTargets[idx] = 12 }

    let rawTotal = rawTargets.values.reduce(0, +)
    guard rawTotal > 0 else {
        return Dictionary(uniqueKeysWithValues: roster.indices.map { ($0, 0) })
    }

    let scale = totalTeamMinutes / rawTotal
    var map: [Int: Double] = [:]
    for idx in roster.indices {
        let raw = rawTargets[idx] ?? 0
        map[idx] = clamp(raw * scale, min: 0, max: 40)
    }
    return map
}

private func rankSubCandidates(tracker: NativeGameStateStore.TeamTracker, blowoutMode: BlowoutRotationMode) -> [SubCandidate] {
    let targetMap = computeTargetMinutesMap(tracker: tracker)
    let roster = tracker.team.players
    return roster.indices.map { idx in
        let box = idx < tracker.boxPlayers.count ? tracker.boxPlayers[idx] : PlayerBoxScore(playerName: "", position: "", minutes: 0, points: 0, fgMade: 0, fgAttempts: 0, threeMade: 0, threeAttempts: 0, ftMade: 0, ftAttempts: 0, rebounds: 0, offensiveRebounds: 0, defensiveRebounds: 0, assists: 0, steals: 0, blocks: 0, turnovers: 0, fouls: 0, plusMinus: 0, energy: 100)
        let energy = box.energy ?? 100
        let skill = playerOverallSkill(roster[idx])
        let minutesPlayed = box.minutes
        let target = targetMap[idx] ?? 0
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

private func isInFoulTrouble(stored: NativeGameStateStore.StoredState, fouls: Int) -> Bool {
    // Early-/mid-game: bench at 4. Final 5 minutes: allow 4 fouls on the floor.
    let inClutchWindow = stored.currentHalf >= 2 && stored.gameClockRemaining <= 300
    if fouls >= 5 { return true }
    if fouls >= 4 && !inClutchWindow { return true }
    return false
}

private func runAutoSubstitutions(stored: inout NativeGameStateStore.StoredState, teamId: Int, random: inout SeededRandom) {
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

private func elapsedGameSecondsTotal(stored: NativeGameStateStore.StoredState) -> Int {
    let periodLength = stored.currentHalf <= 2 ? HALF_SECONDS : OVERTIME_SECONDS
    let elapsedInPeriod = periodLength - stored.gameClockRemaining
    if stored.currentHalf <= 2 {
        return (stored.currentHalf - 1) * HALF_SECONDS + elapsedInPeriod
    }
    return 2 * HALF_SECONDS + (stored.currentHalf - 3) * OVERTIME_SECONDS + elapsedInPeriod
}

private func minuteTarget(for tracker: NativeGameStateStore.TeamTracker, rosterIndex: Int, isStarterSlot: Bool) -> Double {
    guard rosterIndex >= 0, rosterIndex < tracker.team.players.count else { return isStarterSlot ? 28 : 12 }
    let playerName = tracker.team.players[rosterIndex].bio.name
    if let target = tracker.team.rotation?.minuteTargets[playerName], target.isFinite {
        return clamp(target, min: 4, max: 40)
    }
    return isStarterSlot ? 28 : 12
}

private func addTeamExtra(stored: inout NativeGameStateStore.StoredState, teamId: Int, key: String, amount: Int) {
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

private func applyPlusMinus(stored: inout NativeGameStateStore.StoredState, scoringTeamId: Int, points: Int) {
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

private func applyPlayerUsageEnergyCost(
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
    let next = max(0, (stored.teams[teamId].boxPlayers[boxIndex].energy ?? 100) - energyCost)
    stored.teams[teamId].boxPlayers[boxIndex].energy = next
    stored.teams[teamId].activeLineup[lineupIndex].condition.energy = next
    if boxIndex < stored.teams[teamId].team.players.count {
        stored.teams[teamId].team.players[boxIndex].condition.energy = next
    }
}

private func addPlayerStat(
    stored: inout NativeGameStateStore.StoredState,
    teamId: Int,
    lineupIndex: Int,
    mutate: (inout PlayerBoxScore) -> Void
) {
    guard teamId >= 0, teamId < stored.teams.count else { return }
    guard lineupIndex >= 0, lineupIndex < stored.teams[teamId].activeLineupBoxIndices.count else { return }
    let boxIndex = stored.teams[teamId].activeLineupBoxIndices[lineupIndex]
    guard boxIndex >= 0, boxIndex < stored.teams[teamId].boxPlayers.count else { return }
    let before = stored.teams[teamId].boxPlayers[boxIndex]
    mutate(&stored.teams[teamId].boxPlayers[boxIndex])
    guard stored.traceEnabled else { return }
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

private func appendPlayerStatDeltaRecords(
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

private func eventDescription(eventType: String, offenseTeam: String, defenseTeam: String, lineup: [Player], playerIndex: Int) -> String? {
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
    while true {
        guard let snapshot = NativeGameStateStore.snapshot(state.handle) else {
            fatalError("simulateHalf failed: missing game state \(state.handle)")
        }
        if snapshot.gameClockRemaining <= 0 {
            break
        }
        _ = resolveActionChunk(state: &state, random: &random)
    }
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

public func simulateGameWithQA(homeTeam: Team, awayTeam: Team, random: inout SeededRandom) -> SimulatedGameQAResult {
    var state = createInitialGameState(homeTeam: homeTeam, awayTeam: awayTeam, random: &random)
    _ = NativeGameStateStore.withState(state.handle) { stored in
        stored.traceEnabled = true
    }
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
            fatalError("simulateGameWithQA failed: missing game state \(state.handle)")
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
        fatalError("simulateGameWithQA failed: missing game state \(state.handle)")
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
    let game = SimulatedGameResult(
        home: SimulatedTeamResult(name: final.teams[0].team.name, score: final.teams[0].score, boxScore: homeBox),
        away: SimulatedTeamResult(name: final.teams[1].team.name, score: final.teams[1].score, boxScore: awayBox),
        winner: final.teams[0].score == final.teams[1].score ? nil : (final.teams[0].score > final.teams[1].score ? final.teams[0].team.name : final.teams[1].team.name),
        wentToOvertime: overtimeNumber > 0,
        playByPlay: final.playByPlay,
        boxScore: boxScores
    )
    return SimulatedGameQAResult(game: game, actions: final.actionTraces)
}

private func logistic(_ x: Double) -> Double {
    1 / (1 + Foundation.exp(-x))
}

private func average(_ values: [Double]) -> Double {
    guard !values.isEmpty else { return 0 }
    return values.reduce(0, +) / Double(values.count)
}

private func parseLengthToInches(_ value: String?, fallback: Double) -> Double {
    guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
        return fallback
    }

    if let numeric = Double(trimmed), numeric.isFinite {
        return numeric
    }

    if let (feet, inches) = extractFeetInches(trimmed, pattern: #"^\s*(\d+)\s*-\s*(\d+)\s*$"#) {
        return Double(feet * 12 + inches)
    }

    if let (feet, inches) = extractFeetInches(trimmed, pattern: #"^\s*(\d+)\s*'\s*(\d+)"#) {
        return Double(feet * 12 + inches)
    }

    return fallback
}

private func extractFeetInches(_ text: String, pattern: String) -> (Int, Int)? {
    guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
    let nsrange = NSRange(text.startIndex..<text.endIndex, in: text)
    guard let match = regex.firstMatch(in: text, options: [], range: nsrange), match.numberOfRanges >= 3 else {
        return nil
    }
    guard
        let feetRange = Range(match.range(at: 1), in: text),
        let inchesRange = Range(match.range(at: 2), in: text),
        let feet = Int(text[feetRange]),
        let inches = Int(text[inchesRange])
    else {
        return nil
    }
    return (feet, inches)
}

private func getHeightInches(_ player: Player) -> Double {
    parseLengthToInches(player.size.height, fallback: 78)
}

private func getWingspanInches(_ player: Player) -> Double {
    parseLengthToInches(player.size.wingspan, fallback: getHeightInches(player) + 4)
}

private func getWeightPounds(_ player: Player) -> Double {
    if let value = Double(player.size.weight), value.isFinite {
        return value
    }
    return 220
}

private func getRawRating(_ player: Player, path: String) -> Double? {
    switch path {
    case "athleticism.speed": return Double(player.athleticism.speed)
    case "athleticism.agility": return Double(player.athleticism.agility)
    case "athleticism.burst": return Double(player.athleticism.burst)
    case "athleticism.strength": return Double(player.athleticism.strength)
    case "athleticism.vertical": return Double(player.athleticism.vertical)
    case "athleticism.stamina": return Double(player.athleticism.stamina)
    case "athleticism.durability": return Double(player.athleticism.durability)
    case "shooting.layups": return Double(player.shooting.layups)
    case "shooting.dunks": return Double(player.shooting.dunks)
    case "shooting.closeShot": return Double(player.shooting.closeShot)
    case "shooting.midrangeShot": return Double(player.shooting.midrangeShot)
    case "shooting.threePointShooting": return Double(player.shooting.threePointShooting)
    case "shooting.cornerThrees": return Double(player.shooting.cornerThrees)
    case "shooting.upTopThrees": return Double(player.shooting.upTopThrees)
    case "shooting.drawFoul": return Double(player.shooting.drawFoul)
    case "shooting.freeThrows": return Double(player.shooting.freeThrows)
    case "postGame.postControl": return Double(player.postGame.postControl)
    case "postGame.postFadeaways": return Double(player.postGame.postFadeaways)
    case "postGame.postHooks": return Double(player.postGame.postHooks)
    case "skills.ballHandling": return Double(player.skills.ballHandling)
    case "skills.ballSafety": return Double(player.skills.ballSafety)
    case "skills.passingAccuracy": return Double(player.skills.passingAccuracy)
    case "skills.passingVision": return Double(player.skills.passingVision)
    case "skills.passingIQ": return Double(player.skills.passingIQ)
    case "skills.shotIQ": return Double(player.skills.shotIQ)
    case "skills.offballOffense": return Double(player.skills.offballOffense)
    case "skills.hands": return Double(player.skills.hands)
    case "skills.hustle": return Double(player.skills.hustle)
    case "skills.clutch": return Double(player.skills.clutch)
    case "defense.perimeterDefense": return Double(player.defense.perimeterDefense)
    case "defense.postDefense": return Double(player.defense.postDefense)
    case "defense.shotBlocking": return Double(player.defense.shotBlocking)
    case "defense.shotContest": return Double(player.defense.shotContest)
    case "defense.steals": return Double(player.defense.steals)
    case "defense.lateralQuickness": return Double(player.defense.lateralQuickness)
    case "defense.offballDefense": return Double(player.defense.offballDefense)
    case "defense.passPerception": return Double(player.defense.passPerception)
    case "defense.defensiveControl": return Double(player.defense.defensiveControl)
    case "rebounding.offensiveRebounding": return Double(player.rebounding.offensiveRebounding)
    case "rebounding.defensiveRebound": return Double(player.rebounding.defensiveRebound)
    case "rebounding.boxouts": return Double(player.rebounding.boxouts)
    case "tendencies.post": return Double(player.tendencies.post)
    case "tendencies.inside": return Double(player.tendencies.inside)
    case "tendencies.midrange": return Double(player.tendencies.midrange)
    case "tendencies.threePoint": return Double(player.tendencies.threePoint)
    case "tendencies.drive": return Double(player.tendencies.drive)
    case "tendencies.pickAndRoll": return Double(player.tendencies.pickAndRoll)
    case "tendencies.pickAndPop": return Double(player.tendencies.pickAndPop)
    case "tendencies.shootVsPass": return Double(player.tendencies.shootVsPass)
    default: return nil
    }
}

private func getBaseRating(_ player: Player, path: String, fallback: Double = 50) -> Double {
    guard let raw = getRawRating(player, path: path), raw.isFinite else { return fallback }
    if raw <= 1 { return fallback }
    if raw <= 10 { return raw * 10 }
    return raw
}

private func applyClutchModifier(_ player: Player, rating: Double) -> Double {
    let homeCourtMultiplier = player.condition.homeCourtMultiplier
    let baseMultiplier = homeCourtMultiplier.isFinite ? homeCourtMultiplier : 1
    if !player.condition.clutchTime {
        return clamp(rating * baseMultiplier, min: 1, max: 100)
    }
    let clutch = getBaseRating(player, path: "skills.clutch", fallback: 50)
    let clutchEdge = clamp((clutch - 50) / 50, min: -1, max: 1)
    let clutchMultiplier = 1 + clutchEdge * clutchRatingImpact
    return clamp(rating * baseMultiplier * clutchMultiplier, min: 1, max: 100)
}

private func getRating(_ player: Player, path: String, fallback: Double = 50) -> Double {
    guard let raw = getRawRating(player, path: path), raw.isFinite else { return fallback }

    if raw <= 1 { return fallback }
    if raw <= 10 { return applyClutchModifier(player, rating: raw * 10) }

    let isAthleticStaminaOrDurability = path == "athleticism.stamina" || path == "athleticism.durability"
    if isAthleticStaminaOrDurability {
        return applyClutchModifier(player, rating: raw)
    }

    let energy = player.condition.energy
    if !energy.isFinite {
        return applyClutchModifier(player, rating: raw)
    }

    let fatigue = clamp((100 - energy) / 100, min: 0, max: 0.85)
    let stamina = getBaseRating(player, path: "athleticism.stamina", fallback: 50)
    let staminaRecovery = clamp((stamina - 50) / 50, min: -1, max: 1)
    let group = String(path.split(separator: ".").first ?? "")
    let impact: Double
    switch group {
    case "athleticism": impact = 0.33
    case "shooting": impact = 0.3
    case "skills": impact = 0.39
    case "defense": impact = 0.24
    case "rebounding", "postGame": impact = 0.22
    default: impact = 0.22
    }
    let creatorPath = path == "skills.ballHandling"
        || path == "skills.ballSafety"
        || path == "skills.passingIQ"
        || path == "skills.passingVision"
        || path == "tendencies.drive"
        || path == "tendencies.pickAndRoll"
        || path == "tendencies.pickAndPop"
    let creatorPenalty = creatorPath ? clamp(0.11 + fatigue * 0.22 - staminaRecovery * 0.05, min: 0.05, max: 0.3) : 0
    let effectiveImpact = clamp(impact - staminaRecovery * 0.05 + creatorPenalty, min: 0.16, max: 0.72)

    let fatigueAdjusted = applyClutchModifier(player, rating: raw * (1 - fatigue * effectiveImpact))
    let role = player.condition.possessionRole
    let offensiveModifier = player.condition.offensiveCoachingModifier
    let defensiveModifier = player.condition.defensiveCoachingModifier
    var coachingModifier = 1.0
    if role == "offense", offensiveModifier.isFinite {
        coachingModifier = offensiveModifier
    } else if role == "defense", defensiveModifier.isFinite {
        coachingModifier = defensiveModifier
    }
    return clamp(fatigueAdjusted * coachingModifier, min: 1, max: 100)
}

private func weightedSkillScore(player: Player, ratingPaths: [String], random: inout SeededRandom) -> WeightedSkill {
    let ratings = ratingPaths.map { getRating(player, path: $0) }
    let mean = average(ratings)
    let weighted = ratings.map { value -> (value: Double, weight: Double) in
        let excellence = clamp((value - mean) / 50, min: -1, max: 1)
        let baseline = 0.55 + random.nextUnit()
        let strengthBias = 1 + max(0, excellence) * 0.35
        return (value: value, weight: baseline * strengthBias)
    }
    let totalWeight = weighted.reduce(0) { $0 + $1.weight }
    if totalWeight <= 0 {
        return WeightedSkill(score: average(ratings))
    }
    let score = weighted.reduce(0) { $0 + $1.value * $1.weight } / totalWeight
    return WeightedSkill(score: score)
}

private func getMobilitySizePenalty(_ player: Player) -> Double {
    let heightPenalty = (getHeightInches(player) - 76) / 12
    let weightPenalty = (getWeightPounds(player) - 205) / 80
    return clamp(heightPenalty * 0.7 + weightPenalty * 0.9, min: -0.45, max: 1.35)
}

private func getMobilitySizeEdge(
    offensePlayer: Player,
    defensePlayer: Player,
    offenseUsesMobility: Bool,
    defenseUsesMobility: Bool
) -> Double {
    if !offenseUsesMobility && !defenseUsesMobility {
        return 0
    }
    let offensePenalty = offenseUsesMobility ? getMobilitySizePenalty(offensePlayer) : 0
    let defensePenalty = defenseUsesMobility ? getMobilitySizePenalty(defensePlayer) : 0
    return clamp((defensePenalty - offensePenalty) / 12, min: -0.16, max: 0.16)
}

// MARK: - Shot type selection and resolution

enum ShotType {
    case close
    case midrange
    case three
    case layup
    case dunk
    case hook
    case fadeaway
}

private struct ShotProfile {
    var offenseRatings: [String]
    var defenseRatings: [String]
    var basePoints: Int
}

private func shotProfile(for shotType: ShotType) -> ShotProfile {
    switch shotType {
    case .close:
        return ShotProfile(
            offenseRatings: ["shooting.closeShot", "shooting.layups", "athleticism.burst"],
            defenseRatings: ["defense.shotContest", "defense.perimeterDefense", "defense.postDefense"],
            basePoints: 2
        )
    case .midrange:
        return ShotProfile(
            offenseRatings: ["shooting.midrangeShot", "skills.shotIQ", "athleticism.agility"],
            defenseRatings: ["defense.shotContest", "defense.perimeterDefense", "defense.lateralQuickness"],
            basePoints: 2
        )
    case .three:
        return ShotProfile(
            offenseRatings: ["shooting.threePointShooting", "skills.shotIQ"],
            defenseRatings: ["defense.shotContest", "defense.perimeterDefense", "defense.offballDefense"],
            basePoints: 3
        )
    case .layup:
        return ShotProfile(
            offenseRatings: ["shooting.layups", "athleticism.burst", "athleticism.vertical"],
            defenseRatings: ["defense.shotContest", "athleticism.vertical", "defense.shotBlocking"],
            basePoints: 2
        )
    case .dunk:
        return ShotProfile(
            offenseRatings: ["shooting.dunks", "athleticism.vertical", "athleticism.strength"],
            defenseRatings: ["defense.shotContest", "athleticism.vertical", "defense.shotBlocking"],
            basePoints: 2
        )
    case .hook:
        return ShotProfile(
            offenseRatings: ["postGame.postHooks", "postGame.postControl", "athleticism.strength"],
            defenseRatings: ["defense.shotContest", "defense.postDefense", "defense.shotBlocking"],
            basePoints: 2
        )
    case .fadeaway:
        return ShotProfile(
            offenseRatings: ["postGame.postFadeaways", "shooting.midrangeShot"],
            defenseRatings: ["defense.shotContest", "defense.postDefense"],
            basePoints: 2
        )
    }
}

private func baseMakeProbability(for shotType: ShotType) -> Double {
    switch shotType {
    case .three: return 0.322
    case .midrange: return 0.38
    case .close: return 0.45
    case .layup: return 0.56
    case .dunk: return 0.74
    case .hook: return 0.44
    case .fadeaway: return 0.40
    }
}

private func makeScale(for shotType: ShotType) -> Double {
    switch shotType {
    case .three: return 0.09
    case .midrange: return 0.10
    case .close, .hook, .fadeaway: return 0.11
    case .layup, .dunk: return 0.13
    }
}

private func shotTypeEdge(for shotType: ShotType) -> Double {
    switch shotType {
    case .layup: return 0.02
    case .dunk: return 0.04
    case .midrange: return -0.04
    case .fadeaway: return -0.02
    case .three: return -0.04
    case .hook: return 0.01
    case .close: return 0
    }
}

private func minMakeProbability(for shotType: ShotType) -> Double {
    switch shotType {
    case .three: return 0.22
    case .midrange: return 0.28
    case .close: return 0.32
    case .layup: return 0.42
    case .dunk: return 0.55
    case .hook: return 0.30
    case .fadeaway: return 0.26
    }
}

private func maxMakeProbability(for shotType: ShotType) -> Double {
    switch shotType {
    case .three: return 0.52
    case .midrange: return 0.56
    case .close: return 0.66
    case .layup: return 0.80
    case .dunk: return 0.92
    case .hook: return 0.64
    case .fadeaway: return 0.58
    }
}

private func isRimShot(_ shotType: ShotType) -> Bool {
    switch shotType {
    case .layup, .dunk, .hook, .close: return true
    default: return false
    }
}

private func isPointsInPaintScore(shotType: ShotType, spot: OffensiveSpot) -> Bool {
    switch shotType {
    case .layup, .dunk:
        return true
    case .hook, .fadeaway, .close:
        return spot == .middlePaint || spot == .leftPost || spot == .rightPost
    case .midrange, .three:
        return false
    }
}

private func isCornerSpot(_ spot: OffensiveSpot) -> Bool {
    spot == .rightCorner || spot == .leftCorner
}

private func pickShooterSpot(player: Player, random: inout SeededRandom) -> OffensiveSpot {
    let cornerWeight = getBaseRating(player, path: "shooting.cornerThrees") * 0.9
    let upTopWeight = getBaseRating(player, path: "shooting.upTopThrees")
    let postTend = getBaseRating(player, path: "tendencies.post")
    let insideTend = getBaseRating(player, path: "tendencies.inside")
    let total = cornerWeight + upTopWeight + postTend + insideTend
    guard total > 0 else { return .topMiddle }
    var pick = random.nextUnit() * total
    pick -= cornerWeight
    if pick <= 0 { return random.nextUnit() < 0.5 ? .rightCorner : .leftCorner }
    pick -= upTopWeight
    if pick <= 0 {
        let picks: [OffensiveSpot] = [.topMiddle, .topRight, .topLeft]
        return picks[random.int(0, picks.count - 1)]
    }
    pick -= postTend
    if pick <= 0 { return random.nextUnit() < 0.5 ? .rightPost : .leftPost }
    return .middlePaint
}

private func chooseShotFromTendencies(shooter: Player, spot: OffensiveSpot, random: inout SeededRandom) -> ShotType {
    let shotIQ = getBaseRating(shooter, path: "skills.shotIQ")
    let atRim = spot == .middlePaint || spot == .rightPost || spot == .leftPost

    if atRim {
        let hookW = getBaseRating(shooter, path: "postGame.postHooks") * 1.0
        let fadeW = getBaseRating(shooter, path: "postGame.postFadeaways") * 0.8
        let layupW = getBaseRating(shooter, path: "shooting.layups") * 1.1
        let dunkW = getBaseRating(shooter, path: "shooting.dunks") * 0.9
        let total = hookW + fadeW + layupW + dunkW
        var pick = random.nextUnit() * max(total, 1)
        pick -= hookW; if pick <= 0 { return .hook }
        pick -= fadeW; if pick <= 0 { return .fadeaway }
        pick -= layupW; if pick <= 0 { return .layup }
        return .dunk
    }

    let isThreeSpot = spot == .topMiddle || spot == .topRight || spot == .topLeft || spot == .rightCorner || spot == .leftCorner

    if isThreeSpot {
        let threeUtility = getBaseRating(shooter, path: "shooting.threePointShooting") * 1.5
            + getBaseRating(shooter, path: "tendencies.threePoint") * 0.9
        let midUtility = getBaseRating(shooter, path: "shooting.midrangeShot") * 1.1
            + getBaseRating(shooter, path: "tendencies.midrange") * 0.6
        let closeUtility = getBaseRating(shooter, path: "shooting.closeShot") * 0.6
            + getBaseRating(shooter, path: "tendencies.inside") * 0.5
        if shotIQ >= 70 {
            let items: [(ShotType, Double)] = [(.three, threeUtility), (.midrange, midUtility), (.close, closeUtility)]
            let sorted = items.sorted { $0.1 > $1.1 }
            return random.nextUnit() < 0.82 ? sorted[0].0 : sorted[1].0
        }
        let total = threeUtility + midUtility + closeUtility
        var pick = random.nextUnit() * max(total, 1)
        pick -= threeUtility; if pick <= 0 { return .three }
        pick -= midUtility; if pick <= 0 { return .midrange }
        return .close
    }

    let midW = getBaseRating(shooter, path: "shooting.midrangeShot") * 1.2
        + getBaseRating(shooter, path: "tendencies.midrange") * 0.8
    let closeW = getBaseRating(shooter, path: "shooting.closeShot") * 1.2
        + getBaseRating(shooter, path: "tendencies.inside") * 0.7
    let total = midW + closeW
    var pick = random.nextUnit() * max(total, 1)
    pick -= midW; if pick <= 0 { return .midrange }
    return .close
}

private func chooseInteractionSpotAndShot(
    stored: inout NativeGameStateStore.StoredState,
    shooter: Player,
    defender: Player,
    random: inout SeededRandom
) -> (spot: OffensiveSpot, shotType: ShotType) {
    let spotInteraction = resolveInteractionWithTrace(
        stored: &stored,
        label: "shot_spot_selection",
        offensePlayer: shooter,
        defensePlayer: defender,
        offenseRatings: ["skills.offballOffense", "skills.shotIQ", "tendencies.threePoint", "tendencies.inside", "tendencies.post"],
        defenseRatings: ["defense.offballDefense", "defense.perimeterDefense", "defense.postDefense", "defense.lateralQuickness"],
        random: &random
    )
    let perimeterControl = logistic(spotInteraction.edge)
    let spot: OffensiveSpot
    if perimeterControl > 0.64 {
        let cornerLean = getBaseRating(shooter, path: "shooting.cornerThrees")
        let topLean = getBaseRating(shooter, path: "shooting.upTopThrees")
        if cornerLean > topLean + 5 {
            spot = random.nextUnit() < 0.5 ? .leftCorner : .rightCorner
        } else {
            let picks: [OffensiveSpot] = [.topLeft, .topMiddle, .topRight]
            spot = picks[random.int(0, picks.count - 1)]
        }
    } else if perimeterControl < 0.36 {
        let postLean = getBaseRating(shooter, path: "tendencies.post")
        if postLean > 58 {
            spot = random.nextUnit() < 0.5 ? .leftPost : .rightPost
        } else {
            spot = .middlePaint
        }
    } else {
        let picks: [OffensiveSpot] = [.leftElbow, .rightElbow, .topMiddle]
        spot = picks[random.int(0, picks.count - 1)]
    }

    let shotInteraction = resolveInteractionWithTrace(
        stored: &stored,
        label: "shot_type_selection",
        offensePlayer: shooter,
        defensePlayer: defender,
        offenseRatings: ["skills.shotIQ", "shooting.threePointShooting", "shooting.midrangeShot", "shooting.closeShot", "shooting.layups"],
        defenseRatings: ["defense.shotContest", "defense.perimeterDefense", "defense.postDefense"],
        random: &random
    )
    let shotControl = logistic(shotInteraction.edge)
    let shotType: ShotType
    if spot == .middlePaint || spot == .leftPost || spot == .rightPost {
        if shotControl > 0.68 {
            shotType = getBaseRating(shooter, path: "shooting.dunks") > getBaseRating(shooter, path: "shooting.layups") + 4 ? .dunk : .layup
        } else if shotControl > 0.44 {
            shotType = getBaseRating(shooter, path: "postGame.postHooks") > getBaseRating(shooter, path: "postGame.postFadeaways") ? .hook : .fadeaway
        } else {
            shotType = .close
        }
    } else if spot == .leftCorner || spot == .rightCorner || spot == .topLeft || spot == .topMiddle || spot == .topRight {
        shotType = shotControl > 0.48 ? .three : .midrange
    } else {
        shotType = shotControl > 0.56 ? .midrange : .close
    }
    return (spot, shotType)
}

// MARK: - Play types

private enum PlayType {
    case dribbleDrive, postUp, pickAndRoll, pickAndPop, passAroundForShot
}

private struct PlayOutcome {
    var shooterLineupIndex: Int
    var defenderLineupIndex: Int
    var shotType: ShotType
    var spot: OffensiveSpot
    var edgeBonus: Double
    var makeBonus: Double
    var foulBonus: Double
    var assistCandidateIndices: [Int]?
    var assistForceChance: Double?
    var passInterceptionRiskShift: Double = 0
    var isDrive: Bool = false
    var forcedTurnoverStealerLineupIndex: Int? = nil
}

private func isPerimeterSpot(_ spot: OffensiveSpot) -> Bool {
    switch spot {
    case .topMiddle, .topLeft, .topRight, .leftCorner, .rightCorner, .leftSlot, .rightSlot:
        return true
    default:
        return false
    }
}

private func buildHalfCourtReboundLocationHints(
    play: PlayOutcome,
    ballHandlerIdx: Int,
    offenseCount: Int,
    defenseCount: Int
) -> ReboundLocationHints {
    var offense = (0..<offenseCount).map { Optional(defaultReboundSpot(forLineupIndex: $0)) }
    if ballHandlerIdx >= 0, ballHandlerIdx < offense.count {
        offense[ballHandlerIdx] = play.isDrive ? .middlePaint : .topMiddle
    }
    if let passers = play.assistCandidateIndices {
        for idx in passers where idx >= 0 && idx < offense.count && idx != play.shooterLineupIndex {
            if play.isDrive {
                offense[idx] = .middlePaint
            } else {
                offense[idx] = isPerimeterSpot(play.spot) ? .ftLine : .topMiddle
            }
        }
    }
    if play.shooterLineupIndex >= 0, play.shooterLineupIndex < offense.count {
        offense[play.shooterLineupIndex] = play.spot
    }

    var defense = (0..<defenseCount).map { idx -> OffensiveSpot? in
        idx < offense.count ? offense[idx] : defaultReboundSpot(forLineupIndex: idx)
    }
    if play.defenderLineupIndex >= 0, play.defenderLineupIndex < defense.count {
        defense[play.defenderLineupIndex] = play.spot
    }
    return ReboundLocationHints(offense: offense, defense: defense)
}

private func buildTransitionReboundLocationHints(
    offenseCount: Int,
    defenseCount: Int,
    shooterIdx: Int,
    shotDefenderIdx: Int
) -> ReboundLocationHints {
    var offense = (0..<offenseCount).map { Optional(defaultReboundSpot(forLineupIndex: $0)) }
    var defense = (0..<defenseCount).map { Optional(defaultReboundSpot(forLineupIndex: $0)) }
    if shooterIdx >= 0, shooterIdx < offense.count {
        offense[shooterIdx] = .middlePaint
    }
    if shotDefenderIdx >= 0, shotDefenderIdx < defense.count {
        defense[shotDefenderIdx] = .middlePaint
    }
    return ReboundLocationHints(offense: offense, defense: defense)
}

private func choosePlayType(
    stored: inout NativeGameStateStore.StoredState,
    offenseTeam: Team,
    ballHandler: Player,
    primaryDefender: Player,
    random: inout SeededRandom
) -> PlayType {
    let drive = getRating(ballHandler, path: "tendencies.drive")
    let post = getRating(ballHandler, path: "tendencies.post")
    let pickAndRoll = getRating(ballHandler, path: "tendencies.pickAndRoll")
    let pickAndPop = getRating(ballHandler, path: "tendencies.pickAndPop")
    let shootVsPass = getRating(ballHandler, path: "tendencies.shootVsPass")
    let passAroundProfile = (
        getRating(ballHandler, path: "skills.passingVision")
        + getRating(ballHandler, path: "skills.passingIQ")
        + getRating(ballHandler, path: "skills.passingAccuracy")
        + getRating(ballHandler, path: "skills.ballHandling")
    ) / 4
    let passAround = clamp((100 - shootVsPass) * 0.55 + passAroundProfile * 0.5, min: 1, max: 115)
    let handlerEnergy = clamp(ballHandler.condition.energy, min: 0, max: 100)
    let handlerFatigue = clamp((100 - handlerEnergy) / 100, min: 0, max: 0.9)
    let handlerStamina = getBaseRating(ballHandler, path: "athleticism.stamina")
    let wearFactor = clamp(handlerFatigue * (1.02 - (handlerStamina - 50) / 170), min: 0, max: 0.85)

    let formation = offenseTeam.formation
    let passAroundFormationBoost = (formation == .motion || formation == .fiveOut) ? 1.1 : 0.96
    let pickFormationBoost = (formation == .motion || formation == .fiveOut || formation == .highLow) ? 1.07 : 0.97

    let weights: [(PlayType, Double)] = [
        (.dribbleDrive, max(1, drive) * 1.42 * clamp(1 - wearFactor * 0.55, min: 0.55, max: 1.05)),
        (.postUp, max(1, post) * 1.12 * clamp(1 - wearFactor * 0.32, min: 0.68, max: 1.03)),
        (.pickAndRoll, max(1, pickAndRoll * 0.62 + drive * 0.22 + (100 - shootVsPass) * 0.16) * pickFormationBoost * 0.9 * clamp(1 - wearFactor * 0.38, min: 0.62, max: 1.04)),
        (.pickAndPop, max(1, pickAndPop * 0.62 + passAroundProfile * 0.2 + (100 - shootVsPass) * 0.18) * pickFormationBoost * 0.42 * clamp(1 - wearFactor * 0.3, min: 0.7, max: 1.04)),
        (.passAroundForShot, max(1, passAround) * passAroundFormationBoost * 0.68 * clamp(1 + wearFactor * 0.85, min: 0.96, max: 1.58)),
    ]
    var adjusted: [(PlayType, Double)] = []
    for (type, baseWeight) in weights {
        let interaction: InteractionResult
        switch type {
        case .dribbleDrive:
            interaction = resolveInteractionWithTrace(
                stored: &stored,
                label: "play_type_drive",
                offensePlayer: ballHandler,
                defensePlayer: primaryDefender,
                offenseRatings: ["tendencies.drive", "athleticism.burst", "skills.ballHandling"],
                defenseRatings: ["defense.perimeterDefense", "defense.lateralQuickness", "defense.defensiveControl"],
                random: &random
            )
        case .postUp:
            interaction = resolveInteractionWithTrace(
                stored: &stored,
                label: "play_type_post",
                offensePlayer: ballHandler,
                defensePlayer: primaryDefender,
                offenseRatings: ["tendencies.post", "postGame.postControl", "athleticism.strength"],
                defenseRatings: ["defense.postDefense", "defense.defensiveControl", "athleticism.strength"],
                random: &random
            )
        case .pickAndRoll:
            interaction = resolveInteractionWithTrace(
                stored: &stored,
                label: "play_type_pnr",
                offensePlayer: ballHandler,
                defensePlayer: primaryDefender,
                offenseRatings: ["tendencies.pickAndRoll", "skills.passingVision", "skills.ballHandling"],
                defenseRatings: ["defense.passPerception", "defense.lateralQuickness", "defense.perimeterDefense"],
                random: &random
            )
        case .pickAndPop:
            interaction = resolveInteractionWithTrace(
                stored: &stored,
                label: "play_type_pnp",
                offensePlayer: ballHandler,
                defensePlayer: primaryDefender,
                offenseRatings: ["tendencies.pickAndPop", "skills.passingIQ", "skills.shotIQ"],
                defenseRatings: ["defense.passPerception", "defense.offballDefense", "defense.perimeterDefense"],
                random: &random
            )
        case .passAroundForShot:
            interaction = resolveInteractionWithTrace(
                stored: &stored,
                label: "play_type_motion",
                offensePlayer: ballHandler,
                defensePlayer: primaryDefender,
                offenseRatings: ["skills.passingVision", "skills.passingIQ", "tendencies.shootVsPass"],
                defenseRatings: ["defense.offballDefense", "defense.passPerception", "defense.lateralQuickness"],
                random: &random
            )
        }
        let boost = clamp((logistic(interaction.edge) - 0.5) * 0.9, min: -0.35, max: 0.45)
        adjusted.append((type, max(1, baseWeight * (1 + boost))))
    }

    let total = adjusted.reduce(0) { $0 + $1.1 }
    var pick = random.nextUnit() * max(total, 1)
    for (type, weight) in adjusted {
        pick -= weight
        if pick <= 0 { return type }
    }
    return .dribbleDrive
}

private func resolvePlay(
    stored: inout NativeGameStateStore.StoredState,
    offenseLineup: [Player],
    defenseLineup: [Player],
    ballHandlerIdx: Int,
    defenderIdx: Int,
    team: Team,
    random: inout SeededRandom
) -> PlayOutcome {
    let actionPassDecisionBias = 0.03
    let ballHandler = offenseLineup[ballHandlerIdx]
    let primaryDefender = defenseLineup[min(defenderIdx, defenseLineup.count - 1)]
    let playType = choosePlayType(
        stored: &stored,
        offenseTeam: team,
        ballHandler: ballHandler,
        primaryDefender: primaryDefender,
        random: &random
    )
    let pickActionBallHandlerIdx: Int
    if playType == .pickAndRoll || playType == .pickAndPop {
        pickActionBallHandlerIdx = pickLineupIndexForPickActionBallHandler(
            lineup: offenseLineup,
            random: &random
        )
    } else {
        pickActionBallHandlerIdx = ballHandlerIdx
    }
    let pickActionDefenderIdx = min(pickActionBallHandlerIdx, defenseLineup.count - 1)
    let pickActionBallHandler = offenseLineup[pickActionBallHandlerIdx]

    switch playType {
    case .dribbleDrive:
        // Ball handler attacks the rim. Higher foul draw, shots favor rim.
        let onBallDefender = defenseLineup[defenderIdx]
        let driveInteraction = resolveInteractionWithTrace(
            stored: &stored,
            label: "drive_advantage",
            offensePlayer: ballHandler,
            defensePlayer: onBallDefender,
            offenseRatings: ["athleticism.burst", "skills.ballHandling", "shooting.layups", "tendencies.drive"],
            defenseRatings: ["defense.perimeterDefense", "defense.lateralQuickness", "defense.defensiveControl"],
            random: &random
        )
        let driveControl = logistic(driveInteraction.edge)
        let driveTier: Int
        if driveControl <= 0.28 {
            driveTier = -1 // decisive loss
        } else if driveControl <= 0.5 {
            driveTier = 0 // no clear advantage
        } else if driveControl <= 0.72 {
            driveTier = 1 // wins, but not decisively
        } else {
            driveTier = 2 // decisive win
        }

        // Decisive loss on the drive: on-ball defender gets an active steal chance.
        if driveTier == -1 {
            let stripInteraction = resolveInteractionWithTrace(
                stored: &stored,
                label: "drive_strip",
                offensePlayer: ballHandler,
                defensePlayer: onBallDefender,
                offenseRatings: ["skills.ballHandling", "skills.ballSafety", "skills.hands"],
                defenseRatings: ["defense.steals", "skills.hands", "defense.lateralQuickness"],
                random: &random
            )
            let stripDefenseControl = 1 - logistic(stripInteraction.edge)
            let stealChance = clamp(0.08 + stripDefenseControl * 0.35, min: 0.04, max: 0.36)
            if random.nextUnit() < stealChance {
                return PlayOutcome(
                    shooterLineupIndex: ballHandlerIdx,
                    defenderLineupIndex: defenderIdx,
                    shotType: .midrange,
                    spot: .topMiddle,
                    edgeBonus: -0.12,
                    makeBonus: 0,
                    foulBonus: 0,
                    assistCandidateIndices: nil,
                    assistForceChance: 0.2,
                    isDrive: false,
                    forcedTurnoverStealerLineupIndex: defenderIdx
                )
            }
        }

        // Help-defender chain: after beating the on-ball defender, help can force a kickout.
        // Choose strongest helper, then resolve helper-vs-ballhandler interaction.
        let helpCandidates = defenseLineup.enumerated()
            .filter { $0.offset != defenderIdx }
        let helpIdx = helpCandidates.max { lhs, rhs in
            let l = getRating(lhs.element, path: "defense.offballDefense") * 0.55
                + getRating(lhs.element, path: "defense.shotContest") * 0.3
                + getRating(lhs.element, path: "defense.lateralQuickness") * 0.15
            let r = getRating(rhs.element, path: "defense.offballDefense") * 0.55
                + getRating(rhs.element, path: "defense.shotContest") * 0.3
                + getRating(rhs.element, path: "defense.lateralQuickness") * 0.15
            return l < r
        }?.offset ?? defenderIdx
        let helper = defenseLineup[helpIdx]
        let helpInteraction = resolveInteractionWithTrace(
            stored: &stored,
            label: "help_rotation",
            offensePlayer: ballHandler,
            defensePlayer: helper,
            offenseRatings: ["skills.passingVision", "skills.shotIQ", "skills.ballHandling"],
            defenseRatings: ["defense.offballDefense", "defense.shotContest", "defense.lateralQuickness"],
            random: &random
        )
        let helpDefenseControl = 1 - logistic(helpInteraction.edge)
        let sagBonus: Double
        switch driveTier {
        case 2:
            sagBonus = 0.1 + helpDefenseControl * 0.12
        case 1:
            sagBonus = 0.04 + helpDefenseControl * 0.08
        default:
            sagBonus = helpDefenseControl * 0.05
        }
        let kickChance = clamp(
            0.18 + helpDefenseControl * 0.52 + max(0, driveControl - 0.5) * 0.2 + actionPassDecisionBias,
            min: driveTier == 2 ? 0.28 + actionPassDecisionBias : (driveTier == 1 ? 0.2 + actionPassDecisionBias : 0.12 + actionPassDecisionBias),
            max: driveTier == 2 ? 0.84 : 0.68 + actionPassDecisionBias
        )
        if random.nextUnit() < kickChance && offenseLineup.count > 1 {
            let receiverIdx = evaluatePassTarget(
                offenseLineup: offenseLineup,
                defenseLineup: defenseLineup,
                ballHandlerIdx: ballHandlerIdx,
                random: &random,
                opennessBonus: sagBonus
            )
            let shooter = offenseLineup[receiverIdx]
            let shotDefenderIdx = positionMatchedDefenderIndex(shooter: shooter, defenseLineup: defenseLineup, fallback: receiverIdx)
            let selection = chooseInteractionSpotAndShot(
                stored: &stored,
                shooter: shooter,
                defender: defenseLineup[shotDefenderIdx],
                random: &random
            )
            let spot = selection.spot
            let shotType = selection.shotType
            let kickEdgeBonus = driveTier == 2 ? 0.2 : (driveTier == 1 ? 0.14 : 0.1)
            let kickMakeBonus = driveTier == 2 ? 0.03 : (driveTier == 1 ? 0.015 : 0.01)
            return PlayOutcome(
                shooterLineupIndex: receiverIdx,
                defenderLineupIndex: shotDefenderIdx,
                shotType: shotType,
                spot: spot,
                edgeBonus: kickEdgeBonus, // decisive wins collapse more help than non-decisive wins
                makeBonus: kickMakeBonus,
                foulBonus: 0,
                assistCandidateIndices: [ballHandlerIdx],
                assistForceChance: driveTier == 2 ? 0.82 : 0.73,
                passInterceptionRiskShift: 0.12
            )
        }

        let rimChance = clamp(
            0.34 + driveControl * 0.5 - helpDefenseControl * 0.22,
            min: 0.2,
            max: 0.86
        )
        let takesRim = random.nextUnit() < rimChance
        let nonRimSelection = chooseInteractionSpotAndShot(
            stored: &stored,
            shooter: ballHandler,
            defender: onBallDefender,
            random: &random
        )
        let spot: OffensiveSpot = takesRim ? .middlePaint : nonRimSelection.spot
        let shotType: ShotType
        if takesRim {
            shotType = getRating(ballHandler, path: "shooting.dunks") > getRating(ballHandler, path: "shooting.layups") + 5 && random.nextUnit() < 0.35
                ? .dunk
                : .layup
        } else {
            shotType = nonRimSelection.shotType
        }
        return PlayOutcome(
            shooterLineupIndex: ballHandlerIdx,
            defenderLineupIndex: defenderIdx,
            shotType: shotType,
            spot: spot,
            edgeBonus: driveTier == 2 ? 0.12 : (driveTier == 1 ? 0.08 : (driveTier == 0 ? 0.04 : -0.06)),
            makeBonus: 0,
            foulBonus: takesRim ? (driveTier == 2 ? 0.05 : (driveTier == 1 ? 0.04 : 0.02)) : 0,
            assistCandidateIndices: nil,
            assistForceChance: 0.35,
            isDrive: takesRim
        )

    case .postUp:
        // Pick the best post-capable teammate (maybe the ball handler).
        let postIdx = offenseLineup.indices.max { a, b in
            postScore(offenseLineup[a]) < postScore(offenseLineup[b])
        } ?? ballHandlerIdx
        let shooter = offenseLineup[postIdx]
        let postDefenderIdx = min(postIdx, defenseLineup.count - 1)
        let postDefender = defenseLineup[postDefenderIdx]
        let postAdvantage = resolveInteractionWithTrace(
            stored: &stored,
            label: "post_up_advantage",
            offensePlayer: shooter,
            defensePlayer: postDefender,
            offenseRatings: ["postGame.postControl", "postGame.postHooks", "athleticism.strength", "skills.hands"],
            defenseRatings: ["defense.postDefense", "defense.defensiveControl", "athleticism.strength", "defense.shotContest"],
            random: &random
        )
        let postControl = logistic(postAdvantage.edge)
        let postKickChance = clamp(
            0.22 + (1 - postControl) * 0.4 + actionPassDecisionBias,
            min: 0.2 + actionPassDecisionBias,
            max: 0.62 + actionPassDecisionBias
        )
        if offenseLineup.count > 1 && random.nextUnit() < postKickChance {
            let outletIdx = evaluatePassTarget(
                offenseLineup: offenseLineup,
                defenseLineup: defenseLineup,
                ballHandlerIdx: postIdx,
                random: &random,
                opennessBonus: 0.08 + (1 - postControl) * 0.08
            )
            if outletIdx != postIdx {
                let outletShooter = offenseLineup[outletIdx]
                let outletDefIdx = min(outletIdx, defenseLineup.count - 1)
                let outletSelection = chooseInteractionSpotAndShot(
                    stored: &stored,
                    shooter: outletShooter,
                    defender: defenseLineup[outletDefIdx],
                    random: &random
                )
                let outletSpot = outletSelection.spot
                let outletShot = outletSelection.shotType
                return PlayOutcome(
                    shooterLineupIndex: outletIdx,
                    defenderLineupIndex: outletDefIdx,
                    shotType: outletShot,
                    spot: outletSpot,
                    edgeBonus: 0.09,
                    makeBonus: 0.01,
                    foulBonus: 0,
                    assistCandidateIndices: [postIdx],
                    assistForceChance: 0.72,
                    passInterceptionRiskShift: 0.08
                )
            }
        }
        let spot: OffensiveSpot = random.nextUnit() < 0.5 ? .rightPost : .leftPost
        let hookW = getRating(shooter, path: "postGame.postHooks") * (0.72 + postControl * 0.52)
        let fadeW = getRating(shooter, path: "postGame.postFadeaways") * (0.8 + (1 - postControl) * 0.35)
        let layupW = getRating(shooter, path: "shooting.layups") * (0.65 + postControl * 0.6)
        let dunkW = getRating(shooter, path: "shooting.dunks") * (0.35 + postControl * 0.46)
        let total = hookW + fadeW + layupW + dunkW
        let pick = random.nextUnit() * max(total, 1)
        let shotType: ShotType
        if pick < hookW { shotType = .hook }
        else if pick < hookW + fadeW { shotType = .fadeaway }
        else if pick < hookW + fadeW + layupW { shotType = .layup }
        else { shotType = .dunk }
        return PlayOutcome(
            shooterLineupIndex: postIdx,
            defenderLineupIndex: postDefenderIdx,
            shotType: shotType,
            spot: spot,
            edgeBonus: 0.02 + (postControl - 0.5) * 0.18,
            makeBonus: 0,
            foulBonus: isRimShot(shotType) ? (0.02 + postControl * 0.03) : 0,
            assistCandidateIndices: postIdx == ballHandlerIdx ? nil : [ballHandlerIdx],
            assistForceChance: 0.45,
            passInterceptionRiskShift: postIdx == ballHandlerIdx ? 0 : 0.08
        )

    case .pickAndRoll:
        let screenerIdx = pickScreenerIndex(lineup: offenseLineup, excluding: pickActionBallHandlerIdx, random: &random)
        let screener = offenseLineup[screenerIdx]
        let onBallDefender = defenseLineup[pickActionDefenderIdx]
        let screenerDefenderIdx = min(screenerIdx, defenseLineup.count - 1)
        let screenerDefender = defenseLineup[screenerDefenderIdx]
        let screenEdge = screenEffectiveness(
            ballHandler: pickActionBallHandler,
            screener: screener,
            onBallDefender: onBallDefender,
            screenerDefender: screenerDefender
        )
        let nav = chooseScreenNavigation(
            stored: &stored,
            ballHandler: pickActionBallHandler,
            screener: screener,
            onBallDefender: onBallDefender,
            screenerDefender: screenerDefender,
            screenEdge: screenEdge,
            random: &random
        )
        return resolvePickAndRollOutcome(
            stored: &stored,
            offenseLineup: offenseLineup,
            defenseLineup: defenseLineup,
            ballHandlerIdx: pickActionBallHandlerIdx,
            defenderIdx: pickActionDefenderIdx,
            screenerIdx: screenerIdx,
            screenerDefenderIdx: screenerDefenderIdx,
            screenEdge: screenEdge,
            navigation: nav,
            random: &random
        )

    case .pickAndPop:
        let screenerIdx = pickScreenerIndex(lineup: offenseLineup, excluding: pickActionBallHandlerIdx, random: &random)
        let screener = offenseLineup[screenerIdx]
        let onBallDefender = defenseLineup[pickActionDefenderIdx]
        let screenerDefenderIdx = min(screenerIdx, defenseLineup.count - 1)
        let screenerDefender = defenseLineup[screenerDefenderIdx]
        let screenEdge = screenEffectiveness(
            ballHandler: pickActionBallHandler,
            screener: screener,
            onBallDefender: onBallDefender,
            screenerDefender: screenerDefender
        )
        let popDest = choosePopDestination(
            stored: &stored,
            screener: screener,
            closeoutDefender: screenerDefender,
            random: &random
        )
        let popRead = resolveInteractionWithTrace(
            stored: &stored,
            label: "pick_pop_read",
            offensePlayer: pickActionBallHandler,
            defensePlayer: onBallDefender,
            offenseRatings: ["skills.passingVision", "skills.passingIQ", "skills.shotIQ"],
            defenseRatings: ["defense.passPerception", "defense.lateralQuickness", "defense.perimeterDefense"],
            random: &random
        )
        let popReadControl = logistic(popRead.edge)
        let ballHandlerPassLean = clamp(
            0.55
                + (50 - getRating(pickActionBallHandler, path: "tendencies.shootVsPass")) / 150
                + (getRating(pickActionBallHandler, path: "skills.passingVision") - 50) / 300,
            min: 0.4,
            max: 0.82
        )
        let offBallKickChance = clamp(
            0.2 + popReadControl * 0.38 + ballHandlerPassLean * 0.14 + max(0, screenEdge) * 0.08 + actionPassDecisionBias,
            min: 0.18 + actionPassDecisionBias,
            max: 0.62 + actionPassDecisionBias
        )
        let alternateShooterIdx: Int? = {
            guard offenseLineup.count > 2 && random.nextUnit() < offBallKickChance else { return nil }
            let idx = evaluatePassTarget(
                offenseLineup: offenseLineup,
                defenseLineup: defenseLineup,
                ballHandlerIdx: pickActionBallHandlerIdx,
                random: &random
            )
            return (idx != pickActionBallHandlerIdx && idx != screenerIdx) ? idx : nil
        }()
        if let receiverIdx = alternateShooterIdx {
            let shooter = offenseLineup[receiverIdx]
            let receiverDefIdx = min(receiverIdx, defenseLineup.count - 1)
            let selection = chooseInteractionSpotAndShot(
                stored: &stored,
                shooter: shooter,
                defender: defenseLineup[receiverDefIdx],
                random: &random
            )
            let spot = selection.spot
            let shotType = selection.shotType
            return PlayOutcome(
                shooterLineupIndex: receiverIdx,
                defenderLineupIndex: receiverDefIdx,
                shotType: shotType,
                spot: spot,
                edgeBonus: screenEdge * 0.22 + 0.08,
                makeBonus: 0.02,
                foulBonus: 0,
                assistCandidateIndices: [pickActionBallHandlerIdx],
                assistForceChance: 0.74
            )
        }
        return PlayOutcome(
            shooterLineupIndex: screenerIdx,
            defenderLineupIndex: screenerDefenderIdx,
            shotType: popDest.shotType,
            spot: popDest.spot,
            edgeBonus: screenEdge * 0.35 + popDest.edgeBonus,
            makeBonus: 0.02,
            foulBonus: 0,
            assistCandidateIndices: [pickActionBallHandlerIdx],
            assistForceChance: 0.72
        )

    case .passAroundForShot:
        // Creation vs shell defense decides if this generates an advantaged teammate shot.
        let shellDefender = defenseLineup[defenderIdx]
        let creation = resolveInteractionWithTrace(
            stored: &stored,
            label: "pass_around_creation",
            offensePlayer: ballHandler,
            defensePlayer: shellDefender,
            offenseRatings: ["skills.passingVision", "skills.passingIQ", "skills.ballHandling"],
            defenseRatings: ["defense.offballDefense", "defense.passPerception", "defense.lateralQuickness"],
            random: &random
        )
        let creationControl = logistic(creation.edge)
        if creationControl < 0.32 {
            let fallbackSelection = chooseInteractionSpotAndShot(
                stored: &stored,
                shooter: ballHandler,
                defender: defenseLineup[defenderIdx],
                random: &random
            )
            let fallbackSpot = fallbackSelection.spot
            let fallbackShot = fallbackSelection.shotType
            return PlayOutcome(
                shooterLineupIndex: ballHandlerIdx,
                defenderLineupIndex: defenderIdx,
                shotType: fallbackShot,
                spot: fallbackSpot,
                edgeBonus: -0.03,
                makeBonus: 0,
                foulBonus: 0,
                assistCandidateIndices: nil,
                assistForceChance: 0.2
            )
        }
        // Ball moves to the teammate with the highest open-shot expected value after relocation.
        let receiverIdx = evaluatePassTarget(
            offenseLineup: offenseLineup,
            defenseLineup: defenseLineup,
            ballHandlerIdx: ballHandlerIdx,
            random: &random,
            opennessBonus: (creationControl - 0.5) * 0.18
        )
        let shooter = offenseLineup[receiverIdx]
        let shotDefenderIdx = min(receiverIdx, defenseLineup.count - 1)
        let selection = chooseInteractionSpotAndShot(
            stored: &stored,
            shooter: shooter,
            defender: defenseLineup[shotDefenderIdx],
            random: &random
        )
        let spot = selection.spot
        let shotType = selection.shotType
        return PlayOutcome(
            shooterLineupIndex: receiverIdx,
            defenderLineupIndex: shotDefenderIdx,
            shotType: shotType,
            spot: spot,
            edgeBonus: 0.06 + (creationControl - 0.5) * 0.2,
            makeBonus: 0.02,
            foulBonus: 0,
            assistCandidateIndices: nil,
            assistForceChance: 0.75,
            passInterceptionRiskShift: -0.22
        )
    }
}

private func zoneDistanceAdvantage(spot: OffensiveSpot, scheme: DefenseScheme) -> Double {
    switch scheme {
    case .manToMan:
        return 0
    case .zone23:
        // 2-3 packs the paint; weak on perimeter, especially corners.
        switch spot {
        case .leftCorner, .rightCorner: return 0.08
        case .topRight, .topLeft, .topMiddle: return 0.04
        case .middlePaint, .rightPost, .leftPost: return -0.06
        default: return 0
        }
    case .zone32:
        // 3-2 covers perimeter; weak on baseline / high post.
        switch spot {
        case .leftCorner, .rightCorner: return -0.03
        case .topMiddle: return -0.06
        case .middlePaint: return 0.05
        case .rightPost, .leftPost: return 0.04
        default: return 0
        }
    case .zone131:
        switch spot {
        case .leftCorner, .rightCorner: return 0.06
        case .middlePaint: return -0.04
        case .rightElbow, .leftElbow: return 0.05
        default: return 0
        }
    case .packLine:
        // Pack-line gives up threes, squeezes inside.
        switch spot {
        case .topRight, .topLeft, .topMiddle, .rightCorner, .leftCorner: return 0.05
        case .middlePaint, .rightPost, .leftPost: return -0.05
        default: return 0
        }
    }
}

private func positionMatchedDefenderIndex(shooter: Player, defenseLineup: [Player], fallback: Int) -> Int {
    let target = shooter.bio.position.rawValue
    for (idx, defender) in defenseLineup.enumerated() where defender.bio.position.rawValue == target {
        return idx
    }
    return min(fallback, max(0, defenseLineup.count - 1))
}

private func postScore(_ player: Player) -> Double {
    getBaseRating(player, path: "postGame.postControl") * 0.5
        + getBaseRating(player, path: "postGame.postHooks") * 0.3
        + getBaseRating(player, path: "tendencies.post") * 0.2
}

private func evaluatePassTarget(
    offenseLineup: [Player],
    defenseLineup: [Player],
    ballHandlerIdx: Int,
    random: inout SeededRandom,
    opennessBonus: Double = 0
) -> Int {
    var bestIdx = ballHandlerIdx
    var bestScore = -Double.infinity
    for idx in offenseLineup.indices where idx != ballHandlerIdx {
        let player = offenseLineup[idx]
        // Off-ball movement proxy: players with high offballOffense + hustle relocate to openings.
        let movement = getRating(player, path: "skills.offballOffense") * 0.55
            + getRating(player, path: "skills.hustle") * 0.25
            + getRating(player, path: "athleticism.burst") * 0.2
        // Expected shot value: blend of three/mid/close shooting × position tendency.
        let threeRating = getRating(player, path: "shooting.threePointShooting")
        let midRating = getRating(player, path: "shooting.midrangeShot")
        let closeRating = getRating(player, path: "shooting.closeShot")
        let shotEV = 3 * clamp(0.3 + (threeRating - 55) / 260, min: 0.18, max: 0.5)
            + 2 * clamp(0.34 + (midRating - 55) / 260, min: 0.22, max: 0.55)
            + 2 * clamp(0.42 + (closeRating - 55) / 220, min: 0.28, max: 0.65)
        let shotUtility = shotEV / 3
        // Defensive pressure from the matched defender (by lineup slot proximity).
        let defenderIdx = min(idx, defenseLineup.count - 1)
        let defender = defenseLineup[defenderIdx]
        let defensivePressure = getRating(defender, path: "defense.shotContest") * 0.35
            + getRating(defender, path: "defense.perimeterDefense") * 0.25
            + getRating(defender, path: "defense.offballDefense") * 0.4
        let openness = clamp((movement - defensivePressure) / 60 + opennessBonus, min: -0.4, max: 0.92)
        let passRisk = clamp((getRating(defender, path: "defense.passPerception") - 55) / 220, min: 0, max: 0.15)
        let fatigue = clamp((100 - player.condition.energy) / 100, min: 0, max: 0.92)
        let stamina = getBaseRating(player, path: "athleticism.stamina")
        let fatigueTax = fatigue * clamp(8.8 - (stamina - 50) / 14, min: 6.5, max: 11.5)
        let score = shotUtility * 12 + openness * 18 - passRisk * 8 - fatigueTax + random.nextUnit() * 2
        if score > bestScore {
            bestScore = score
            bestIdx = idx
        }
    }
    return bestIdx
}

private func openShotUtility(_ player: Player) -> Double {
    getBaseRating(player, path: "skills.shotIQ") * 0.25
        + getBaseRating(player, path: "shooting.threePointShooting") * 0.35
        + getBaseRating(player, path: "shooting.midrangeShot") * 0.2
        + getBaseRating(player, path: "skills.offballOffense") * 0.2
}

private func pickScreenerIndex(lineup: [Player], excluding: Int, random: inout SeededRandom) -> Int {
    let candidates = lineup.indices.filter { $0 != excluding }
    guard !candidates.isEmpty else { return excluding }

    let weights = candidates.map { idx -> Double in
        let p = lineup[idx]
        let base = getBaseRating(p, path: "athleticism.strength") * 0.58
            + getBaseRating(p, path: "postGame.postControl") * 0.17
            + getBaseRating(p, path: "skills.offballOffense") * 0.14
            + getBaseRating(p, path: "skills.hands") * 0.11
        let positionMultiplier: Double
        if isFourFiveLike(p) {
            positionMultiplier = 2.9
        } else if p.bio.position == .f || p.bio.position == .sf || p.bio.position == .wing {
            positionMultiplier = 0.8
        } else {
            positionMultiplier = 0.18
        }
        return max(0.1, base * positionMultiplier)
    }
    return candidates[weightedChoiceIndex(weights: weights, random: &random)]
}

private enum ScreenNavigation {
    case over, under, switchSwitch, ice
}

private func chooseScreenNavigation(
    stored: inout NativeGameStateStore.StoredState,
    ballHandler: Player,
    screener: Player,
    onBallDefender: Player,
    screenerDefender: Player,
    screenEdge: Double,
    random: inout SeededRandom
) -> ScreenNavigation {
    let pointInteraction = resolveInteractionWithTrace(
        stored: &stored,
        label: "screen_navigation_point",
        offensePlayer: ballHandler,
        defensePlayer: onBallDefender,
        offenseRatings: ["skills.ballHandling", "athleticism.agility", "skills.shotIQ"],
        defenseRatings: ["defense.perimeterDefense", "defense.lateralQuickness", "skills.shotIQ"],
        random: &random
    )
    let bigInteraction = resolveInteractionWithTrace(
        stored: &stored,
        label: "screen_navigation_big",
        offensePlayer: screener,
        defensePlayer: screenerDefender,
        offenseRatings: ["athleticism.strength", "skills.offballOffense", "skills.hands"],
        defenseRatings: ["defense.defensiveControl", "athleticism.strength", "defense.lateralQuickness"],
        random: &random
    )
    let offenseControl = clamp(logistic(pointInteraction.edge * 0.62 + bigInteraction.edge * 0.38 + screenEdge * 0.4), min: 0.05, max: 0.95)
    let defenseControl = 1 - offenseControl
    let overWeight = max(1, defenseControl * 55 + getBaseRating(onBallDefender, path: "defense.perimeterDefense") * 0.18)
    let underWeight = max(1, defenseControl * 28 + getBaseRating(onBallDefender, path: "skills.shotIQ") * 0.1)
    let switchWeight = max(1, offenseControl * 48 + getBaseRating(screenerDefender, path: "defense.lateralQuickness") * 0.22)
    let iceWeight = max(1, defenseControl * 36 + getBaseRating(onBallDefender, path: "defense.shotContest") * 0.16)
    let total = overWeight + underWeight + switchWeight + iceWeight
    var pick = random.nextUnit() * max(total, 1)
    pick -= overWeight; if pick <= 0 { return .over }
    pick -= underWeight; if pick <= 0 { return .under }
    pick -= switchWeight; if pick <= 0 { return .switchSwitch }
    return .ice
}

private func resolvePickAndRollOutcome(
    stored: inout NativeGameStateStore.StoredState,
    offenseLineup: [Player],
    defenseLineup: [Player],
    ballHandlerIdx: Int,
    defenderIdx: Int,
    screenerIdx: Int,
    screenerDefenderIdx: Int,
    screenEdge: Double,
    navigation: ScreenNavigation,
    random: inout SeededRandom
) -> PlayOutcome {
    let ballHandler = offenseLineup[ballHandlerIdx]
    let screener = offenseLineup[screenerIdx]
    let onBallDefender = defenseLineup[defenderIdx]
    let screenerDefender = defenseLineup[screenerDefenderIdx]
    let pnrPassDecisionBias = 0.03
    let passLean = clamp(
        0.55
            + (50 - getRating(ballHandler, path: "tendencies.shootVsPass")) / 150
            + (getRating(ballHandler, path: "skills.passingVision") - 50) / 300,
        min: 0.4,
        max: 0.82
    )

    switch navigation {
    case .over:
        // Ball handler drives off the screen; roller threat pulls help.
        let rollerSeal = resolveInteractionWithTrace(
            stored: &stored,
            label: "roller_seal",
            offensePlayer: screener,
            defensePlayer: screenerDefender,
            offenseRatings: ["postGame.postControl", "athleticism.strength", "skills.hands"],
            defenseRatings: ["defense.postDefense", "defense.defensiveControl", "athleticism.strength"],
            random: &random
        )
        let handlerRead = resolveInteractionWithTrace(
            stored: &stored,
            label: "pnr_handler_read",
            offensePlayer: ballHandler,
            defensePlayer: onBallDefender,
            offenseRatings: ["skills.passingVision", "skills.passingIQ", "skills.ballHandling"],
            defenseRatings: ["defense.passPerception", "defense.lateralQuickness", "defense.perimeterDefense"],
            random: &random
        )
        let rollerFinishChance = clamp(
            0.18
                + logistic(rollerSeal.edge + screenEdge * 0.45) * 0.46
                + logistic(handlerRead.edge) * 0.12
                + (passLean - 0.55) * 0.16,
            min: 0.2,
            max: 0.78
        )
        if random.nextUnit() < rollerFinishChance {
            let takesDunk = getRating(screener, path: "shooting.dunks") > 65 && random.nextUnit() < 0.45
            return PlayOutcome(
                shooterLineupIndex: screenerIdx,
                defenderLineupIndex: screenerDefenderIdx,
                shotType: takesDunk ? .dunk : .layup,
                spot: .middlePaint,
                edgeBonus: screenEdge * 0.4 + 0.1,
                makeBonus: 0.04,
                foulBonus: 0.03,
                assistCandidateIndices: [ballHandlerIdx],
                assistForceChance: 0.82,
                isDrive: false
            )
        }
        if random.nextUnit() < clamp(0.14 + passLean * 0.42 + pnrPassDecisionBias, min: 0.2 + pnrPassDecisionBias, max: 0.56 + pnrPassDecisionBias) {
            let receiverIdx = evaluatePassTarget(
                offenseLineup: offenseLineup,
                defenseLineup: defenseLineup,
                ballHandlerIdx: ballHandlerIdx,
                random: &random
            )
            let shooter = offenseLineup[receiverIdx]
            let receiverDefIdx = min(receiverIdx, defenseLineup.count - 1)
            let selection = chooseInteractionSpotAndShot(
                stored: &stored,
                shooter: shooter,
                defender: defenseLineup[receiverDefIdx],
                random: &random
            )
            let spot = selection.spot
            let shotType = selection.shotType
            return PlayOutcome(
                shooterLineupIndex: receiverIdx,
                defenderLineupIndex: receiverDefIdx,
                shotType: shotType,
                spot: spot,
                edgeBonus: screenEdge * 0.24 + 0.06,
                makeBonus: 0.02,
                foulBonus: 0,
                assistCandidateIndices: [ballHandlerIdx],
                assistForceChance: 0.72,
                isDrive: false
            )
        }
        return PlayOutcome(
            shooterLineupIndex: ballHandlerIdx,
            defenderLineupIndex: defenderIdx,
            shotType: .layup,
            spot: .middlePaint,
            edgeBonus: screenEdge * 0.32,
            makeBonus: 0.03,
            foulBonus: 0.04,
            assistCandidateIndices: nil,
            assistForceChance: 0.3,
            isDrive: true
        )
    case .under:
        // Defender drops → open pull-up three or midrange for ball handler.
        let threeRating = getRating(ballHandler, path: "shooting.threePointShooting")
        let midRating = getRating(ballHandler, path: "shooting.midrangeShot")
        let shootsThree = threeRating >= midRating - 4
        let shotType: ShotType = shootsThree ? .three : .midrange
        let spot: OffensiveSpot = shootsThree ? .topMiddle : .rightElbow
        if offenseLineup.count > 1 && random.nextUnit() < clamp(0.22 + passLean * 0.5 + pnrPassDecisionBias, min: 0.28 + pnrPassDecisionBias, max: 0.7) {
            let receiverIdx = evaluatePassTarget(
                offenseLineup: offenseLineup,
                defenseLineup: defenseLineup,
                ballHandlerIdx: ballHandlerIdx,
                random: &random
            )
            let shooter = offenseLineup[receiverIdx]
            let receiverDefIdx = min(receiverIdx, defenseLineup.count - 1)
            let selection = chooseInteractionSpotAndShot(
                stored: &stored,
                shooter: shooter,
                defender: defenseLineup[receiverDefIdx],
                random: &random
            )
            let spot = selection.spot
            let shotType = selection.shotType
            return PlayOutcome(
                shooterLineupIndex: receiverIdx,
                defenderLineupIndex: receiverDefIdx,
                shotType: shotType,
                spot: spot,
                edgeBonus: screenEdge * 0.16 + 0.08,
                makeBonus: 0.02,
                foulBonus: 0,
                assistCandidateIndices: [ballHandlerIdx],
                assistForceChance: 0.7
            )
        }
        return PlayOutcome(
            shooterLineupIndex: ballHandlerIdx,
            defenderLineupIndex: defenderIdx,
            shotType: shotType,
            spot: spot,
            edgeBonus: screenEdge * 0.2 + 0.1,
            makeBonus: 0.03,
            foulBonus: 0,
            assistCandidateIndices: nil,
            assistForceChance: 0.25
        )
    case .switchSwitch:
        // Mismatch: if ball handler is notably quicker than big, attack. Else post the small.
        let handlerBurst = getRating(ballHandler, path: "athleticism.burst")
        let bigBurst = getRating(defenseLineup[min(screenerDefenderIdx, defenseLineup.count - 1)], path: "athleticism.burst")
        if handlerBurst > bigBurst + 8 {
            if offenseLineup.count > 1 && random.nextUnit() < clamp(0.18 + passLean * 0.4 + pnrPassDecisionBias, min: 0.22 + pnrPassDecisionBias, max: 0.58 + pnrPassDecisionBias) {
                let receiverIdx = evaluatePassTarget(
                    offenseLineup: offenseLineup,
                    defenseLineup: defenseLineup,
                    ballHandlerIdx: ballHandlerIdx,
                    random: &random
                )
                let shooter = offenseLineup[receiverIdx]
                let receiverDefIdx = min(receiverIdx, defenseLineup.count - 1)
                let selection = chooseInteractionSpotAndShot(
                    stored: &stored,
                    shooter: shooter,
                    defender: defenseLineup[receiverDefIdx],
                    random: &random
                )
                let spot = selection.spot
                let shotType = selection.shotType
                return PlayOutcome(
                    shooterLineupIndex: receiverIdx,
                    defenderLineupIndex: receiverDefIdx,
                    shotType: shotType,
                    spot: spot,
                    edgeBonus: 0.14,
                    makeBonus: 0.02,
                    foulBonus: 0,
                    assistCandidateIndices: [ballHandlerIdx],
                    assistForceChance: 0.68
                )
            }
            return PlayOutcome(
                shooterLineupIndex: ballHandlerIdx,
                defenderLineupIndex: screenerDefenderIdx,
                shotType: .layup,
                spot: .middlePaint,
                edgeBonus: 0.2,
                makeBonus: 0.04,
                foulBonus: 0.04,
                assistCandidateIndices: nil,
                assistForceChance: 0.3,
                isDrive: true
            )
        } else {
            // Screener posts up the smaller defender.
            let shotType: ShotType = random.nextUnit() < 0.55 ? .hook : .fadeaway
            return PlayOutcome(
                shooterLineupIndex: screenerIdx,
                defenderLineupIndex: defenderIdx,
                shotType: shotType,
                spot: random.nextUnit() < 0.5 ? .leftPost : .rightPost,
                edgeBonus: 0.12,
                makeBonus: 0.02,
                foulBonus: 0.02,
                assistCandidateIndices: [ballHandlerIdx],
                assistForceChance: 0.6
            )
        }
    case .ice:
        // Defense cuts off the middle; ball handler forced sideline → tough midrange or reset to a passer.
        if random.nextUnit() < clamp(0.58 + (passLean - 0.55) * 0.25 + pnrPassDecisionBias, min: 0.42 + pnrPassDecisionBias, max: 0.72) {
            // Reset pass to best-open teammate for a shot.
            let receiverIdx = offenseLineup.indices
                .filter { $0 != ballHandlerIdx && $0 != screenerIdx }
                .max { a, b in openShotUtility(offenseLineup[a]) < openShotUtility(offenseLineup[b]) }
                ?? ballHandlerIdx
            let shooter = offenseLineup[receiverIdx]
            let receiverDefIdx = min(receiverIdx, defenseLineup.count - 1)
            let selection = chooseInteractionSpotAndShot(
                stored: &stored,
                shooter: shooter,
                defender: defenseLineup[receiverDefIdx],
                random: &random
            )
            let spot = selection.spot
            let shotType = selection.shotType
            return PlayOutcome(
                shooterLineupIndex: receiverIdx,
                defenderLineupIndex: receiverDefIdx,
                shotType: shotType,
                spot: spot,
                edgeBonus: 0.06,
                makeBonus: 0.01,
                foulBonus: 0,
                assistCandidateIndices: [ballHandlerIdx],
                assistForceChance: 0.6
            )
        }
        return PlayOutcome(
            shooterLineupIndex: ballHandlerIdx,
            defenderLineupIndex: defenderIdx,
            shotType: .midrange,
            spot: random.nextUnit() < 0.5 ? .rightElbow : .leftElbow,
            edgeBonus: -0.08,
            makeBonus: -0.02,
            foulBonus: 0,
            assistCandidateIndices: nil,
            assistForceChance: 0.2
        )
    }
}

private struct PopDestination {
    var shotType: ShotType
    var spot: OffensiveSpot
    var edgeBonus: Double
}

private func choosePopDestination(
    stored: inout NativeGameStateStore.StoredState,
    screener: Player,
    closeoutDefender: Player,
    random: inout SeededRandom
) -> PopDestination {
    // Compare expected value: midrange (2 * mid_make_prob) vs three (3 * three_make_prob)
    let popChoiceInteraction = resolveInteractionWithTrace(
        stored: &stored,
        label: "pop_destination",
        offensePlayer: screener,
        defensePlayer: closeoutDefender,
        offenseRatings: ["shooting.threePointShooting", "shooting.midrangeShot", "skills.shotIQ"],
        defenseRatings: ["defense.shotContest", "defense.perimeterDefense", "defense.lateralQuickness"],
        random: &random
    )
    let popControl = logistic(popChoiceInteraction.edge)
    let midRating = getRating(screener, path: "shooting.midrangeShot")
    let threeRating = getRating(screener, path: "shooting.threePointShooting")
    let midEV = 2 * clamp(0.32 + (midRating - 55) / 250 + (0.5 - popControl) * 0.06, min: 0.25, max: 0.58)
    let threeEV = 3 * clamp(0.28 + (threeRating - 55) / 300 + (popControl - 0.5) * 0.07, min: 0.2, max: 0.52)
    if threeEV > midEV + 0.1 {
        let spot: OffensiveSpot = random.nextUnit() < 0.5 ? .topRight : .topLeft
        return PopDestination(shotType: .three, spot: spot, edgeBonus: 0.02)
    } else if midEV > threeEV + 0.05 {
        let spot: OffensiveSpot = random.nextUnit() < 0.5 ? .rightElbow : .leftElbow
        return PopDestination(shotType: .midrange, spot: spot, edgeBonus: 0.03)
    }
    // Toss-up: 50/50
    if random.nextUnit() < 0.5 {
        return PopDestination(shotType: .three, spot: .topMiddle, edgeBonus: 0)
    }
    return PopDestination(shotType: .midrange, spot: .rightElbow, edgeBonus: 0)
}

private func screenEffectiveness(
    ballHandler: Player,
    screener: Player,
    onBallDefender: Player,
    screenerDefender: Player
) -> Double {
    let offense = getBaseRating(screener, path: "athleticism.strength") * 0.55
        + getBaseRating(ballHandler, path: "skills.ballHandling") * 0.25
        + getBaseRating(ballHandler, path: "athleticism.agility") * 0.2
    let defense = (
        getBaseRating(onBallDefender, path: "defense.lateralQuickness")
        + getBaseRating(onBallDefender, path: "defense.perimeterDefense")
        + getBaseRating(screenerDefender, path: "defense.defensiveControl")
        + getBaseRating(screenerDefender, path: "athleticism.strength")
    ) / 4
    return clamp((offense - defense) / 100, min: -0.5, max: 0.8)
}

// MARK: - Dead balls, timeouts, clutch, formation, fouls

private func isDeadBall(eventType: String) -> Bool {
    switch eventType {
    case "made_shot", "foul", "turnover", "turnover_shot_clock", "bonus_foul",
         "charge", "loose_ball_foul", "non_shooting_foul", "technical_foul":
        return true
    default:
        return false
    }
}

private func maybeCallTechnicalFoul(stored: inout NativeGameStateStore.StoredState, random: inout SeededRandom) {
    guard stored.teams.count >= 2 else { return }
    let firstLineup = stored.teams[0].activeLineup
    let secondLineup = stored.teams[1].activeLineup
    guard !firstLineup.isEmpty, !secondLineup.isEmpty else { return }

    func candidateForTechnical(teamId: Int, opponentTeamId: Int) -> (lineupIdx: Int, chance: Double)? {
        let lineup = stored.teams[teamId].activeLineup
        let opponentLineup = stored.teams[opponentTeamId].activeLineup
        guard !lineup.isEmpty, !opponentLineup.isEmpty else { return nil }

        var bestIdx = 0
        var bestRisk = -1.0
        for idx in lineup.indices {
            let player = lineup[idx]
            let boxIdx = idx < stored.teams[teamId].activeLineupBoxIndices.count ? stored.teams[teamId].activeLineupBoxIndices[idx] : -1
            let fouls = (boxIdx >= 0 && boxIdx < stored.teams[teamId].boxPlayers.count) ? stored.teams[teamId].boxPlayers[boxIdx].fouls : 0
            let risk = clamp(
                (100 - player.condition.energy) * 0.5
                    + Double(fouls) * 12
                    + (100 - getBaseRating(player, path: "skills.shotIQ")) * 0.25
                    + (100 - getBaseRating(player, path: "skills.clutch")) * 0.2,
                min: 0,
                max: 120
            )
            if risk > bestRisk {
                bestRisk = risk
                bestIdx = idx
            }
        }

        let irritant = opponentLineup[min(bestIdx, opponentLineup.count - 1)]
        let composureInteraction = resolveInteractionWithTrace(
            stored: &stored,
            label: "technical_temper",
            offensePlayer: lineup[bestIdx],
            defensePlayer: irritant,
            offenseRatings: ["skills.shotIQ", "skills.clutch", "skills.ballSafety"],
            defenseRatings: ["defense.defensiveControl", "skills.hustle", "defense.offballDefense"],
            random: &random
        )
        let temperDefenseControl = 1 - logistic(composureInteraction.edge)
        let riskComponent = bestRisk / 120
        let chance = clamp(0.0004 + temperDefenseControl * 0.0026 + riskComponent * 0.0014, min: 0.0002, max: 0.005)
        return (bestIdx, chance)
    }

    guard
        let first = candidateForTechnical(teamId: 0, opponentTeamId: 1),
        let second = candidateForTechnical(teamId: 1, opponentTeamId: 0)
    else { return }

    let offender = first.chance >= second.chance
        ? (teamId: 0, lineupIdx: first.lineupIdx, chance: first.chance)
        : (teamId: 1, lineupIdx: second.lineupIdx, chance: second.chance)
    guard offender.chance >= 0.0025 else { return }
    let offendingTeamId = offender.teamId
    let offendingLineupIdx = offender.lineupIdx
    let benefitingTeamId = offendingTeamId == 0 ? 1 : 0
    guard !stored.teams[benefitingTeamId].activeLineup.isEmpty else { return }
    // Pick best FT shooter on the benefiting team's floor.
    let lineup = stored.teams[benefitingTeamId].activeLineup
    var bestIdx = 0
    var bestFT = -1.0
    for (idx, player) in lineup.enumerated() {
        let ft = getBaseRating(player, path: "shooting.freeThrows")
        if ft > bestFT { bestFT = ft; bestIdx = idx }
    }
    let shooter = lineup[bestIdx]
    let made = random.nextUnit() < freeThrowMakeProbability(
        stored: &stored,
        shooter: shooter,
        defenseTeamId: offendingTeamId,
        label: "free_throw_focus_technical",
        random: &random
    )
    let ftMade = made ? 1 : 0
    addPlayerStat(stored: &stored, teamId: benefitingTeamId, lineupIndex: bestIdx) { line in
        line.ftAttempts += 1
        line.ftMade += ftMade
        line.points += ftMade
    }
    if ftMade > 0 {
        stored.teams[benefitingTeamId].score += ftMade
        applyPlusMinus(stored: &stored, scoringTeamId: benefitingTeamId, points: ftMade)
    }
    // Tag the highest-risk on-floor player as the offender.
    addPlayerStat(stored: &stored, teamId: offendingTeamId, lineupIndex: offendingLineupIdx) { $0.fouls += 1 }
    if offendingTeamId >= 0, offendingTeamId < stored.teamFoulsInHalf.count {
        stored.teamFoulsInHalf[offendingTeamId] += 1
    }
}

private func maybeCallTimeout(stored: inout NativeGameStateStore.StoredState, teamId: Int, random: inout SeededRandom) {
    guard teamId >= 0, teamId < stored.teams.count else { return }
    guard stored.teams[teamId].team.timeouts > 0 else { return }
    let oppId = teamId == 0 ? 1 : 0
    let scoreDelta = stored.teams[teamId].score - stored.teams[oppId].score
    // Use timeout when down by a lot late, or when starters are gassed.
    let lateAndTrailing = stored.gameClockRemaining < 240 && scoreDelta < -6
    let starterTired = stored.teams[teamId].activeLineup.contains { ($0.condition.energy) < 45 }
    guard !stored.teams[teamId].activeLineup.isEmpty, !stored.teams[oppId].activeLineup.isEmpty else { return }
    let tiredIdx = stored.teams[teamId].activeLineup.enumerated().min { $0.element.condition.energy < $1.element.condition.energy }?.offset ?? 0
    let pressureIdx = stored.teams[oppId].activeLineup.enumerated().max { lhs, rhs in
        let l = getBaseRating(lhs.element, path: "defense.offballDefense") * 0.4
            + getBaseRating(lhs.element, path: "defense.defensiveControl") * 0.35
            + getBaseRating(lhs.element, path: "skills.hustle") * 0.25
        let r = getBaseRating(rhs.element, path: "defense.offballDefense") * 0.4
            + getBaseRating(rhs.element, path: "defense.defensiveControl") * 0.35
            + getBaseRating(rhs.element, path: "skills.hustle") * 0.25
        return l < r
    }?.offset ?? 0
    let timeoutInteraction = resolveInteractionWithTrace(
        stored: &stored,
        label: "timeout_pressure",
        offensePlayer: stored.teams[teamId].activeLineup[tiredIdx],
        defensePlayer: stored.teams[oppId].activeLineup[pressureIdx],
        offenseRatings: ["skills.shotIQ", "skills.clutch", "skills.ballSafety"],
        defenseRatings: ["defense.offballDefense", "defense.defensiveControl", "skills.hustle"],
        random: &random
    )
    let timeoutNeed = 1 - logistic(timeoutInteraction.edge)
    if lateAndTrailing && timeoutNeed > 0.42 {
        stored.teams[teamId].team.timeouts -= 1
        recoverTeam(stored: &stored, teamId: teamId, amount: 18)
    } else if starterTired && timeoutNeed > 0.62 {
        stored.teams[teamId].team.timeouts -= 1
        recoverTeam(stored: &stored, teamId: teamId, amount: 12)
    }
}

private func recoverTeam(stored: inout NativeGameStateStore.StoredState, teamId: Int, amount: Double) {
    for idx in stored.teams[teamId].activeLineup.indices {
        let boxIndex = stored.teams[teamId].activeLineupBoxIndices[idx]
        if boxIndex >= 0, boxIndex < stored.teams[teamId].boxPlayers.count {
            let current = stored.teams[teamId].boxPlayers[boxIndex].energy ?? 100
            let next = min(100, current + amount)
            stored.teams[teamId].boxPlayers[boxIndex].energy = next
            stored.teams[teamId].activeLineup[idx].condition.energy = next
            if boxIndex < stored.teams[teamId].team.players.count {
                stored.teams[teamId].team.players[boxIndex].condition.energy = next
            }
        }
    }
}

private func recoverAllPlayersForHalftime(stored: inout NativeGameStateStore.StoredState) {
    for teamId in stored.teams.indices {
        for boxIndex in stored.teams[teamId].boxPlayers.indices {
            let current = stored.teams[teamId].boxPlayers[boxIndex].energy ?? 100
            let next = min(100, current + 26)
            stored.teams[teamId].boxPlayers[boxIndex].energy = next
            if boxIndex < stored.teams[teamId].team.players.count {
                stored.teams[teamId].team.players[boxIndex].condition.energy = next
            }
        }
        for idx in stored.teams[teamId].activeLineup.indices {
            let boxIndex = stored.teams[teamId].activeLineupBoxIndices[idx]
            if boxIndex >= 0, boxIndex < stored.teams[teamId].boxPlayers.count {
                stored.teams[teamId].activeLineup[idx].condition.energy = stored.teams[teamId].boxPlayers[boxIndex].energy ?? 100
            }
        }
    }
}

private func syncClutchTime(stored: inout NativeGameStateStore.StoredState) {
    let isLastPeriod = stored.currentHalf >= 2
    let scoreDelta = abs(stored.teams[0].score - stored.teams[1].score)
    let isClutch = isLastPeriod && stored.gameClockRemaining <= 300 && scoreDelta <= 8
    for teamId in stored.teams.indices {
        for idx in stored.teams[teamId].activeLineup.indices {
            stored.teams[teamId].activeLineup[idx].condition.clutchTime = isClutch
        }
    }
}

private func advanceOffensiveFormation(stored: inout NativeGameStateStore.StoredState, teamId: Int) {
    guard teamId >= 0, teamId < stored.teams.count else { return }
    guard let formations = stored.teams[teamId].team.formations, !formations.isEmpty else { return }
    let nextIndex = (stored.formationCycleIndex[teamId] + 1) % formations.count
    stored.formationCycleIndex[teamId] = nextIndex
    stored.teams[teamId].team.formation = formations[nextIndex]
}

private func registerDefensiveFoul(stored: inout NativeGameStateStore.StoredState, defenseTeamId: Int, lineupIndex: Int, shooting: Bool) {
    addPlayerStat(stored: &stored, teamId: defenseTeamId, lineupIndex: lineupIndex) { $0.fouls += 1 }
    if defenseTeamId >= 0, defenseTeamId < stored.teamFoulsInHalf.count {
        stored.teamFoulsInHalf[defenseTeamId] += 1
    }
}

private func freeThrowMakeProbability(
    stored: inout NativeGameStateStore.StoredState,
    shooter: Player,
    defenseTeamId: Int?,
    label: String,
    random: inout SeededRandom
) -> Double {
    let base = clamp(getBaseRating(shooter, path: "shooting.freeThrows") / 120, min: 0.45, max: 0.92)
    guard let defenseTeamId, defenseTeamId >= 0, defenseTeamId < stored.teams.count else {
        return base
    }
    let defenseLineup = stored.teams[defenseTeamId].activeLineup
    guard !defenseLineup.isEmpty else { return base }

    let pressureDefender = defenseLineup.max { lhs, rhs in
        let l = getBaseRating(lhs, path: "defense.defensiveControl") * 0.5
            + getBaseRating(lhs, path: "skills.hustle") * 0.3
            + getBaseRating(lhs, path: "skills.clutch") * 0.2
        let r = getBaseRating(rhs, path: "defense.defensiveControl") * 0.5
            + getBaseRating(rhs, path: "skills.hustle") * 0.3
            + getBaseRating(rhs, path: "skills.clutch") * 0.2
        return l < r
    } ?? defenseLineup[0]

    let interaction = resolveInteractionWithTrace(
        stored: &stored,
        label: label,
        offensePlayer: shooter,
        defensePlayer: pressureDefender,
        offenseRatings: ["shooting.freeThrows", "skills.shotIQ", "skills.clutch"],
        defenseRatings: ["defense.defensiveControl", "skills.hustle", "skills.clutch"],
        random: &random
    )
    let focusBoost = (logistic(interaction.edge) - 0.5) * 0.18
    return clamp(base + focusBoost, min: 0.4, max: 0.95)
}

private func teamFoulsForPeriod(_ stored: NativeGameStateStore.StoredState, teamId: Int) -> Int {
    guard teamId >= 0, teamId < stored.teamFoulsInHalf.count else { return 0 }
    return stored.teamFoulsInHalf[teamId]
}

private func maybeCallNonShootingFoul(
    stored: inout NativeGameStateStore.StoredState,
    offenseTeamId: Int,
    defenseTeamId: Int,
    ballHandlerIdx: Int,
    defenderIdx: Int,
    willEndPossession: Bool,
    eventType: inout String,
    switchedPossession: inout Bool,
    points: inout Int,
    random: inout SeededRandom
) {
    // Only trigger on setup (no shot taken yet).
    guard eventType == "setup" else { return }
    // Take-foul: defense trailing late intentionally fouls to stop clock and send to FT line.
    let defenseScore = stored.teams[defenseTeamId].score
    let offenseScore = stored.teams[offenseTeamId].score
    let defenseDelta = defenseScore - offenseScore
    let isLastPeriod = stored.currentHalf >= 2
    let clockRemaining = stored.gameClockRemaining
    let takeFoulWindow = isLastPeriod && clockRemaining <= 45 && defenseDelta <= -1 && defenseDelta >= -9
    let defender = stored.teams[defenseTeamId].activeLineup[min(defenderIdx, stored.teams[defenseTeamId].activeLineup.count - 1)]
    let ballHandler = stored.teams[offenseTeamId].activeLineup[min(ballHandlerIdx, stored.teams[offenseTeamId].activeLineup.count - 1)]
    let foulPressure = resolveInteractionWithTrace(
        stored: &stored,
        label: "non_shooting_foul_pressure",
        offensePlayer: ballHandler,
        defensePlayer: defender,
        offenseRatings: ["skills.ballHandling", "skills.ballSafety", "skills.passingIQ", "skills.shotIQ"],
        defenseRatings: ["defense.defensiveControl", "skills.hustle", "defense.offballDefense", "defense.lateralQuickness"],
        random: &random
    )
    let defenseControl = 1 - logistic(foulPressure.edge)
    let discipline = getBaseRating(defender, path: "defense.defensiveControl") * 0.6
        + getBaseRating(defender, path: "skills.shotIQ") * 0.4
    let disciplineRelief = (discipline - 50) / 300
    let baseIntent = takeFoulWindow ? (clockRemaining <= 20 ? 0.52 : 0.3) : 0.012
    let foulChance = clamp(
        baseIntent + defenseControl * 0.09 - disciplineRelief,
        min: takeFoulWindow ? 0.2 : 0.005,
        max: takeFoulWindow ? 0.75 : 0.12
    )
    guard random.nextUnit() < foulChance else { return }
    registerDefensiveFoul(stored: &stored, defenseTeamId: defenseTeamId, lineupIndex: defenderIdx, shooting: false)

    let teamFouls = teamFoulsForPeriod(stored, teamId: defenseTeamId)
    if teamFouls >= 10 {
        // Double bonus: 2 FTs.
        let shooter = stored.teams[offenseTeamId].activeLineup[ballHandlerIdx]
        var ftMade = 0
        for _ in 0..<2 {
            let ftProb = freeThrowMakeProbability(
                stored: &stored,
                shooter: shooter,
                defenseTeamId: defenseTeamId,
                label: "free_throw_focus_bonus",
                random: &random
            )
            if random.nextUnit() < ftProb {
                ftMade += 1
            }
        }
        addPlayerStat(stored: &stored, teamId: offenseTeamId, lineupIndex: ballHandlerIdx) { line in
            line.ftAttempts += 2
            line.ftMade += ftMade
            line.points += ftMade
        }
        if ftMade > 0 {
            points += ftMade
            stored.teams[offenseTeamId].score += ftMade
            applyPlusMinus(stored: &stored, scoringTeamId: offenseTeamId, points: ftMade)
        }
        eventType = "bonus_foul"
        switchedPossession = true
    } else if teamFouls >= 7 {
        // 1-and-1.
        let shooter = stored.teams[offenseTeamId].activeLineup[ballHandlerIdx]
        let firstProb = freeThrowMakeProbability(
            stored: &stored,
            shooter: shooter,
            defenseTeamId: defenseTeamId,
            label: "free_throw_focus_one_and_one",
            random: &random
        )
        let first = random.nextUnit() < firstProb
        var ftAtt = 1
        var ftMade = first ? 1 : 0
        if first {
            ftAtt = 2
            let secondProb = freeThrowMakeProbability(
                stored: &stored,
                shooter: shooter,
                defenseTeamId: defenseTeamId,
                label: "free_throw_focus_one_and_one",
                random: &random
            )
            if random.nextUnit() < secondProb {
                ftMade += 1
            }
        }
        addPlayerStat(stored: &stored, teamId: offenseTeamId, lineupIndex: ballHandlerIdx) { line in
            line.ftAttempts += ftAtt
            line.ftMade += ftMade
            line.points += ftMade
        }
        if ftMade > 0 {
            points += ftMade
            stored.teams[offenseTeamId].score += ftMade
            applyPlusMinus(stored: &stored, scoringTeamId: offenseTeamId, points: ftMade)
        }
        eventType = "bonus_foul"
        switchedPossession = true
    } else {
        // Non-bonus: inbound, no FTs, possession stays (offense retains ball, fresh shot clock).
        eventType = "non_shooting_foul"
        switchedPossession = false
    }
    _ = willEndPossession
}

// MARK: - Press defense

private func shouldApplyPress(stored: NativeGameStateStore.StoredState, offenseTeamId: Int, defenseTeamId: Int) -> Double {
    let defense = stored.teams[defenseTeamId].team
    let pressTendency = defense.tendencies.press / 50.0  // 1.0 baseline
    let trailing = stored.teams[defenseTeamId].score - stored.teams[offenseTeamId].score
    let secondsLeft = stored.currentHalf >= 2 ? stored.gameClockRemaining : stored.gameClockRemaining + HALF_SECONDS * (2 - stored.currentHalf)
    let lateTrail = secondsLeft <= 120 && trailing <= -2
    if pressTendency < 1.05 && !lateTrail { return 0 }
    let base = max(0, pressTendency - 1.0) * 0.55
    let urgency = lateTrail ? clamp(Double(-trailing) / 10, min: 0.2, max: 0.8) : 0
    return clamp(base + urgency, min: 0, max: 0.85)
}

private func maybeResolvePress(
    stored: inout NativeGameStateStore.StoredState,
    offenseTeamId: Int,
    defenseTeamId: Int,
    random: inout SeededRandom
) -> (event: String, switchedPossession: Bool, points: Int)? {
    let pressChance = shouldApplyPress(stored: stored, offenseTeamId: offenseTeamId, defenseTeamId: defenseTeamId)
    guard pressChance > 0 else { return nil }

    let offenseLineup = stored.teams[offenseTeamId].activeLineup
    let defenseLineup = stored.teams[defenseTeamId].activeLineup
    guard !offenseLineup.isEmpty, !defenseLineup.isEmpty else { return nil }

    // Pick a "receiver" (likely the team's best ball-handler) and trap defenders.
    let receiverIdx = pickLineupIndexForBallHandler(
        lineup: offenseLineup,
        random: &random
    )
    let receiver = offenseLineup[receiverIdx]

    var trapCandidates: [(Int, Double)] = []
    trapCandidates.reserveCapacity(defenseLineup.count)
    for (idx, defender) in defenseLineup.enumerated() {
        let trapScore = getRating(defender, path: "defense.steals") * 0.42
            + getRating(defender, path: "skills.hands") * 0.24
            + getRating(defender, path: "defense.lateralQuickness") * 0.2
            + getRating(defender, path: "defense.passPerception") * 0.14
        trapCandidates.append((idx, trapScore))
    }
    trapCandidates.sort { $0.1 > $1.1 }
    let leadTrapIdx = trapCandidates.first?.0 ?? 0
    let supportTrapIdx = trapCandidates.count > 1 ? trapCandidates[1].0 : leadTrapIdx
    let leadTrap = defenseLineup[leadTrapIdx]

    let setupInteraction = resolveInteractionWithTrace(
        stored: &stored,
        label: "press_setup",
        offensePlayer: receiver,
        defensePlayer: leadTrap,
        offenseRatings: ["skills.ballHandling", "skills.ballSafety", "skills.passingIQ", "athleticism.burst"],
        defenseRatings: ["defense.offballDefense", "defense.lateralQuickness", "defense.defensiveControl"],
        random: &random
    )
    let setupDefenseControl = 1 - logistic(setupInteraction.edge)
    let trapTriggerChance = clamp(pressChance * 0.42 + setupDefenseControl * 0.5, min: 0.05, max: 0.9)
    guard random.nextUnit() < trapTriggerChance else { return nil }

    let trapInteraction = resolveInteractionWithTrace(
        stored: &stored,
        label: "trap_ball_security",
        offensePlayer: receiver,
        defensePlayer: leadTrap,
        offenseRatings: ["skills.ballHandling", "skills.ballSafety", "skills.hands", "skills.passingIQ"],
        defenseRatings: ["defense.steals", "skills.hands", "defense.passPerception", "defense.lateralQuickness"],
        random: &random
    )
    let trapDefenseControl = 1 - logistic(trapInteraction.edge)
    let supportPressure = defenseLineup[supportTrapIdx]
    let supportBoost = clamp(
        (
            getRating(supportPressure, path: "defense.steals") * 0.45
                + getRating(supportPressure, path: "skills.hands") * 0.3
                + getRating(supportPressure, path: "defense.passPerception") * 0.25
        ) / 100,
        min: 0.2,
        max: 0.95
    )
    let stealChance = clamp(0.03 + trapDefenseControl * 0.32 + supportBoost * 0.08, min: 0.02, max: 0.28)
    if random.nextUnit() < stealChance {
        let stealerPool = [leadTrapIdx, supportTrapIdx]
        let stealerWeights = stealerPool.map { idx in
            getRating(defenseLineup[idx], path: "defense.steals") * 0.58
                + getRating(defenseLineup[idx], path: "skills.hands") * 0.42
        }
        let stealPick = weightedChoiceIndex(weights: stealerWeights, random: &random)
        let bestDefIdx = stealerPool[stealPick]
        addPlayerStat(stored: &stored, teamId: offenseTeamId, lineupIndex: receiverIdx) { $0.turnovers += 1 }
        addPlayerStat(stored: &stored, teamId: defenseTeamId, lineupIndex: bestDefIdx) { $0.steals += 1 }
        addTeamExtra(stored: &stored, teamId: offenseTeamId, key: "turnovers", amount: 1)
        stored.pendingTransition = NativeGameStateStore.PendingTransition(source: "steal")
        return (event: "turnover", switchedPossession: true, points: 0)
    }

    let breakAdvantage = resolveInteractionWithTrace(
        stored: &stored,
        label: "break_advantage",
        offensePlayer: receiver,
        defensePlayer: leadTrap,
        offenseRatings: ["athleticism.burst", "athleticism.speed", "skills.passingVision", "skills.ballHandling"],
        defenseRatings: ["defense.lateralQuickness", "defense.offballDefense", "defense.passPerception"],
        random: &random
    )
    let attackAfterBreak = stored.teams[offenseTeamId].team.tendencies.pressBreakAttack / 50.0
    let breakChance = clamp(
        0.12 + logistic(breakAdvantage.edge) * 0.48 + (attackAfterBreak - 1) * 0.15,
        min: 0.08,
        max: 0.75
    )
    if random.nextUnit() < breakChance {
        stored.pendingTransition = NativeGameStateStore.PendingTransition(source: "press_break")
    }
    return nil  // Let the normal possession play out.
}

// MARK: - Pass delivery

private func resolvePassInterception(
    stored: inout NativeGameStateStore.StoredState,
    passer: Player,
    receiver: Player,
    defenseLineup: [Player],
    riskShift: Double = 0,
    random: inout SeededRandom
) -> Int? {
    guard !defenseLineup.isEmpty else { return nil }
    // Identify likely lane-jumpers, then resolve passer-vs-defender interactions.
    let laneThreats = defenseLineup.enumerated().map { idx, defender in
        (
            idx,
            getRating(defender, path: "defense.passPerception") * 0.42
                + getRating(defender, path: "defense.steals") * 0.28
                + getRating(defender, path: "skills.hands") * 0.18
                + getRating(defender, path: "defense.lateralQuickness") * 0.12
        )
    }
    let candidates = laneThreats.sorted { $0.1 > $1.1 }.prefix(min(3, defenseLineup.count))
    let receiverWindow = getRating(receiver, path: "skills.hands") * 0.58
        + getRating(receiver, path: "skills.shotIQ") * 0.42

    let riskScale = clamp(1 + riskShift, min: 0.55, max: 1.45)
    let safeScale = clamp(2 - riskScale, min: 0.7, max: 1.45)

    var weights: [Double] = []
    var defenderIndices: [Int] = []
    var stealTotal = 0.0
    for (idx, laneThreat) in candidates {
        let defender = defenseLineup[idx]
        let laneInteraction = resolveInteractionWithTrace(
            stored: &stored,
            label: "pass_interception_lane",
            offensePlayer: passer,
            defensePlayer: defender,
            offenseRatings: ["skills.passingAccuracy", "skills.passingIQ", "skills.passingVision"],
            defenseRatings: ["defense.passPerception", "defense.steals", "skills.hands", "defense.lateralQuickness"],
            random: &random
        )
        let secureEdge = laneInteraction.edge + (receiverWindow - 55) / 100
        // Keep lane-jumpers impactful, but tune interception rate lower so picks are rarer.
        let stealSignal = clamp((1 - logistic(secureEdge)) * 0.4, min: 0.008, max: 0.32)
        let laneBoost = clamp((laneThreat - 60) / 320, min: -0.04, max: 0.05)
        let stealWeight = max(0.025, (stealSignal + laneBoost) * riskScale * 4.6)
        weights.append(stealWeight)
        defenderIndices.append(idx)
        stealTotal += stealWeight
    }
    let safePassWeight = max(1.0, (84 - stealTotal * 0.55) * safeScale)
    let pick = weightedChoiceIndex(weights: [safePassWeight] + weights, random: &random)
    if pick == 0 {
        return nil
    }
    return defenderIndices[pick - 1]
}

// MARK: - Fast break / transition

private func pickTransitionRunnerIndex(lineup: [Player], random: inout SeededRandom) -> Int {
    weightedRandomIndex(lineup: lineup, random: &random) { player in
        let runScore = getRating(player, path: "athleticism.burst") * 0.28
            + getRating(player, path: "athleticism.speed") * 0.27
            + getRating(player, path: "skills.offballOffense") * 0.2
            + getRating(player, path: "skills.hands") * 0.12
            + getRating(player, path: "skills.shotIQ") * 0.13
        let interiorPenalty = clamp((getWeightPounds(player) - 220) / 60, min: 0, max: 0.3)
        return max(1, runScore * (1 - interiorPenalty))
    }
}

private func pickTransitionPointDefenderIndex(lineup: [Player], random: inout SeededRandom) -> Int {
    weightedRandomIndex(lineup: lineup, random: &random) { player in
        let recovery = getRating(player, path: "athleticism.burst") * 0.26
            + getRating(player, path: "athleticism.speed") * 0.26
            + getRating(player, path: "defense.lateralQuickness") * 0.18
            + getRating(player, path: "defense.offballDefense") * 0.18
            + getRating(player, path: "defense.shotContest") * 0.12
        return max(1, recovery)
    }
}

private func chooseFastBreakFinish(player: Player, random: inout SeededRandom) -> ShotType {
    let dunkLean = getRating(player, path: "shooting.dunks") * 0.5
        + getRating(player, path: "athleticism.vertical") * 0.3
        + getRating(player, path: "athleticism.strength") * 0.2
    let layupLean = getRating(player, path: "shooting.layups") * 0.62
        + getRating(player, path: "shooting.closeShot") * 0.24
        + getRating(player, path: "skills.shotIQ") * 0.14
    let total = max(1, dunkLean + layupLean)
    return random.nextUnit() * total < layupLean ? .layup : .dunk
}

private func maybeResolveFastBreak(
    stored: inout NativeGameStateStore.StoredState,
    offenseTeamId: Int,
    defenseTeamId: Int,
    random: inout SeededRandom
) -> (event: String, switchedPossession: Bool, points: Int)? {
    guard let transition = stored.pendingTransition else { return nil }
    stored.pendingTransition = nil

    let offenseLineup = stored.teams[offenseTeamId].activeLineup
    let defenseLineup = stored.teams[defenseTeamId].activeLineup
    guard !offenseLineup.isEmpty, !defenseLineup.isEmpty else { return nil }

    let runnerIdx = pickTransitionRunnerIndex(lineup: offenseLineup, random: &random)
    let leadDefIdx = pickTransitionPointDefenderIndex(lineup: defenseLineup, random: &random)
    let runner = offenseLineup[runnerIdx]
    let leadDef = defenseLineup[leadDefIdx]
    let sourceBoost: Double = transition.source == "steal" ? 0.06 : (transition.source == "press_break" ? 0.045 : 0.01)

    let pushInteraction = resolveInteractionWithTrace(
        stored: &stored,
        label: "fast_break_push",
        offensePlayer: runner,
        defensePlayer: leadDef,
        offenseRatings: ["athleticism.burst", "athleticism.speed", "skills.ballHandling", "skills.shotIQ"],
        defenseRatings: ["defense.offballDefense", "defense.lateralQuickness", "defense.passPerception"],
        random: &random
    )
    let pushChance = clamp(0.04 + logistic(pushInteraction.edge) * 0.5 + sourceBoost * 0.25, min: 0.03, max: 0.72)
    guard random.nextUnit() < pushChance else { return nil }

    let runScore = getRating(runner, path: "athleticism.burst") * 0.38
        + getRating(runner, path: "athleticism.speed") * 0.34
        + getRating(runner, path: "skills.ballHandling") * 0.14
        + getRating(runner, path: "skills.offballOffense") * 0.14
    let recoveryScore = getRating(leadDef, path: "athleticism.burst") * 0.33
        + getRating(leadDef, path: "athleticism.speed") * 0.31
        + getRating(leadDef, path: "defense.lateralQuickness") * 0.2
        + getRating(leadDef, path: "defense.shotContest") * 0.16
    let raceInteraction = resolveInteractionWithTrace(
        stored: &stored,
        label: "fast_break_race",
        offensePlayer: runner,
        defensePlayer: leadDef,
        offenseRatings: ["athleticism.burst", "athleticism.speed", "skills.ballHandling", "skills.offballOffense"],
        defenseRatings: ["athleticism.burst", "athleticism.speed", "defense.lateralQuickness", "defense.shotContest"],
        random: &random
    )
    let raceEdge = (runScore - recoveryScore) / 100 + sourceBoost + raceInteraction.edge * 0.28
    let beatDefenseChance = clamp(0.1 + logistic(raceEdge) * 0.74, min: 0.06, max: 0.88)
    guard random.nextUnit() < beatDefenseChance else { return nil }

    let shotType = chooseFastBreakFinish(player: runner, random: &random)
    let profile = shotProfile(for: shotType)
    let shotInteraction = resolveInteractionWithTrace(
        stored: &stored,
        label: "fast_break_finish",
        offensePlayer: runner,
        defensePlayer: leadDef,
        offenseRatings: profile.offenseRatings,
        defenseRatings: profile.defenseRatings,
        random: &random
    )
    let finishQuality = resolveInteractionWithTrace(
        stored: &stored,
        label: "fast_break_finish_quality",
        offensePlayer: runner,
        defensePlayer: leadDef,
        offenseRatings: profile.offenseRatings + ["skills.hands", "skills.shotIQ"],
        defenseRatings: profile.defenseRatings + ["defense.defensiveControl", "defense.shotContest"],
        random: &random
    )
    let madeProb = clamp(
        baseMakeProbability(for: shotType)
            + (logistic(shotInteraction.edge + 0.3) - 0.5) * makeScale(for: shotType) * 0.58
            + (logistic(finishQuality.edge) - 0.5) * 0.42
            + 0.06,
        min: minMakeProbability(for: shotType),
        max: maxMakeProbability(for: shotType)
    )
    let made = random.nextUnit() < madeProb

    addPlayerStat(stored: &stored, teamId: offenseTeamId, lineupIndex: runnerIdx) { line in
        line.fgAttempts += 1
        if made { line.fgMade += 1 }
    }

    if made {
        let pts = profile.basePoints
        stored.teams[offenseTeamId].score += pts
        applyPlusMinus(stored: &stored, scoringTeamId: offenseTeamId, points: pts)
        addPlayerStat(stored: &stored, teamId: offenseTeamId, lineupIndex: runnerIdx) { $0.points += pts }
        addTeamExtra(stored: &stored, teamId: offenseTeamId, key: "fastBreakPoints", amount: pts)
        if isPointsInPaintScore(shotType: shotType, spot: .middlePaint) {
            addTeamExtra(stored: &stored, teamId: offenseTeamId, key: "pointsInPaint", amount: pts)
        }
        return (event: "made_shot", switchedPossession: true, points: pts)
    }

    // Missed break finish: still interaction-based, but transition positioning usually favors set defenders.
    let offenseCrashPreference = teamReboundCrashPreference(
        crashBoards: stored.teams[offenseTeamId].team.tendencies.crashBoardsOffense,
        fastBreakBias: stored.teams[offenseTeamId].team.tendencies.defendFastBreakOffense
    )
    let defenseCrashPreference = teamReboundCrashPreference(
        crashBoards: stored.teams[defenseTeamId].team.tendencies.crashBoardsDefense,
        fastBreakBias: stored.teams[defenseTeamId].team.tendencies.attemptFastBreakDefense
    )
    let reboundLocationHints = buildTransitionReboundLocationHints(
        offenseCount: offenseLineup.count,
        defenseCount: defenseLineup.count,
        shooterIdx: runnerIdx,
        shotDefenderIdx: leadDefIdx
    )
    let rebound = resolveReboundOutcome(
        stored: &stored,
        offenseLineup: offenseLineup,
        defenseLineup: defenseLineup,
        shotType: shotType,
        spot: .middlePaint,
        shooterIndex: runnerIdx,
        shotDefenderIndex: leadDefIdx,
        offenseCrashPreference: offenseCrashPreference,
        defenseCrashPreference: defenseCrashPreference,
        offensePositioning: 0.88,
        defensePositioning: 1.12,
        offenseLocationHints: reboundLocationHints.offense,
        defenseLocationHints: reboundLocationHints.defense,
        random: &random
    )
    if rebound.offensive {
        addPlayerStat(stored: &stored, teamId: offenseTeamId, lineupIndex: rebound.lineupIndex) { line in
            line.rebounds += 1
            line.offensiveRebounds += 1
        }
        return (event: "missed_shot", switchedPossession: false, points: 0)
    } else {
        addPlayerStat(stored: &stored, teamId: defenseTeamId, lineupIndex: rebound.lineupIndex) { line in
            line.rebounds += 1
            line.defensiveRebounds += 1
        }
        // Chained transition: defensive rebound seeds another potential break.
        stored.pendingTransition = NativeGameStateStore.PendingTransition(source: "def_rebound")
        return (event: "missed_shot", switchedPossession: true, points: 0)
    }
}
