import Foundation

func resolveHalfCourtAction(
    stored: inout NativeGameStateStore.StoredState,
    offenseTeamId: Int,
    defenseTeamId: Int,
    ballHandlerIdx: Int,
    defenderIdx: Int,
    ballHandler: Player,
    primaryDefender: Player,
    random: inout SeededRandom
) -> (eventType: String, points: Int, switchedPossession: Bool) {
    var eventType = "setup"
    var points = 0
    var switchedPossession = false

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
        let trailingSecurityRelief = clamp(Double(max(0, stored.teams[defenseTeamId].score - stored.teams[offenseTeamId].score)) / 340, min: 0, max: 0.05)
        let turnoverBase = clamp(0.085 + pressureEdge * 0.08, min: 0.05, max: 0.165)
        let turnoverBoost = clamp((0.5 - logistic(turnoverInteraction.edge)) * 0.1, min: -0.035, max: 0.07)
        let isTurnover = random.nextUnit() < clamp(turnoverBase + turnoverBoost - trailingSecurityRelief, min: 0.03, max: 0.22)

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
                offenseTeamId: offenseTeamId,
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
            let offenseDeficit = stored.teams[defenseTeamId].score - stored.teams[offenseTeamId].score
            let trailingBoost: Double = {
                guard stored.currentHalf >= 2 else { return 0 }
                let deficitBoost = clamp(Double(offenseDeficit) / 220, min: 0, max: 0.16)
                let lowScoreBoost = stored.teams[offenseTeamId].score < 32 && stored.gameClockRemaining <= 900 ? 0.2 : 0
                let largeDeficitBoost = offenseDeficit >= 18 ? 0.05 : 0
                return deficitBoost + lowScoreBoost + largeDeficitBoost
            }()
            let shooterUsageTax: Double = {
                guard play.shooterLineupIndex >= 0, play.shooterLineupIndex < stored.teams[offenseTeamId].activeLineupBoxIndices.count else { return 0 }
                let boxIdx = stored.teams[offenseTeamId].activeLineupBoxIndices[play.shooterLineupIndex]
                guard boxIdx >= 0, boxIdx < stored.teams[offenseTeamId].boxPlayers.count else { return 0 }
                let shooterBox = stored.teams[offenseTeamId].boxPlayers[boxIdx]
                let pointTax = Double(max(0, shooterBox.points - 10)) * 0.0073
                let attemptTax = Double(max(0, shooterBox.fgAttempts - 8)) * 0.0052
                return clamp(pointTax + attemptTax, min: 0, max: 0.2)
            }()
            let baseMinMake = minMakeProbability(for: shotType)
            let usageAdjustedMinMake = clamp(baseMinMake - shooterUsageTax * 0.6, min: baseMinMake - 0.11, max: baseMinMake)
            let madeProbability = clamp(
                shotMakeBase + shotTypeEdgeBonus + play.makeBonus + zoneMod + trailingBoost
                    + (logistic(shotInteraction.edge + play.edgeBonus) - 0.5) * shotMakeScale
                    - shooterUsageTax,
                min: usageAdjustedMinMake,
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
                let blockChance = clamp(0.07 + blockDefenseControl * 0.54, min: 0.06, max: 0.62)
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
                let andOneChance = clamp(0.012 + andOneDefenseControl * 0.08 + play.foulBonus * 0.45, min: 0.012, max: 0.12)
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
                let shootingFoulChance = clamp(0.018 + foulDefenseControl * 0.14 + play.foulBonus * 0.45, min: 0.02, max: 0.2)
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
                            offensePositioning: 0.9,
                            defensePositioning: 1.1,
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

    return (eventType, points, switchedPossession)
}

func possessionDurationSeconds(for pace: PaceProfile, random: inout SeededRandom) -> Int {
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

func paceShotBias(for pace: PaceProfile) -> Double {
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

func paceTransitionEmphasis(for pace: PaceProfile) -> Double {
    switch pace {
    case .verySlow: return 0.05
    case .slow: return 0.12
    case .slightlySlow: return 0.2
    case .normal: return 0.32
    case .slightlyFast: return 0.48
    case .fast: return 0.66
    case .veryFast: return 0.84
    }
}

func blowoutRotationMode(stored: NativeGameStateStore.StoredState, teamId: Int) -> BlowoutRotationMode {
    guard teamId >= 0, teamId < stored.teams.count else { return .none }
    guard stored.currentHalf >= 2 else { return .none }
    let oppId = teamId == 0 ? 1 : 0
    let lead = stored.teams[teamId].score - stored.teams[oppId].score
    let inFinalTenRegulation = stored.currentHalf == 2 && stored.gameClockRemaining <= 600
    let inFinalFiveRegulation = stored.currentHalf == 2 && stored.gameClockRemaining <= 300
    let inOvertime = stored.currentHalf > 2

    if lead >= 34 {
        return .deepBench
    }
    if inFinalFiveRegulation && lead >= 10 {
        return .deepBench
    }
    if inFinalTenRegulation && lead >= 14 {
        return .deepBench
    }
    if inOvertime && lead >= 16 {
        return .deepBench
    }
    if inFinalTenRegulation && lead >= 8 {
        return .bench
    }
    guard lead >= 18 else { return .none }
    return .bench
}

func syncPossessionRoles(stored: inout NativeGameStateStore.StoredState) {
    let offenseTeamId = stored.possessionTeamId
    let defenseTeamId = offenseTeamId == 0 ? 1 : 0
    for teamId in stored.teams.indices {
        let role = teamId == offenseTeamId ? "offense" : teamId == defenseTeamId ? "defense" : nil
        for idx in stored.teams[teamId].activeLineup.indices {
            stored.teams[teamId].activeLineup[idx].condition.possessionRole = role
        }
    }
}
