import Foundation

/// Account level & XP.
public enum Progression {
    public static let levelUpGems = 10

    public static func xpNeeded(forLevel level: Int) -> Int { 100 + (level - 1) * 60 }

    /// Adds XP and returns every level reached, in order.
    @discardableResult
    public static func addXP(_ amount: Int, to profile: inout PlayerProfile) -> [Int] {
        profile.xp += amount
        var gained: [Int] = []
        while profile.xp >= xpNeeded(forLevel: profile.level) {
            profile.xp -= xpNeeded(forLevel: profile.level)
            profile.level += 1
            profile.gems += levelUpGems
            gained.append(profile.level)
        }
        return gained
    }

    public static func fraction(for profile: PlayerProfile) -> Double {
        Double(profile.xp) / Double(xpNeeded(forLevel: profile.level))
    }
}
