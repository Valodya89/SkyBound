import Foundation

/// Tunable configuration for a game mode.
public struct ModeConfig: Sendable, Hashable {
    public let name: String
    public let icon: String
    /// SF Symbol for native UI.
    public let symbol: String
    public let tagline: String
    /// Energy required to launch a run.
    public let energyCost: Int
    /// Time limit in seconds; `0` means endless.
    public let timeLimit: Double
    public let density: Double
    public let coinRate: Double
    public let speed: Double
    public let allowsRevive: Bool
    public let payout: Double
    public let unlockLevel: Int
    public let hasBosses: Bool
    /// Distance between boss encounters in metres.
    public let bossInterval: Double
    public let isHidden: Bool

    public var isTimed: Bool { timeLimit > 0 }
}

/// All playable modes. `daily` is hidden from the mode picker and launched from the Daily Challenge.
public enum GameMode: String, Codable, CaseIterable, Sendable, Identifiable {
    case classic
    case sprint
    case rush
    case gauntlet
    case hardcore
    case daily

    public var id: String { rawValue }

    public static var selectable: [GameMode] { allCases.filter { !$0.config.isHidden } }

    public var config: ModeConfig {
        switch self {
        case .classic:
            ModeConfig(name: "Classic Dash", icon: "🌀", symbol: "tornado", tagline: "Endless run. Speed climbs forever.",
                       energyCost: 1, timeLimit: 0, density: 1, coinRate: 1, speed: 1, allowsRevive: true,
                       payout: 1, unlockLevel: 0, hasBosses: true, bossInterval: 1500, isHidden: false)
        case .sprint:
            ModeConfig(name: "Time Sprint", icon: "⏱", symbol: "timer", tagline: "60 seconds. Score as hard as you can.",
                       energyCost: 1, timeLimit: 60, density: 1.25, coinRate: 1.15, speed: 1.15, allowsRevive: true,
                       payout: 1.25, unlockLevel: 0, hasBosses: false, bossInterval: 1500, isHidden: false)
        case .rush:
            ModeConfig(name: "Coin Rush", icon: "🧲", symbol: "banknote.fill", tagline: "40s of pure loot. Barely any walls.",
                       energyCost: 1, timeLimit: 40, density: 0.34, coinRate: 2.6, speed: 0.92, allowsRevive: true,
                       payout: 1, unlockLevel: 2, hasBosses: false, bossInterval: 1500, isHidden: false)
        case .gauntlet:
            ModeConfig(name: "Gauntlet", icon: "⚡", symbol: "bolt.fill", tagline: "Tight corridors, bosses twice as often.",
                       energyCost: 2, timeLimit: 0, density: 1.7, coinRate: 0.9, speed: 1.35, allowsRevive: true,
                       payout: 1.7, unlockLevel: 4, hasBosses: true, bossInterval: 900, isHidden: false)
        case .hardcore:
            ModeConfig(name: "Hardcore", icon: "💀", symbol: "flame.fill", tagline: "Max speed. No revives. Triple payout.",
                       energyCost: 2, timeLimit: 0, density: 1.5, coinRate: 1, speed: 1.75, allowsRevive: false,
                       payout: 3, unlockLevel: 7, hasBosses: true, bossInterval: 1500, isHidden: false)
        case .daily:
            ModeConfig(name: "Daily Challenge", icon: "🗓", symbol: "calendar", tagline: "Same course for everyone. One try.",
                       energyCost: 0, timeLimit: 0, density: 1.15, coinRate: 1.1, speed: 1.1, allowsRevive: false,
                       payout: 1.5, unlockLevel: 0, hasBosses: true, bossInterval: 1500, isHidden: true)
        }
    }

    public func isUnlocked(atLevel level: Int) -> Bool { level >= config.unlockLevel }
}
