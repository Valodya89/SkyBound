import Foundation

/// Player preferences. Persisted alongside progress.
public struct PlayerSettings: Sendable, Hashable, Codable {
    public var soundEnabled = true
    public var musicEnabled = true
    public var screenShakeEnabled = true
    public var ghostEnabled = true
    public var hapticsEnabled = true

    public init() {}
}

/// One sample of a recorded run used for the best-run ghost.
public struct GhostSample: Sendable, Hashable, Codable {
    public var distance: Int
    public var lane: Int

    public init(distance: Int, lane: Int) {
        self.distance = distance
        self.lane = lane
    }
}

/// Everything about the player that survives app launches.
///
/// This is a plain value type so it can be snapshotted, diffed in tests and serialised with `Codable`.
public struct PlayerProfile: Sendable, Hashable, Codable {
    public static let schemaVersion = 1

    public var schemaVersion = PlayerProfile.schemaVersion
    public var displayName = "Pilot"

    // Wallet & energy
    public var coins = 150
    public var gems = 20
    public var energy = 5
    public var maxEnergy = 5
    /// Seconds until the next energy point regenerates.
    public var energyTimer = 45
    public var energyRegenSeconds = 45
    public var energySlotsBought = 0

    // Progression
    public var xp = 0
    public var level = 1
    public var bestByMode: [GameMode: Int] = [:]
    public var bestOverall = 0
    public var totalRuns = 0
    public var totalCoins = 0
    public var totalDistance = 0
    public var totalNearMisses = 0
    public var bossKills = 0

    // Loadout
    public var selectedMode: GameMode = .classic
    public var inventory: [BoostKind: Int] = [.magnet: 1, .slowmo: 1, .shield: 1]
    public var upgrades: [UpgradeKind: Int] = [:]
    public var ownedSkinIDs: [String] = [SkinCatalog.defaultSkinID]
    public var equippedSkinID = SkinCatalog.defaultSkinID
    public var ghosts: [GameMode: [GhostSample]] = [:]

    // Monetisation state (all simulated)
    public var pityCounter = 0
    public var passXP = 0
    public var passPremium = false
    public var claimedFreeTiers: Set<Int> = []
    public var claimedPremiumTiers: Set<Int> = []
    public var isVIP = false
    public var adsRemoved = false
    public var founderBundleOwned = false
    public var interstitialCounter = 0

    // Daily state
    public var loginStreakDay = 1
    public var loginClaimedToday = false
    public var wheelSpunToday = false
    public var freeGemAdsWatchedToday = 0
    public var dailyChallengeSeed = 0
    public var dailyChallengeDone = false
    public var dailyChallengeScore = 0
    /// YYYYMMDD of the last day the profile was opened.
    public var lastActiveDay = 0
    /// Unix time of the last save, used to regenerate energy that accrued while the app was closed.
    public var lastSavedAt: Double = 0

    public var duels: [Duel] = []
    public var missions: [Mission] = Mission.dailySet
    public var achievements: [Achievement] = Achievement.defaults
    public var settings = PlayerSettings()

    public init() {}

    // MARK: - Derived helpers

    public func inventoryCount(_ boost: BoostKind) -> Int { inventory[boost] ?? 0 }
    public func upgradeLevel(_ kind: UpgradeKind) -> Int { upgrades[kind] ?? 0 }
    public func owns(skinID: String) -> Bool { ownedSkinIDs.contains(skinID) }
    public var equippedSkin: Skin { SkinCatalog.skin(equippedSkinID) }
    public func best(for mode: GameMode) -> Int { bestByMode[mode] ?? 0 }
    public var hasOpenDuel: Bool { duels.contains { $0.status == .open } }
    public var hasClaimableMission: Bool { missions.contains { $0.canClaim } }
    public var isEnergyFull: Bool { energy >= maxEnergy }

    public func balance(_ currency: Currency) -> Int {
        switch currency {
        case .coins: coins
        case .gems: gems
        }
    }

    public func canAfford(_ price: Price) -> Bool { balance(price.currency) >= price.amount }

    public mutating func credit(_ amount: Int, _ currency: Currency) {
        switch currency {
        case .coins: coins += amount
        case .gems: gems += amount
        }
    }

    /// Returns `false` (and leaves the profile untouched) when the player cannot afford it.
    @discardableResult
    public mutating func spend(_ price: Price) -> Bool {
        guard canAfford(price) else { return false }
        credit(-price.amount, price.currency)
        return true
    }

    public mutating func addBoost(_ kind: BoostKind, count: Int = 1) {
        inventory[kind, default: 0] += count
    }

    @discardableResult
    public mutating func consumeBoost(_ kind: BoostKind) -> Bool {
        guard inventoryCount(kind) > 0 else { return false }
        inventory[kind, default: 0] -= 1
        return true
    }

    public mutating func unlockSkin(_ id: String, equip: Bool = true) {
        if !ownedSkinIDs.contains(id) { ownedSkinIDs.append(id) }
        if equip { equippedSkinID = id }
    }

    public mutating func bumpAchievement(_ id: String, by n: Int) {
        guard let i = achievements.firstIndex(where: { $0.id == id }) else { return }
        achievements[i].bump(by: n)
    }

    public mutating func raiseAchievement(_ id: String, to n: Int) {
        guard let i = achievements.firstIndex(where: { $0.id == id }) else { return }
        achievements[i].raise(to: n)
    }

    public mutating func advanceMission(_ id: String, by n: Int) {
        guard let i = missions.firstIndex(where: { $0.id == id }) else { return }
        missions[i].advance(by: n)
    }
}
