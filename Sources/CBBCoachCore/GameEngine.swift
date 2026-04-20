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
    public var playByPlay: [PlayByPlayEvent]
    public var boxScore: [TeamBoxScore]?
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
        var playByPlay: [PlayByPlayEvent]
        var teamFoulsInHalf: [Int]
        var formationCycleIndex: [Int]
        var pendingTransition: PendingTransition?
        var lastSubElapsedGameSeconds: [Int]
    }

    private static let lock = NSLock()
    private static nonisolated(unsafe) var nextId = 1
    private static nonisolated(unsafe) var states: [String: StoredState] = [:]

    static func create(home: Team, away: Team, random: inout SeededRandom) -> String {
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
            playByPlay: [],
            teamFoulsInHalf: [0, 0],
            formationCycleIndex: [0, 0],
            pendingTransition: nil,
            lastSubElapsedGameSeconds: [-9999, -9999]
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
            teamExtras: ["turnovers": 0]
        )
    }
}

private struct WeightedSkill: Sendable {
    var score: Double
}

public func createInitialGameState(homeTeam: Team, awayTeam: Team, random: inout SeededRandom) -> GameState {
    let handle = NativeGameStateStore.create(home: homeTeam, away: awayTeam, random: &random)
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
    let edge = (offense.score - defense.score) / 14 + mobilitySizeEdge
    let successProbability = clamp(logistic(edge), min: 0.03, max: 0.97)
    let offenseWon = random.nextUnit() < successProbability

    return InteractionResult(
        offenseScore: offense.score,
        defenseScore: defense.score,
        edge: edge,
        offenseWon: offenseWon
    )
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

        syncPossessionRoles(stored: &stored)
        syncClutchTime(stored: &stored)
        advanceOffensiveFormation(stored: &stored, teamId: offenseTeamId)

        let possessionSeconds = possessionDurationSeconds(for: stored.teams[offenseTeamId].team.pace, random: &random)
        applyChunkMinutesAndEnergy(stored: &stored, possessionSeconds: possessionSeconds)

        let offenseStrength = computeLineupOffenseStrength(stored.teams[offenseTeamId].activeLineup)
        let defenseStrength = computeLineupDefenseStrength(stored.teams[defenseTeamId].activeLineup)
        let teamEdge = (offenseStrength - defenseStrength) / 22 + (random.nextUnit() * 0.2 - 0.1)

        let ballHandlerIdx = pickLineupIndexForBallHandler(lineup: stored.teams[offenseTeamId].activeLineup, random: &random)
        let defenderIdx = min(ballHandlerIdx, stored.teams[defenseTeamId].activeLineup.count - 1)
        let ballHandler = stored.teams[offenseTeamId].activeLineup[ballHandlerIdx]
        let primaryDefender = stored.teams[defenseTeamId].activeLineup[defenderIdx]

        let shotClockPressure = clamp(
            Double(SHOT_CLOCK_SECONDS - stored.shotClockRemaining) / Double(max(1, SHOT_CLOCK_SECONDS - CHUNK_SECONDS)),
            min: 0,
            max: 1
        )
        let paceBias = paceShotBias(for: stored.teams[offenseTeamId].team.pace)
        let shotIQ = getBaseRating(ballHandler, path: "skills.shotIQ")
        let shooterTendency = getBaseRating(ballHandler, path: "tendencies.shootVsPass")
        let attemptShotChance = clamp(
            0.08
                + Foundation.pow(shotClockPressure, 1.4) * 0.56
                + (shotIQ - 55) / 320
                + (shooterTendency - 55) / 320
                + paceBias,
            min: 0.06,
            max: 0.85
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
            let turnoverInteraction = resolveInteraction(
                offensePlayer: ballHandler,
                defensePlayer: primaryDefender,
                offenseRatings: ["skills.ballHandling", "skills.ballSafety", "skills.passingIQ"],
                defenseRatings: ["defense.steals", "defense.passPerception", "skills.hands"],
                random: &random
            )
            let turnoverBase = clamp(0.12 - teamEdge * 0.03, min: 0.06, max: 0.18)
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
                    offenseLineup: stored.teams[offenseTeamId].activeLineup,
                    defenseLineup: stored.teams[defenseTeamId].activeLineup,
                    ballHandlerIdx: ballHandlerIdx,
                    defenderIdx: defenderIdx,
                    team: stored.teams[offenseTeamId].team,
                    random: &random
                )
                let shooter = stored.teams[offenseTeamId].activeLineup[play.shooterLineupIndex]
                let shotDefender = stored.teams[defenseTeamId].activeLineup[play.defenderLineupIndex]

                // Pass delivery: if shooter differs from ball handler, the ball has to get there.
                var passIntercepted = false
                if play.shooterLineupIndex != ballHandlerIdx {
                    if let stealerIdx = resolvePassInterception(
                        passer: ballHandler,
                        receiver: shooter,
                        defenseLineup: stored.teams[defenseTeamId].activeLineup,
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
                if play.isDrive {
                    let defenderStanding = getBaseRating(shotDefender, path: "defense.defensiveControl") * 0.5
                        + getBaseRating(shotDefender, path: "defense.offballDefense") * 0.25
                        + getBaseRating(shotDefender, path: "skills.hustle") * 0.25
                    let shooterControl = getBaseRating(shooter, path: "skills.ballHandling") * 0.5
                        + getBaseRating(shooter, path: "skills.shotIQ") * 0.5
                    let chargeChance = clamp(0.012 + (defenderStanding - shooterControl) / 1400, min: 0.005, max: 0.04)
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
                let shotInteraction = resolveInteraction(
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
                    shotMakeBase + teamEdge * 0.06 + shotTypeEdgeBonus + play.makeBonus + zoneMod
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
                    let blockChance = clamp(
                        0.025 + (getBaseRating(shotDefender, path: "defense.shotBlocking") - 50) / 260,
                        min: 0.01,
                        max: 0.22
                    )
                    if random.nextUnit() < blockChance {
                        addPlayerStat(stored: &stored, teamId: defenseTeamId, lineupIndex: play.defenderLineupIndex) { $0.blocks += 1 }
                    }
                }

                if made {
                    points = profile.basePoints
                    stored.teams[offenseTeamId].score += points
                    applyPlusMinus(stored: &stored, scoringTeamId: offenseTeamId, points: points)
                    addPlayerStat(stored: &stored, teamId: offenseTeamId, lineupIndex: play.shooterLineupIndex) { $0.points += points }
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
                    if let assistIdx = pickAssistLineupIndex(
                        lineup: stored.teams[offenseTeamId].activeLineup,
                        shooterIndex: play.shooterLineupIndex,
                        candidates: assistPool,
                        forceAssistChance: play.assistForceChance,
                        random: &random
                    ) {
                        addPlayerStat(stored: &stored, teamId: offenseTeamId, lineupIndex: assistIdx) { $0.assists += 1 }
                    }

                    let andOneChance = clamp(0.05 + max(0, -shotInteraction.edge) * 0.04 + play.foulBonus, min: 0.02, max: 0.18)
                    if random.nextUnit() < andOneChance {
                        registerDefensiveFoul(stored: &stored, defenseTeamId: defenseTeamId, lineupIndex: play.defenderLineupIndex, shooting: true)
                        let ftMade = random.nextUnit() < clamp(getBaseRating(shooter, path: "shooting.freeThrows") / 120, min: 0.45, max: 0.92) ? 1 : 0
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
                    let shootingFoulChance = clamp(0.08 + max(0, -shotInteraction.edge) * 0.08 + play.foulBonus, min: 0.04, max: 0.28)
                    if random.nextUnit() < shootingFoulChance {
                        registerDefensiveFoul(stored: &stored, defenseTeamId: defenseTeamId, lineupIndex: play.defenderLineupIndex, shooting: true)
                        let ftAttempts = isThree ? 3 : 2
                        var ftMade = 0
                        for _ in 0..<ftAttempts {
                            if random.nextUnit() < clamp(getBaseRating(shooter, path: "shooting.freeThrows") / 120, min: 0.45, max: 0.92) {
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
                        let looseBallFoulChance = 0.018
                        if random.nextUnit() < looseBallFoulChance {
                            // Call it on a random defensive rebounder (they were boxing out); offense keeps ball.
                            let foulerIdx = pickRebounderIndex(
                                lineup: stored.teams[defenseTeamId].activeLineup,
                                offensive: false,
                                shotType: shotType,
                                random: &random
                            )
                            registerDefensiveFoul(stored: &stored, defenseTeamId: defenseTeamId, lineupIndex: foulerIdx, shooting: false)
                            eventType = "loose_ball_foul"
                            switchedPossession = false
                        } else {
                        let offenseReboundChance = clamp(0.27 + teamEdge * 0.04, min: 0.18, max: 0.37)
                        let offenseRebound = random.nextUnit() < offenseReboundChance
                        if offenseRebound {
                            let reboundIdx = pickRebounderIndex(
                                lineup: stored.teams[offenseTeamId].activeLineup,
                                offensive: true,
                                shotType: shotType,
                                random: &random,
                                spot: play.spot,
                                opposingLineup: stored.teams[defenseTeamId].activeLineup
                            )
                            addPlayerStat(stored: &stored, teamId: offenseTeamId, lineupIndex: reboundIdx) { line in
                                line.rebounds += 1
                                line.offensiveRebounds += 1
                            }
                            switchedPossession = false
                        } else {
                            let reboundIdx = pickRebounderIndex(
                                lineup: stored.teams[defenseTeamId].activeLineup,
                                offensive: false,
                                shotType: shotType,
                                random: &random,
                                spot: play.spot,
                                opposingLineup: stored.teams[offenseTeamId].activeLineup
                            )
                            addPlayerStat(stored: &stored, teamId: defenseTeamId, lineupIndex: reboundIdx) { line in
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
                description: eventDescription(
                    eventType: eventType,
                    offenseTeam: stored.teams[offenseTeamId].team.name,
                    defenseTeam: stored.teams[defenseTeamId].team.name,
                    lineup: stored.teams[offenseTeamId].activeLineup,
                    playerIndex: ballHandlerIdx
                ),
                detail: nil
            )
        )

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
    _ = pace
    _ = random
    return CHUNK_SECONDS
}

private func paceShotBias(for pace: PaceProfile) -> Double {
    switch pace {
    case .verySlow: return -0.08
    case .slow: return -0.055
    case .slightlySlow: return -0.03
    case .normal: return 0
    case .slightlyFast: return 0.02
    case .fast: return 0.04
    case .veryFast: return 0.06
    }
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

private func pickLineupIndexForBallHandler(lineup: [Player], random: inout SeededRandom) -> Int {
    guard !lineup.isEmpty else { return 0 }
    return weightedRandomIndex(
        lineup: lineup,
        random: &random
    ) { player in
        let base = getBaseRating(player, path: "skills.ballHandling") * 0.33
            + getBaseRating(player, path: "skills.passingVision") * 0.2
            + getBaseRating(player, path: "skills.passingIQ") * 0.15
            + (100 - getBaseRating(player, path: "tendencies.shootVsPass")) * 0.14
            + getBaseRating(player, path: "skills.shotIQ") * 0.1
            + getBaseRating(player, path: "athleticism.burst") * 0.08
        let positionMultiplier: Double = isPointGuardLike(player) ? 1.35 : (player.bio.position == .sg ? 1.05 : 0.84)
        return max(1, base * positionMultiplier)
    }
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

private func pickLineupIndexForPickActionBallHandler(lineup: [Player], random: inout SeededRandom) -> Int {
    guard !lineup.isEmpty else { return 0 }
    return weightedRandomIndex(
        lineup: lineup,
        random: &random
    ) { player in
        let base = getBaseRating(player, path: "skills.ballHandling") * 0.34
            + getBaseRating(player, path: "skills.passingVision") * 0.16
            + getBaseRating(player, path: "skills.passingIQ") * 0.14
            + getBaseRating(player, path: "skills.shotIQ") * 0.1
            + getBaseRating(player, path: "athleticism.burst") * 0.08
            + getBaseRating(player, path: "tendencies.pickAndRoll") * 0.1
            + getBaseRating(player, path: "tendencies.pickAndPop") * 0.08
        let positionMultiplier: Double = isPointGuardLike(player) ? 2.6 : (player.bio.position == .sg ? 0.95 : 0.58)
        return max(1, base * positionMultiplier)
    }
}

private func pickAssistLineupIndex(
    lineup: [Player],
    shooterIndex: Int,
    candidates: [Int],
    forceAssistChance: Double?,
    random: inout SeededRandom
) -> Int? {
    let filtered = candidates.filter { $0 != shooterIndex && $0 >= 0 && $0 < lineup.count }
    guard !filtered.isEmpty else { return nil }
    let threshold = forceAssistChance ?? 0.62
    guard random.nextUnit() < threshold else { return nil }
    let weights = filtered.map { idx in
        getBaseRating(lineup[idx], path: "skills.passingVision") * 0.45
            + getBaseRating(lineup[idx], path: "skills.passingAccuracy") * 0.35
            + getBaseRating(lineup[idx], path: "skills.passingIQ") * 0.2
    }
    let pick = weightedChoiceIndex(weights: weights, random: &random)
    return filtered[pick]
}

private enum ReboundZone {
    case paint, leftBlock, rightBlock, leftPerimeter, rightPerimeter, topPerimeter
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

private func reboundZoneWithShortBias(
    initialZone: ReboundZone,
    shotType: ShotType,
    random: inout SeededRandom
) -> ReboundZone {
    let shortChance: Double
    switch shotType {
    case .three:
        shortChance = 0.42
    case .midrange, .fadeaway:
        shortChance = 0.56
    case .layup, .dunk, .hook, .close:
        shortChance = 0.72
    }
    guard random.nextUnit() < shortChance else { return initialZone }

    switch initialZone {
    case .leftPerimeter:
        return random.nextUnit() < 0.75 ? .leftBlock : .paint
    case .rightPerimeter:
        return random.nextUnit() < 0.75 ? .rightBlock : .paint
    case .topPerimeter:
        return .paint
    case .leftBlock:
        return random.nextUnit() < 0.7 ? .leftBlock : .paint
    case .rightBlock:
        return random.nextUnit() < 0.7 ? .rightBlock : .paint
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

private func fallbackZones(for zone: ReboundZone) -> [ReboundZone] {
    switch zone {
    case .paint:
        return [.leftBlock, .rightBlock]
    case .leftBlock, .rightBlock:
        return [.paint]
    case .leftPerimeter, .rightPerimeter, .topPerimeter:
        return []
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

private func pickRebounderIndex(
    lineup: [Player],
    offensive: Bool,
    shotType: ShotType,
    random: inout SeededRandom,
    spot: OffensiveSpot = .middlePaint,
    opposingLineup: [Player] = []
) -> Int {
    guard !lineup.isEmpty else { return 0 }
    let initialZone = reboundZone(for: shotType, spot: spot)
    let zone = reboundZoneWithShortBias(initialZone: initialZone, shotType: shotType, random: &random)
    let opposingBoxoutAvg: Double
    if opposingLineup.isEmpty {
        opposingBoxoutAvg = 50
    } else {
        opposingBoxoutAvg = average(opposingLineup.map { getBaseRating($0, path: "rebounding.boxouts") })
    }
    // Offense crashing against tall boxouts is suppressed; defense enjoys a boost when boxing out well.
    let boxoutResistance = clamp((opposingBoxoutAvg - 50) / 60, min: -0.2, max: 0.35)
    let targetPresence = lineup.reduce(0) { $0 + zonePresenceAffinity($1, zone: zone) }
    let fallbackPresence: Double = fallbackZones(for: zone).reduce(0) { total, fallbackZone in
        total + lineup.reduce(0) { $0 + zonePresenceAffinity($1, zone: fallbackZone) }
    }
    let needsZoneFallback = !fallbackZones(for: zone).isEmpty && targetPresence < 1.0 && fallbackPresence > 0.8

    return weightedRandomIndex(lineup: lineup, random: &random) { player in
        let reboundRating = offensive
            ? getBaseRating(player, path: "rebounding.offensiveRebounding")
            : getBaseRating(player, path: "rebounding.defensiveRebound")
        let boxouts = getBaseRating(player, path: "rebounding.boxouts")
        let baseScore = reboundRating * 0.6 + boxouts * 0.3 + getBaseRating(player, path: "skills.hustle") * 0.1
        let zoneBias: Double
        switch zone {
        case .paint, .leftBlock, .rightBlock:
            zoneBias = getBaseRating(player, path: "athleticism.strength") * 0.2
                + getBaseRating(player, path: "athleticism.vertical") * 0.2
                + getBaseRating(player, path: "rebounding.boxouts") * 0.2
        case .leftPerimeter, .rightPerimeter, .topPerimeter:
            zoneBias = getBaseRating(player, path: "athleticism.burst") * 0.22
                + getBaseRating(player, path: "athleticism.speed") * 0.18
                + (getBaseRating(player, path: "athleticism.strength") < 75 ? 10 : 0)
        }
        let proximity = positionProximity(player, zone: zone)
        let crashingPenalty = offensive ? (1 - boxoutResistance) : (1 + boxoutResistance * 0.5)
        let zoneFallbackBoost: Double
        if needsZoneFallback {
            let fallbackAffinity = fallbackZones(for: zone).reduce(0) { total, fallbackZone in
                total + zonePresenceAffinity(player, zone: fallbackZone)
            }
            zoneFallbackBoost = 1 + fallbackAffinity * 0.32
        } else {
            zoneFallbackBoost = 1
        }
        return max(1, (baseScore + zoneBias * 0.45) * proximity * crashingPenalty * zoneFallbackBoost)
    }
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
    let energyDelta = Double(possessionSeconds) * 0.025
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

    let floor: Double = roster.count > 5 ? 4 : 0
    let remaining = max(0, totalTeamMinutes - floor * Double(roster.count))
    let weights = roster.map { max(1, playerOverallSkill($0)) }
    let totalWeight = weights.reduce(0, +)
    var map: [Int: Double] = [:]
    for idx in roster.indices {
        let share = totalWeight > 0 ? remaining * (weights[idx] / totalWeight) : remaining / Double(roster.count)
        map[idx] = clamp(floor + share, min: 0, max: 40)
    }
    return map
}

private func rankSubCandidates(tracker: NativeGameStateStore.TeamTracker) -> [SubCandidate] {
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

    let tracker = stored.teams[teamId]
    let ranked = rankSubCandidates(tracker: tracker)
    var current = tracker.activeLineupBoxIndices

    var swaps = 0
    let maxSwaps = 2
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

        if !(betterBy > 6 || fatigueUpgrade || rotationUpgrade) { break }

        current[weakest.slot] = best.rosterIndex
        swaps += 1
        bench = ranked.filter { !current.contains($0.rosterIndex) }
        _ = random.nextUnit() // Keep determinism parity with prior implementation's random use.
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
    guard rosterIndex >= 0, rosterIndex < tracker.team.players.count else { return isStarterSlot ? 30 : 14 }
    let playerName = tracker.team.players[rosterIndex].bio.name
    if let target = tracker.team.rotation?.minuteTargets[playerName], target.isFinite {
        return clamp(target, min: 4, max: 40)
    }
    return isStarterSlot ? 30 : 14
}

private func addTeamExtra(stored: inout NativeGameStateStore.StoredState, teamId: Int, key: String, amount: Int) {
    guard teamId >= 0, teamId < stored.teams.count else { return }
    stored.teams[teamId].teamExtras[key, default: 0] += amount
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
    mutate(&stored.teams[teamId].boxPlayers[boxIndex])
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

public func simulateGame(homeTeam: Team, awayTeam: Team, random: inout SeededRandom) -> SimulatedGameResult {
    var state = createInitialGameState(homeTeam: homeTeam, awayTeam: awayTeam, random: &random)
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
        playByPlay: final.playByPlay,
        boxScore: boxScores
    )
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
    let group = String(path.split(separator: ".").first ?? "")
    let impact: Double
    switch group {
    case "athleticism": impact = 0.3
    case "shooting": impact = 0.18
    case "skills": impact = 0.24
    case "defense": impact = 0.22
    case "rebounding", "postGame": impact = 0.2
    default: impact = 0.2
    }

    let fatigueAdjusted = applyClutchModifier(player, rating: raw * (1 - fatigue * impact))
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

private func computeTeamOffenseStrength(_ team: Team) -> Double {
    let lineup = Array(team.lineup.prefix(5))
    return computeLineupOffenseStrength(lineup)
}

private func computeLineupOffenseStrength(_ lineup: [Player]) -> Double {
    guard !lineup.isEmpty else { return 50 }
    let values = lineup.map { player in
        average([
            getBaseRating(player, path: "skills.shotIQ"),
            getBaseRating(player, path: "shooting.threePointShooting"),
            getBaseRating(player, path: "shooting.midrangeShot"),
            getBaseRating(player, path: "shooting.closeShot"),
            getBaseRating(player, path: "skills.ballHandling"),
        ])
    }
    return average(values)
}

private func computeTeamDefenseStrength(_ team: Team) -> Double {
    let lineup = Array(team.lineup.prefix(5))
    return computeLineupDefenseStrength(lineup)
}

private func computeLineupDefenseStrength(_ lineup: [Player]) -> Double {
    guard !lineup.isEmpty else { return 50 }
    let values = lineup.map { player in
        average([
            getBaseRating(player, path: "defense.perimeterDefense"),
            getBaseRating(player, path: "defense.postDefense"),
            getBaseRating(player, path: "defense.shotContest"),
            getBaseRating(player, path: "defense.lateralQuickness"),
            getBaseRating(player, path: "skills.hustle"),
        ])
    }
    return average(values)
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
    case .three: return 0.33
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
    var isDrive: Bool = false
}

private func choosePlayType(offenseTeam: Team, ballHandler: Player, random: inout SeededRandom) -> PlayType {
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

    let formation = offenseTeam.formation
    let passAroundFormationBoost = (formation == .motion || formation == .fiveOut) ? 1.1 : 0.96
    let pickFormationBoost = (formation == .motion || formation == .fiveOut || formation == .highLow) ? 1.07 : 0.97

    let weights: [(PlayType, Double)] = [
        (.dribbleDrive, max(1, drive) * 1.42),
        (.postUp, max(1, post) * 1.12),
        (.pickAndRoll, max(1, pickAndRoll * 0.62 + drive * 0.22 + (100 - shootVsPass) * 0.16) * pickFormationBoost * 0.9),
        (.pickAndPop, max(1, pickAndPop * 0.62 + passAroundProfile * 0.2 + (100 - shootVsPass) * 0.18) * pickFormationBoost * 0.42),
        (.passAroundForShot, max(1, passAround) * passAroundFormationBoost * 0.68),
    ]
    let total = weights.reduce(0) { $0 + $1.1 }
    var pick = random.nextUnit() * max(total, 1)
    for (type, weight) in weights {
        pick -= weight
        if pick <= 0 { return type }
    }
    return .dribbleDrive
}

private func resolvePlay(
    offenseLineup: [Player],
    defenseLineup: [Player],
    ballHandlerIdx: Int,
    defenderIdx: Int,
    team: Team,
    random: inout SeededRandom
) -> PlayOutcome {
    let ballHandler = offenseLineup[ballHandlerIdx]
    let playType = choosePlayType(offenseTeam: team, ballHandler: ballHandler, random: &random)
    let pickActionBallHandlerIdx: Int
    if playType == .pickAndRoll || playType == .pickAndPop {
        pickActionBallHandlerIdx = pickLineupIndexForPickActionBallHandler(lineup: offenseLineup, random: &random)
    } else {
        pickActionBallHandlerIdx = ballHandlerIdx
    }
    let pickActionDefenderIdx = min(pickActionBallHandlerIdx, defenseLineup.count - 1)
    let pickActionBallHandler = offenseLineup[pickActionBallHandlerIdx]

    switch playType {
    case .dribbleDrive:
        // Ball handler attacks the rim. Higher foul draw, shots favor rim.
        let driveRating = getRating(ballHandler, path: "tendencies.drive") + getRating(ballHandler, path: "athleticism.burst")
        let defenderPerim = getRating(defenseLineup[defenderIdx], path: "defense.perimeterDefense")
            + getRating(defenseLineup[defenderIdx], path: "defense.lateralQuickness")
        let driveEdge = (driveRating - defenderPerim) / 400

        // Help-defender chain: after beating the on-ball defender, help can force a kickout.
        // Weighted by passing vision vs weak-side defenders' help tendencies.
        let helpScore = defenseLineup.enumerated()
            .filter { $0.offset != defenderIdx }
            .map { _, d in
                getRating(d, path: "defense.offballDefense") * 0.55
                    + getRating(d, path: "defense.shotContest") * 0.3
                    + getRating(d, path: "defense.lateralQuickness") * 0.15
            }
            .max() ?? 50
        let visionScore = getRating(ballHandler, path: "skills.passingVision") * 0.6
            + getRating(ballHandler, path: "skills.shotIQ") * 0.4
        let kickChance = clamp(0.3 + (helpScore - visionScore) / 240, min: 0.12, max: 0.65)
        if random.nextUnit() < kickChance && offenseLineup.count > 1 {
            let receiverIdx = evaluatePassTarget(
                offenseLineup: offenseLineup,
                defenseLineup: defenseLineup,
                ballHandlerIdx: ballHandlerIdx,
                random: &random
            )
            let shooter = offenseLineup[receiverIdx]
            let spot = pickShooterSpot(player: shooter, random: &random)
            let shotType = chooseShotFromTendencies(shooter: shooter, spot: spot, random: &random)
            let shotDefenderIdx = positionMatchedDefenderIndex(shooter: shooter, defenseLineup: defenseLineup, fallback: receiverIdx)
            return PlayOutcome(
                shooterLineupIndex: receiverIdx,
                defenderLineupIndex: shotDefenderIdx,
                shotType: shotType,
                spot: spot,
                edgeBonus: 0.18, // drive-and-kick typically generates quality looks
                makeBonus: 0.03,
                foulBonus: 0,
                assistCandidateIndices: [ballHandlerIdx],
                assistForceChance: 0.82
            )
        }

        let takesRim = random.nextUnit() < clamp(0.55 + driveEdge, min: 0.25, max: 0.8)
        let spot: OffensiveSpot = takesRim ? .middlePaint : pickShooterSpot(player: ballHandler, random: &random)
        let shotType: ShotType
        if takesRim {
            shotType = getRating(ballHandler, path: "shooting.dunks") > getRating(ballHandler, path: "shooting.layups") + 5 && random.nextUnit() < 0.35
                ? .dunk
                : .layup
        } else {
            shotType = chooseShotFromTendencies(shooter: ballHandler, spot: spot, random: &random)
        }
        return PlayOutcome(
            shooterLineupIndex: ballHandlerIdx,
            defenderLineupIndex: defenderIdx,
            shotType: shotType,
            spot: spot,
            edgeBonus: 0.08,
            makeBonus: 0,
            foulBonus: takesRim ? 0.04 : 0,
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
        let spot: OffensiveSpot = random.nextUnit() < 0.5 ? .rightPost : .leftPost
        let hookW = getRating(shooter, path: "postGame.postHooks") * 1.1
        let fadeW = getRating(shooter, path: "postGame.postFadeaways") * 0.9
        let layupW = getRating(shooter, path: "shooting.layups") * 0.8
        let dunkW = getRating(shooter, path: "shooting.dunks") * 0.5
        let total = hookW + fadeW + layupW + dunkW
        let pick = random.nextUnit() * max(total, 1)
        let shotType: ShotType
        if pick < hookW { shotType = .hook }
        else if pick < hookW + fadeW { shotType = .fadeaway }
        else if pick < hookW + fadeW + layupW { shotType = .layup }
        else { shotType = .dunk }
        // The post defender is usually the matching slot; approximate by same index.
        let postDefenderIdx = min(postIdx, defenseLineup.count - 1)
        return PlayOutcome(
            shooterLineupIndex: postIdx,
            defenderLineupIndex: postDefenderIdx,
            shotType: shotType,
            spot: spot,
            edgeBonus: 0.04,
            makeBonus: 0,
            foulBonus: isRimShot(shotType) ? 0.03 : 0,
            assistCandidateIndices: postIdx == ballHandlerIdx ? nil : [ballHandlerIdx],
            assistForceChance: 0.45
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
            onBallDefender: onBallDefender,
            screenerDefender: screenerDefender,
            screenEdge: screenEdge,
            random: &random
        )
        return resolvePickAndRollOutcome(
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
        let popDest = choosePopDestination(screener: screener, random: &random)
        let offBallKickChance = clamp(
            0.24
                + (100 - getRating(pickActionBallHandler, path: "tendencies.shootVsPass")) / 260
                + (getRating(pickActionBallHandler, path: "skills.passingVision") - 50) / 320,
            min: 0.12,
            max: 0.5
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
            let spot = pickShooterSpot(player: shooter, random: &random)
            let shotType = chooseShotFromTendencies(shooter: shooter, spot: spot, random: &random)
            return PlayOutcome(
                shooterLineupIndex: receiverIdx,
                defenderLineupIndex: min(receiverIdx, defenseLineup.count - 1),
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
        // Ball moves to the teammate with the highest open-shot expected value after relocation.
        let receiverIdx = evaluatePassTarget(
            offenseLineup: offenseLineup,
            defenseLineup: defenseLineup,
            ballHandlerIdx: ballHandlerIdx,
            random: &random
        )
        let shooter = offenseLineup[receiverIdx]
        let shotDefenderIdx = min(receiverIdx, defenseLineup.count - 1)
        let spot = pickShooterSpot(player: shooter, random: &random)
        let shotType = chooseShotFromTendencies(shooter: shooter, spot: spot, random: &random)
        return PlayOutcome(
            shooterLineupIndex: receiverIdx,
            defenderLineupIndex: shotDefenderIdx,
            shotType: shotType,
            spot: spot,
            edgeBonus: 0.12,
            makeBonus: 0.02,
            foulBonus: 0,
            assistCandidateIndices: nil,
            assistForceChance: 0.75
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
    random: inout SeededRandom
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
        let openness = clamp((movement - defensivePressure) / 60, min: -0.4, max: 0.8)
        let passRisk = clamp((getRating(defender, path: "defense.passPerception") - 55) / 220, min: 0, max: 0.15)
        let score = shotUtility * 12 + openness * 18 - passRisk * 8 + random.nextUnit() * 2
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
    onBallDefender: Player,
    screenerDefender: Player,
    screenEdge: Double,
    random: inout SeededRandom
) -> ScreenNavigation {
    let navIQ = getBaseRating(onBallDefender, path: "defense.perimeterDefense") * 0.4
        + getBaseRating(onBallDefender, path: "defense.lateralQuickness") * 0.35
        + getBaseRating(onBallDefender, path: "skills.shotIQ") * 0.25
    let bigMobility = getBaseRating(screenerDefender, path: "defense.lateralQuickness")
    let overWeight = max(5, navIQ * 1.1 - screenEdge * 20)
    let underWeight = max(5, (100 - navIQ * 0.3) * 0.5)
    let switchWeight = max(5, bigMobility * 0.9 - 15)
    let iceWeight = max(5, (getBaseRating(onBallDefender, path: "defense.shotContest") - 40) * 0.6)
    let total = overWeight + underWeight + switchWeight + iceWeight
    var pick = random.nextUnit() * max(total, 1)
    pick -= overWeight; if pick <= 0 { return .over }
    pick -= underWeight; if pick <= 0 { return .under }
    pick -= switchWeight; if pick <= 0 { return .switchSwitch }
    return .ice
}

private func resolvePickAndRollOutcome(
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
        let rollerFinishChance = clamp(0.44 + screenEdge * 0.3 + (passLean - 0.55) * 0.2, min: 0.2, max: 0.75)
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
        if random.nextUnit() < clamp(passLean * 0.34, min: 0.12, max: 0.42) {
            let receiverIdx = evaluatePassTarget(
                offenseLineup: offenseLineup,
                defenseLineup: defenseLineup,
                ballHandlerIdx: ballHandlerIdx,
                random: &random
            )
            let shooter = offenseLineup[receiverIdx]
            let spot = pickShooterSpot(player: shooter, random: &random)
            let shotType = chooseShotFromTendencies(shooter: shooter, spot: spot, random: &random)
            return PlayOutcome(
                shooterLineupIndex: receiverIdx,
                defenderLineupIndex: min(receiverIdx, defenseLineup.count - 1),
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
        if offenseLineup.count > 1 && random.nextUnit() < clamp(passLean * 0.55, min: 0.2, max: 0.62) {
            let receiverIdx = evaluatePassTarget(
                offenseLineup: offenseLineup,
                defenseLineup: defenseLineup,
                ballHandlerIdx: ballHandlerIdx,
                random: &random
            )
            let shooter = offenseLineup[receiverIdx]
            let spot = pickShooterSpot(player: shooter, random: &random)
            let shotType = chooseShotFromTendencies(shooter: shooter, spot: spot, random: &random)
            return PlayOutcome(
                shooterLineupIndex: receiverIdx,
                defenderLineupIndex: min(receiverIdx, defenseLineup.count - 1),
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
            if offenseLineup.count > 1 && random.nextUnit() < clamp(passLean * 0.4, min: 0.16, max: 0.5) {
                let receiverIdx = evaluatePassTarget(
                    offenseLineup: offenseLineup,
                    defenseLineup: defenseLineup,
                    ballHandlerIdx: ballHandlerIdx,
                    random: &random
                )
                let shooter = offenseLineup[receiverIdx]
                let spot = pickShooterSpot(player: shooter, random: &random)
                let shotType = chooseShotFromTendencies(shooter: shooter, spot: spot, random: &random)
                return PlayOutcome(
                    shooterLineupIndex: receiverIdx,
                    defenderLineupIndex: min(receiverIdx, defenseLineup.count - 1),
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
        if random.nextUnit() < clamp(0.58 + (passLean - 0.55) * 0.25, min: 0.42, max: 0.72) {
            // Reset pass to best-open teammate for a shot.
            let receiverIdx = offenseLineup.indices
                .filter { $0 != ballHandlerIdx && $0 != screenerIdx }
                .max { a, b in openShotUtility(offenseLineup[a]) < openShotUtility(offenseLineup[b]) }
                ?? ballHandlerIdx
            let shooter = offenseLineup[receiverIdx]
            let spot = pickShooterSpot(player: shooter, random: &random)
            let shotType = chooseShotFromTendencies(shooter: shooter, spot: spot, random: &random)
            return PlayOutcome(
                shooterLineupIndex: receiverIdx,
                defenderLineupIndex: min(receiverIdx, defenseLineup.count - 1),
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

private func choosePopDestination(screener: Player, random: inout SeededRandom) -> PopDestination {
    // Compare expected value: midrange (2 * mid_make_prob) vs three (3 * three_make_prob)
    let midRating = getRating(screener, path: "shooting.midrangeShot")
    let threeRating = getRating(screener, path: "shooting.threePointShooting")
    let midEV = 2 * clamp(0.32 + (midRating - 55) / 250, min: 0.25, max: 0.55)
    let threeEV = 3 * clamp(0.28 + (threeRating - 55) / 300, min: 0.2, max: 0.48)
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
    guard random.nextUnit() < 0.003 else { return }
    let offendingTeamId = random.nextUnit() < 0.5 ? 0 : 1
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
    let made = random.nextUnit() < clamp(getBaseRating(shooter, path: "shooting.freeThrows") / 120, min: 0.45, max: 0.92)
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
    // Tag a random defender on the offending team with the technical foul.
    let offendingLineupIdx = random.int(0, max(0, stored.teams[offendingTeamId].activeLineup.count - 1))
    addPlayerStat(stored: &stored, teamId: offendingTeamId, lineupIndex: offendingLineupIdx) { $0.fouls += 1 }
    if offendingTeamId >= 0, offendingTeamId < stored.teamFoulsInHalf.count {
        stored.teamFoulsInHalf[offendingTeamId] += 1
    }
}

private func maybeCallTimeout(stored: inout NativeGameStateStore.StoredState, teamId: Int, random: inout SeededRandom) {
    guard teamId >= 0, teamId < stored.teams.count else { return }
    guard stored.teams[teamId].team.timeouts > 0 else { return }
    let scoreDelta = stored.teams[teamId].score - stored.teams[teamId == 0 ? 1 : 0].score
    // Use timeout when down by a lot late, or when starters are gassed.
    let lateAndTrailing = stored.gameClockRemaining < 240 && scoreDelta < -6
    let starterTired = stored.teams[teamId].activeLineup.contains { ($0.condition.energy) < 45 }
    if lateAndTrailing && random.nextUnit() < 0.25 {
        stored.teams[teamId].team.timeouts -= 1
        recoverTeam(stored: &stored, teamId: teamId, amount: 18)
    } else if starterTired && random.nextUnit() < 0.05 {
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
            let next = min(100, current + 40)
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
    let foulChance: Double
    if takeFoulWindow {
        // Aggressive intentional fouling when trailing late, especially inside 20s.
        foulChance = clockRemaining <= 20 ? 0.65 : 0.35
    } else {
        foulChance = 0.04
    }
    guard random.nextUnit() < foulChance else { return }
    registerDefensiveFoul(stored: &stored, defenseTeamId: defenseTeamId, lineupIndex: defenderIdx, shooting: false)

    let teamFouls = teamFoulsForPeriod(stored, teamId: defenseTeamId)
    if teamFouls >= 10 {
        // Double bonus: 2 FTs.
        let shooter = stored.teams[offenseTeamId].activeLineup[ballHandlerIdx]
        var ftMade = 0
        for _ in 0..<2 {
            if random.nextUnit() < clamp(getBaseRating(shooter, path: "shooting.freeThrows") / 120, min: 0.45, max: 0.92) {
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
        let first = random.nextUnit() < clamp(getBaseRating(shooter, path: "shooting.freeThrows") / 120, min: 0.45, max: 0.92)
        var ftAtt = 1
        var ftMade = first ? 1 : 0
        if first {
            ftAtt = 2
            if random.nextUnit() < clamp(getBaseRating(shooter, path: "shooting.freeThrows") / 120, min: 0.45, max: 0.92) {
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
    guard random.nextUnit() < pressChance else { return nil }

    let offenseLineup = stored.teams[offenseTeamId].activeLineup
    let defenseLineup = stored.teams[defenseTeamId].activeLineup
    guard !offenseLineup.isEmpty, !defenseLineup.isEmpty else { return nil }

    // Pick a "receiver" (likely the team's best ball-handler) and two trap defenders.
    let receiverIdx = pickLineupIndexForBallHandler(lineup: offenseLineup, random: &random)
    let receiver = offenseLineup[receiverIdx]

    // Press break skill of the receiver and team passing support.
    let breakSkill = getRating(receiver, path: "skills.ballHandling") * 0.45
        + getRating(receiver, path: "skills.ballSafety") * 0.25
        + getRating(receiver, path: "skills.passingIQ") * 0.2
        + getRating(receiver, path: "athleticism.burst") * 0.1
    let teamPressBreak = stored.teams[offenseTeamId].team.tendencies.pressBreakPass / 50.0

    // Average of top two trap defenders' steal/hands.
    let defenderScores = defenseLineup.map { defender in
        getRating(defender, path: "defense.steals") * 0.45
            + getRating(defender, path: "skills.hands") * 0.25
            + getRating(defender, path: "defense.lateralQuickness") * 0.3
    }.sorted(by: >)
    let trapPressure = defenderScores.prefix(2).reduce(0, +) / 2

    let edge = (breakSkill * teamPressBreak - trapPressure) / 100

    let stealChance = clamp(0.09 - edge * 0.25, min: 0.02, max: 0.22)
    if random.nextUnit() < stealChance {
        // Trap steal.
        var bestDefIdx = 0
        var bestScore = -1.0
        for (idx, d) in defenseLineup.enumerated() {
            let s = getRating(d, path: "defense.steals") + getRating(d, path: "skills.hands") * 0.5
            if s > bestScore { bestScore = s; bestDefIdx = idx }
        }
        addPlayerStat(stored: &stored, teamId: offenseTeamId, lineupIndex: receiverIdx) { $0.turnovers += 1 }
        addPlayerStat(stored: &stored, teamId: defenseTeamId, lineupIndex: bestDefIdx) { $0.steals += 1 }
        addTeamExtra(stored: &stored, teamId: offenseTeamId, key: "turnovers", amount: 1)
        stored.pendingTransition = NativeGameStateStore.PendingTransition(source: "steal")
        return (event: "turnover", switchedPossession: true, points: 0)
    }

    // Survived the press cleanly → possible transition for offense.
    let attackAfterBreak = stored.teams[offenseTeamId].team.tendencies.pressBreakAttack / 50.0
    if random.nextUnit() < clamp(0.25 + (attackAfterBreak - 1) * 0.3 + edge * 0.2, min: 0.1, max: 0.7) {
        stored.pendingTransition = NativeGameStateStore.PendingTransition(source: "press_break")
    }
    return nil  // Let the normal possession play out.
}

// MARK: - Pass delivery

private func resolvePassInterception(
    passer: Player,
    receiver: Player,
    defenseLineup: [Player],
    random: inout SeededRandom
) -> Int? {
    guard !defenseLineup.isEmpty else { return nil }
    let passerAccuracy = getRating(passer, path: "skills.passingAccuracy") * 0.55
        + getRating(passer, path: "skills.passingIQ") * 0.3
        + getRating(passer, path: "skills.passingVision") * 0.15
    let receiverSafety = getRating(receiver, path: "skills.hands") * 0.6
        + getRating(receiver, path: "skills.shotIQ") * 0.4
    let offenseScore = (passerAccuracy + receiverSafety) / 2

    // Each defender gets a chance; take the highest pick chance.
    var bestChance = 0.0
    var bestIdx = 0
    for (idx, defender) in defenseLineup.enumerated() {
        let pick = getRating(defender, path: "defense.passPerception") * 0.4
            + getRating(defender, path: "defense.steals") * 0.25
            + getRating(defender, path: "skills.hands") * 0.2
            + getRating(defender, path: "defense.lateralQuickness") * 0.15
        let edge = (pick - offenseScore) / 140
        let chance = clamp(0.022 + edge * 0.12, min: 0.002, max: 0.18)
        if chance > bestChance {
            bestChance = chance
            bestIdx = idx
        }
    }
    if random.nextUnit() < bestChance {
        return bestIdx
    }
    return nil
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

    let sourceBoost: Double = transition.source == "steal" ? 0.12 : (transition.source == "press_break" ? 0.1 : 0.03)
    let pushChance = clamp(0.18 + sourceBoost, min: 0.05, max: 0.82)
    guard random.nextUnit() < pushChance else { return nil }

    let runnerIdx = pickTransitionRunnerIndex(lineup: offenseLineup, random: &random)
    let leadDefIdx = pickTransitionPointDefenderIndex(lineup: defenseLineup, random: &random)
    let runner = offenseLineup[runnerIdx]
    let leadDef = defenseLineup[leadDefIdx]

    let runScore = getRating(runner, path: "athleticism.burst") * 0.38
        + getRating(runner, path: "athleticism.speed") * 0.34
        + getRating(runner, path: "skills.ballHandling") * 0.14
        + getRating(runner, path: "skills.offballOffense") * 0.14
    let recoveryScore = getRating(leadDef, path: "athleticism.burst") * 0.33
        + getRating(leadDef, path: "athleticism.speed") * 0.31
        + getRating(leadDef, path: "defense.lateralQuickness") * 0.2
        + getRating(leadDef, path: "defense.shotContest") * 0.16
    let raceEdge = (runScore - recoveryScore) / 100 + sourceBoost
    let beatDefenseChance = clamp(0.24 + raceEdge * 0.5, min: 0.06, max: 0.86)
    guard random.nextUnit() < beatDefenseChance else { return nil }

    let shotType = chooseFastBreakFinish(player: runner, random: &random)
    let profile = shotProfile(for: shotType)
    let shotInteraction = resolveInteraction(
        offensePlayer: runner,
        defensePlayer: leadDef,
        offenseRatings: profile.offenseRatings,
        defenseRatings: profile.defenseRatings,
        random: &random
    )
    let madeProb = clamp(
        baseMakeProbability(for: shotType) + 0.18
            + (logistic(shotInteraction.edge + 0.5) - 0.5) * makeScale(for: shotType),
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
        return (event: "made_shot", switchedPossession: true, points: pts)
    }

    // Missed break finish: defense recovers rebounds more often in transition.
    let offReboundChance = 0.2
    if random.nextUnit() < offReboundChance {
        let rbIdx = pickRebounderIndex(lineup: offenseLineup, offensive: true, shotType: shotType, random: &random)
        addPlayerStat(stored: &stored, teamId: offenseTeamId, lineupIndex: rbIdx) { line in
            line.rebounds += 1
            line.offensiveRebounds += 1
        }
        return (event: "missed_shot", switchedPossession: false, points: 0)
    } else {
        let rbIdx = pickRebounderIndex(lineup: defenseLineup, offensive: false, shotType: shotType, random: &random)
        addPlayerStat(stored: &stored, teamId: defenseTeamId, lineupIndex: rbIdx) { line in
            line.rebounds += 1
            line.defensiveRebounds += 1
        }
        // Chained transition: defensive rebound seeds another potential break.
        stored.pendingTransition = NativeGameStateStore.PendingTransition(source: "def_rebound")
        return (event: "missed_shot", switchedPossession: true, points: 0)
    }
}
