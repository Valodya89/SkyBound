import Foundation

/// A real-money product sold through the App Store.
///
/// `id` is the App Store Connect product identifier, so the catalog here is the single source of truth
/// for both the UI and the StoreKit product request. `priceLabel` is only a placeholder shown until the
/// localised `Product.displayPrice` arrives from StoreKit — never treat it as the price the user pays.
public struct StoreProduct: Sendable, Hashable, Identifiable {
    /// Maps onto the App Store Connect product type.
    public enum Kind: Sendable, Hashable {
        /// Grants currency or a one-shot payload and can be bought again.
        case consumable
        /// Bought once, restorable forever.
        case nonConsumable
        /// Auto-renewable subscription; the entitlement disappears when it lapses.
        case autoRenewable
    }

    public enum Grant: Sendable, Hashable {
        case gems(Int)
        case vip
        case removeAds
        case founderBundle
        case piggyBank
    }

    /// Every product identifier starts with this, matching the app's bundle identifier.
    public static let idPrefix = "com.ravo.skybound."
    /// Subscription group configured in App Store Connect. All VIP tiers live here.
    public static let vipSubscriptionGroupID = "skybound.vip"

    public let id: String
    public let kind: Kind
    public let icon: String
    /// SF Symbol for native UI.
    public let symbol: String
    public let name: String
    public let detail: String
    /// Placeholder price, shown only while StoreKit has not returned the real localised price.
    public let priceLabel: String
    public let grant: Grant
    public let badge: String?

    public static let vip = StoreProduct(id: idPrefix + "vip.monthly", kind: .autoRenewable, icon: "👑", symbol: "crown.fill", name: "VIP Pass",
                                         detail: "+2 energy cap · 2× coins every run · no interstitials",
                                         priceLabel: "$6.99", grant: .vip, badge: "BEST VALUE")

    public static let gemPacks: [StoreProduct] = [
        StoreProduct(id: idPrefix + "gems.pouch", kind: .consumable, icon: "💎", symbol: "diamond.fill", name: "Pouch of Gems", detail: "120 gems", priceLabel: "$1.99", grant: .gems(120), badge: nil),
        StoreProduct(id: idPrefix + "gems.chest", kind: .consumable, icon: "💠", symbol: "diamond.circle.fill", name: "Chest of Gems", detail: "650 gems · +8% bonus", priceLabel: "$7.99", grant: .gems(650), badge: "POPULAR"),
        StoreProduct(id: idPrefix + "gems.vault", kind: .consumable, icon: "🔷", symbol: "rhombus.fill", name: "Vault of Gems", detail: "1,450 gems · +20% bonus", priceLabel: "$14.99", grant: .gems(1450), badge: nil),
        StoreProduct(id: idPrefix + "gems.hoard", kind: .consumable, icon: "🌌", symbol: "sparkles", name: "Singularity Hoard", detail: "4,000 gems · +34% bonus", priceLabel: "$39.99", grant: .gems(4000), badge: nil),
    ]

    public static let founderBundle = StoreProduct(id: idPrefix + "bundle.founder", kind: .nonConsumable, icon: "🎁", symbol: "gift.fill", name: "Founder's Bundle",
                                                   detail: "1,200 gems + Gilded Comet skin + 3 boosts", priceLabel: "$5.99",
                                                   grant: .founderBundle, badge: "BEST STARTER")
    public static let removeAds = StoreProduct(id: idPrefix + "noads", kind: .nonConsumable, icon: "🚫", symbol: "nosign", name: "Remove Ads",
                                               detail: "Kills every interstitial permanently", priceLabel: "$2.99",
                                               grant: .removeAds, badge: nil)
    public static let piggyBank = StoreProduct(id: idPrefix + "piggybank", kind: .consumable, icon: "🐷", symbol: "banknote.fill", name: "Piggy Bank",
                                               detail: "Fills as you play · smash to collect", priceLabel: "$3.99",
                                               grant: .piggyBank, badge: nil)

    /// Everything StoreKit has to fetch at launch.
    public static let all: [StoreProduct] = [vip] + gemPacks + [founderBundle, removeAds, piggyBank]
    public static let allIDs: [String] = all.map(\.id)

    public static func product(id: String) -> StoreProduct? { all.first { $0.id == id } }

    /// Billing period appended to `priceLabel` while StoreKit's localised period is unavailable.
    public var fallbackPeriodSuffix: String { kind == .autoRenewable ? "/mo" : "" }
}

/// What the App Store currently says the player owns. Rebuilt from `Transaction.currentEntitlements`,
/// so a lapsed subscription or a refund takes the perk away again.
public struct StoreEntitlements: Sendable, Hashable {
    public var isVIP = false
    public var vipExpiresAt: Date?
    public var adsRemoved = false
    public var founderBundleOwned = false

    public init(isVIP: Bool = false, vipExpiresAt: Date? = nil, adsRemoved: Bool = false, founderBundleOwned: Bool = false) {
        self.isVIP = isVIP
        self.vipExpiresAt = vipExpiresAt
        self.adsRemoved = adsRemoved
        self.founderBundleOwned = founderBundleOwned
    }
}

public enum ShopSystem {
    public static let offerDurationSeconds = 600
    /// Energy slots the VIP subscription adds on top of the purchasable cap.
    public static let vipEnergyBonus = 2
    /// How many redeemed transaction identifiers are remembered to keep consumables from being granted twice.
    public static let redeemedHistoryLimit = 200

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

    /// Applies a purchase that the App Store has already verified and charged for.
    /// Returns a human-readable description of what was granted, or `nil` when the player already owns it.
    @discardableResult
    public static func apply(_ product: StoreProduct, to profile: inout PlayerProfile) -> String? {
        guard !isOwned(product, profile: profile) else { return nil }
        switch product.grant {
        case .gems(let n):
            profile.gems += n
            return "+\(n) gems"
        case .vip:
            setVIP(true, profile: &profile)
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

    /// Turns the VIP subscription perk on or off. The energy-cap bonus is applied and removed symmetrically
    /// so a lapsed subscription cannot leave a permanently inflated cap behind.
    public static func setVIP(_ active: Bool, profile: inout PlayerProfile, expires: Date? = nil) {
        defer { profile.vipExpiresAt = active ? expires?.timeIntervalSince1970 : nil }
        guard active != profile.isVIP else { return }
        profile.isVIP = active
        if active {
            profile.maxEnergy += vipEnergyBonus
            profile.energy += vipEnergyBonus
        } else {
            profile.maxEnergy = max(EnergySystem.baseCap + profile.energySlotsBought, profile.maxEnergy - vipEnergyBonus)
            profile.energy = min(profile.energy, profile.maxEnergy)
        }
    }

    /// Reconciles the profile with what the App Store reports. Only call this with entitlements that were
    /// actually read from StoreKit: an empty snapshot revokes everything.
    public static func sync(_ entitlements: StoreEntitlements, to profile: inout PlayerProfile) {
        setVIP(entitlements.isVIP, profile: &profile, expires: entitlements.vipExpiresAt)
        profile.adsRemoved = entitlements.adsRemoved
        // Refunded bundles become purchasable again; the gems and skin already handed out are not clawed back.
        profile.founderBundleOwned = entitlements.founderBundleOwned
    }

    /// `true` the first time a transaction identifier is seen. Guards consumables against a double grant when
    /// a transaction could not be finished on the previous launch.
    public static func redeem(transactionID: String, profile: inout PlayerProfile) -> Bool {
        guard !profile.redeemedTransactionIDs.contains(transactionID) else { return false }
        profile.redeemedTransactionIDs.append(transactionID)
        if profile.redeemedTransactionIDs.count > redeemedHistoryLimit {
            profile.redeemedTransactionIDs.removeFirst(profile.redeemedTransactionIDs.count - redeemedHistoryLimit)
        }
        return true
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
