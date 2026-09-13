import Foundation

public enum Rarity: String, Codable, CaseIterable, Sendable, Comparable {
    case common, rare, epic, legendary

    public var displayName: String {
        switch self {
        case .common: "Common"
        case .rare: "Rare"
        case .epic: "Epic"
        case .legendary: "Legendary"
        }
    }

    public var colorHex: String {
        switch self {
        case .common: "#9AA6B8"
        case .rare: "#6FD3EC"
        case .epic: "#B48CFF"
        case .legendary: "#F3B53F"
        }
    }

    /// Drop chance as displayed in the crate odds table.
    public var dropRate: Double {
        switch self {
        case .common: 0.65
        case .rare: 0.25
        case .epic: 0.08
        case .legendary: 0.02
        }
    }

    /// Coins refunded when a pull is a duplicate of this rarity.
    public var duplicateRefund: Int {
        switch self {
        case .common: 40
        case .rare: 120
        case .epic: 300
        case .legendary: 800
        }
    }

    private var order: Int {
        switch self {
        case .common: 0
        case .rare: 1
        case .epic: 2
        case .legendary: 3
        }
    }

    public static func < (lhs: Rarity, rhs: Rarity) -> Bool { lhs.order < rhs.order }
}

/// A cosmetic rocket skin. Skins never change gameplay stats.
public struct Skin: Identifiable, Sendable, Hashable, Codable {
    public let id: String
    public let name: String
    public let colorHex: String
    public let rarity: Rarity
    public let icon: String
    /// SF Symbol for native UI.
    public let symbol: String

    public init(id: String, name: String, colorHex: String, rarity: Rarity, icon: String, symbol: String) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.rarity = rarity
        self.icon = icon
        self.symbol = symbol
    }
}

public enum SkinCatalog {
    public static let defaultSkinID = "default"

    public static let all: [Skin] = [
        Skin(id: "default", name: "Standard", colorHex: "#EEF1F5", rarity: .common, icon: "▲", symbol: "triangle.fill"),
        Skin(id: "ember", name: "Ember", colorHex: "#FF6A5A", rarity: .common, icon: "🔥", symbol: "flame.fill"),
        Skin(id: "moss", name: "Mossline", colorHex: "#7DE86A", rarity: .common, icon: "🌿", symbol: "leaf.fill"),
        Skin(id: "slate", name: "Slate", colorHex: "#9FB0C4", rarity: .common, icon: "◆", symbol: "diamond.fill"),
        Skin(id: "toxic", name: "Citrus", colorHex: "#D7F53A", rarity: .rare, icon: "🍋", symbol: "drop.fill"),
        Skin(id: "frost", name: "Frostbite", colorHex: "#8FE3FF", rarity: .rare, icon: "❄️", symbol: "snowflake"),
        Skin(id: "bloom", name: "Bloom", colorHex: "#FF7FC4", rarity: .rare, icon: "🌸", symbol: "camera.macro"),
        Skin(id: "royal", name: "Royal", colorHex: "#9B85FF", rarity: .epic, icon: "♛", symbol: "crown.fill"),
        Skin(id: "vapor", name: "Sunset", colorHex: "#FF5D8F", rarity: .epic, icon: "🌴", symbol: "sun.horizon.fill"),
        Skin(id: "circuit", name: "Circuit", colorHex: "#2FE0A6", rarity: .epic, icon: "⚡️", symbol: "cpu.fill"),
        Skin(id: "gilded", name: "Gilded Comet", colorHex: "#FFC53D", rarity: .legendary, icon: "☄️", symbol: "sparkles"),
        Skin(id: "singular", name: "Prism", colorHex: "#FFF6C9", rarity: .legendary, icon: "✦", symbol: "star.fill"),
    ]

    private static let byID: [String: Skin] = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })

    public static func skin(_ id: String) -> Skin {
        byID[id] ?? all[0]
    }

    public static func skins(of rarity: Rarity) -> [Skin] {
        all.filter { $0.rarity == rarity }
    }
}
