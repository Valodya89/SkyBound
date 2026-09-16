import Foundation
import Testing
import StarlaneCore
@testable import Starlane

@MainActor
@Suite("RunController")
struct RunControllerTests {
    private func makeController() -> RunController {
        let c = RunController(audio: SilentAudioService(), haptics: SilentHapticsService())
        c.viewportChanged(CGSize(width: 390, height: 844))
        return c
    }

    private func drive(_ c: RunController, frames: Int, from start: TimeInterval = 0) -> TimeInterval {
        var t = start
        for _ in 0..<frames {
            t += 1 / 60
            _ = c.advance(now: t)
        }
        return t
    }

    @Test("Starts in attract and steps the autopilot")
    func attract() {
        let c = makeController()
        #expect(c.phase == .attract)
        #expect(!c.isInRun)
        _ = drive(c, frames: 120)
        #expect(c.simulation.worldZ > 0)
    }

    @Test("Countdown releases the ship and a crash reaches results with revive open")
    func crashToResults() async throws {
        let c = makeController()
        var config = RunConfig(mode: .classic, viewportWidth: 390, viewportHeight: 844)
        config.seed = 3
        var ended: RunSummary?
        c.onRunEnded = { s, _ in ended = s }
        c.start(config: config, screenShake: false)
        #expect(c.phase == .countdown)
        #expect(c.isInRun)

        try await Task.sleep(for: .milliseconds(2700))
        #expect(c.phase == .playing)
        #expect(c.simulation.isRunning)

        var t: TimeInterval = 0
        for _ in 0..<6000 where c.phase == .playing {
            t = drive(c, frames: 1, from: t)
        }
        #expect(c.phase == .crashed)
        try await Task.sleep(for: .milliseconds(800))
        #expect(c.phase == .results)
        #expect(ended != nil)
        #expect(c.summary?.mode == .classic)
        #expect(c.isReviveOpen)
        #expect(c.canRevive)

        c.revive()
        #expect(c.phase == .countdown)
        #expect(c.simulation.hasRevived)
        #expect(!c.canRevive)
    }

    @Test("Pause freezes the simulation")
    func pause() async throws {
        let c = makeController()
        c.start(config: RunConfig(mode: .classic, viewportWidth: 390, viewportHeight: 844), screenShake: true)
        try await Task.sleep(for: .milliseconds(2700))
        let t = drive(c, frames: 10)
        c.pause()
        #expect(c.phase == .paused)
        let before = c.simulation.distance
        _ = drive(c, frames: 30, from: t)
        #expect(c.simulation.distance == before)
        c.quit()
        #expect(c.phase == .results)
    }

    @Test("Quitting from the pause menu banks the run")
    func quitBanks() async throws {
        let c = makeController()
        var banked: RunSummary?
        c.onRunEnded = { s, _ in banked = s }
        c.start(config: RunConfig(mode: .sprint, viewportWidth: 390, viewportHeight: 844), screenShake: true)
        try await Task.sleep(for: .milliseconds(2700))
        _ = drive(c, frames: 60)
        c.pause()
        c.quit()
        #expect(banked?.mode == .sprint)
        #expect(!c.canRevive)
    }
}

@MainActor
@Suite("GameCoordinator")
struct GameCoordinatorTests {
    private func make(_ mutate: (inout PlayerProfile) -> Void = { _ in }) -> GameCoordinator {
        var p = PlayerProfile()
        mutate(&p)
        return AppEnvironment.preview(profile: p).coordinator
    }

    @Test("Launching spends energy, consumes the boost and enters the run")
    func launch() {
        let c = make()
        c.run.viewportChanged(CGSize(width: 390, height: 844))
        c.equipBoost(.shield)
        c.launch(.classic)
        #expect(c.player.profile.energy == 4)
        #expect(c.player.profile.inventoryCount(.shield) == 0)
        #expect(c.run.phase == .countdown)
        #expect(c.run.simulation.hasShield)
        #expect(c.equippedBoost == nil)
    }

    @Test("No energy routes to the shop with a toast")
    func noEnergy() {
        let c = make { $0.energy = 0 }
        c.launch(.classic)
        #expect(c.run.phase == .attract)
        #expect(c.router.sheet == .shop)
        #expect(c.router.toast != nil)
    }

    @Test("Daily is blocked once played")
    func dailyBlocked() {
        let c = make { $0.dailyChallengeDone = true; $0.lastActiveDay = DaySeed.value(for: Date()) }
        c.launch(.daily)
        #expect(c.run.phase == .attract)
        #expect(c.router.toast?.text.contains("Daily") == true)
    }

    @Test("Locked modes cannot be selected")
    func lockedMode() {
        let c = make()
        c.selectMode(.hardcore)
        #expect(c.player.profile.selectedMode == .classic)
        c.selectMode(.sprint)
        #expect(c.player.profile.selectedMode == .sprint)
    }

    @Test("Crate pulls debit gems and populate the reveal")
    func pulls() {
        let c = make { $0.gems = 500 }
        c.pull(count: 10)
        #expect(c.player.profile.gems == 50)
        #expect(c.lastPulls.count == 10)
        c.pull(count: 10)
        #expect(c.router.toast?.text == "Not enough gems")
    }

    @Test("Daily login claim shows a reward pop-up and advances the streak")
    func login() {
        let c = make()
        c.claimDailyLogin()
        #expect(c.router.reward?.title == "DAY 1 CLAIMED")
        #expect(c.player.profile.loginStreakDay == 2)
        #expect(c.player.profile.coins == 300)
        c.router.dismissReward()
        #expect(c.router.reward == nil)
    }

    @Test("Reward pop-ups queue instead of replacing each other")
    func rewardQueue() {
        let c = make()
        c.router.showReward(symbol: "a", title: "ONE", detail: "")
        c.router.showReward(symbol: "b", title: "TWO", detail: "")
        #expect(c.router.reward?.title == "ONE")
        c.router.dismissReward()
        #expect(c.router.reward?.title == "TWO")
        c.router.dismissReward()
        #expect(c.router.reward == nil)
    }

    @Test("Rewarded ad gates free gems")
    func freeGems() {
        let c = make()
        c.watchFreeGemAd()
        #expect(c.router.ad?.kind == .rewarded)
        #expect(c.player.profile.gems == 20)
        c.router.finishAd()
        #expect(c.router.ad == nil)
        #expect(c.player.profile.gems == 25)
        #expect(c.player.profile.freeGemAdsWatchedToday == 1)
    }

    @Test("A verified transaction grants the product and shows the reward")
    func purchase() async throws {
        let c = make()
        c.purchase(.vip)
        try await Task.sleep(for: .milliseconds(600))
        #expect(c.player.profile.isVIP)
        #expect(c.player.profile.maxEnergy == 7)
        #expect(c.router.reward?.title == "VIP ACTIVATED")
        #expect(c.player.profile.redeemedTransactionIDs.count == 1)
    }

    @Test("A replayed transaction never grants twice")
    func replayedTransactionIsIgnored() async throws {
        let c = make()
        let store = c.purchases as! SimulatedPurchaseService
        let pack = StoreProduct.gemPacks[0]
        let info = StoreTransactionInfo(product: pack, transactionID: "tx-42", isRestore: false)
        #expect(store.onTransaction?(info) == true)
        #expect(c.player.profile.gems == 20 + 120)
        // StoreKit replays a transaction that could not be finished last time.
        #expect(store.onTransaction?(info) == true)
        #expect(c.player.profile.gems == 20 + 120)
    }

    @Test("Entitlements arriving from the App Store revoke a lapsed VIP")
    func entitlementsRevokeVIP() async throws {
        let c = make()
        c.purchase(.vip)
        try await Task.sleep(for: .milliseconds(600))
        #expect(c.player.profile.isVIP)

        let store = c.purchases as! SimulatedPurchaseService
        store.onEntitlements?(StoreEntitlements())
        #expect(!c.player.profile.isVIP)
        #expect(c.player.profile.maxEnergy == 5)
        #expect(c.router.toast != nil)
    }

    @Test("Restoring a purchase does not replay the reward popup")
    func restoreIsQuiet() {
        let c = make()
        let store = c.purchases as! SimulatedPurchaseService
        let info = StoreTransactionInfo(product: .removeAds, transactionID: "tx-restore", isRestore: true)
        #expect(store.onTransaction?(info) == true)
        #expect(c.player.profile.adsRemoved)
        #expect(c.router.reward == nil)
    }

    @Test("Prices fall back to the catalog label until StoreKit answers")
    func priceLabels() {
        let c = make()
        #expect(c.priceLabel(for: .removeAds) == StoreProduct.removeAds.priceLabel)
    }

    @Test("Settings sync to services")
    func settings() {
        let c = make()
        c.updateSettings { $0.soundEnabled = false; $0.hapticsEnabled = false }
        #expect(!c.audio.soundEnabled)
        #expect(!c.haptics.isEnabled)
        #expect(!c.player.profile.settings.soundEnabled)
    }

    @Test("Reset wipes progress")
    func reset() {
        let c = make { $0.coins = 9999; $0.level = 7 }
        c.resetProgress()
        #expect(c.player.profile.coins == 150)
        #expect(c.player.profile.level == 1)
    }
}

@MainActor
@Suite("PlayerStore")
struct PlayerStoreTests {
    @Test("Tick regenerates energy and counts the offer down")
    func tick() {
        var p = PlayerProfile()
        p.energy = 1
        p.energyTimer = 2
        let store = PlayerStore(store: InMemoryProfileStore(initial: p))
        store.tick()
        #expect(store.profile.energyTimer == 1)
        store.tick()
        #expect(store.profile.energy == 2)
        #expect(store.offerSecondsLeft == ShopSystem.offerDurationSeconds - 2)
    }

    @Test("Energy regenerates while the app was closed")
    func offlineEnergy() {
        var p = PlayerProfile()
        p.energy = 0
        p.energyTimer = 45
        p.lastSavedAt = Date().timeIntervalSince1970 - 100
        let store = PlayerStore(store: InMemoryProfileStore(initial: p))
        #expect(store.profile.energy == 2)
    }

    @Test("Saves land in the store")
    func persists() async throws {
        let mem = InMemoryProfileStore()
        let store = PlayerStore(store: mem)
        store.update { $0.coins = 777 }
        try await Task.sleep(for: .milliseconds(600))
        #expect(try mem.load()?.coins == 777)
    }

    @Test("Leaderboard includes the player")
    func leaderboard() {
        let store = PlayerStore(store: InMemoryProfileStore())
        #expect(store.leaderboard.contains { $0.isPlayer })
        #expect(store.leaderboard.count == RivalNames.all.count + 1)
    }
}
