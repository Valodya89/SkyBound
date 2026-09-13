import Foundation

/// The two soft/hard currencies in the economy.
public enum Currency: String, Codable, Sendable, CaseIterable {
    case coins
    case gems

    public var displayName: String {
        switch self {
        case .coins: "coins"
        case .gems: "gems"
        }
    }

    public var symbol: String {
        switch self {
        case .coins: "🪙"
        case .gems: "💎"
        }
    }

    /// SF Symbol used by the native UI.
    public var systemImage: String {
        switch self {
        case .coins: "circle.circle.fill"
        case .gems: "diamond.fill"
        }
    }
}

/// A simple price tag used by shop items, boosts and upgrades.
public struct Price: Sendable, Hashable, Codable {
    public let amount: Int
    public let currency: Currency

    public init(_ amount: Int, _ currency: Currency) {
        self.amount = amount
        self.currency = currency
    }

    public static func coins(_ amount: Int) -> Price { Price(amount, .coins) }
    public static func gems(_ amount: Int) -> Price { Price(amount, .gems) }
}
