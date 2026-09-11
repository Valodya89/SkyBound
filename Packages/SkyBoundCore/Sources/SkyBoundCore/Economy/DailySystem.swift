import Foundation

/// Everything that resets at local midnight, plus the login calendar and fortune wheel.
public enum DailySystem {
    public static let freeGemAdsPerDay = 3
    public static let freeGemAdReward = 5

    /// Applies the day rollover if the calendar day changed since the profile was last active.
    /// Returns `true` when a reset happened.
    @discardableResult
    public static func rollover(_ profile: inout PlayerProfile, now: Date, calendar: Calendar = .current) -> Bool {
        let today = DaySeed.value(for: now, calendar: calendar)
        profile.dailyChallengeSeed = today
        guard profile.lastActiveDay != today else { return false }

        // Missing a day breaks the login streak.
        if profile.lastActiveDay != 0, !isConsecutive(previous: profile.lastActiveDay, today: today, calendar: calendar) {
            profile.loginStreakDay = 1
        }
        profile.lastActiveDay = today
        profile.loginClaimedToday = false
        profile.wheelSpunToday = false
        profile.freeGemAdsWatchedToday = 0
        profile.dailyChallengeDone = false
        profile.dailyChallengeScore = 0
        for i in profile.missions.indices { profile.missions[i].reset() }
        return true
    }

    static func isConsecutive(previous: Int, today: Int, calendar: Calendar) -> Bool {
        guard let prev = date(fromSeed: previous, calendar: calendar),
              let cur = date(fromSeed: today, calendar: calendar) else { return false }
        let days = calendar.dateComponents([.day], from: prev, to: cur).day ?? 99
        return days <= 1
    }

    static func date(fromSeed seed: Int, calendar: Calendar) -> Date? {
        var c = DateComponents()
        c.year = seed / 10000
        c.month = (seed / 100) % 100
        c.day = seed % 100
        return calendar.date(from: c)
    }

    // MARK: Login calendar

    public static func todayReward(_ profile: PlayerProfile) -> DailyLoginReward {
        let idx = min(max(profile.loginStreakDay - 1, 0), DailyLoginReward.calendar.count - 1)
        return DailyLoginReward.calendar[idx]
    }

    @discardableResult
    public static func claimLogin(_ profile: inout PlayerProfile) -> DailyLoginReward? {
        guard !profile.loginClaimedToday else { return nil }
        let r = todayReward(profile)
        profile.coins += r.coins
        profile.gems += r.gems
        if let skin = r.skinID { profile.unlockSkin(skin) }
        profile.loginClaimedToday = true
        profile.loginStreakDay = profile.loginStreakDay >= DailyLoginReward.calendar.count ? 1 : profile.loginStreakDay + 1
        return r
    }

    // MARK: Fortune wheel

    public static func spinWheel(rng: inout some RandomSource) -> WheelPrize {
        WheelPrize.wheel[rng.nextIndex(count: WheelPrize.wheel.count)]
    }

    public static func apply(prize: WheelPrize, to profile: inout PlayerProfile) {
        switch prize.kind {
        case .coins(let n): profile.coins += n
        case .gems(let n): profile.gems += n
        case .boost(let b): profile.addBoost(b)
        }
    }

    // MARK: Free gems

    public static func canWatchFreeGemAd(_ profile: PlayerProfile) -> Bool {
        profile.freeGemAdsWatchedToday < freeGemAdsPerDay
    }

    @discardableResult
    public static func grantFreeGems(_ profile: inout PlayerProfile) -> Bool {
        guard canWatchFreeGemAd(profile) else { return false }
        profile.gems += freeGemAdReward
        profile.freeGemAdsWatchedToday += 1
        return true
    }

    // MARK: Daily challenge board

    public struct BoardRow: Sendable, Hashable, Identifiable {
        public let id: String
        public let name: String
        public let score: Int
        public let isPlayer: Bool

        public init(id: String, name: String, score: Int, isPlayer: Bool) {
            self.id = id
            self.name = name
            self.score = score
            self.isPlayer = isPlayer
        }
    }

    /// Simulated rivals for today's seed, plus the player.
    public static func challengeBoard(_ profile: PlayerProfile) -> [BoardRow] {
        var rng = Mulberry32(seed: UInt32(truncatingIfNeeded: profile.dailyChallengeSeed))
        var rows = RivalNames.all.prefix(9).map { name in
            BoardRow(id: name, name: name, score: Int(1200 + rng.nextUnit() * 4200), isPlayer: false)
        }
        rows.append(BoardRow(id: "you", name: "YOU", score: profile.dailyChallengeScore, isPlayer: true))
        return rows.sorted { $0.score > $1.score }
    }
}
