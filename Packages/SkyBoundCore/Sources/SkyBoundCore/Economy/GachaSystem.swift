import Foundation

/// A single crate pull result.
public struct PullResult: Sendable, Hashable, Identifiable {
    public let id: UUID
    public let skin: Skin
    public let isNew: Bool
    public let refund: Int

    public init(skin: Skin, isNew: Bool, refund: Int) {
        id = UUID()
        self.skin = skin
        self.isNew = isNew
        self.refund = refund
    }
}

/// Rocket crates: cosmetics only, with a hard pity at 40 pulls.
public enum GachaSystem {
    public static let pityLimit = 40
    public static let singlePrice = Price.gems(50)
    public static let tenPrice = Price.gems(450)

    public static func rollRarity(pity: Int, rng: inout some RandomSource) -> Rarity {
        if pity >= pityLimit - 1 { return .legendary }
        let r = rng.nextUnit()
        if r < 0.02 { return .legendary }
        if r < 0.10 { return .epic }
        if r < 0.35 { return .rare }
        return .common
    }

    public static func pullOne(_ profile: inout PlayerProfile, forced: Rarity? = nil, rng: inout some RandomSource) -> PullResult {
        let rarity = forced ?? rollRarity(pity: profile.pityCounter, rng: &rng)
        profile.pityCounter = rarity == .legendary ? 0 : profile.pityCounter + 1
        let pool = SkinCatalog.skins(of: rarity)
        let skin = pool[rng.nextIndex(count: pool.count)]
        let isNew = !profile.owns(skinID: skin.id)
        var refund = 0
        if isNew {
            profile.unlockSkin(skin.id, equip: false)
        } else {
            refund = rarity.duplicateRefund
            profile.coins += refund
        }
        return PullResult(skin: skin, isNew: isNew, refund: refund)
    }

    /// Performs a 1× or 10× pull. Returns `nil` when the player cannot afford it.
    public static func pull(count: Int, profile: inout PlayerProfile, rng: inout some RandomSource) -> [PullResult]? {
        let price = count >= 10 ? tenPrice : singlePrice
        guard profile.spend(price) else { return nil }
        var out: [PullResult] = []
        for _ in 0..<count { out.append(pullOne(&profile, rng: &rng)) }
        if count >= 10, !out.contains(where: { $0.skin.rarity != .common }) {
            out[out.count - 1] = pullOne(&profile, forced: .rare, rng: &rng)
        }
        profile.raiseAchievement(Achievement.collector, to: profile.ownedSkinIDs.count)
        return out
    }

    public static func pityFraction(_ profile: PlayerProfile) -> Double {
        Double(profile.pityCounter) / Double(pityLimit)
    }
}
