import Foundation

/// Regenerating energy that gates runs.
public enum EnergySystem {
    public static let maxCap = 12
    public static let refillPrice = Price.gems(15)

    public static func capUpgradePrice(for profile: PlayerProfile) -> Price {
        .gems(180 + profile.energySlotsBought * 160)
    }

    /// Advance the regeneration timer by whole seconds (also used to catch up after the app was closed).
    public static func tick(_ profile: inout PlayerProfile, seconds: Int) {
        guard seconds > 0 else { return }
        var remaining = seconds
        while remaining > 0, profile.energy < profile.maxEnergy {
            if profile.energyTimer <= remaining {
                remaining -= profile.energyTimer
                profile.energy += 1
                profile.energyTimer = profile.energyRegenSeconds
            } else {
                profile.energyTimer -= remaining
                remaining = 0
            }
        }
        if profile.energy >= profile.maxEnergy {
            profile.energyTimer = profile.energyRegenSeconds
        }
    }

    public static func canLaunch(_ mode: GameMode, profile: PlayerProfile) -> Bool {
        profile.energy >= mode.config.energyCost
    }

    @discardableResult
    public static func spend(for mode: GameMode, profile: inout PlayerProfile) -> Bool {
        let cost = mode.config.energyCost
        guard profile.energy >= cost else { return false }
        profile.energy -= cost
        return true
    }

    @discardableResult
    public static func refill(_ profile: inout PlayerProfile) -> Bool {
        guard profile.spend(refillPrice) else { return false }
        profile.energy = profile.maxEnergy
        return true
    }

    @discardableResult
    public static func raiseCap(_ profile: inout PlayerProfile) -> Bool {
        guard profile.maxEnergy < maxCap, profile.spend(capUpgradePrice(for: profile)) else { return false }
        profile.maxEnergy += 1
        profile.energySlotsBought += 1
        profile.energy += 1
        return true
    }
}
