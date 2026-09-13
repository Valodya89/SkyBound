import Foundation

/// A source of uniform doubles in `[0, 1)`. Value semantics keep simulations reproducible.
public protocol RandomSource: Sendable {
    mutating func nextUnit() -> Double
}

public extension RandomSource {
    mutating func next(in range: ClosedRange<Double>) -> Double {
        range.lowerBound + nextUnit() * (range.upperBound - range.lowerBound)
    }

    mutating func nextIndex(count: Int) -> Int {
        guard count > 0 else { return 0 }
        return min(count - 1, Int(nextUnit() * Double(count)))
    }

    mutating func chance(_ p: Double) -> Bool { nextUnit() < p }
}

/// Deterministic 32-bit generator (mulberry32). Used for the Daily Challenge so every player gets the same course.
public struct Mulberry32: RandomSource, Hashable {
    private var state: UInt32

    public init(seed: UInt32) { state = seed }

    public mutating func nextUnit() -> Double {
        state = state &+ 0x6D2B_79F5
        var t = UInt32(state)
        t = (t ^ (t >> 15)) &* (1 | t)
        t = (t &+ ((t ^ (t >> 7)) &* (61 | t))) ^ t
        let r = t ^ (t >> 14)
        return Double(r) / 4_294_967_296
    }
}

/// Non-deterministic source backed by the system generator.
public struct SystemRandomSource: RandomSource {
    public init() {}
    public mutating func nextUnit() -> Double { Double.random(in: 0..<1) }
}

public enum DaySeed {
    /// `YYYYMMDD` for the given date in the given calendar. The same number feeds the daily course generator.
    public static func value(for date: Date, calendar: Calendar = .current) -> Int {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return (c.year ?? 2000) * 10000 + (c.month ?? 1) * 100 + (c.day ?? 1)
    }
}
