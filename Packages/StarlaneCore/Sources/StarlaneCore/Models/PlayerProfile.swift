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

    /// Tolerant decoding: any key missing from an older save falls back to its default instead of failing the
    /// whole load, so adding a field never wipes existing players.
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = PlayerProfile()
        schemaVersion = try c.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? d.schemaVersion
        displayName = try c.decodeIfPresent(String.self, forKey: .displayName) ?? d.displayName
        coins = try c.decodeIfPresent(Int.self, forKey: .coins) ?? d.coins
        gems = try c.decodeIfPresent(Int.self, forKey: .gems) ?? d.gems
        energy = try c.decodeIfPresent(Int.self, forKey: .energy) ?? d.energy
        maxEnergy = try c.decodeIfPresent(Int.self, forKey: .maxEnergy) ?? d.maxEnergy
        energyTimer = try c.decodeIfPresent(Int.self, forKey: .energyTimer) ?? d.energyTimer
        energyRegenSeconds = try c.decodeIfPresent(Int.self, forKey: .energyRegenSeconds) ?? d.energyRegenSeconds
        energySlotsBought = try c.decodeIfPresent(Int.self, forKey: .energySlotsBought) ?? d.energySlotsBought
        xp = try c.decodeIfPresent(Int.self, forKey: .xp) ?? d.xp
        level = try c.decodeIfPresent(Int.self, forKey: .level) ?? d.level
        bestByMode = try c.decodeIfPresent([GameMode: Int].self, forKey: .bestByMode) ?? d.bestByMode
        bestOverall = try c.decodeIfPresent(Int.self, forKey: .bestOverall) ?? d.bestOverall
        totalRuns = try c.decodeIfPresent(Int.self, forKey: .totalRuns) ?? d.totalRuns
        totalCoins = try c.decodeIfPresent(Int.self, forKey: .totalCoins) ?? d.totalCoins
        totalDistance = try c.decodeIfPresent(Int.self, forKey: .totalDistance) ?? d.totalDistance
        totalNearMisses = try c.decodeIfPresent(Int.self, forKey: .totalNearMisses) ?? d.totalNearMisses
        bossKills = try c.decodeIfPresent(Int.self, forKey: .bossKills) ?? d.bossKills
        selectedMode = try c.decodeIfPresent(GameMode.self, forKey: .selectedMode) ?? d.selectedMode
        inventory = try c.decodeIfPresent([BoostKind: Int].self, forKey: .inventory) ?? d.inventory
        upgrades = try c.decodeIfPresent([UpgradeKind: Int].self, forKey: .upgrades) ?? d.upgrades
        ownedSkinIDs = try c.decodeIfPresent([String].self, forKey: .ownedSkinIDs) ?? d.ownedSkinIDs
        equippedSkinID = try c.decodeIfPresent(String.self, forKey: .equippedSkinID) ?? d.equippedSkinID
        ghosts = try c.decodeIfPresent([GameMode: [GhostSample]].self, forKey: .ghosts) ?? d.ghosts
        pityCounter = try c.decodeIfPresent(Int.self, forKey: .pityCounter) ?? d.pityCounter
        passXP = try c.decodeIfPresent(Int.self, forKey: .passXP) ?? d.passXP
        passPremium = try c.decodeIfPresent(Bool.self, forKey: .passPremium) ?? d.passPremium
        claimedFreeTiers = try c.decodeIfPresent(Set<Int>.self, forKey: .claimedFreeTiers) ?? d.claimedFreeTiers
        claimedPremiumTiers = try c.decodeIfPresent(Set<Int>.self, forKey: .claimedPremiumTiers) ?? d.claimedPremiumTiers
        isVIP = try c.decodeIfPresent(Bool.self, forKey: .isVIP) ?? d.isVIP
        adsRemoved = try c.decodeIfPresent(Bool.self, forKey: .adsRemoved) ?? d.adsRemoved
        founderBundleOwned = try c.decodeIfPresent(Bool.self, forKey: .founderBundleOwned) ?? d.founderBundleOwned
        interstitialCounter = try c.decodeIfPresent(Int.self, forKey: .interstitialCounter) ?? d.interstitialCounter
        loginStreakDay = try c.decodeIfPresent(Int.self, forKey: .loginStreakDay) ?? d.loginStreakDay
        loginClaimedToday = try c.decodeIfPresent(Bool.self, forKey: .loginClaimedToday) ?? d.loginClaimedToday
        wheelSpunToday = try c.decodeIfPresent(Bool.self, forKey: .wheelSpunToday) ?? d.wheelSpunToday
        freeGemAdsWatchedToday = try c.decodeIfPresent(Int.self, forKey: .freeGemAdsWatchedToday) ?? d.freeGemAdsWatchedToday
        dailyChallengeSeed = try c.decodeIfPresent(Int.self, forKey: .dailyChallengeSeed) ?? d.dailyChallengeSeed
        dailyChallengeDone = try c.decodeIfPresent(Bool.self, forKey: .dailyChallengeDone) ?? d.dailyChallengeDone
        dailyChallengeScore = try c.decodeIfPresent(Int.self, forKey: .dailyChallengeScore) ?? d.dailyChallengeScore
        lastActiveDay = try c.decodeIfPresent(Int.self, forKey: .lastActiveDay) ?? d.lastActiveDay
        lastSavedAt = try c.decodeIfPresent(Double.self, forKey: .lastSavedAt) ?? d.lastSavedAt
        duels = try c.decodeIfPresent([Duel].self, forKey: .duels) ?? d.duels
        missions = try c.decodeIfPresent([Mission].self, forKey: .missions) ?? d.missions
        achievements = try c.decodeIfPresent([Achievement].self, forKey: .achievements) ?? d.achievements
        settings = try c.decodeIfPresent(PlayerSettings.self, forKey: .settings) ?? d.settings
        schemaVersion = PlayerProfile.schemaVersion
    }

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
        raiseAchievement(Achievement.collector, to: ownedSkinIDs.count)
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
