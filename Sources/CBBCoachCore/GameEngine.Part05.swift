import Foundation

func reboundCrashParticipationWeight(
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
    let roleFactor = clamp(
        0.76
            + positionProximity(player, zone: zone) * 0.2
            + zonePresenceAffinity(player, zone: zone) * 0.16,
        min: 0.72,
        max: 1.24
    )
    if let location {
        // Location-first crash model: players farther from the landing zone gain more from high crash intent.
        let base = 0.68 + location * 0.28
        let distance = clamp(1.35 - location, min: 0, max: 1)
        let crashGain = 0.32 + distance * 0.78
        return max(0.2, (base + crash * crashGain) * roleFactor)
    }
    let mobility = getBaseRating(player, path: "athleticism.burst") * 0.42
        + getBaseRating(player, path: "athleticism.speed") * 0.3
        + getBaseRating(player, path: "skills.hustle") * 0.28
    let mobilityScale = clamp((mobility - 50) / 100, min: -0.18, max: 0.24)
    return max(0.2, (0.84 + crash * (0.34 + mobilityScale)) * roleFactor)
}

func reboundCandidateCount(crashPreference: Double) -> Int {
    let crash = clamp(crashPreference, min: 0, max: 1)
    if crash > 0.72 { return 3 }
    if crash > 0.56 { return 2 }
    if crash < 0.28 { return 1 }
    return 2
}

func reboundChaosScale(for zone: ReboundZone) -> Double {
    switch zone {
    case .paint, .leftBlock, .rightBlock:
        return 0.11
    case .leftPerimeter, .rightPerimeter:
        return 0.2
    case .topPerimeter:
        return 0.22
    }
}

func heightReboundRating(_ player: Player) -> Double {
    let heightInches = getHeightInches(player)
    return clamp((heightInches - 76) * 4 + 56, min: 34, max: 98)
}

func wingspanReboundRating(_ player: Player) -> Double {
    let wingspanInches = getWingspanInches(player)
    return clamp((wingspanInches - 80) * 4 + 56, min: 34, max: 100)
}

func reboundCollectorRoleBonus(_ player: Player) -> Double {
    switch player.bio.position {
    case .c, .big:
        return 0.24
    case .pf:
        return 0.17
    case .f:
        return 0.12
    case .sf, .wing:
        return 0.07
    case .sg, .cg:
        return -0.08
    case .pg:
        return -0.16
    }
}

private func baseRating(_ raw: Int) -> Double {
    normalizedBaseRating(Double(raw), fallback: 50)
}

func offensiveReboundSkillScore(_ player: Player, zone: ReboundZone) -> Double {
    let oreb = baseRating(player.rebounding.offensiveRebounding)
    let box = baseRating(player.rebounding.boxouts)
    let hustle = baseRating(player.skills.hustle)
    let hands = baseRating(player.skills.hands)
    let vertical = baseRating(player.athleticism.vertical)
    let strength = baseRating(player.athleticism.strength)
    let burst = baseRating(player.athleticism.burst)
    let speed = baseRating(player.athleticism.speed)
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

func defensiveReboundSkillScore(_ player: Player, zone: ReboundZone) -> Double {
    let dreb = baseRating(player.rebounding.defensiveRebound)
    let box = baseRating(player.rebounding.boxouts)
    let hustle = baseRating(player.skills.hustle)
    let hands = baseRating(player.skills.hands)
    let vertical = baseRating(player.athleticism.vertical)
    let strength = baseRating(player.athleticism.strength)
    let burst = baseRating(player.athleticism.burst)
    let speed = baseRating(player.athleticism.speed)
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

func topReboundCandidateIndices(
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

func selectReboundScrambleParticipants(
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

    var pairOptions: [(offenseIdx: Int, defenseIdx: Int, score: Double)] = []
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
            let sizeEdge = (heightReboundRating(offenseLineup[offenseIdx]) - heightReboundRating(defenseLineup[defenseIdx])) * 0.008
                + (wingspanReboundRating(offenseLineup[offenseIdx]) - wingspanReboundRating(defenseLineup[defenseIdx])) * 0.009
            pairOptions.append((offenseIdx, defenseIdx, interaction.edge + sizeEdge))
        }
    }
    guard !pairOptions.isEmpty else { return (offenseCandidates[0], defenseCandidates[0]) }
    let pairWeights = pairOptions.map { option in
        Foundation.exp(clamp(option.score * 0.82, min: -2.1, max: 2.1))
    }
    let chosen = pairOptions[weightedChoiceIndex(weights: pairWeights, random: &random)]
    return (chosen.offenseIdx, chosen.defenseIdx)
}

func resolveReboundOutcome(
    stored: inout NativeGameStateStore.StoredState,
    offenseTeamId: Int,
    defenseTeamId: Int,
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
    let scramblePair = selectReboundScrambleParticipants(
        stored: &stored,
        offenseLineup: offenseLineup,
        defenseLineup: defenseLineup,
        zone: zone,
        offenseCrashPreference: offenseCrashPreference,
        defenseCrashPreference: defenseCrashPreference,
        offenseLocationHints: offenseLocationHints,
        defenseLocationHints: defenseLocationHints,
        random: &random
    )
    let bestOffenseIdx = scramblePair.offenseIdx
    let bestDefenseIdx = scramblePair.defenseIdx
    let boxoutBattle = resolveInteractionWithTrace(
        stored: &stored,
        label: "rebound_boxout_battle",
        offensePlayer: offenseLineup[bestOffenseIdx],
        defensePlayer: defenseLineup[bestDefenseIdx],
        offenseRatings: ["rebounding.offensiveRebounding", "skills.hustle", "athleticism.vertical", "athleticism.strength", "skills.hands"],
        defenseRatings: ["rebounding.boxouts", "rebounding.defensiveRebound", "athleticism.strength", "athleticism.vertical", "defense.defensiveControl"],
        random: &random
    )
    let boxoutSizeEdge = (heightReboundRating(offenseLineup[bestOffenseIdx]) - heightReboundRating(defenseLineup[bestDefenseIdx])) * 0.009
        + (wingspanReboundRating(offenseLineup[bestOffenseIdx]) - wingspanReboundRating(defenseLineup[bestDefenseIdx])) * 0.010
    let boxoutPositioningEdge = (offensePositioning - defensePositioning) * 0.16
    let oReboundElite = eliteRatingPremium(getRating(offenseLineup[bestOffenseIdx], path: "rebounding.offensiveRebounding"), maxBoost: 0.55)
    let dBoxoutElite = eliteRatingPremium(getRating(defenseLineup[bestDefenseIdx], path: "rebounding.boxouts"), maxBoost: 0.55)
    let boxoutEliteEdge = oReboundElite - dBoxoutElite
    let slipEdge = boxoutBattle.edge + boxoutSizeEdge + boxoutPositioningEdge + boxoutEliteEdge

    let gatherBattle = resolveInteractionWithTrace(
        stored: &stored,
        label: "rebound_gather_battle",
        offensePlayer: offenseLineup[bestOffenseIdx],
        defensePlayer: defenseLineup[bestDefenseIdx],
        offenseRatings: ["rebounding.offensiveRebounding", "skills.hands", "skills.hustle", "athleticism.vertical", "athleticism.burst"],
        defenseRatings: ["rebounding.defensiveRebound", "rebounding.boxouts", "skills.hands", "skills.hustle", "athleticism.vertical"],
        random: &random
    )
    let gatherSizeEdge = (heightReboundRating(offenseLineup[bestOffenseIdx]) - heightReboundRating(defenseLineup[bestDefenseIdx])) * 0.009
        + (wingspanReboundRating(offenseLineup[bestOffenseIdx]) - wingspanReboundRating(defenseLineup[bestDefenseIdx])) * 0.010
    let chaosScale = reboundChaosScale(for: zone)
    let reboundChaosNoise = (random.nextUnit() + random.nextUnit() + random.nextUnit() - 1.5) * (chaosScale * 2.3)
    let dReboundElite = eliteRatingPremium(getRating(defenseLineup[bestDefenseIdx], path: "rebounding.defensiveRebound"), maxBoost: 0.55)
    let gatherEliteEdge = oReboundElite - dReboundElite
    let finalEdge = gatherBattle.edge + gatherSizeEdge + (offensePositioning - defensePositioning) * 0.12 + slipEdge * 0.4 + reboundChaosNoise + gatherEliteEdge
    let crashEdge = (offenseCrashPreference - defenseCrashPreference) * 0.22
    // Defensive teams convert more misses by default; offense needs a real edge to sustain OREBs.
    let defensiveAdvantage = 1.05 + clamp((defensePositioning - offensePositioning) * 0.09, min: -0.08, max: 0.14)
    let offenseCollectProbability = clamp(logistic(finalEdge + crashEdge - defensiveAdvantage), min: 0.05, max: 0.62)
    if random.nextUnit() < offenseCollectProbability {
        let rebounderIdx = selectReboundCollectorViaInteractions(
            stored: &stored,
            offenseTeamId: offenseTeamId,
            defenseTeamId: defenseTeamId,
            offenseLineup: offenseLineup,
            defenseLineup: defenseLineup,
            offenseCollects: true,
            zone: zone,
            offenseCrashPreference: offenseCrashPreference,
            defenseCrashPreference: defenseCrashPreference,
            offenseLocationHints: offenseLocationHints,
            defenseLocationHints: defenseLocationHints,
            priorityOffenseIndices: offenseCandidates,
            priorityDefenseIndices: defenseCandidates,
            random: &random
        )
        return ReboundOutcome(offensive: true, lineupIndex: rebounderIdx)
    }
    let rebounderIdx = selectReboundCollectorViaInteractions(
        stored: &stored,
        offenseTeamId: offenseTeamId,
        defenseTeamId: defenseTeamId,
        offenseLineup: offenseLineup,
        defenseLineup: defenseLineup,
        offenseCollects: false,
        zone: zone,
        offenseCrashPreference: offenseCrashPreference,
        defenseCrashPreference: defenseCrashPreference,
        offenseLocationHints: offenseLocationHints,
        defenseLocationHints: defenseLocationHints,
        priorityOffenseIndices: offenseCandidates,
        priorityDefenseIndices: defenseCandidates,
        random: &random
    )
    return ReboundOutcome(offensive: false, lineupIndex: rebounderIdx)
}

func selectReboundCollectorViaInteractions(
    stored: inout NativeGameStateStore.StoredState,
    offenseTeamId: Int,
    defenseTeamId: Int,
    offenseLineup: [Player],
    defenseLineup: [Player],
    offenseCollects: Bool,
    zone: ReboundZone,
    offenseCrashPreference: Double,
    defenseCrashPreference: Double,
    offenseLocationHints: [OffensiveSpot?]? = nil,
    defenseLocationHints: [OffensiveSpot?]? = nil,
    priorityOffenseIndices: [Int],
    priorityDefenseIndices: [Int],
    random: inout SeededRandom
) -> Int {
    guard !offenseLineup.isEmpty, !defenseLineup.isEmpty else { return 0 }
    let offensePriority = Set(priorityOffenseIndices.filter { $0 >= 0 && $0 < offenseLineup.count })
    let defensePriority = Set(priorityDefenseIndices.filter { $0 >= 0 && $0 < defenseLineup.count })
    let offenseCollectorIndices = offensePriority.isEmpty ? Array(offenseLineup.indices) : Array(offensePriority)
    let defenseCollectorIndices = defensePriority.isEmpty ? Array(defenseLineup.indices) : Array(defensePriority)

    if offenseCollects {
        var collectorScores: [(idx: Int, score: Double)] = []
        for offenseIdx in offenseCollectorIndices {
            let nearby = reboundNearbyWeight(offenseLineup[offenseIdx], lineupIndex: offenseIdx, zone: zone, locationHints: offenseLocationHints)
            let crashWeight = reboundCrashParticipationWeight(
                offenseLineup[offenseIdx],
                lineupIndex: offenseIdx,
                zone: zone,
                crashPreference: offenseCrashPreference,
                locationHints: offenseLocationHints
            )
            let participationBoost = offensePriority.contains(offenseIdx) ? 0.02 : 0
            var interactionEdges: [Double] = []
            for defenseIdx in defenseLineup.indices {
                let interaction = resolveInteractionWithTrace(
                    stored: &stored,
                    label: "rebound_collector_offense",
                    offensePlayer: offenseLineup[offenseIdx],
                    defensePlayer: defenseLineup[defenseIdx],
                    offenseRatings: ["rebounding.offensiveRebounding", "skills.hands", "skills.hustle", "athleticism.vertical", "athleticism.burst"],
                    defenseRatings: ["rebounding.defensiveRebound", "rebounding.boxouts", "skills.hands", "skills.hustle", "athleticism.strength"],
                    random: &random
                )
                let sizeEdge = (heightReboundRating(offenseLineup[offenseIdx]) - heightReboundRating(defenseLineup[defenseIdx])) * 0.007
                    + (wingspanReboundRating(offenseLineup[offenseIdx]) - wingspanReboundRating(defenseLineup[defenseIdx])) * 0.008
                interactionEdges.append(interaction.edge + sizeEdge)
            }
            let matchupMean = average(interactionEdges)
            let matchupBest = interactionEdges.max() ?? matchupMean
            let matchupScore = matchupMean * 0.7 + matchupBest * 0.3
            let roleBonus = reboundCollectorRoleBonus(offenseLineup[offenseIdx])
            let reboundLoadTax: Double = {
                guard offenseTeamId >= 0, offenseTeamId < stored.teams.count else { return 0 }
                guard offenseIdx >= 0, offenseIdx < stored.teams[offenseTeamId].activeLineupBoxIndices.count else { return 0 }
                let boxIdx = stored.teams[offenseTeamId].activeLineupBoxIndices[offenseIdx]
                guard boxIdx >= 0, boxIdx < stored.teams[offenseTeamId].boxPlayers.count else { return 0 }
                let currentRebounds = stored.teams[offenseTeamId].boxPlayers[boxIdx].rebounds
                let baselineLoad = Double(max(0, currentRebounds - 6)) * 0.1
                let surgeLoad = Double(max(0, currentRebounds - 10)) * 0.08
                return clamp(baselineLoad + surgeLoad, min: 0, max: 1.8)
            }()
            let focusBoost: Double = {
                guard offenseTeamId >= 0, offenseTeamId < stored.teams.count else { return 0 }
                guard offenseIdx >= 0, offenseIdx < stored.teams[offenseTeamId].activeLineupBoxIndices.count else { return 0 }
                let boxIdx = stored.teams[offenseTeamId].activeLineupBoxIndices[offenseIdx]
                return boxIdx == stored.teams[offenseTeamId].reboundFocusBoxIndex ? stored.teams[offenseTeamId].reboundFocusBoost : 0
            }()
            let score = matchupScore + (nearby - 1) * 0.26 + (crashWeight - 1) * 0.22 + participationBoost + roleBonus + focusBoost - reboundLoadTax
            collectorScores.append((offenseIdx, score))
        }
        let chaosScale = reboundChaosScale(for: zone)
        let collectorWeights = collectorScores.map { candidate in
            let jitter = 0.78 + random.nextUnit() * 0.44
            let noisyScore = candidate.score + (random.nextUnit() + random.nextUnit() - 1.0) * chaosScale * 2.8
            return Foundation.exp(clamp(noisyScore * 1.05, min: -2.7, max: 2.7)) * jitter
        }
        return collectorScores[weightedChoiceIndex(weights: collectorWeights, random: &random)].idx
    }

    var collectorScores: [(idx: Int, score: Double)] = []
    for defenseIdx in defenseCollectorIndices {
        let nearby = reboundNearbyWeight(defenseLineup[defenseIdx], lineupIndex: defenseIdx, zone: zone, locationHints: defenseLocationHints)
        let crashWeight = reboundCrashParticipationWeight(
            defenseLineup[defenseIdx],
            lineupIndex: defenseIdx,
            zone: zone,
            crashPreference: defenseCrashPreference,
            locationHints: defenseLocationHints
        )
        let participationBoost = defensePriority.contains(defenseIdx) ? 0.02 : 0
        var interactionEdges: [Double] = []
        for offenseIdx in offenseLineup.indices {
            let interaction = resolveInteractionWithTrace(
                stored: &stored,
                label: "rebound_collector_defense",
                offensePlayer: offenseLineup[offenseIdx],
                defensePlayer: defenseLineup[defenseIdx],
                offenseRatings: ["rebounding.offensiveRebounding", "skills.hands", "skills.hustle", "athleticism.vertical", "athleticism.burst"],
                defenseRatings: ["rebounding.defensiveRebound", "rebounding.boxouts", "skills.hands", "skills.hustle", "athleticism.strength"],
                random: &random
            )
            let sizeEdge = (heightReboundRating(defenseLineup[defenseIdx]) - heightReboundRating(offenseLineup[offenseIdx])) * 0.007
                + (wingspanReboundRating(defenseLineup[defenseIdx]) - wingspanReboundRating(offenseLineup[offenseIdx])) * 0.008
            interactionEdges.append(-interaction.edge + sizeEdge)
        }
        let matchupMean = average(interactionEdges)
        let matchupBest = interactionEdges.max() ?? matchupMean
        let matchupScore = matchupMean * 0.7 + matchupBest * 0.3
        let roleBonus = reboundCollectorRoleBonus(defenseLineup[defenseIdx])
        let reboundLoadTax: Double = {
            guard defenseTeamId >= 0, defenseTeamId < stored.teams.count else { return 0 }
            guard defenseIdx >= 0, defenseIdx < stored.teams[defenseTeamId].activeLineupBoxIndices.count else { return 0 }
            let boxIdx = stored.teams[defenseTeamId].activeLineupBoxIndices[defenseIdx]
            guard boxIdx >= 0, boxIdx < stored.teams[defenseTeamId].boxPlayers.count else { return 0 }
            let currentRebounds = stored.teams[defenseTeamId].boxPlayers[boxIdx].rebounds
            let baselineLoad = Double(max(0, currentRebounds - 6)) * 0.1
            let surgeLoad = Double(max(0, currentRebounds - 10)) * 0.08
            return clamp(baselineLoad + surgeLoad, min: 0, max: 1.8)
        }()
        let focusBoost: Double = {
            guard defenseTeamId >= 0, defenseTeamId < stored.teams.count else { return 0 }
            guard defenseIdx >= 0, defenseIdx < stored.teams[defenseTeamId].activeLineupBoxIndices.count else { return 0 }
            let boxIdx = stored.teams[defenseTeamId].activeLineupBoxIndices[defenseIdx]
            return boxIdx == stored.teams[defenseTeamId].reboundFocusBoxIndex ? stored.teams[defenseTeamId].reboundFocusBoost : 0
        }()
        let score = matchupScore + (nearby - 1) * 0.26 + (crashWeight - 1) * 0.22 + participationBoost + roleBonus + focusBoost - reboundLoadTax
        collectorScores.append((defenseIdx, score))
    }
    let chaosScale = reboundChaosScale(for: zone)
    let collectorWeights = collectorScores.map { candidate in
        let jitter = 0.78 + random.nextUnit() * 0.44
        let noisyScore = candidate.score + (random.nextUnit() + random.nextUnit() - 1.0) * chaosScale * 2.8
        return Foundation.exp(clamp(noisyScore * 1.05, min: -2.7, max: 2.7)) * jitter
    }
    return collectorScores[weightedChoiceIndex(weights: collectorWeights, random: &random)].idx
}

func weightedRandomIndex(lineup: [Player], random: inout SeededRandom, weight: (Player) -> Double) -> Int {
    let weights = lineup.map { max(0.1, weight($0)) }
    return weightedChoiceIndex(weights: weights, random: &random)
}

func weightedChoiceIndex(weights: [Double], random: inout SeededRandom) -> Int {
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

func applyChunkMinutesAndEnergy(stored: inout NativeGameStateStore.StoredState, possessionSeconds: Int) {
    let minuteDelta = Double(possessionSeconds) / 60
    let energyDelta = Double(possessionSeconds) * 0.03
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

struct SubCandidate {
    var rosterIndex: Int
    var score: Double
    var energy: Double
    var minutesPlayed: Double
    var target: Double
    var rotationNeed: Double
    var fouls: Int
    var fouledOut: Bool
}

func playerOverallSkill(_ player: Player) -> Double {
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
