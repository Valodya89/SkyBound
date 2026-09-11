import Foundation

/// Consumable boosts equipped before a run or picked up as orbs mid-run.
public enum BoostKind: String, Codable, CaseIterable, Sendable, Identifiable {
    case magnet
    case slowmo
    case doubleCoin
    case shield
    case headStart

    public var id: String { rawValue }

    public var name: String {
        switch self {
        case .magnet: "Magnet"
        case .slowmo: "Slow-Mo"
        case .doubleCoin: "2× Coins"
        case .shield: "Shield"
        case .headStart: "Head Start"
        }
    }

    public var icon: String {
        switch self {
        case .magnet: "🧲"
        case .slowmo: "🐌"
        case .doubleCoin: "💰"
        case .shield: "🛡"
        case .headStart: "🚀"
        }
    }

    /// SF Symbol for native UI.
    public var symbol: String {
        switch self {
        case .magnet: "dot.radiowaves.left.and.right"
        case .slowmo: "tortoise.fill"
        case .doubleCoin: "dollarsign.circle.fill"
        case .shield: "shield.fill"
        case .headStart: "hare.fill"
        }
    }

    public var detail: String {
        switch self {
        case .magnet: "Pulls every pickup toward you for 8s"
        case .slowmo: "Halves world speed for 8s"
        case .doubleCoin: "Doubles all coin value for the whole run"
        case .shield: "Absorbs one crash"
        case .headStart: "Begin at 800m with the score banked"
        }
    }

    public var price: Price {
        switch self {
        case .magnet: .coins(90)
        case .slowmo: .coins(110)
        case .doubleCoin: .coins(180)
        case .shield: .gems(45)
        case .headStart: .gems(60)
        }
    }

    public var colorHex: String {
        switch self {
        case .magnet: "#9B85FF"
        case .slowmo: "#4FC3F7"
        case .doubleCoin: "#FFC53D"
        case .shield: "#2FE0A6"
        case .headStart: "#FF9273"
        }
    }

    /// Boosts that can spawn as orbs on the track.
    public static let orbKinds: [BoostKind] = [.magnet, .slowmo, .shield]
}
