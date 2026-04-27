import Foundation

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
        let offenseLead = stored.teams[offenseTeamId].score - stored.teams[defenseTeamId].score
        let lateGameBlowout = stored.currentHalf >= 2 && offenseLead >= 16
        let trailingPushPace = stored.currentHalf >= 2 && offenseLead <= -12
        let effectivePace: PaceProfile = lateGameBlowout
            ? .verySlow
            : (trailingPushPace ? .fast : (blowoutMode == .none ? stored.teams[offenseTeamId].team.pace : .verySlow))
        let possessionSeconds = possessionDurationSeconds(for: effectivePace, random: &random)
        applyChunkMinutesAndEnergy(stored: &stored, possessionSeconds: possessionSeconds)

        let ballHandlerIdx = pickLineupIndexForBallHandler(
            lineup: stored.teams[offenseTeamId].activeLineup,
            lineupBoxIndices: stored.teams[offenseTeamId].activeLineupBoxIndices,
            initiatedActionCountByBoxIndex: stored.teams[offenseTeamId].initiatedActionCountByBoxIndex,
            totalInitiatedActions: stored.teams[offenseTeamId].initiatedActionCount,
            random: &random
        )
        recordActionInitiator(stored: &stored, teamId: offenseTeamId, lineupIndex: ballHandlerIdx)
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
        let offenseDeficit = stored.teams[defenseTeamId].score - stored.teams[offenseTeamId].score
        let trailingAttemptBoost = clamp(Double(max(0, offenseDeficit)) / 240, min: 0, max: 0.14)
        let lowScoreAttemptBoost = stored.currentHalf >= 2 && stored.teams[offenseTeamId].score < 30 ? 0.15 : 0
        let attemptShotChance = clamp(
            0.07
                + Foundation.pow(shotClockPressure, 1.35) * 0.50
                + (possessionControl - 0.5) * 0.27
                + intentBias
                + trailingAttemptBoost
                + lowScoreAttemptBoost
                + paceBias,
            min: 0.14,
            max: 0.78
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
            let resolution = resolveHalfCourtAction(
                stored: &stored,
                offenseTeamId: offenseTeamId,
                defenseTeamId: defenseTeamId,
                ballHandlerIdx: ballHandlerIdx,
                defenderIdx: defenderIdx,
                ballHandler: ballHandler,
                primaryDefender: primaryDefender,
                random: &random
            )
            eventType = resolution.eventType
            points = resolution.points
            switchedPossession = resolution.switchedPossession
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
