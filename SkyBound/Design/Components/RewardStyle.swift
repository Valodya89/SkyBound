import SwiftUI
import SkyBoundCore

extension TierReward {
    var symbol: String {
        switch kind {
        case .coins: "circle.circle.fill"
        case .gems: "diamond.fill"
        case .crate: "shippingbox"
        }
    }

    var tintHex: String {
        switch kind {
        case .coins: "#F2B544"
        case .gems: "#7EDCF2"
        case .crate: "#B48CFF"
        }
    }

    var currency: Currency? {
        switch kind {
        case .coins: .coins
        case .gems: .gems
        case .crate: nil
        }
    }
}

extension WheelPrize.Kind {
    var currency: Currency? {
        switch self {
        case .coins: .coins
        case .gems: .gems
        case .boost: nil
        }
    }
}

extension GameMode {
    /// Line icon for the mode picker.
    var lineIcon: String {
        switch self {
        case .classic: "wind"
        case .sprint: "timer"
        case .rush: "banknote"
        case .gauntlet: "bolt"
        case .hardcore: "flame"
        case .daily: "calendar"
        }
    }
}

extension HubTab {
    func hasBadge(_ p: PlayerProfile) -> Bool {
        switch self {
        case .pass: p.hasClaimableMission || SeasonPass.claimableCount(p) > 0
        case .rank: p.hasOpenDuel
        default: false
        }
    }
}
