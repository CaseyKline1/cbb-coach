import Foundation

func resolvePlay(
    stored: inout NativeGameStateStore.StoredState,
    offenseLineup: [Player],
    defenseLineup: [Player],
    offenseTeamId: Int,
    ballHandlerIdx: Int,
    defenderIdx: Int,
    team: Team,
    random: inout SeededRandom
) -> PlayOutcome {
    let ballHandlerBoxIndex = ballHandlerIdx < stored.teams[offenseTeamId].activeLineupBoxIndices.count
        ? stored.teams[offenseTeamId].activeLineupBoxIndices[ballHandlerIdx]
        : ballHandlerIdx
    let handlerInitiated = stored.teams[offenseTeamId].initiatedActionCountByBoxIndex[ballHandlerBoxIndex, default: 0]
    let totalInitiated = max(1, stored.teams[offenseTeamId].initiatedActionCount)
    let handlerShare = Double(handlerInitiated) / Double(totalInitiated)
    let handlerUsageOverload = clamp((handlerShare - 0.34) / 0.26, min: 0, max: 1)
    let actionPassDecisionBias = 0.12 + handlerUsageOverload * 0.06
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
            lineupBoxIndices: stored.teams[offenseTeamId].activeLineupBoxIndices,
            initiatedActionCountByBoxIndex: stored.teams[offenseTeamId].initiatedActionCountByBoxIndex,
            totalInitiatedActions: stored.teams[offenseTeamId].initiatedActionCount,
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
        // Elite slashers (high burst + handle) win drives more decisively than the
        // matchup logistic alone allows; elite on-ball stoppers do the inverse.
        let driverElite = eliteRatingPremium(getRating(ballHandler, path: "athleticism.burst"), maxBoost: 0.30)
            + eliteRatingPremium(getRating(ballHandler, path: "skills.ballHandling"), maxBoost: 0.25)
        let stopperElite = eliteRatingPremium(getRating(onBallDefender, path: "defense.perimeterDefense"), maxBoost: 0.30)
            + eliteRatingPremium(getRating(onBallDefender, path: "defense.lateralQuickness"), maxBoost: 0.25)
        let driveControl = logistic(driveInteraction.edge + driverElite - stopperElite)
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
            0.62 + helpDefenseControl * 0.5 + max(0, driveControl - 0.5) * 0.12 + actionPassDecisionBias,
            min: driveTier == 2 ? 0.8 + actionPassDecisionBias : (driveTier == 1 ? 0.74 + actionPassDecisionBias : 0.64 + actionPassDecisionBias),
            max: 0.99
        )
        if random.nextUnit() < kickChance && offenseLineup.count > 1 {
            let receiverIdx = evaluatePassTarget(
                offenseLineup: offenseLineup,
                defenseLineup: defenseLineup,
                ballHandlerIdx: ballHandlerIdx,
                random: &random,
                opennessBonus: sagBonus,
                lineupBoxIndices: stored.teams[offenseTeamId].activeLineupBoxIndices,
                currentBoxPlayers: stored.teams[offenseTeamId].boxPlayers
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
                let kickMakeBonus = driveTier == 2 ? 0.05 : (driveTier == 1 ? 0.035 : 0.02)
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
            0.34 + driveControl * 0.5 - helpDefenseControl * 0.22 - handlerUsageOverload * 0.24,
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
            makeBonus: -0.05 - handlerUsageOverload * 0.07,
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
        // Post premium is intentionally larger than drive/PnR: elite low-post players
        // (Embiid/Jokic tier) should dominate average defenders rather than blending
        // into the field. The premium feeds the postControl edge, which then ripples
        // through shot edgeBonus/foulBonus/shot-type weights below.
        let postOffenseElite = eliteRatingPremium(getRating(shooter, path: "postGame.postControl"), maxBoost: 0.55)
            + eliteRatingPremium(getRating(shooter, path: "athleticism.strength"), maxBoost: 0.20)
        let postDefenseElite = eliteRatingPremium(getRating(postDefender, path: "defense.postDefense"), maxBoost: 0.55)
            + eliteRatingPremium(getRating(postDefender, path: "athleticism.strength"), maxBoost: 0.18)
        let postControl = logistic(postAdvantage.edge + postOffenseElite - postDefenseElite)
        let postKickChance = clamp(
            0.62 + (1 - postControl) * 0.32 + actionPassDecisionBias,
            min: 0.7 + actionPassDecisionBias,
            max: 0.97
        )
        if offenseLineup.count > 1 && random.nextUnit() < postKickChance {
            let outletIdx = evaluatePassTarget(
                offenseLineup: offenseLineup,
                defenseLineup: defenseLineup,
                ballHandlerIdx: postIdx,
                random: &random,
                opennessBonus: 0.08 + (1 - postControl) * 0.08,
                lineupBoxIndices: stored.teams[offenseTeamId].activeLineupBoxIndices,
                currentBoxPlayers: stored.teams[offenseTeamId].boxPlayers
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
                    makeBonus: 0.03,
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
            makeBonus: postIdx == ballHandlerIdx ? (-0.04 - handlerUsageOverload * 0.06) : 0,
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
            handlerUsageOverload: handlerUsageOverload,
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
        let popReaderElite = eliteRatingPremium(getRating(pickActionBallHandler, path: "skills.passingVision"), maxBoost: 0.35)
        let popPerimeterElite = eliteRatingPremium(getRating(onBallDefender, path: "defense.perimeterDefense"), maxBoost: 0.30)
        let popReadControl = logistic(popRead.edge + popReaderElite - popPerimeterElite)
        let ballHandlerPassLean = clamp(
            0.55
                + (50 - getRating(pickActionBallHandler, path: "tendencies.shootVsPass")) / 150
                + (getRating(pickActionBallHandler, path: "skills.passingVision") - 50) / 300,
            min: 0.4,
            max: 0.82
        )
        let offBallKickChance = clamp(
            0.55 + popReadControl * 0.32 + ballHandlerPassLean * 0.14 + max(0, screenEdge) * 0.08 + actionPassDecisionBias,
            min: 0.62 + actionPassDecisionBias,
            max: 0.97
        )
        let alternateShooterIdx: Int? = {
            guard offenseLineup.count > 2 && random.nextUnit() < offBallKickChance else { return nil }
            let idx = evaluatePassTarget(
                offenseLineup: offenseLineup,
                defenseLineup: defenseLineup,
                ballHandlerIdx: pickActionBallHandlerIdx,
                random: &random,
                lineupBoxIndices: stored.teams[offenseTeamId].activeLineupBoxIndices,
                currentBoxPlayers: stored.teams[offenseTeamId].boxPlayers
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
                makeBonus: 0.05,
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
            makeBonus: 0.04,
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
            let receiverIdx = evaluatePassTarget(
                offenseLineup: offenseLineup,
                defenseLineup: defenseLineup,
                ballHandlerIdx: ballHandlerIdx,
                random: &random,
                opennessBonus: -0.04,
                lineupBoxIndices: stored.teams[offenseTeamId].activeLineupBoxIndices,
                currentBoxPlayers: stored.teams[offenseTeamId].boxPlayers
            )
            let shooter = offenseLineup[receiverIdx]
            let shotDefenderIdx = min(receiverIdx, defenseLineup.count - 1)
            let fallbackSelection = chooseInteractionSpotAndShot(
                stored: &stored,
                shooter: shooter,
                defender: defenseLineup[shotDefenderIdx],
                random: &random
            )
            let fallbackSpot = fallbackSelection.spot
            let fallbackShot = fallbackSelection.shotType
            return PlayOutcome(
                shooterLineupIndex: receiverIdx,
                defenderLineupIndex: shotDefenderIdx,
                shotType: fallbackShot,
                spot: fallbackSpot,
                edgeBonus: -0.08,
                makeBonus: 0.0,
                foulBonus: 0,
                assistCandidateIndices: [ballHandlerIdx],
                assistForceChance: 0.72
            )
        }
        // Ball moves to the teammate with the highest open-shot expected value after relocation.
        let receiverIdx = evaluatePassTarget(
            offenseLineup: offenseLineup,
            defenseLineup: defenseLineup,
            ballHandlerIdx: ballHandlerIdx,
            random: &random,
            opennessBonus: (creationControl - 0.5) * 0.18,
            lineupBoxIndices: stored.teams[offenseTeamId].activeLineupBoxIndices,
            currentBoxPlayers: stored.teams[offenseTeamId].boxPlayers
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
            makeBonus: 0.04,
            foulBonus: 0,
            assistCandidateIndices: [ballHandlerIdx],
            assistForceChance: 0.82,
            passInterceptionRiskShift: -0.22
        )
    }
}
