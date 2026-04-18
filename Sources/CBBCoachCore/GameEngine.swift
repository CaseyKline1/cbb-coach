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
    public var half: Int
    public var clockRemaining: Int
    public var type: String
    public var teamIndex: Int
    public var points: Int
    public var description: String

    public init(half: Int, clockRemaining: Int, type: String, teamIndex: Int, points: Int = 0, description: String = "") {
        self.half = half
        self.clockRemaining = clockRemaining
        self.type = type
        self.teamIndex = teamIndex
        self.points = points
        self.description = description
    }
}

public struct PlayerBoxScore: Codable, Equatable, Sendable {
    public var playerName: String
    public var position: PlayerPosition
    public var minutes: Double = 0
    public var points: Int = 0
    public var fgMade: Int = 0
    public var fgAttempts: Int = 0
    public var threeMade: Int = 0
    public var threeAttempts: Int = 0
    public var ftMade: Int = 0
    public var ftAttempts: Int = 0
    public var rebounds: Int = 0
    public var offensiveRebounds: Int = 0
    public var defensiveRebounds: Int = 0
    public var assists: Int = 0
    public var steals: Int = 0
    public var blocks: Int = 0
    public var turnovers: Int = 0
    public var fouls: Int = 0
    public var energy: Double = 100
}

public struct TeamBoxScore: Codable, Equatable, Sendable {
    public var name: String
    public var players: [PlayerBoxScore]
    public var teamExtras: [String: Int]
}

public struct SimulatedTeamResult: Codable, Equatable, Sendable {
    public var name: String
    public var score: Int
    public var boxScore: TeamBoxScore
}

public struct SimulatedGameResult: Codable, Equatable, Sendable {
    public var home: SimulatedTeamResult
    public var away: SimulatedTeamResult
    public var winner: String?
    public var playByPlay: [PlayByPlayEvent]
    public var boxScore: [TeamBoxScore]
}

public struct GameState: Codable, Equatable, Sendable {
    public var teams: [Team]
    public var currentHalf: Int = 1
    public var gameClockRemaining: Int = HALF_SECONDS
    public var shotClockRemaining: Int = SHOT_CLOCK_SECONDS
    public var possessionTeamIndex: Int = 0
    public var playByPlay: [PlayByPlayEvent] = []
    public var boxScore: [TeamBoxScore]

    public init(teams: [Team], possessionTeamIndex: Int = 0) {
        self.teams = teams
        self.possessionTeamIndex = possessionTeamIndex
        self.boxScore = teams.map { team in
            TeamBoxScore(
                name: team.name,
                players: team.players.map {
                    PlayerBoxScore(playerName: $0.bio.name.isEmpty ? "Unknown" : $0.bio.name, position: $0.bio.position)
                },
                teamExtras: ["turnovers": 0, "steals": 0, "blocks": 0, "fouls": 0]
            )
        }
    }
}

public func createInitialGameState(homeTeam: Team, awayTeam: Team, random: inout SeededRandom) -> GameState {
    GameState(teams: [homeTeam, awayTeam], possessionTeamIndex: random.int(0, 1))
}

private func playerRating(_ player: Player, keyPath: String) -> Double {
    switch keyPath {
    case "shooting.threePointShooting": return Double(player.shooting.threePointShooting)
    case "shooting.midrangeShot": return Double(player.shooting.midrangeShot)
    case "shooting.closeShot": return Double(player.shooting.closeShot)
    case "shooting.layups": return Double(player.shooting.layups)
    case "shooting.dunks": return Double(player.shooting.dunks)
    case "skills.ballHandling": return Double(player.skills.ballHandling)
    case "skills.ballSafety": return Double(player.skills.ballSafety)
    case "skills.passingIQ": return Double(player.skills.passingIQ)
    case "skills.passingVision": return Double(player.skills.passingVision)
    case "skills.shotIQ": return Double(player.skills.shotIQ)
    case "defense.perimeterDefense": return Double(player.defense.perimeterDefense)
    case "defense.shotContest": return Double(player.defense.shotContest)
    case "defense.steals": return Double(player.defense.steals)
    case "defense.postDefense": return Double(player.defense.postDefense)
    case "rebounding.offensiveRebounding": return Double(player.rebounding.offensiveRebounding)
    case "rebounding.defensiveRebound": return Double(player.rebounding.defensiveRebound)
    default: return 50
    }
}

public func resolveInteraction(
    offensePlayer: Player,
    defensePlayer: Player,
    offenseRatings: [String],
    defenseRatings: [String],
    random: inout SeededRandom
) -> InteractionResult {
    let offenseScore = offenseRatings.map { playerRating(offensePlayer, keyPath: $0) }.reduce(0, +) / Double(max(1, offenseRatings.count))
    let defenseScore = defenseRatings.map { playerRating(defensePlayer, keyPath: $0) }.reduce(0, +) / Double(max(1, defenseRatings.count))
    let noise = (random.nextUnit() - 0.5) * 22
    let edge = offenseScore - defenseScore + noise
    return InteractionResult(offenseScore: offenseScore, defenseScore: defenseScore, edge: edge, offenseWon: edge >= 0)
}

private func lineupIndex(_ state: GameState, teamIndex: Int, random: inout SeededRandom) -> Int {
    let count = state.teams[teamIndex].lineup.count
    guard count > 0 else { return 0 }
    return random.int(0, count - 1)
}

private func applyEnergy(_ player: inout Player, drain: Double) {
    player.condition.energy = clamp(player.condition.energy - drain, min: 0, max: 100)
}

private func addMinutes(_ box: inout PlayerBoxScore, seconds: Int) {
    box.minutes += Double(seconds) / 60
}

private func paceShotBias(_ pace: PaceProfile) -> Double {
    switch pace {
    case .verySlow: return -0.10
    case .slow: return -0.07
    case .slightlySlow: return -0.035
    case .normal: return 0
    case .slightlyFast: return 0.03
    case .fast: return 0.06
    case .veryFast: return 0.09
    }
}

@discardableResult
public func resolveActionChunk(state: inout GameState, random: inout SeededRandom) -> String {
    let offenseTeam = state.possessionTeamIndex
    let defenseTeam = (offenseTeam + 1) % 2

    let offenseLineupIdx = lineupIndex(state, teamIndex: offenseTeam, random: &random)
    let defenseLineupIdx = lineupIndex(state, teamIndex: defenseTeam, random: &random)

    guard offenseLineupIdx < state.teams[offenseTeam].lineup.count,
          defenseLineupIdx < state.teams[defenseTeam].lineup.count else {
        state.gameClockRemaining = max(0, state.gameClockRemaining - CHUNK_SECONDS)
        state.shotClockRemaining = max(0, state.shotClockRemaining - CHUNK_SECONDS)
        return "empty_chunk"
    }

    var offensePlayer = state.teams[offenseTeam].lineup[offenseLineupIdx]
    var defensePlayer = state.teams[defenseTeam].lineup[defenseLineupIdx]

    let shotMixRoll = random.nextUnit()
    let baseThreeChance = 0.35 + paceShotBias(state.teams[offenseTeam].pace)
    let baseRimChance = 0.31 - paceShotBias(state.teams[offenseTeam].pace) / 2

    let shotType: String
    let offenseRatings: [String]
    let defenseRatings: [String]
    let makeBonus: Double
    if shotMixRoll < baseThreeChance {
        shotType = "three"
        offenseRatings = ["shooting.threePointShooting", "skills.shotIQ"]
        defenseRatings = ["defense.perimeterDefense", "defense.shotContest"]
        makeBonus = -0.42
    } else if shotMixRoll < baseThreeChance + baseRimChance {
        shotType = "rim"
        offenseRatings = ["shooting.layups", "athleticism.burst", "skills.ballHandling"]
        defenseRatings = ["defense.shotContest", "defense.postDefense"]
        makeBonus = 0.22
    } else {
        shotType = "mid"
        offenseRatings = ["shooting.midrangeShot", "skills.shotIQ"]
        defenseRatings = ["defense.shotContest", "defense.perimeterDefense"]
        makeBonus = -0.4
    }

    let duel = resolveInteraction(
        offensePlayer: offensePlayer,
        defensePlayer: defensePlayer,
        offenseRatings: offenseRatings,
        defenseRatings: defenseRatings,
        random: &random
    )

    var makeProbability = 0.5 + duel.edge / 140 + makeBonus
    makeProbability = clamp(makeProbability, min: 0.08, max: 0.92)

    let made = random.nextUnit() < makeProbability
    let points = shotType == "three" ? 3 : 2

    var teamBox = state.boxScore[offenseTeam]
    var playerBox = teamBox.players[min(offenseLineupIdx, max(0, teamBox.players.count - 1))]
    playerBox.fgAttempts += 1
    if shotType == "three" { playerBox.threeAttempts += 1 }

    if made {
        state.teams[offenseTeam].score += points
        playerBox.points += points
        playerBox.fgMade += 1
        if shotType == "three" { playerBox.threeMade += 1 }

        state.playByPlay.append(
            PlayByPlayEvent(
                half: state.currentHalf,
                clockRemaining: state.gameClockRemaining,
                type: "made_shot",
                teamIndex: offenseTeam,
                points: points,
                description: "\(state.teams[offenseTeam].name) made a \(points)-point shot"
            )
        )
        state.possessionTeamIndex = defenseTeam
        state.shotClockRemaining = SHOT_CLOCK_SECONDS
    } else {
        state.playByPlay.append(
            PlayByPlayEvent(
                half: state.currentHalf,
                clockRemaining: state.gameClockRemaining,
                type: "missed_shot",
                teamIndex: offenseTeam,
                points: 0,
                description: "\(state.teams[offenseTeam].name) missed"
            )
        )

        let reboundRoll = random.nextUnit()
        if reboundRoll < 0.27 {
            playerBox.offensiveRebounds += 1
            playerBox.rebounds += 1
            state.shotClockRemaining = SHOT_CLOCK_SECONDS
            state.playByPlay.append(
                PlayByPlayEvent(
                    half: state.currentHalf,
                    clockRemaining: state.gameClockRemaining,
                    type: "offensive_rebound",
                    teamIndex: offenseTeam,
                    description: "Offensive rebound"
                )
            )
        } else {
            state.possessionTeamIndex = defenseTeam
            state.shotClockRemaining = SHOT_CLOCK_SECONDS
            state.playByPlay.append(
                PlayByPlayEvent(
                    half: state.currentHalf,
                    clockRemaining: state.gameClockRemaining,
                    type: "defensive_rebound",
                    teamIndex: defenseTeam,
                    description: "Defensive rebound"
                )
            )
        }
    }

    addMinutes(&playerBox, seconds: CHUNK_SECONDS)
    teamBox.players[min(offenseLineupIdx, max(0, teamBox.players.count - 1))] = playerBox
    state.boxScore[offenseTeam] = teamBox

    applyEnergy(&offensePlayer, drain: 1.2)
    applyEnergy(&defensePlayer, drain: 1.2)
    state.teams[offenseTeam].lineup[offenseLineupIdx] = offensePlayer
    state.teams[defenseTeam].lineup[defenseLineupIdx] = defensePlayer

    state.gameClockRemaining = max(0, state.gameClockRemaining - CHUNK_SECONDS)
    state.shotClockRemaining = max(0, state.shotClockRemaining - CHUNK_SECONDS)

    if state.shotClockRemaining == 0 {
        state.playByPlay.append(
            PlayByPlayEvent(
                half: state.currentHalf,
                clockRemaining: state.gameClockRemaining,
                type: "shot_clock_turnover",
                teamIndex: state.possessionTeamIndex,
                description: "Shot clock violation"
            )
        )
        state.possessionTeamIndex = (state.possessionTeamIndex + 1) % 2
        state.shotClockRemaining = SHOT_CLOCK_SECONDS
    }

    return made ? "made_shot" : "missed_shot"
}

public func simulateHalf(state: inout GameState, random: inout SeededRandom) {
    while state.gameClockRemaining > 0 {
        resolveActionChunk(state: &state, random: &random)
    }
}

public func simulateGame(homeTeam: Team, awayTeam: Team, random: inout SeededRandom) -> SimulatedGameResult {
    var state = createInitialGameState(homeTeam: homeTeam, awayTeam: awayTeam, random: &random)

    for half in 1...2 {
        state.currentHalf = half
        state.gameClockRemaining = HALF_SECONDS
        state.shotClockRemaining = SHOT_CLOCK_SECONDS
        simulateHalf(state: &state, random: &random)
    }

    var overtime = 0
    while state.teams[0].score == state.teams[1].score {
        overtime += 1
        state.currentHalf = 2 + overtime
        state.gameClockRemaining = OVERTIME_SECONDS
        state.shotClockRemaining = SHOT_CLOCK_SECONDS
        simulateHalf(state: &state, random: &random)
    }

    for i in state.boxScore.indices {
        for j in state.boxScore[i].players.indices {
            let p = state.teams[i].players[min(j, max(0, state.teams[i].players.count - 1))]
            state.boxScore[i].players[j].energy = p.condition.energy
        }
    }

    let home = SimulatedTeamResult(name: state.teams[0].name, score: state.teams[0].score, boxScore: state.boxScore[0])
    let away = SimulatedTeamResult(name: state.teams[1].name, score: state.teams[1].score, boxScore: state.boxScore[1])

    let winner: String?
    if home.score == away.score {
        winner = nil
    } else {
        winner = home.score > away.score ? home.name : away.name
    }

    return SimulatedGameResult(home: home, away: away, winner: winner, playByPlay: state.playByPlay, boxScore: state.boxScore)
}
