import Foundation
import Testing
@testable import StarlaneCore

@Suite("Progression")
struct ProgressionTests {
    @Test func levelUpGrantsGems() {
        var p = PlayerProfile()
        let gems = p.gems
        let gained = Progression.addXP(250, to: &p)
        #expect(gained == [2])
        #expect(p.level == 2)
        #expect(p.xp == 150)
        #expect(p.gems == gems + Progression.levelUpGems)
    }

    @Test func multiLevel() {
        var p = PlayerProfile()
        let gained = Progression.addXP(100 + 160 + 220 + 5, to: &p)
        #expect(gained == [2, 3, 4])
        #expect(p.xp == 5)
    }
}

@Suite("Energy")
struct EnergyTests {
    @Test func regeneratesOverTime() {
        var p = PlayerProfile()
        p.energy = 2
        p.energyTimer = 45
        EnergySystem.tick(&p, seconds: 100)
        #expect(p.energy == 4)
        #expect(p.energyTimer == 35)
    }

    @Test func capsAtMax() {
        var p = PlayerProfile()
        p.energy = 4
        EnergySystem.tick(&p, seconds: 10_000)
        #expect(p.energy == p.maxEnergy)
        #expect(p.energyTimer == p.energyRegenSeconds)
    }

    @Test func spendAndRefill() {
        var p = PlayerProfile()
        #expect(EnergySystem.spend(for: .gauntlet, profile: &p))
        #expect(p.energy == 3)
        p.energy = 0
        #expect(!EnergySystem.spend(for: .classic, profile: &p))
        p.gems = 15
        #expect(EnergySystem.refill(&p))
        #expect(p.energy == p.maxEnergy)
        #expect(p.gems == 0)
    }

    @Test func raiseCapStopsAtLimit() {
        var p = PlayerProfile()
        p.gems = 100_000
        while EnergySystem.raiseCap(&p) {}
        #expect(p.maxEnergy == EnergySystem.maxCap)
    }
}

@Suite("Gacha")
struct GachaTests {
    @Test func pityGuaranteesLegendary() {
        var p = PlayerProfile()
        p.pityCounter = 39
        var rng = Mulberry32(seed: 99)
        let r = GachaSystem.pullOne(&p, rng: &rng)
        #expect(r.skin.rarity == .legendary)
        #expect(p.pityCounter == 0)
    }

    @Test func tenPullGuaranteesRarePlus() {
        var p = PlayerProfile()
        p.gems = 450
        var rng = Mulberry32(seed: 4)
        let out = GachaSystem.pull(count: 10, profile: &p, rng: &rng)
        #expect(out?.count == 10)
        #expect(out?.contains { $0.skin.rarity >= .rare } == true)
        #expect(p.gems == 0)
    }

    @Test func cannotAfford() {
        var p = PlayerProfile()
        p.gems = 10
        var rng = Mulberry32(seed: 4)
        #expect(GachaSystem.pull(count: 1, profile: &p, rng: &rng) == nil)
        #expect(p.gems == 10)
    }

    @Test func duplicateRefundsCoins() {
        var p = PlayerProfile()
        p.ownedSkinIDs = SkinCatalog.all.map(\.id)
        let coins = p.coins
        var rng = Mulberry32(seed: 2)
        let r = GachaSystem.pullOne(&p, forced: .common, rng: &rng)
        #expect(!r.isNew)
        #expect(p.coins == coins + Rarity.common.duplicateRefund)
    }
}

@Suite("Season pass")
struct SeasonPassTests {
    @Test func tiersAndClaims() {
        var p = PlayerProfile()
        p.passXP = 520
        #expect(SeasonPass.tier(for: p) == 5)
        #expect(SeasonPass.tierProgress(for: p) == 20)
        #expect(SeasonPass.isClaimable(tier: 5, premium: false, profile: p))
        #expect(!SeasonPass.isClaimable(tier: 6, premium: false, profile: p))
        #expect(!SeasonPass.isClaimable(tier: 5, premium: true, profile: p))
        let gems = p.gems
        #expect(SeasonPass.claim(tier: 5, premium: false, profile: &p)?.kind == .gems(20))
        #expect(p.gems == gems + 20)
        #expect(SeasonPass.claim(tier: 5, premium: false, profile: &p) == nil)
    }

    @Test func premiumUnlock() {
        var p = PlayerProfile()
        p.gems = 250
        #expect(SeasonPass.unlockPremium(&p))
        #expect(p.passPremium)
        #expect(!SeasonPass.unlockPremium(&p))
    }

    @Test func missionClaim() {
        var p = PlayerProfile()
        p.advanceMission(Mission.coinsID, by: 60)
        #expect(p.hasClaimableMission)
        let r = SeasonPass.claimMission(id: Mission.coinsID, profile: &p)
        #expect(r?.gems == 15)
        #expect(p.passXP == SeasonPass.missionClaimSP)
        #expect(SeasonPass.claimMission(id: Mission.coinsID, profile: &p) == nil)
    }
}

@Suite("Duels")
struct DuelTests {
    @Test func winPaysGems() {
        var p = PlayerProfile()
        var rng = Mulberry32(seed: 8)
        let d = DuelSystem.challenge(rival: "NovaKid", profile: &p, rng: &rng)
        #expect(d != nil)
        #expect(DuelSystem.challenge(rival: "NovaKid", profile: &p, rng: &rng) == nil)
        let gems = p.gems
        let won = DuelSystem.resolve(score: (d?.rivalScore ?? 0) + 1, profile: &p)
        #expect(won.count == 1)
        #expect(p.gems == gems + Duel.winReward)
        #expect(p.duels[0].status == .won)
    }

    @Test func threeLossesClose() {
        var p = PlayerProfile()
        var rng = Mulberry32(seed: 8)
        _ = DuelSystem.challenge(rival: "NovaKid", profile: &p, rng: &rng)
        for _ in 0..<3 { _ = DuelSystem.resolve(score: 1, profile: &p) }
        #expect(p.duels[0].status == .lost)
        #expect(p.duels[0].triesLeft == 0)
    }
}

@Suite("Daily")
struct DailyTests {
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: 12))!
    }

    @Test func rolloverResetsDailies() {
        var p = PlayerProfile()
        p.loginClaimedToday = true
        p.wheelSpunToday = true
        p.dailyChallengeDone = true
        p.freeGemAdsWatchedToday = 3
        p.advanceMission(Mission.coinsID, by: 30)
        p.lastActiveDay = 20260906
        #expect(DailySystem.rollover(&p, now: date(2026, 9, 7), calendar: calendar))
        #expect(!p.loginClaimedToday)
        #expect(!p.wheelSpunToday)
        #expect(!p.dailyChallengeDone)
        #expect(p.freeGemAdsWatchedToday == 0)
        #expect(p.missions[0].progress == 0)
        #expect(p.dailyChallengeSeed == 20260907)
        #expect(!DailySystem.rollover(&p, now: date(2026, 9, 7), calendar: calendar))
    }

    @Test func missingADayBreaksStreak() {
        var p = PlayerProfile()
        p.loginStreakDay = 5
        p.lastActiveDay = 20260901
        _ = DailySystem.rollover(&p, now: date(2026, 9, 7), calendar: calendar)
        #expect(p.loginStreakDay == 1)
    }

    @Test func consecutiveDayKeepsStreak() {
        var p = PlayerProfile()
        p.loginStreakDay = 5
        p.lastActiveDay = 20260906
        _ = DailySystem.rollover(&p, now: date(2026, 9, 7), calendar: calendar)
        #expect(p.loginStreakDay == 5)
    }

    @Test func loginCalendarWraps() {
        var p = PlayerProfile()
        p.loginStreakDay = 7
        let r = DailySystem.claimLogin(&p)
        #expect(r?.skinID == "vapor")
        #expect(p.owns(skinID: "vapor"))
        #expect(p.loginStreakDay == 1)
        #expect(DailySystem.claimLogin(&p) == nil)
    }

    @Test func challengeBoardIsSeeded() {
        var p = PlayerProfile()
        p.dailyChallengeSeed = 20260907
        let a = DailySystem.challengeBoard(p)
        let b = DailySystem.challengeBoard(p)
        #expect(a == b)
        #expect(a.contains { $0.isPlayer })
    }
}

@Suite("Shop")
struct ShopTests {
    @Test func founderBundle() {
        var p = PlayerProfile()
        #expect(ShopSystem.apply(.founderBundle, to: &p) != nil)
        #expect(p.gems == 1220)
        #expect(p.equippedSkinID == "gilded")
        #expect(p.inventoryCount(.doubleCoin) == 1)
        #expect(ShopSystem.apply(.founderBundle, to: &p) == nil)
    }

    @Test func vipRaisesEnergyCap() {
        var p = PlayerProfile()
        _ = ShopSystem.apply(.vip, to: &p)
        #expect(p.isVIP)
        #expect(p.maxEnergy == 7)
    }

    @Test("A lapsed VIP subscription gives the energy cap back")
    func vipLapseReturnsCap() {
        var p = PlayerProfile()
        #expect(EnergySystem.raiseCap(&p) == false)  // no gems yet
        p.gems = 400
        #expect(EnergySystem.raiseCap(&p))
        let boughtCap = p.maxEnergy
        ShopSystem.setVIP(true, profile: &p, expires: Date(timeIntervalSince1970: 1_800_000_000))
        #expect(p.maxEnergy == boughtCap + ShopSystem.vipEnergyBonus)
        #expect(p.vipExpiresAt == 1_800_000_000)
        ShopSystem.setVIP(false, profile: &p)
        #expect(!p.isVIP)
        #expect(p.maxEnergy == boughtCap)
        #expect(p.energy <= p.maxEnergy)
        #expect(p.vipExpiresAt == nil)
    }

    @Test("Turning VIP on twice does not stack the energy bonus")
    func vipIsIdempotent() {
        var p = PlayerProfile()
        ShopSystem.setVIP(true, profile: &p)
        ShopSystem.setVIP(true, profile: &p)
        #expect(p.maxEnergy == 5 + ShopSystem.vipEnergyBonus)
    }

    @Test("Syncing App Store entitlements revokes what the player no longer owns")
    func entitlementSync() {
        var p = PlayerProfile()
        _ = ShopSystem.apply(.vip, to: &p)
        _ = ShopSystem.apply(.removeAds, to: &p)
        _ = ShopSystem.apply(.founderBundle, to: &p)
        let gems = p.gems

        ShopSystem.sync(StoreEntitlements(isVIP: true, adsRemoved: true, founderBundleOwned: true), to: &p)
        #expect(p.isVIP && p.adsRemoved && p.founderBundleOwned)

        // Subscription lapsed and the bundle was refunded; the gems already spent are not clawed back.
        ShopSystem.sync(StoreEntitlements(), to: &p)
        #expect(!p.isVIP)
        #expect(!p.adsRemoved)
        #expect(!p.founderBundleOwned)
        #expect(p.maxEnergy == 5)
        #expect(p.gems == gems)
    }

    @Test("A transaction identifier is only ever granted once")
    func redeemIsIdempotent() {
        var p = PlayerProfile()
        #expect(ShopSystem.redeem(transactionID: "tx-1", profile: &p))
        #expect(!ShopSystem.redeem(transactionID: "tx-1", profile: &p))
        #expect(ShopSystem.redeem(transactionID: "tx-2", profile: &p))
        // The history stays bounded and keeps the newest identifiers.
        for i in 0..<(ShopSystem.redeemedHistoryLimit + 50) {
            _ = ShopSystem.redeem(transactionID: "bulk-\(i)", profile: &p)
        }
        #expect(p.redeemedTransactionIDs.count == ShopSystem.redeemedHistoryLimit)
        #expect(p.redeemedTransactionIDs.last == "bulk-\(ShopSystem.redeemedHistoryLimit + 49)")
        #expect(!p.redeemedTransactionIDs.contains("tx-1"))
    }

    @Test("Every product identifier is unique, prefixed and resolvable")
    func catalogIdentifiers() {
        let ids = StoreProduct.allIDs
        #expect(ids.count == 8)
        #expect(Set(ids).count == ids.count)
        #expect(ids.allSatisfy { $0.hasPrefix(StoreProduct.idPrefix) })
        #expect(ids.allSatisfy { StoreProduct.product(id: $0) != nil })
        #expect(StoreProduct.product(id: "nope") == nil)
        #expect(StoreProduct.vip.kind == .autoRenewable)
        #expect(StoreProduct.removeAds.kind == .nonConsumable)
        #expect(StoreProduct.gemPacks.allSatisfy { $0.kind == .consumable })
    }

    @Test func upgradesCostMore() {
        var p = PlayerProfile()
        p.coins = 10_000
        #expect(UpgradeSystem.price(.grazer, profile: p) == 460)
        #expect(UpgradeSystem.buy(.grazer, profile: &p))
        #expect(UpgradeSystem.price(.grazer, profile: p) == 920)
        #expect(p.coins == 10_000 - 460)
    }
}

@Suite("RunResolver")
struct RunResolverTests {
    @Test func banksEverything() {
        var p = PlayerProfile()
        let ghost = (0..<10).map { GhostSample(distance: $0 * 50, lane: 1) }
        let run = RunSummary(mode: .classic, score: 2400, distance: 1600, coins: 80, gems: 2, bestCombo: 6,
                             nearMisses: 12, bossesDefeated: 1, zonesReached: 2, endedByTimer: false, ghost: ghost)
        let outcome = RunResolver.bank(run, into: &p)
        #expect(outcome.isPersonalBest)
        #expect(outcome.isNewModeBest)
        #expect(p.coins == 230)
        #expect(p.gems >= 22)
        #expect(p.bestOverall == 2400)
        #expect(p.ghosts[.classic]?.count == 10)
        #expect(p.missions.first { $0.id == Mission.coinsID }?.isDone == true)
        #expect(p.missions.first { $0.id == Mission.distanceID }?.isDone == true)
        #expect(p.achievements.first { $0.id == Achievement.comboArtist }?.isDone == true)
        #expect(p.totalRuns == 1)
        #expect(!outcome.levelsGained.isEmpty)
    }

    @Test("A revived run is only credited for what happened after the revive")
    func continuationBanksDelta() {
        var p = PlayerProfile()
        var rng = Mulberry32(seed: 5)
        _ = DuelSystem.challenge(rival: "NovaKid", profile: &p, rng: &rng)
        let first = RunSummary(mode: .classic, score: 1000, distance: 800, coins: 40, gems: 1, bestCombo: 3,
                               nearMisses: 4, bossesDefeated: 0, zonesReached: 1, endedByTimer: false, ghost: [])
        let o1 = RunResolver.bank(first, into: &p)
        let coinsAfterFirst = p.coins, triesAfterFirst = p.duels[0].triesLeft
        let second = RunSummary(mode: .classic, score: 1500, distance: 1300, coins: 70, gems: 1, bestCombo: 3,
                                nearMisses: 6, bossesDefeated: 1, zonesReached: 2, endedByTimer: false, ghost: [])
        let o2 = RunResolver.bank(second, previouslyBanked: first, into: &p)
        #expect(p.coins == coinsAfterFirst + 30)
        #expect(p.totalRuns == 1)
        #expect(p.totalDistance == 1300)
        #expect(p.totalNearMisses == 6)
        #expect(p.bossKills == 1)
        #expect(p.bestOverall == 1500)
        #expect(o2.xpEarned == 500 / 8 + 30)
        #expect(o1.xpEarned == 1000 / 8 + 40)
        #expect(p.duels[0].triesLeft == triesAfterFirst)
    }

    @Test func dailyMarksDone() {
        var p = PlayerProfile()
        let run = RunSummary(mode: .daily, score: 300, distance: 200, coins: 5, gems: 0, bestCombo: 1,
                             nearMisses: 0, bossesDefeated: 0, zonesReached: 1, endedByTimer: false, ghost: [])
        _ = RunResolver.bank(run, into: &p)
        #expect(p.dailyChallengeDone)
        #expect(p.dailyChallengeScore == 300)
    }
}

@Suite("Persistence")
struct PersistenceTests {
    @Test func fileRoundTrip() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("starlane-test-\(UUID().uuidString).json")
        let store = FileProfileStore(fileURL: url)
        defer { try? store.wipe() }
        var p = PlayerProfile()
        p.coins = 999
        p.bestByMode[.sprint] = 1234
        p.upgrades[.grazer] = 2
        p.duels = [Duel(rivalName: "NovaKid", hue: 57, rivalScore: 800)]
        try store.save(p)
        let loaded = try store.load()
        #expect(loaded == p)
        try store.wipe()
        #expect(try store.load() == nil)
    }
}

@Suite("Audit regressions")
struct AuditRegressionTests {
    @Test("A save missing newer keys still decodes")
    func tolerantDecoding() throws {
        let json = #"{"coins": 777, "gems": 3, "level": 4, "displayName": "Old"}"#.data(using: .utf8)!
        let p = try JSONDecoder().decode(PlayerProfile.self, from: json)
        #expect(p.coins == 777)
        #expect(p.level == 4)
        #expect(p.energy == 5)
        #expect(p.missions.count == Mission.dailySet.count)
        #expect(p.schemaVersion == PlayerProfile.schemaVersion)
    }

    @Test("A corrupt profile file is moved aside, not overwritten")
    func corruptFileKept() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("starlane-corrupt-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("profile.json")
        try Data("not json".utf8).write(to: url)
        let store = FileProfileStore(fileURL: url)
        #expect(throws: (any Error).self) { try store.load() }
        let kept = try FileManager.default.contentsOfDirectory(atPath: dir.path)
        #expect(kept.contains { $0.hasPrefix("profile.corrupt-") })
        #expect(!FileManager.default.fileExists(atPath: url.path))
    }

    @Test("Ten-pull guarantee costs exactly ten pity steps and never hides an item")
    func tenPullGuarantee() {
        var p = PlayerProfile()
        p.gems = 20_000
        var rng = Mulberry32(seed: 11)
        for _ in 0..<30 {
            let before = p.ownedSkinIDs.count
            let refundsBefore = p.coins
            let pity = p.pityCounter
            let out = GachaSystem.pull(count: 10, profile: &p, rng: &rng)!
            #expect(out.count == 10)
            #expect(out.contains { $0.skin.rarity != .common })
            let newOnes = out.filter(\.isNew).count
            #expect(p.ownedSkinIDs.count == before + newOnes)
            #expect(p.coins - refundsBefore == out.map(\.refund).reduce(0, +))
            let legendaries = out.filter { $0.skin.rarity == .legendary }.count
            if legendaries == 0 { #expect(p.pityCounter == pity + 10) }
        }
    }

    @Test("Pity beats a forced rarity")
    func pityWins() {
        var p = PlayerProfile()
        p.pityCounter = GachaSystem.pityLimit - 1
        var rng = Mulberry32(seed: 1)
        let r = GachaSystem.pullOne(&p, forced: .rare, rng: &rng)
        #expect(r.skin.rarity == .legendary)
        #expect(p.pityCounter == 0)
    }

    @Test("Refilling full energy is refused and costs nothing")
    func refillAtFull() {
        var p = PlayerProfile()
        p.gems = 100
        #expect(!EnergySystem.refill(&p))
        #expect(p.gems == 100)
    }

    @Test("VIP's bonus slots do not reduce the purchasable ones")
    func vipCap() {
        var p = PlayerProfile()
        p.gems = 100_000
        p.maxEnergy += 2 // VIP
        var bought = 0
        while EnergySystem.raiseCap(&p) { bought += 1 }
        #expect(bought == EnergySystem.purchasableSlots)
        #expect(p.maxEnergy == EnergySystem.maxCap + 2)
    }

    @Test("A clock wound backwards does not re-grant the dailies")
    func clockBackwards() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        func date(_ y: Int, _ m: Int, _ d: Int) -> Date { calendar.date(from: DateComponents(year: y, month: m, day: d))! }
        var p = PlayerProfile()
        p.lastActiveDay = 20260910
        p.loginClaimedToday = true
        #expect(!DailySystem.rollover(&p, now: date(2026, 9, 8), calendar: calendar))
        #expect(p.loginClaimedToday)
        #expect(DailySystem.rollover(&p, now: date(2026, 9, 11), calendar: calendar))
    }

    @Test("Closed duels are pruned")
    func duelHistoryBounded() {
        var p = PlayerProfile()
        var rng = Mulberry32(seed: 3)
        for i in 0..<(DuelSystem.keptHistory + 15) {
            _ = DuelSystem.challenge(rival: RivalNames.all[i % RivalNames.all.count], profile: &p, rng: &rng)
            _ = DuelSystem.resolve(score: 1_000_000, profile: &p)
        }
        #expect(p.duels.count == DuelSystem.keptHistory)
    }

    @Test("Unlocking a rocket anywhere counts toward Collector")
    func collectorFromAnySource() {
        var p = PlayerProfile()
        p.unlockSkin("ember", equip: false)
        p.unlockSkin("moss", equip: false)
        #expect(p.achievements.first { $0.id == Achievement.collector }?.progress == 3)
    }
}
