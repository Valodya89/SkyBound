import Foundation

/// Permanent rocket upgrades bought with coins.
public enum UpgradeKind: String, Codable, CaseIterable, Sendable, Identifiable {
    case coinValue
    case magnetField
    case autoShield
    case scoreCore
    case grazer

    public var id: String { rawValue }

    public var name: String {
        switch self {
        case .coinValue: "Coin Value"
        case .magnetField: "Magnet Field"
        case .autoShield: "Auto-Shield"
        case .scoreCore: "Score Core"
        case .grazer: "Grazer"
        }
    }

    public var icon: String {
        switch self {
        case .coinValue: "🪙"
        case .magnetField: "🧲"
        case .autoShield: "🛡"
        case .scoreCore: "📈"
        case .grazer: "⚡"
        }
    }

    /// SF Symbol for native UI.
    public var symbol: String {
        switch self {
        case .coinValue: "dollarsign.circle.fill"
        case .magnetField: "dot.radiowaves.left.and.right"
        case .autoShield: "shield.lefthalf.filled"
        case .scoreCore: "chart.line.uptrend.xyaxis"
        case .grazer: "bolt.fill"
        }
    }

    public var detail: String {
        switch self {
        case .coinValue: "+15% coin value per level"
        case .magnetField: "+1.5s magnet time, wider pull"
        case .autoShield: "+18% chance to start with a shield"
        case .scoreCore: "+8% score rate per level"
        case .grazer: "+12 points per near miss"
        }
    }

    public var maxLevel: Int { 5 }

    public var basePrice: Int {
        switch self {
        case .coinValue: 600
        case .magnetField: 520
        case .autoShield: 820
        case .scoreCore: 700
        case .grazer: 460
        }
    }

    public func price(atLevel level: Int) -> Int { basePrice * (level + 1) }
}
