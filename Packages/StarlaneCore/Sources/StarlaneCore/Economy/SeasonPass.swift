import Foundation

public struct TierReward: Sendable, Hashable {
    public enum Kind: Sendable, Hashable {
        case coins(Int)
        case gems(Int)
        case crate
    }

    public let kind: Kind

    public var icon: String {
        switch kind {
        case .coins: "🪙"
        case .gems: "💎"
        case .crate: "🎁"
        }
    }

    public var label: String {
        switch kind {
        case .coins(let n): "\(n)"
        case .gems(let n): "\(n)"
        case .crate: "Crate"
        }
    }
}

/// Season 1 · Skyward. Twenty tiers, 100 SP each.
public enum SeasonPass {
    public static let tierCount = 20
    public static let xpPerTier = 100
    public static let premiumPrice = Price.gems(250)
    public static let missionClaimSP = 50
    public static let seasonName = "Season 1 · Skyward"

    public static func tier(for profile: PlayerProfile) -> Int {
        min(tierCount, profile.passXP / xpPerTier)
    }

    public static func tierProgress(for profile: PlayerProfile) -> Int {
        tier(for: profile) >= tierCount ? xpPerTier : profile.passXP % xpPerTier
    }

    public static func reward(tier: Int, premium: Bool) -> TierReward {
        if premium {
            if tier % 5 == 0 { return TierReward(kind: .gems(75)) }
            if tier % 3 == 0 { return TierReward(kind: .crate) }
            return TierReward(kind: .coins(400))
        }
        if tier % 5 == 0 { return TierReward(kind: .gems(20)) }
        return TierReward(kind: .coins(150))
    }

    public static func isClaimable(tier: Int, premium: Bool, profile: PlayerProfile) -> Bool {
        guard tier >= 1, tier <= self.tier(for: profile) else { return false }
        if premium {
            return profile.passPremium && !profile.claimedPremiumTiers.contains(tier)
        }
        return !profile.claimedFreeTiers.contains(tier)
    }

    public static func claimableCount(_ profile: PlayerProfile) -> Int {
        var n = 0
        for t in 1...tierCount {
            if isClaimable(tier: t, premium: false, profile: profile) { n += 1 }
            if isClaimable(tier: t, premium: true, profile: profile) { n += 1 }
        }
        return n
    }

    /// Claims a tier. Crates are converted into a free single pull credit (`freeCrates`).
    @discardableResult
    public static func claim(tier: Int, premium: Bool, profile: inout PlayerProfile) -> TierReward? {
        guard isClaimable(tier: tier, premium: premium, profile: profile) else { return nil }
        let r = reward(tier: tier, premium: premium)
        switch r.kind {
        case .coins(let n): profile.coins += n
        case .gems(let n): profile.gems += n
        case .crate: profile.gems += GachaSystem.singlePrice.amount
        }
        if premium { profile.claimedPremiumTiers.insert(tier) } else { profile.claimedFreeTiers.insert(tier) }
        return r
    }

    @discardableResult
    public static func unlockPremium(_ profile: inout PlayerProfile) -> Bool {
        guard !profile.passPremium, profile.spend(premiumPrice) else { return false }
        profile.passPremium = true
        return true
    }

    /// Claims a completed daily mission.
    @discardableResult
    public static func claimMission(id: String, profile: inout PlayerProfile) -> MissionReward? {
        guard let i = profile.missions.firstIndex(where: { $0.id == id }), profile.missions[i].canClaim else { return nil }
        profile.missions[i].isClaimed = true
        let r = profile.missions[i].reward
        profile.coins += r.coins
        profile.gems += r.gems
        profile.passXP += missionClaimSP
        return r
    }
}
