import Foundation

public enum CoachRole: String, Codable, Sendable {
    case headCoach = "head_coach"
    case assistant = "assistant"
}

public enum AssistantFocus: String, Codable, CaseIterable, Sendable {
    case recruiting
    case development
    case gamePrep = "game_prep"
    case scouting
}

public struct CoachSkills: Codable, Equatable, Sendable {
    public var recruiting: Int = 50
    public var playerDevelopment: Int = 50
    public var guardDevelopment: Int = 50
    public var wingDevelopment: Int = 50
    public var bigDevelopment: Int = 50
    public var offensiveCoaching: Int = 50
    public var defensiveCoaching: Int = 50
    public var fundraising: Int = 50
    public var scouting: Int = 50
    public var potential: Int = 50

    public init() {}

    enum CodingKeys: String, CodingKey {
        case recruiting
        case playerDevelopment
        case guardDevelopment
        case wingDevelopment
        case bigDevelopment
        case offensiveCoaching
        case defensiveCoaching
        case fundraising
        case scouting
        case potential
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        recruiting = try container.decodeIfPresent(Int.self, forKey: .recruiting) ?? 50
        playerDevelopment = try container.decodeIfPresent(Int.self, forKey: .playerDevelopment) ?? 50
        guardDevelopment = try container.decodeIfPresent(Int.self, forKey: .guardDevelopment) ?? 50
        wingDevelopment = try container.decodeIfPresent(Int.self, forKey: .wingDevelopment) ?? 50
        bigDevelopment = try container.decodeIfPresent(Int.self, forKey: .bigDevelopment) ?? 50
        offensiveCoaching = try container.decodeIfPresent(Int.self, forKey: .offensiveCoaching) ?? 50
        defensiveCoaching = try container.decodeIfPresent(Int.self, forKey: .defensiveCoaching) ?? 50
        fundraising = try container.decodeIfPresent(Int.self, forKey: .fundraising) ?? 50
        scouting = try container.decodeIfPresent(Int.self, forKey: .scouting) ?? 50
        potential = try container.decodeIfPresent(Int.self, forKey: .potential) ?? 50
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(recruiting, forKey: .recruiting)
        try container.encode(playerDevelopment, forKey: .playerDevelopment)
        try container.encode(guardDevelopment, forKey: .guardDevelopment)
        try container.encode(wingDevelopment, forKey: .wingDevelopment)
        try container.encode(bigDevelopment, forKey: .bigDevelopment)
        try container.encode(offensiveCoaching, forKey: .offensiveCoaching)
        try container.encode(defensiveCoaching, forKey: .defensiveCoaching)
        try container.encode(fundraising, forKey: .fundraising)
        try container.encode(scouting, forKey: .scouting)
        try container.encode(potential, forKey: .potential)
    }

    static func normalized(from source: CoachSkills?, random: inout SeededRandom) -> CoachSkills {
        var output = CoachSkills()
        func fallback() -> Int { clamp(50 + random.int(-20, 20), min: 1, max: 100) }

        output.recruiting = clamp(source?.recruiting ?? fallback(), min: 1, max: 100)
        output.playerDevelopment = clamp(source?.playerDevelopment ?? fallback(), min: 1, max: 100)
        output.guardDevelopment = clamp(source?.guardDevelopment ?? fallback(), min: 1, max: 100)
        output.wingDevelopment = clamp(source?.wingDevelopment ?? fallback(), min: 1, max: 100)
        output.bigDevelopment = clamp(source?.bigDevelopment ?? fallback(), min: 1, max: 100)
        output.offensiveCoaching = clamp(source?.offensiveCoaching ?? fallback(), min: 1, max: 100)
        output.defensiveCoaching = clamp(source?.defensiveCoaching ?? fallback(), min: 1, max: 100)
        output.fundraising = clamp(source?.fundraising ?? fallback(), min: 1, max: 100)
        output.scouting = clamp(source?.scouting ?? fallback(), min: 1, max: 100)
        output.potential = clamp(source?.potential ?? fallback(), min: 1, max: 100)

        return output
    }
}

public struct Coach: Codable, Equatable, Sendable {
    public var role: CoachRole = .assistant
    public var name: String?
    public var focus: AssistantFocus?
    public var age: Int = 45
    public var pressAggressiveness: Int = 50
    public var pace: PaceProfile = .normal
    public var defaultOffensiveSet: OffensiveFormation = .motion
    public var defaultDefensiveSet: DefenseScheme = .manToMan
    public var almaMater: String = "Independent"
    public var pipelineState: String = "CA"
    public var skills: CoachSkills = CoachSkills()

    public init() {}
}

public struct CoachingStaff: Codable, Equatable, Sendable {
    public var headCoach: Coach
    public var assistants: [Coach]
    public var gamePrepAssistantIndex: Int?

    public var coaches: [Coach] {
        [headCoach] + assistants
    }

    public init(headCoach: Coach, assistants: [Coach], gamePrepAssistantIndex: Int? = nil) {
        self.headCoach = headCoach
        self.assistants = assistants
        self.gamePrepAssistantIndex = gamePrepAssistantIndex
    }
}

public let DEFAULT_PIPELINE_STATE_WEIGHTS: [String: Int] = [
    "CA": 10, "TX": 10, "FL": 8, "NY": 6, "NC": 6, "IL": 6, "GA": 6, "PA": 5,
    "OH": 5, "VA": 4, "NJ": 4, "MI": 4, "IN": 4, "TN": 3, "AZ": 3, "WA": 3,
    "MO": 3, "MD": 3, "AL": 2, "LA": 2, "SC": 2, "KY": 2, "MS": 1, "AR": 1
]

private let SCHOOL_KEYWORDS_TO_STATE: [String: String] = [
    "Alabama": "AL", "Arizona": "AZ", "Arkansas": "AR", "California": "CA", "Colorado": "CO",
    "Connecticut": "CT", "Florida": "FL", "Georgia": "GA", "Illinois": "IL", "Indiana": "IN",
    "Iowa": "IA", "Kansas": "KS", "Kentucky": "KY", "Louisiana": "LA", "Maryland": "MD",
    "Michigan": "MI", "Minnesota": "MN", "Mississippi": "MS", "Missouri": "MO", "Nebraska": "NE",
    "Nevada": "NV", "Ohio": "OH", "Oklahoma": "OK", "Oregon": "OR", "Pennsylvania": "PA",
    "Tennessee": "TN", "Texas": "TX", "Virginia": "VA", "Washington": "WA", "Wisconsin": "WI",
    "Carolina": "NC"
]

public struct CreateCoachOptions: Codable, Equatable, Sendable {
    public var role: CoachRole = .assistant
    public var name: String?
    public var age: Int?
    public var pressAggressiveness: Int?
    public var pace: PaceProfile = .normal
    public var defaultOffensiveSet: OffensiveFormation = .motion
    public var defaultDefensiveSet: DefenseScheme = .manToMan
    public var almaMater: String?
    public var schoolPool: [String] = []
    public var teamName: String = ""
    public var almaMaterState: String?
    public var pipelineState: String?
    public var pipelineStateWeights: [String: Int] = DEFAULT_PIPELINE_STATE_WEIGHTS
    public var skills: CoachSkills?

    public init() {}
}

public func createCoach(options: CreateCoachOptions = CreateCoachOptions(), random: inout SeededRandom) -> Coach {
    do {
        let args = [try toJSONValue(options)]
        let response = try JSRuntime.shared.invokeWithRandom(moduleId: "./coach", fn: "createCoach", args: args, random: &random)
        return try fromJSONValue(response.result, as: Coach.self)
    } catch {
        fatalError("createCoach failed: \(error)")
    }
}

public struct CreateCoachingStaffOptions: Codable, Equatable, Sendable {
    public var headCoach: CreateCoachOptions?
    public var assistants: [CreateCoachOptions] = []
    public var gamePrepAssistantIndex: Int?
    public var schoolPool: [String] = []
    public var teamName: String = ""
    public var defaultPace: PaceProfile = .normal
    public var defaultOffensiveSet: OffensiveFormation = .motion
    public var defaultDefensiveSet: DefenseScheme = .manToMan
    public var pipelineStateWeights: [String: Int] = DEFAULT_PIPELINE_STATE_WEIGHTS

    public init() {}
}

public func createCoachingStaff(options: CreateCoachingStaffOptions = CreateCoachingStaffOptions(), random: inout SeededRandom) -> CoachingStaff {
    do {
        let args = [try toJSONValue(options)]
        let response = try JSRuntime.shared.invokeWithRandom(moduleId: "./coach", fn: "createCoachingStaff", args: args, random: &random)
        return try fromJSONValue(response.result, as: CoachingStaff.self)
    } catch {
        fatalError("createCoachingStaff failed: \(error)")
    }
}

private func chooseAlmaMater(_ options: CreateCoachOptions, random: inout SeededRandom) -> String {
    if let value = options.almaMater?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty {
        return value
    }

    let pool = options.schoolPool.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    if let picked = random.choose(pool) {
        return picked
    }

    return options.teamName.isEmpty ? "Independent" : options.teamName
}

private func inferStateFromSchoolName(_ schoolName: String) -> String? {
    let trimmed = schoolName.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }

    let upper = trimmed.uppercased()
    if upper.count == 2, DEFAULT_PIPELINE_STATE_WEIGHTS[upper] != nil {
        return upper
    }

    for (keyword, state) in SCHOOL_KEYWORDS_TO_STATE {
        if trimmed.contains(keyword) {
            return state
        }
    }
    return nil
}

private func choosePipelineState(_ options: CreateCoachOptions, almaMater: String, random: inout SeededRandom) -> String {
    if let pipeline = options.pipelineState?.trimmingCharacters(in: .whitespacesAndNewlines), !pipeline.isEmpty {
        return pipeline.uppercased()
    }

    let inferred = options.almaMaterState ?? inferStateFromSchoolName(almaMater)
    if let inferred, random.nextUnit() < 0.45 {
        return inferred
    }

    let weighted = options.pipelineStateWeights.filter { $0.value > 0 }
    let total = weighted.reduce(0) { $0 + $1.value }
    guard total > 0 else { return "CA" }

    var roll = random.nextUnit() * Double(total)
    for (state, weight) in weighted {
        roll -= Double(weight)
        if roll <= 0 {
            return state
        }
    }
    return weighted.first?.key ?? "CA"
}
