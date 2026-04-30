import Foundation

public enum PlayerPosition: String, Codable, CaseIterable, Sendable {
    case pg = "PG"
    case sg = "SG"
    case sf = "SF"
    case pf = "PF"
    case c = "C"
    case cg = "CG"
    case wing = "Wing"
    case f = "F"
    case big = "Big"
}

public enum PlayerYear: String, Codable, CaseIterable, Sendable {
    case hs = "HS"
    case fr = "FR"
    case so = "SO"
    case jr = "JR"
    case sr = "SR"
    case graduated = "Graduated"
}

public struct Player: Codable, Equatable, Sendable {
    public struct Bio: Codable, Equatable, Sendable {
        public var name: String = ""
        public var position: PlayerPosition = .pg
        public var home: String = ""
        public var year: PlayerYear = .hs
        public var redshirtUsed: Bool = false
        public var potential: Int = 1
        public var nilDollarsLastYear: Double? = nil
    }

    public struct Athleticism: Codable, Equatable, Sendable {
        public var speed: Int = 1
        public var agility: Int = 1
        public var burst: Int = 1
        public var strength: Int = 1
        public var vertical: Int = 1
        public var stamina: Int = 1
        public var durability: Int = 1
    }

    public struct Shooting: Codable, Equatable, Sendable {
        public var layups: Int = 1
        public var dunks: Int = 1
        public var closeShot: Int = 1
        public var midrangeShot: Int = 1
        public var threePointShooting: Int = 1
        public var cornerThrees: Int = 1
        public var upTopThrees: Int = 1
        public var drawFoul: Int = 1
        public var freeThrows: Int = 1
    }

    public struct PostGame: Codable, Equatable, Sendable {
        public var postControl: Int = 1
        public var postFadeaways: Int = 1
        public var postHooks: Int = 1
    }

    public struct Skills: Codable, Equatable, Sendable {
        public var ballHandling: Int = 1
        public var ballSafety: Int = 1
        public var passingAccuracy: Int = 1
        public var passingVision: Int = 1
        public var passingIQ: Int = 1
        public var shotIQ: Int = 1
        public var offballOffense: Int = 1
        public var hands: Int = 1
        public var hustle: Int = 1
        public var clutch: Int = 1
    }

    public struct Defense: Codable, Equatable, Sendable {
        public var perimeterDefense: Int = 1
        public var postDefense: Int = 1
        public var shotBlocking: Int = 1
        public var shotContest: Int = 1
        public var steals: Int = 1
        public var lateralQuickness: Int = 1
        public var offballDefense: Int = 1
        public var passPerception: Int = 1
        public var defensiveControl: Int = 1
    }

    public struct Rebounding: Codable, Equatable, Sendable {
        public var offensiveRebounding: Int = 1
        public var defensiveRebound: Int = 1
        public var boxouts: Int = 1
    }

    public struct Tendencies: Codable, Equatable, Sendable {
        public var post: Int = 1
        public var inside: Int = 1
        public var midrange: Int = 1
        public var threePoint: Int = 1
        public var drive: Int = 1
        public var pickAndRoll: Int = 1
        public var pickAndPop: Int = 1
        public var shootVsPass: Int = 1
    }

    public struct Size: Codable, Equatable, Sendable {
        public var height: String = ""
        public var weight: String = ""
        public var wingspan: String = ""
    }

    public struct Condition: Codable, Equatable, Sendable {
        public var energy: Double = 100
        public var clutchTime: Bool = false
        public var fouledOut: Bool = false
        public var homeCourtMultiplier: Double = 1
        public var possessionRole: String?
        public var offensiveCoachingModifier: Double = 1
        public var defensiveCoachingModifier: Double = 1
    }

    public var bio = Bio()
    public var athleticism = Athleticism()
    public var shooting = Shooting()
    public var postGame = PostGame()
    public var skills = Skills()
    public var defense = Defense()
    public var rebounding = Rebounding()
    public var tendencies = Tendencies()
    public var size = Size()
    public var condition = Condition()
    public var greed: Double? = nil
    public var loyalty: Double? = nil

    public init() {}
}

public var POSITIONS: [PlayerPosition] { PlayerPosition.allCases }
public var YEARS: [PlayerYear] { PlayerYear.allCases }

public func createPlayer() -> Player {
    Player()
}
