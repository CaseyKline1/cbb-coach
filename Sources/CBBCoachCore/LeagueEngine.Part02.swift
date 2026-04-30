import Foundation

public func createD1League(options: CreateLeagueOptions) throws -> LeagueState {
    let dataset = try LoadedD1Data.get()
    let allTeams = dataset.conferences.flatMap { conference in
        conference.teams.map { (conference, $0) }
    }

    guard !allTeams.isEmpty else {
        throw NSError(domain: "CBBCoachCore", code: 1001, userInfo: [NSLocalizedDescriptionKey: "No teams available in D1 dataset"]) 
    }

    let requestedName = options.userTeamName.trimmingCharacters(in: .whitespacesAndNewlines)
    let userTuple = allTeams.first(where: { _, team in
        if let userTeamId = options.userTeamId, !userTeamId.isEmpty {
            return team.id == userTeamId
        }
        return team.name.caseInsensitiveCompare(requestedName) == .orderedSame
    }) ?? allTeams.first!

    let userConference = userTuple.0
    let userTeamRef = userTuple.1

    var random = SeededRandom(seed: hashString(options.seed))
    let totalRegularSeasonGames = max(1, options.totalRegularSeasonGames)

    var teams: [LeagueStore.TeamState] = []
    teams.reserveCapacity(allTeams.count)

    for (conference, teamRef) in allTeams {
        let isUser = teamRef.id == userTeamRef.id
        let teamPrestige = prestigeForTeam(teamId: teamRef.id, conferenceId: conference.id)
        let teamLastYearResult = lastYearResultForTeam(teamId: teamRef.id, conferenceId: conference.id)
        // Keep using the shared league RNG so each team's roster draw is unique.
        let roster = buildTeamRoster(teamName: teamRef.name, prestige: teamPrestige, random: &random)

        var createTeamOptions = CreateTeamOptions(name: teamRef.name, players: roster)
        createTeamOptions.formation = random.choose(OffensiveFormation.allCases) ?? .motion
        createTeamOptions.defenseScheme = random.choose(DefenseScheme.allCases) ?? .manToMan
        createTeamOptions.pace = random.choose(PaceProfile.allCases) ?? .normal

        if isUser {
            var staffOptions = CreateCoachingStaffOptions()
            var head = CreateCoachOptions()
            head.role = .headCoach
            head.name = options.userHeadCoachName
            head.skills = options.userHeadCoachSkills
            head.almaMater = options.userHeadCoachAlmaMater
            head.pipelineState = options.userHeadCoachPipelineState
            staffOptions.headCoach = head
            staffOptions.teamName = teamRef.name
            createTeamOptions.coachingStaff = createCoachingStaff(options: staffOptions, random: &random)
        }

        let model = createTeam(options: createTeamOptions, random: &random)
        let confGames = max(0, min(conference.inferredConferenceGames ?? 18, totalRegularSeasonGames))
        let nonConfGames = max(0, totalRegularSeasonGames - confGames)

        teams.append(
            LeagueStore.TeamState(
                teamId: teamRef.id,
                teamName: teamRef.name,
                conferenceId: conference.id,
                conferenceName: conference.name,
                teamModel: model,
                prestige: teamPrestige,
                lastYearResult: teamLastYearResult,
                wins: 0,
                losses: 0,
                conferenceWins: 0,
                conferenceLosses: 0,
                pointsFor: 0,
                pointsAgainst: 0,
                targetGames: totalRegularSeasonGames,
                targetConferenceGames: confGames,
                targetNonConferenceGames: nonConfGames
            )
        )
    }

    let requiredUserNonConferenceGames = max(0, totalRegularSeasonGames - max(0, min(userConference.inferredConferenceGames ?? 18, totalRegularSeasonGames)))

    var state = LeagueStore.State(
        optionsSeed: options.seed,
        status: "in_progress",
        currentDay: 0,
        totalRegularSeasonGames: totalRegularSeasonGames,
        userTeamId: userTeamRef.id,
        userSelectedOpponentIds: [],
        requiredUserNonConferenceGames: requiredUserNonConferenceGames,
        conferences: dataset.conferences,
        teams: teams,
        schedule: [],
        userGameHistory: [],
        scheduleGenerated: false,
        conferenceTournaments: nil,
        nationalTournament: nil,
        remainingRegularSeasonGames: nil,
        playersLeaving: nil
    )

    autoFillUserNonConferenceOpponentsInState(&state, seed: "create:\(options.seed)")
    generateSeasonScheduleInState(&state)

    let handle = LeagueStore.put(state)
    return LeagueState(handle: handle)
}

public func listCareerTeamOptions() -> [CareerTeamOption] {
    guard let dataset = try? LoadedD1Data.get() else {
        return []
    }
    return dataset.conferences
        .flatMap { conference in
            conference.teams.map {
                CareerTeamOption(teamId: $0.id, teamName: $0.name, conferenceId: conference.id, conferenceName: conference.name)
            }
        }
        .sorted { lhs, rhs in
            if lhs.conferenceName != rhs.conferenceName { return lhs.conferenceName < rhs.conferenceName }
            return lhs.teamName < rhs.teamName
        }
}

public func listUserNonConferenceOptions(_ league: LeagueState) -> [NonConferenceOption] {
    guard let state = LeagueStore.get(league.handle), let user = state.teams.first(where: { $0.teamId == state.userTeamId }) else {
        return []
    }

    return state.teams
        .filter { $0.teamId != user.teamId && $0.conferenceId != user.conferenceId }
        .sorted { $0.teamName < $1.teamName }
        .map { team in
            NonConferenceOption(
                teamId: team.teamId,
                teamName: team.teamName,
                conferenceId: team.conferenceId,
                conferenceName: team.conferenceName,
                overall: teamOverall(team.teamModel),
                selected: state.userSelectedOpponentIds.contains(team.teamId)
            )
        }
}

public func getPreseasonSchedulingBoard(_ league: LeagueState, page: Int = 1, pageSize: Int = 20, query: String? = nil) -> PreseasonBoard {
    let trimmedQuery = (query ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    let all = listUserNonConferenceOptions(league)
        .filter { option in
            guard !trimmedQuery.isEmpty else { return true }
            return option.teamName.localizedCaseInsensitiveContains(trimmedQuery) || option.conferenceName.localizedCaseInsensitiveContains(trimmedQuery)
        }

    let pageSizeSafe = max(1, pageSize)
    let totalPages = max(1, Int(ceil(Double(all.count) / Double(pageSizeSafe))))
    let pageSafe = clamp(page, min: 1, max: totalPages)
    let start = (pageSafe - 1) * pageSizeSafe
    let end = min(all.count, start + pageSizeSafe)
    let slice = start < end ? Array(all[start..<end]) : []

    let options = slice.enumerated().map { idx, item in
        PreseasonBoardOption(
            teamId: item.teamId,
            teamName: item.teamName,
            conferenceId: item.conferenceId,
            conferenceName: item.conferenceName,
            overall: item.overall,
            selected: item.selected,
            displayIndex: idx,
            absoluteIndex: start + idx
        )
    }

    let selectedOpponents = all
        .filter { $0.selected == true }
        .map {
            PreseasonSelectedOpponent(teamId: $0.teamId, teamName: $0.teamName, conferenceId: $0.conferenceId, conferenceName: $0.conferenceName, overall: $0.overall)
        }

    let selectedCount = selectedOpponents.count
    let requiredCount = LeagueStore.get(league.handle)?.requiredUserNonConferenceGames ?? 0

    return PreseasonBoard(
        page: pageSafe,
        pageSize: pageSizeSafe,
        totalPages: totalPages,
        search: trimmedQuery,
        totalOptions: all.count,
        requiredCount: requiredCount,
        selectedCount: selectedCount,
        remainingCount: max(0, requiredCount - selectedCount),
        selectedOpponents: selectedOpponents,
        options: options
    )
}

public func setUserNonConferenceOpponents(_ league: inout LeagueState, opponentTeamIds: [String]) {
    _ = LeagueStore.update(league.handle) { state in
        guard let user = state.teams.first(where: { $0.teamId == state.userTeamId }) else { return }
        let valid = Set(
            state.teams
                .filter { $0.teamId != user.teamId && $0.conferenceId != user.conferenceId }
                .map(\.teamId)
        )
        let deduped = Array(NSOrderedSet(array: opponentTeamIds.filter { valid.contains($0) })) as? [String] ?? []
        state.userSelectedOpponentIds = Array(deduped.prefix(state.requiredUserNonConferenceGames))
        state.scheduleGenerated = false
        state.schedule.removeAll()
        state.userGameHistory.removeAll()
        state.conferenceTournaments = nil
        state.nationalTournament = nil
        resetTeamRecords(&state)
    }
}

public func autoFillUserNonConferenceOpponents(_ league: inout LeagueState, seed: String = "autofill") {
    _ = LeagueStore.update(league.handle) { state in
        autoFillUserNonConferenceOpponentsInState(&state, seed: seed)
        state.scheduleGenerated = false
        state.schedule.removeAll()
        state.userGameHistory.removeAll()
        state.conferenceTournaments = nil
        state.nationalTournament = nil
        resetTeamRecords(&state)
    }
}

public func generateSeasonSchedule(_ league: inout LeagueState) {
    _ = LeagueStore.update(league.handle) { state in
        generateSeasonScheduleInState(&state)
    }
}

public func getUserSchedule(_ league: LeagueState) -> [UserGameSummary] {
    guard let state = LeagueStore.get(league.handle), let user = state.teams.first(where: { $0.teamId == state.userTeamId }) else {
        return []
    }

    return state.schedule
        .filter { $0.homeTeamId == user.teamId || $0.awayTeamId == user.teamId }
        .sorted {
            if $0.day != $1.day { return $0.day < $1.day }
            return $0.gameId < $1.gameId
        }
        .map { userSummaryFromGame($0, userTeamId: user.teamId) }
}

public func getUserRoster(_ league: LeagueState) -> [UserRosterPlayerSummary] {
    guard let state = LeagueStore.get(league.handle), let user = state.teams.first(where: { $0.teamId == state.userTeamId }) else {
        return []
    }

    let lineupNames = Set(user.teamModel.lineup.map(\.bio.name))
    return rosterSummaryPlayers(from: user.teamModel, lineupNames: lineupNames)
}

public func getTeamRosters(_ league: LeagueState) -> [TeamRosterSummary] {
    guard let state = LeagueStore.get(league.handle) else {
        return []
    }

    return state.teams.map { team in
        let lineupNames = Set(team.teamModel.lineup.map(\.bio.name))
        return TeamRosterSummary(
            teamId: team.teamId,
            teamName: team.teamModel.name,
            players: rosterSummaryPlayers(from: team.teamModel, lineupNames: lineupNames)
        )
    }
}

func rosterSummaryPlayers(from team: Team, lineupNames: Set<String>) -> [UserRosterPlayerSummary] {
    team.players.enumerated().map { idx, player in
        UserRosterPlayerSummary(
            playerIndex: idx,
            name: player.bio.name,
            position: player.bio.position.rawValue,
            year: player.bio.year.rawValue,
            home: player.bio.home,
            height: player.size.height,
            weight: player.size.weight,
            wingspan: player.size.wingspan,
            overall: playerOverall(player),
            isStarter: lineupNames.contains(player.bio.name),
            attributes: [
                "potential": player.bio.potential,

                "speed": player.athleticism.speed,
                "agility": player.athleticism.agility,
                "burst": player.athleticism.burst,
                "strength": player.athleticism.strength,
                "vertical": player.athleticism.vertical,
                "stamina": player.athleticism.stamina,
                "durability": player.athleticism.durability,

                "layups": player.shooting.layups,
                "dunks": player.shooting.dunks,
                "closeShot": player.shooting.closeShot,
                "midrangeShot": player.shooting.midrangeShot,
                "threePointShooting": player.shooting.threePointShooting,
                "cornerThrees": player.shooting.cornerThrees,
                "upTopThrees": player.shooting.upTopThrees,
                "drawFoul": player.shooting.drawFoul,
                "freeThrows": player.shooting.freeThrows,

                "postControl": player.postGame.postControl,
                "postFadeaways": player.postGame.postFadeaways,
                "postHooks": player.postGame.postHooks,

                "ballHandling": player.skills.ballHandling,
                "ballSafety": player.skills.ballSafety,
                "passingAccuracy": player.skills.passingAccuracy,
                "passingVision": player.skills.passingVision,
                "passingIQ": player.skills.passingIQ,
                "shotIQ": player.skills.shotIQ,
                "offballOffense": player.skills.offballOffense,
                "hands": player.skills.hands,
                "hustle": player.skills.hustle,
                "clutch": player.skills.clutch,

                "perimeterDefense": player.defense.perimeterDefense,
                "postDefense": player.defense.postDefense,
                "shotBlocking": player.defense.shotBlocking,
                "shotContest": player.defense.shotContest,
                "steals": player.defense.steals,
                "lateralQuickness": player.defense.lateralQuickness,
                "offballDefense": player.defense.offballDefense,
                "passPerception": player.defense.passPerception,
                "defensiveControl": player.defense.defensiveControl,

                "offensiveRebounding": player.rebounding.offensiveRebounding,
                "defensiveRebound": player.rebounding.defensiveRebound,
                "boxouts": player.rebounding.boxouts,

                "tendencyPost": player.tendencies.post,
                "tendencyInside": player.tendencies.inside,
                "tendencyMidrange": player.tendencies.midrange,
                "tendencyThreePoint": player.tendencies.threePoint,
                "tendencyDrive": player.tendencies.drive,
                "tendencyPickAndRoll": player.tendencies.pickAndRoll,
                "tendencyPickAndPop": player.tendencies.pickAndPop,
                "tendencyShootVsPass": player.tendencies.shootVsPass,
            ]
        )
    }
}

public func getUserRotation(_ league: LeagueState) -> [UserRotationSlot] {
    guard let state = LeagueStore.get(league.handle), let user = state.teams.first(where: { $0.teamId == state.userTeamId }) else {
        return []
    }

    let defaultSlots = defaultRotationSlots(for: user.teamModel)
    guard let targets = user.teamModel.rotation?.minuteTargets, !targets.isEmpty else {
        return defaultSlots
    }

    return defaultSlots.map { slot in
        guard let playerIndex = slot.playerIndex, playerIndex < user.teamModel.players.count else { return slot }
        let player = user.teamModel.players[playerIndex]
        let mapped = targets[player.bio.name] ?? slot.minutes
        return UserRotationSlot(slot: slot.slot, playerIndex: slot.playerIndex, position: slot.position, minutes: mapped)
    }
}

public func setUserRotation(_ league: inout LeagueState, slots: [UserRotationSlot]) -> [UserRotationSlot] {
    LeagueStore.update(league.handle) { state in
        guard let userIndex = state.teams.firstIndex(where: { $0.teamId == state.userTeamId }) else {
            return []
        }

        let team = state.teams[userIndex].teamModel
        var targets: [String: Double] = [:]
        for slot in slots {
            guard let playerIndex = slot.playerIndex, playerIndex >= 0, playerIndex < team.players.count else { continue }
            let playerName = team.players[playerIndex].bio.name
            targets[playerName] = clamp(slot.minutes, min: 0, max: 40)
        }

        var updatedTeam = team
        updatedTeam.rotation = TeamRotation(minuteTargets: targets)

        let lineupIndexes = slots
            .sorted { $0.minutes > $1.minutes }
            .compactMap(\.playerIndex)
            .filter { $0 >= 0 && $0 < updatedTeam.players.count }

        if lineupIndexes.count >= 5 {
            updatedTeam.lineup = Array(lineupIndexes.prefix(5)).map { updatedTeam.players[$0] }
        }

        state.teams[userIndex].teamModel = updatedTeam

        let defaultSlots = defaultRotationSlots(for: updatedTeam)
        guard let minuteTargets = updatedTeam.rotation?.minuteTargets, !minuteTargets.isEmpty else {
            return defaultSlots
        }
        return defaultSlots.map { slot in
            guard let playerIndex = slot.playerIndex, playerIndex < updatedTeam.players.count else { return slot }
            let player = updatedTeam.players[playerIndex]
            let mapped = minuteTargets[player.bio.name] ?? slot.minutes
            return UserRotationSlot(slot: slot.slot, playerIndex: slot.playerIndex, position: slot.position, minutes: mapped)
        }
    } ?? []
}

public func getUserCoachingStaff(_ league: LeagueState) -> UserCoachingStaffSummary {
    guard let state = LeagueStore.get(league.handle), let user = state.teams.first(where: { $0.teamId == state.userTeamId }) else {
        fatalError("User team is missing coaching staff.")
    }

    return UserCoachingStaffSummary(
        headCoach: user.teamModel.coachingStaff.headCoach,
        assistants: user.teamModel.coachingStaff.assistants,
        gamePrepAssistantIndex: user.teamModel.coachingStaff.gamePrepAssistantIndex
    )
}

public func setUserAssistantFocus(_ league: inout LeagueState, assistantIndex: Int, focus: AssistantFocus) {
    _ = LeagueStore.update(league.handle) { state in
        guard let userIndex = state.teams.firstIndex(where: { $0.teamId == state.userTeamId }) else { return }
        guard assistantIndex >= 0, assistantIndex < state.teams[userIndex].teamModel.coachingStaff.assistants.count else { return }

        state.teams[userIndex].teamModel.coachingStaff.assistants[assistantIndex].focus = focus
        if focus == .gamePrep {
            state.teams[userIndex].teamModel.coachingStaff.gamePrepAssistantIndex = assistantIndex
        } else if state.teams[userIndex].teamModel.coachingStaff.gamePrepAssistantIndex == assistantIndex {
            state.teams[userIndex].teamModel.coachingStaff.gamePrepAssistantIndex = nil
        }
    }
}
