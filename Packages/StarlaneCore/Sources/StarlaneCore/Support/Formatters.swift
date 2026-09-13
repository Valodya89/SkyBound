import Foundation

public enum GameFormat {
    /// `1:05` style clock for energy and offer timers.
    public static func clock(_ seconds: Int) -> String {
        let s = max(seconds, 0)
        return "\(s / 60):" + String(format: "%02d", s % 60)
    }

    /// `12:34:56` countdown to the next day.
    public static func longClock(_ seconds: Int) -> String {
        let s = max(seconds, 0)
        return String(format: "%02d:%02d:%02d", s / 3600, (s % 3600) / 60, s % 60)
    }

    /// Wallet-style compact number: `12.3k`.
    public static func compact(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM", Double(n) / 1_000_000) }
        if n >= 10_000 { return String(format: "%.1fk", Double(n) / 1000) }
        return grouped(n)
    }

    /// Locale-independent multiplier such as `1.25` or `3`.
    public static func multiplier(_ v: Double) -> String {
        v == v.rounded() ? String(Int(v)) : String(format: "%.2f", v).replacingOccurrences(of: "0+$", with: "", options: .regularExpression)
    }

    public static func grouped(_ n: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = ","
        f.usesGroupingSeparator = true
        return f.string(from: NSNumber(value: n)) ?? "\(n)"
    }

    /// Seconds remaining until local midnight.
    public static func secondsUntilMidnight(from date: Date, calendar: Calendar = .current) -> Int {
        let start = calendar.startOfDay(for: date)
        guard let next = calendar.date(byAdding: .day, value: 1, to: start) else { return 0 }
        return max(0, Int(next.timeIntervalSince(date)))
    }
}
