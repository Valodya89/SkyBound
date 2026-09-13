import Foundation

/// Injectable time source so daily resets and timers are testable.
public protocol Clock: Sendable {
    var now: Date { get }
}

public struct SystemClock: Clock {
    public init() {}
    public var now: Date { Date() }
}

/// A clock you can move by hand in tests.
public final class ManualClock: Clock, @unchecked Sendable {
    private let lock = NSLock()
    private var _now: Date

    public init(now: Date = Date(timeIntervalSince1970: 1_700_000_000)) { _now = now }

    public var now: Date {
        get { lock.withLock { _now } }
        set { lock.withLock { _now = newValue } }
    }

    public func advance(by seconds: TimeInterval) {
        lock.withLock { _now = _now.addingTimeInterval(seconds) }
    }
}
