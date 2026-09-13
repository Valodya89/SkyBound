import Foundation

/// A simulated real-money product. Nothing charges real money; the app applies `grant` locally.
public struct StoreProduct: Sendable, Hashable, Identifiable {
    public enum Grant: Sendable, Hashable {
        case gems(Int)
        case vip
        case removeAds
        case founderBundle
        case piggyBank
    }

    public let id: String
    public let icon: String
    /// SF Symbol for native UI.
    public let symbol: String
    public let name: String
    public let detail: String
    public let priceLabel: String
    public let grant: Grant
    public let badge: String?

    public static let vip = StoreProduct(id: "vip", icon: "👑", symbol: "crown.fill", name: "VIP Pass",
                                         detail: "+2 energy cap · 2× coins every run · no interstitials",
                                         priceLabel: "$6.99/mo", grant: .vip, badge: "BEST VALUE")

    public static let gemPacks: [StoreProduct] = [
        StoreProduct(id: "gems.pouch", icon: "💎", symbol: "diamond.fill", name: "Pouch of Gems", detail: "120 gems", priceLabel: "$1.99", grant: .gems(120), badge: nil),
        StoreProduct(id: "gems.chest", icon: "💠", symbol: "diamond.circle.fill", name: "Chest of Gems", detail: "650 gems · +8% bonus", priceLabel: "$7.99", grant: .gems(650), badge: "POPULAR"),
        StoreProduct(id: "gems.vault", icon: "🔷", symbol: "rhombus.fill", name: "Vault of Gems", detail: "1,450 gems · +20% bonus", priceLabel: "$14.99", grant: .gems(1450), badge: nil),
        StoreProduct(id: "gems.hoard", icon: "🌌", symbol: "sparkles", name: "Singularity Hoard", detail: "4,000 gems · +34% bonus", priceLabel: "$39.99", grant: .gems(4000), badge: nil),
    ]

    public static let founderBundle = StoreProduct(id: "bundle.founder", icon: "🎁", symbol: "gift.fill", name: "Founder's Bundle",
                                                   detail: "1,200 gems + Gilded Comet skin + 3 boosts", priceLabel: "$5.99",
                                                   grant: .founderBundle, badge: "70% OFF")
    public static let removeAds = StoreProduct(id: "noads", icon: "🚫", symbol: "nosign", name: "Remove Ads",
                                               detail: "Kills every interstitial permanently", priceLabel: "$2.99",
                                               grant: .removeAds, badge: nil)
    public static let piggyBank = StoreProduct(id: "piggy", icon: "🐷", symbol: "banknote.fill", name: "Piggy Bank",
                                               detail: "Fills as you play · smash to collect", priceLabel: "$3.99",
                                               grant: .piggyBank, badge: nil)
}

public enum ShopSystem {
    public static let offerDurationSeconds = 600

    public static func piggyBankValue(_ profile: PlayerProfile) -> Int {
        min(4000, profile.totalCoins * 2 + 400)
    }

    public static func isOwned(_ product: StoreProduct, profile: PlayerProfile) -> Bool {
        switch product.grant {
        case .vip: profile.isVIP
        case .removeAds: profile.adsRemoved
        case .founderBundle: profile.founderBundleOwned
        case .gems, .piggyBank: false
        }
    }

    /// Applies a (simulated) purchase. Returns a human-readable description of what was granted.
    @discardableResult
    public static func apply(_ product: StoreProduct, to profile: inout PlayerProfile) -> String? {
        guard !isOwned(product, profile: profile) else { return nil }
        switch product.grant {
        case .gems(let n):
            profile.gems += n
            return "+\(n) gems"
        case .vip:
            profile.isVIP = true
            profile.maxEnergy += 2
            profile.energy += 2
            return "VIP activated"
        case .removeAds:
            profile.adsRemoved = true
            return "Interstitials disabled"
        case .founderBundle:
            profile.gems += 1200
            profile.unlockSkin("gilded")
            profile.addBoost(.shield)
            profile.addBoost(.magnet)
            profile.addBoost(.doubleCoin)
            profile.founderBundleOwned = true
            return "1200 gems, a Legendary skin and 3 boosts"
        case .piggyBank:
            let v = piggyBankValue(profile)
            profile.coins += v
            profile.totalCoins = 0
            return "+\(v) coins"
        }
    }

    @discardableResult
    public static func buyBoost(_ kind: BoostKind, profile: inout PlayerProfile) -> Bool {
        guard profile.spend(kind.price) else { return false }
        profile.addBoost(kind)
        return true
    }
}

public enum UpgradeSystem {
    public static func price(_ kind: UpgradeKind, profile: PlayerProfile) -> Int {
        kind.price(atLevel: profile.upgradeLevel(kind))
    }

    public static func isMaxed(_ kind: UpgradeKind, profile: PlayerProfile) -> Bool {
        profile.upgradeLevel(kind) >= kind.maxLevel
    }

    @discardableResult
    public static func buy(_ kind: UpgradeKind, profile: inout PlayerProfile) -> Bool {
        guard !isMaxed(kind, profile: profile), profile.spend(.coins(price(kind, profile: profile))) else { return false }
        profile.upgrades[kind, default: 0] += 1
        return true
    }
}
