import Foundation
import Testing
@testable import CBBCoachCore

@Test("Contested transfer recruits name finalists before committing")
func contestedTransferRecruitsNameFinalistsBeforeCommitting() throws {
    var league = try createD1League(options: CreateLeagueOptions(userTeamName: "UConn", seed: "portal-finalists", totalRegularSeasonGames: 1))
    var random = SeededRandom(seed: 8181)

    _ = LeagueStore.update(league.handle) { state in
        state.status = "completed"
        state.offseasonStage = .transferPortal
        state.playersLeaving = nil
        state.nilRetention = []
        state.nilRetentionFinalized = true
        state.transferPortalWeek = 2

        let previousTeam = state.teams.first { $0.teamId != state.userTeamId } ?? state.teams[0]
        let destinationIds = Array(state.teams.filter { $0.teamId != previousTeam.teamId }.prefix(6).map(\.teamId))
        state.transferPortal = (0..<12).map { index in
            var player = createPlayer()
            player.bio.name = "Finalist Guard \(index + 1)"
            player.bio.position = .pg
            player.bio.year = .so
            player.bio.potential = 76
            applyRatings(&player, base: 72, random: &random)

            let interest = Dictionary(uniqueKeysWithValues: destinationIds.enumerated().map { offset, teamId in
                (teamId, 80.0 - Double(offset) * 0.35)
            })

            return TransferPortalEntry(
                id: "synthetic:finalist-guard-\(index)",
                previousTeamId: previousTeam.teamId,
                previousTeamName: previousTeam.teamName,
                finalistTeamIds: [],
                finalistTeamNames: [],
                interestByTeamId: interest,
                playerModel: player,
                playerName: player.bio.name,
                position: player.bio.position.rawValue,
                year: player.bio.year.rawValue,
                overall: playerOverall(player),
                potential: player.bio.potential,
                askingPrice: 10_000,
                intrinsicValue: 10_000,
                reason: "Testing finalist phase.",
                loyalty: 45,
                greed: 50
            )
        }
        let entryIds = state.transferPortal?.map(\.id) ?? []
        state.transferPortalUserTargets = entryIds
        state.transferPortalUserOffers = Dictionary(uniqueKeysWithValues: entryIds.map { ($0, 10_000.0) })
    }

    _ = advanceOffseason(&league)

    let portal = getTransferPortalSummary(league)
    let finalistRows = portal.entries.filter { $0.playerName.hasPrefix("Finalist Guard") }
    #expect(finalistRows.count == 12)
    #expect(finalistRows.allSatisfy { $0.committedTeamId == nil })
    #expect(finalistRows.allSatisfy { $0.finalistTeamIds.count >= 2 })
}
