import Foundation

@inlinable
public func clamp<T: Comparable>(_ value: T, min lower: T, max upper: T) -> T {
    Swift.max(lower, Swift.min(value, upper))
}

@inlinable
public func asInt(_ value: Double) -> Int {
    Int(value.rounded())
}

public struct SeededRandom: Sendable {
    private var state: UInt64

    public init(seed: UInt64) {
        self.state = seed == 0 ? 0x9E3779B97F4A7C15 : seed
    }

    public mutating func nextUnit() -> Double {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        let upper = state >> 11
        return Double(upper) / Double(1 << 53)
    }

    public mutating func int(_ min: Int, _ maxInclusive: Int) -> Int {
        guard maxInclusive > min else { return min }
        let span = Double(maxInclusive - min + 1)
        return min + Int((nextUnit() * span).rounded(.down))
    }

    public mutating func choose<T>(_ values: [T]) -> T? {
        guard !values.isEmpty else { return nil }
        let index = int(0, values.count - 1)
        return values[index]
    }
}

public func hashString(_ input: String) -> UInt64 {
    var h: UInt64 = 1469598103934665603
    for byte in input.utf8 {
        h ^= UInt64(byte)
        h = h &* 1099511628211
    }
    return h
}
