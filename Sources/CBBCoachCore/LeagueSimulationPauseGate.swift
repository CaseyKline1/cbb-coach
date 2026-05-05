import Foundation

public enum LeagueSimulationPauseGate {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var paused = false

    public static func setPaused(_ value: Bool) {
        lock.lock()
        paused = value
        lock.unlock()
    }

    public static func waitIfPaused() {
        if Thread.isMainThread { return }
        while true {
            lock.lock()
            let isPaused = paused
            lock.unlock()
            if !isPaused { return }
            Thread.sleep(forTimeInterval: 0.1)
        }
    }
}
