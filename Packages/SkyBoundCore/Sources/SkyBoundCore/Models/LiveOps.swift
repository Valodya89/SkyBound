import Foundation

/// One day of the seven-day login calendar.
public struct DailyLoginReward: Sendable, Hashable, Identifiable {
    public let day: Int
    public let coins: Int
    public let gems: Int
    public let skinID: String?

    public var id: Int { day }

    public static let calendar: [DailyLoginReward] = [
        .init(day: 1, coins: 150, gems: 0, skinID: nil),
        .init(day: 2, coins: 250, gems: 0, skinID: nil),
        .init(day: 3, coins: 0, gems: 12, skinID: nil),
        .init(day: 4, coins: 400, gems: 0, skinID: nil),
        .init(day: 5, coins: 0, gems: 20, skinID: nil),
        .init(day: 6, coins: 700, gems: 0, skinID: nil),
        .init(day: 7, coins: 0, gems: 60, skinID: "vapor"),
    ]
}

/// A slice on the fortune wheel.
public struct WheelPrize: Sendable, Hashable, Identifiable {
    public enum Kind: Sendable, Hashable {
        case coins(Int)
        case gems(Int)
        case boost(BoostKind)
    }

    public let id: Int
    public let label: String
    public let kind: Kind
    public let colorHex: String

    public static let wheel: [WheelPrize] = [
        .init(id: 0, label: "100🪙", kind: .coins(100), colorHex: "#8B5CFF"),
        .init(id: 1, label: "10💎", kind: .gems(10), colorHex: "#3DF0FF"),
        .init(id: 2, label: "300🪙", kind: .coins(300), colorHex: "#FF3D9A"),
        .init(id: 3, label: "🛡×1", kind: .boost(.shield), colorHex: "#4DFFA8"),
        .init(id: 4, label: "25💎", kind: .gems(25), colorHex: "#FFC23D"),
        .init(id: 5, label: "150🪙", kind: .coins(150), colorHex: "#8B5CFF"),
        .init(id: 6, label: "🧲×1", kind: .boost(.magnet), colorHex: "#FF7A3D"),
        .init(id: 7, label: "1000🪙", kind: .coins(1000), colorHex: "#FF3D9A"),
    ]
}

/// A fake advert shown by the simulated ad service.
public struct MockAd: Sendable, Hashable, Identifiable {
    public let id: Int
    public let icon: String
    /// SF Symbol for native UI.
    public let symbol: String
    public let name: String
    public let blurb: String

    public static let catalog: [MockAd] = [
        .init(id: 0, icon: "🚀", symbol: "paperplane.fill", name: "GALAXY BLASTER 3", blurb: "Command a fleet. Crush the void. Free to install."),
        .init(id: 1, icon: "🏰", symbol: "building.columns.fill", name: "KINGDOM OF ASH", blurb: "Build. Raid. Betray. 40M players can't be wrong."),
        .init(id: 2, icon: "🧩", symbol: "puzzlepiece.fill", name: "PUZZLE MANOR", blurb: "Can YOU solve level 7? 96% of players fail."),
        .init(id: 3, icon: "🍰", symbol: "cup.and.saucer.fill", name: "CAFE TYCOON", blurb: "Your dream bakery is 3 taps away."),
    ]
}

public struct BossDefinition: Sendable, Hashable {
    public let name: String
    public let hitPoints: Int

    public static let roster: [BossDefinition] = [
        .init(name: "ORBITAL WARDEN", hitPoints: 8),
        .init(name: "RELAY SENTINEL", hitPoints: 10),
        .init(name: "THE ARCHITECT", hitPoints: 12),
        .init(name: "NULL PRIME", hitPoints: 14),
    ]

    /// Bosses get tougher every 4,500 metres.
    public static func boss(forDistance distance: Double) -> BossDefinition {
        let idx = min(max(Int(distance / 4500), 0), roster.count - 1)
        return roster[idx]
    }
}

public enum RivalNames {
    public static let all: [String] = [
        "ShadowByte", "NovaKid", "PixelWraith", "Glitchrunner", "VaporTine", "EchoDash", "ZeroDrift",
        "LunaBlaze", "HexProwler", "SynthFox", "NullPointer", "Kilowatt",
    ]

    /// Stable hue for avatars, derived from the rival's index.
    public static func hue(forIndex i: Int) -> Double { Double((i * 57) % 360) }
}
