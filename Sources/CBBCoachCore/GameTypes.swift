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

    public var score: Int = 0

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

public struct CreateTeamOptions: Sendable {
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
    let normalizedStaff: CoachingStaff
    if let coachingStaff = options.coachingStaff {
        normalizedStaff = coachingStaff
    } else {
        var staffOptions = CreateCoachingStaffOptions()
        if let coaches = options.coaches, let first = coaches.first {
            var head = CreateCoachOptions()
            head.role = .headCoach
            head.age = first.age
            head.pressAggressiveness = first.pressAggressiveness
            head.pace = first.pace
            head.defaultOffensiveSet = first.defaultOffensiveSet
            head.defaultDefensiveSet = first.defaultDefensiveSet
            head.almaMater = first.almaMater
            head.pipelineState = first.pipelineState
            head.skills = first.skills
            staffOptions.headCoach = head

            let assistants = coaches.dropFirst().map { coach in
                var opt = CreateCoachOptions()
                opt.age = coach.age
                opt.pressAggressiveness = coach.pressAggressiveness
                opt.pace = coach.pace
                opt.defaultOffensiveSet = coach.defaultOffensiveSet
                opt.defaultDefensiveSet = coach.defaultDefensiveSet
                opt.almaMater = coach.almaMater
                opt.pipelineState = coach.pipelineState
                opt.skills = coach.skills
                return opt
            }
            staffOptions.assistants = assistants
        }
        staffOptions.schoolPool = options.schoolPool ?? (options.name.isEmpty ? [] : [options.name])
        staffOptions.teamName = options.name
        staffOptions.defaultPace = options.pace
        staffOptions.defaultOffensiveSet = options.formation
        staffOptions.defaultDefensiveSet = options.defenseScheme
        if let weights = options.pipelineStateWeights {
            staffOptions.pipelineStateWeights = weights
        }
        normalizedStaff = createCoachingStaff(options: staffOptions, random: &random)
    }

    return Team(
        name: options.name,
        players: options.players,
        lineup: options.lineup,
        formation: options.formation,
        formations: options.formations,
        defenseScheme: options.defenseScheme,
        tendencies: options.tendencies,
        timeouts: options.timeouts,
        rotation: options.rotation,
        pace: options.pace,
        coachingStaff: normalizedStaff
    )
}
