import Foundation

public struct UserPlaybookSummary: Codable, Equatable, Sendable {
    public var pace: PaceProfile
    public var defenseScheme: DefenseScheme
    public var offenseWeights: [String: Int]

    public init(pace: PaceProfile, defenseScheme: DefenseScheme, offenseWeights: [String: Int]) {
        self.pace = pace
        self.defenseScheme = defenseScheme
        self.offenseWeights = offenseWeights
    }
}

public func getUserPlaybook(_ league: LeagueState) -> UserPlaybookSummary? {
    guard let state = LeagueStore.get(league.handle),
          let user = state.teams.first(where: { $0.teamId == state.userTeamId }) else {
        return nil
    }

    let team = user.teamModel
    var weights: [String: Int] = [:]
    if let formations = team.formations, !formations.isEmpty {
        var counts: [OffensiveFormation: Int] = [:]
        for formation in formations {
            counts[formation, default: 0] += 1
        }
        let total = formations.count
        for formation in OffensiveFormation.allCases {
            let count = counts[formation] ?? 0
            weights[formation.rawValue] = Int((Double(count) / Double(total) * 100).rounded())
        }
    } else {
        for formation in OffensiveFormation.allCases {
            weights[formation.rawValue] = formation == team.formation ? 100 : 0
        }
    }

    return UserPlaybookSummary(
        pace: team.pace,
        defenseScheme: team.defenseScheme,
        offenseWeights: weights
    )
}

public func setUserPlaybook(
    _ league: inout LeagueState,
    pace: PaceProfile,
    defenseScheme: DefenseScheme,
    offenseWeights: [String: Int]
) {
    _ = LeagueStore.update(league.handle) { state in
        guard let userIndex = state.teams.firstIndex(where: { $0.teamId == state.userTeamId }) else { return }

        var team = state.teams[userIndex].teamModel
        team.pace = pace
        team.defenseScheme = defenseScheme

        let sequence = expandOffenseWeights(offenseWeights)
        if sequence.isEmpty {
            team.formations = nil
        } else {
            team.formations = sequence
            team.formation = sequence[0]
        }

        state.teams[userIndex].teamModel = team
    }
}

func expandOffenseWeights(_ weights: [String: Int]) -> [OffensiveFormation] {
    var pairs: [(OffensiveFormation, Int)] = []
    for formation in OffensiveFormation.allCases {
        let value = max(0, weights[formation.rawValue] ?? 0)
        if value > 0 {
            pairs.append((formation, value))
        }
    }
    guard !pairs.isEmpty else { return [] }

    let total = pairs.reduce(0) { $0 + $1.1 }
    let bucketSize = max(5, total / 20)
    var result: [OffensiveFormation] = []
    for (formation, weight) in pairs {
        let count = max(1, Int((Double(weight) / Double(bucketSize)).rounded()))
        for _ in 0..<count {
            result.append(formation)
        }
    }

    var interleaved: [OffensiveFormation] = []
    var queues: [[OffensiveFormation]] = pairs.map { pair in
        Array(repeating: pair.0, count: result.filter { $0 == pair.0 }.count)
    }
    while queues.contains(where: { !$0.isEmpty }) {
        for index in queues.indices where !queues[index].isEmpty {
            interleaved.append(queues[index].removeFirst())
        }
    }
    return interleaved
}
