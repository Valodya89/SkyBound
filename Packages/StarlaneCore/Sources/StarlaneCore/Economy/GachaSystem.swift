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
        let pityDue = profile.pityCounter >= pityLimit - 1
        let rarity: Rarity = pityDue ? .legendary : (forced ?? rollRarity(pity: profile.pityCounter, rng: &rng))
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

    /// Price for a pull of `count`: the ten-pull bundle at 10+, otherwise singles.
    public static func price(count: Int) -> Price {
        count >= 10 ? tenPrice : .gems(singlePrice.amount * max(count, 1))
    }

    /// Performs a 1× or 10× pull. Returns `nil` when the player cannot afford it. A ten-pull guarantees at
    /// least one Rare or better: the decision is made *before* the last pull so no hidden extra pull happens.
    public static func pull(count: Int, profile: inout PlayerProfile, rng: inout some RandomSource) -> [PullResult]? {
        guard count > 0, profile.spend(price(count: count)) else { return nil }
        var out: [PullResult] = []
        for i in 0..<count {
            let isLast = i == count - 1
            let needsRare = count >= 10 && isLast && out.allSatisfy { $0.skin.rarity == .common }
            out.append(pullOne(&profile, forced: needsRare ? .rare : nil, rng: &rng))
        }
        return out
    }

    public static func pityFraction(_ profile: PlayerProfile) -> Double {
        Double(profile.pityCounter) / Double(pityLimit)
    }
}
