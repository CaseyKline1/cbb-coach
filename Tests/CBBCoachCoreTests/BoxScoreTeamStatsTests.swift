import Testing
@testable import CBBCoachCore

@Test("Completed team extras include standard box score totals")
func completedTeamExtrasIncludeStandardBoxScoreTotals() {
    let players = [
        PlayerBoxScore(
            playerName: "Point Guard",
            position: "PG",
            minutes: 32,
            points: 18,
            fgMade: 7,
            fgAttempts: 12,
            threeMade: 2,
            threeAttempts: 5,
            ftMade: 2,
            ftAttempts: 2,
            rebounds: 4,
            offensiveRebounds: 1,
            defensiveRebounds: 3,
            assists: 8,
            steals: 2,
            blocks: 0,
            turnovers: 3,
            fouls: 2,
            plusMinus: 5,
            energy: 81
        ),
        PlayerBoxScore(
            playerName: "Center",
            position: "C",
            minutes: 28,
            points: 14,
            fgMade: 6,
            fgAttempts: 9,
            threeMade: 0,
            threeAttempts: 0,
            ftMade: 2,
            ftAttempts: 4,
            rebounds: 10,
            offensiveRebounds: 4,
            defensiveRebounds: 6,
            assists: 1,
            steals: 0,
            blocks: 3,
            turnovers: 2,
            fouls: 4,
            plusMinus: 2,
            energy: 76
        ),
    ]

    let extras = completedTeamExtras(
        score: 77,
        players: players,
        teamExtras: [
            "turnovers": 8,
            "fastBreakPoints": 12,
            "pointsInPaint": 34,
        ]
    )

    #expect(extras["points"] == 77)
    #expect(extras["minutes"] == 60)
    #expect(extras["fgMade"] == 13)
    #expect(extras["fgAttempts"] == 21)
    #expect(extras["threeMade"] == 2)
    #expect(extras["threeAttempts"] == 5)
    #expect(extras["ftMade"] == 4)
    #expect(extras["ftAttempts"] == 6)
    #expect(extras["rebounds"] == 14)
    #expect(extras["offensiveRebounds"] == 5)
    #expect(extras["defensiveRebounds"] == 9)
    #expect(extras["assists"] == 9)
    #expect(extras["steals"] == 2)
    #expect(extras["blocks"] == 3)
    #expect(extras["turnovers"] == 8)
    #expect(extras["fouls"] == 6)
    #expect(extras["plusMinus"] == 7)
    #expect(extras["fastBreakPoints"] == 12)
    #expect(extras["pointsInPaint"] == 34)
}
