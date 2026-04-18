import Foundation

public let CHUNK_SECONDS = 5
public let HALF_SECONDS = 20 * 60
public let OVERTIME_SECONDS = 5 * 60
public let SHOT_CLOCK_SECONDS = 30

public enum OffensiveSpot: String, Codable, CaseIterable, Sendable {
    case middlePaint = "middle_paint"
    case rightPost = "right_post"
    case leftPost = "left_post"
    case rightSlot = "right_slot"
    case leftSlot = "left_slot"
    case rightElbow = "right_elbow"
    case leftElbow = "left_elbow"
    case ftLine = "ft_line"
    case topMiddle = "top_middle"
    case topRight = "top_right"
    case topLeft = "top_left"
    case rightCorner = "right_corner"
    case leftCorner = "left_corner"
}

public enum OffensiveFormation: String, Codable, CaseIterable, Sendable {
    case fiveOut = "5_out"
    case fourOutOnePost = "4_out_1_post"
    case highLow = "high_low"
    case triangle = "triangle"
    case motion = "motion"
}

public enum DefenseScheme: String, Codable, CaseIterable, Sendable {
    case manToMan = "man_to_man"
    case zone23 = "2_3"
    case zone32 = "3_2"
    case zone131 = "1_3_1"
    case packLine = "pack_line"
}

public enum PaceProfile: String, Codable, CaseIterable, Sendable {
    case verySlow = "very_slow"
    case slow = "slow"
    case slightlySlow = "slightly_slow"
    case normal = "normal"
    case slightlyFast = "slightly_fast"
    case fast = "fast"
    case veryFast = "very_fast"
}

public struct TeamTendencies: Codable, Equatable, Sendable {
    public var fastBreakOffense: Double = 50
    public var crashBoardsOffense: Double = 50
    public var defendFastBreakOffense: Double = 50
    public var crashBoardsDefense: Double = 50
    public var attemptFastBreakDefense: Double = 50
    public var press: Double = 50
    public var trapRate: Double = 50
    public var pressBreakPass: Double = 50
    public var pressBreakAttack: Double = 50

    public init() {}
}

public struct TeamRotation: Codable, Equatable, Sendable {
    public var minuteTargets: [String: Double]

    public init(minuteTargets: [String: Double] = [:]) {
        self.minuteTargets = minuteTargets
    }
}

public struct Team: Codable, Equatable, Sendable {
    public var name: String
    public var players: [Player]
    public var lineup: [Player]
    public var formation: OffensiveFormation
    public var formations: [OffensiveFormation]?
    public var defenseScheme: DefenseScheme
    public var tendencies: TeamTendencies
    public var timeouts: Int
    public var rotation: TeamRotation?
    public var pace: PaceProfile
    public var coachingStaff: CoachingStaff

    public var coaches: [Coach] {
        coachingStaff.coaches
    }

    public var score: Int?

    public init(
        name: String,
        players: [Player],
        lineup: [Player]? = nil,
        formation: OffensiveFormation = .motion,
        formations: [OffensiveFormation]? = nil,
        defenseScheme: DefenseScheme = .manToMan,
        tendencies: TeamTendencies = TeamTendencies(),
        timeouts: Int = 4,
        rotation: TeamRotation? = nil,
        pace: PaceProfile = .normal,
        coachingStaff: CoachingStaff
    ) {
        self.name = name
        self.players = players
        self.lineup = lineup ?? players
        self.formation = formation
        self.formations = formations
        self.defenseScheme = defenseScheme
        self.tendencies = tendencies
        self.timeouts = timeouts
        self.rotation = rotation
        self.pace = pace
        self.coachingStaff = coachingStaff
    }
}

public struct CreateTeamOptions: Codable, Equatable, Sendable {
    public var name: String
    public var players: [Player]
    public var lineup: [Player]?
    public var formation: OffensiveFormation = .motion
    public var formations: [OffensiveFormation]?
    public var defenseScheme: DefenseScheme = .manToMan
    public var tendencies: TeamTendencies = TeamTendencies()
    public var timeouts: Int = 4
    public var rotation: TeamRotation?
    public var pace: PaceProfile = .normal
    public var coachingStaff: CoachingStaff?
    public var coaches: [Coach]?
    public var schoolPool: [String]?
    public var pipelineStateWeights: [String: Int]?

    public init(name: String, players: [Player]) {
        self.name = name
        self.players = players
    }
}

public func createTeam(options: CreateTeamOptions, random: inout SeededRandom) -> Team {
    do {
        let args = [try toJSONValue(options)]
        let response = try JSRuntime.shared.invokeWithRandom(moduleId: "./gameEngine", fn: "createTeam", args: args, random: &random)
        return try fromJSONValue(response.result, as: Team.self)
    } catch {
        fatalError("createTeam failed: \(error)")
    }
}
