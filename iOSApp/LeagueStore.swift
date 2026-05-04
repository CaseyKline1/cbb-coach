import Foundation
import CBBCoachCore

enum LeagueStore {
    private static let fileName = "league_save.json"
    private static let schemaVersion = 1

    private struct Envelope: Codable {
        let schemaVersion: Int
        let teamName: String
        let league: LeagueState
    }

    private static var fileURL: URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent(fileName)
    }

    static func save(_ league: LeagueState, teamName: String) {
        let envelope = Envelope(schemaVersion: schemaVersion, teamName: teamName, league: league)
        do {
            let data = try JSONEncoder().encode(envelope)
            try data.write(to: fileURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        } catch {
            NSLog("LeagueStore.save failed: \(error)")
        }
    }

    static func load(expectedTeam: String) -> LeagueState? {
        let url = fileURL
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        do {
            let data = try Data(contentsOf: url)
            let envelope = try JSONDecoder().decode(Envelope.self, from: data)
            guard envelope.schemaVersion == schemaVersion,
                  envelope.teamName == expectedTeam else {
                return nil
            }
            return envelope.league
        } catch {
            NSLog("LeagueStore.load failed: \(error)")
            return nil
        }
    }

    static func clear() {
        let url = fileURL
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try? FileManager.default.removeItem(at: url)
    }
}
