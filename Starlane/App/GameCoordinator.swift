import Foundation
import Observation
import StarlaneCore

/// The app's use-cases. Views call intents here; the coordinator orchestrates the player store,
/// the run controller, ads, purchases and presentation. Nothing in here touches SwiftUI.
@Observable
final class GameCoordinator {
    let player: PlayerStore
    let run: RunController
    let router: UIRouter
    let audio: any AudioService
    let haptics: any HapticsService
    @ObservationIgnored private let ads: any AdService
    @ObservationIgnored let purchases: any PurchaseService
    @ObservationIgnored private var rng = SystemRandomSource()

    /// Boost chosen in the mode picker. Consumed when a run launches.
    private(set) var equippedBoost: BoostKind?
    /// Last crate opening, for the reveal animation.
    private(set) var lastPulls: [PullResult] = []
    /// Fortune-wheel presentation state.
    private(set) var wheelAngle: Double = 0
    private(set) var isWheelSpinning = false
    private(set) var isPurchasing = false
    private(set) var isRestoring = false
    /// Bumped whenever StoreKit delivers prices, so the shop redraws with the localised catalog.
    private(set) var storeRevision = 0

    init(player: PlayerStore, run: RunController, router: UIRouter, audio: any AudioService,
         haptics: any HapticsService, ads: any AdService, purchases: any PurchaseService) {
        self.player = player
        self.run = run
        self.router = router
        self.audio = audio
        self.haptics = haptics
        self.ads = ads
        self.purchases = purchases
        syncPreferences()
        run.onRunEnded = { [weak self] summary, previous in self?.bank(summary, previouslyBanked: previous) }
        wireStore()
    }

    // MARK: - Storefront wiring

    /// Connects the storefront before anything else can buy: transactions that arrive from another device,
    /// from an Ask to Buy approval or from an interrupted grant land here without the shop being open.
    private func wireStore() {
        purchases.onTransaction = { [weak self] info in
            guard let self else { return false }
            return grant(info)
        }
        purchases.onEntitlements = { [weak self] entitlements in
            guard let self else { return }
            let wasVIP = player.profile.isVIP
            player.update { ShopSystem.sync(entitlements, to: &$0) }
            player.saveNow()
            storeRevision += 1
            if wasVIP, !entitlements.isVIP {
                router.toast("VIP has lapsed — renew any time in Supply")
            }
        }
        purchases.start()
    }

    /// Applies one verified transaction. Returns `true` once the grant is on disk, which is the signal the
    /// service needs before it may finish the transaction.
    @discardableResult
    private func grant(_ info: StoreTransactionInfo) -> Bool {
        var granted: String?
        var isFresh = false
        player.update { profile in
            isFresh = ShopSystem.redeem(transactionID: info.transactionID, profile: &profile)
            guard isFresh else { return }
            granted = ShopSystem.apply(info.product, to: &profile)
        }
        player.saveNow()
        storeRevision += 1
        // Already redeemed, or a restore of something the profile knows about: nothing to celebrate.
        guard isFresh, !info.isRestore else { return true }
        if let granted { showPurchaseReward(info.product, granted: granted) }
        haptics.success()
        return true
    }

    private func showPurchaseReward(_ product: StoreProduct, granted: String) {
        let title: String
        switch product.grant {
        case .vip: title = "VIP ACTIVATED"
        case .removeAds: title = "ADS REMOVED"
        case .founderBundle: title = "BUNDLE UNLOCKED"
        case .piggyBank: title = "SMASHED"
        case .gems(let n): title = "+\(n) GEMS"
        }
        router.showReward(symbol: product.symbol, tint: product.grant == .vip ? "#F2B544" : "#7EDCF2",
                          title: title, detail: granted)
    }

    /// Localised price for a product, falling back to the catalog placeholder until StoreKit answers.
    func priceLabel(for product: StoreProduct) -> String {
        _ = storeRevision
        guard let display = purchases.display[product.id] else {
            return product.priceLabel + product.fallbackPeriodSuffix
        }
        return display.priceWithPeriod
    }

    /// Just the amount, without the "/mo" suffix — for layouts that print the period separately.
    func priceAmount(for product: StoreProduct) -> String {
        _ = storeRevision
        return purchases.display[product.id]?.price ?? product.priceLabel
    }

    func introOffer(for product: StoreProduct) -> String? {
        _ = storeRevision
        return purchases.display[product.id]?.introOffer
    }

    // MARK: - App lifecycle

    func appDidBecomeActive() {
        player.refreshDay()
        player.catchUp()
        player.startTicking()
        run.appDidBecomeActive()
        audio.warmUp()
        // Picks up a renewal or a cancellation made in Settings while the app was backgrounded.
        Task { [weak self] in await self?.purchases.refresh() }
    }

    func appWillResignActive() {
        run.appWillResignActive()
        player.stopTicking()
        player.saveNow()
    }

    func syncPreferences() {
        let s = player.profile.settings
        audio.soundEnabled = s.soundEnabled
        audio.musicEnabled = s.musicEnabled
        haptics.isEnabled = s.hapticsEnabled
    }

    func updateSettings(_ body: (inout PlayerSettings) -> Void) {
        player.update { body(&$0.settings) }
        syncPreferences()
        audio.play(.ui)
    }

    // MARK: - Launching runs

    /// The PLAY button: launches the selected mode (Daily is only launched from its own sheet).
    func play() {
        let mode = player.profile.selectedMode.config.isHidden ? .classic : player.profile.selectedMode
        launch(mode)
    }

    func selectMode(_ mode: GameMode) {
        guard mode.isUnlocked(atLevel: player.profile.level) else { return }
        player.update { $0.selectedMode = mode }
        audio.play(.ui)
    }

    func equipBoost(_ boost: BoostKind?) {
        if let boost, player.profile.inventoryCount(boost) == 0 { return }
        equippedBoost = boost
        audio.play(.ui)
    }

    func launch(_ mode: GameMode) {
        let profile = player.profile
        if mode == .daily, profile.dailyChallengeDone {
            router.toast("Daily already played — back tomorrow")
            return
        }
        guard EnergySystem.canLaunch(mode, profile: profile) else {
            router.toast("Not enough energy")
            router.open(.shop)
            return
        }

        var config = RunConfig(mode: mode, viewportWidth: run.viewport.width, viewportHeight: run.viewport.height)
        config.upgrades = profile.upgrades
        config.isVIP = profile.isVIP
        config.ghost = profile.ghosts[mode] ?? []
        config.ghostEnabled = profile.settings.ghostEnabled
        config.startsWithShield = rng.chance(Double(profile.upgradeLevel(.autoShield)) * 0.18)
        if mode == .daily {
            config.seed = UInt32(truncatingIfNeeded: profile.dailyChallengeSeed)
        } else if let boost = equippedBoost, profile.inventoryCount(boost) > 0 {
            // Auto-Shield already rolled a shield: keep the equipped one in the bag instead of wasting it.
            if boost == .shield, config.startsWithShield {
                router.toast("Auto-Shield kicked in — your Shield boost is saved")
            } else {
                config.equippedBoost = boost
            }
        }

        player.update { p in
            EnergySystem.spend(for: mode, profile: &p)
            if mode != .daily { p.selectedMode = mode }
            if let boost = config.equippedBoost { p.consumeBoost(boost) }
        }
        // The daily runs without boosts, so a boost picked for the next normal run stays equipped.
        if config.equippedBoost != nil { equippedBoost = nil }
        router.closeSheet()
        run.start(config: config, screenShake: profile.settings.screenShakeEnabled)
    }

    private func bank(_ summary: RunSummary, previouslyBanked previous: RunSummary?) {
        var outcome = RunOutcome()
        player.update { outcome = RunResolver.bank(summary, previouslyBanked: previous, into: &$0) }
        run.recordOutcome(outcome)
        for level in outcome.levelsGained {
            router.showReward(symbol: "arrow.up.circle.fill", tint: "#7EDCF2", title: "LEVEL \(level)", detail: "+\(Progression.levelUpGems) gems · new modes may be unlocked")
        }
        for duel in outcome.duelsWon {
            router.showReward(symbol: "trophy.fill", title: "DUEL WON", detail: "Beat \(duel.rivalName) · +\(Duel.winReward) gems")
        }
        player.saveNow()
    }

    // MARK: - Results actions

    func revive() {
        guard run.canRevive else { return }
        run.cancelReviveTimer()
        showAd(.rewarded) { [weak self] in
            self?.run.revive()
            self?.router.toast("Revived with a shield")
        }
    }

    func doubleCoins() {
        guard run.canDoublePayout else { return }
        let bonus = run.simulation.coins
        // The revive window must not tick away while the player is watching this ad.
        run.reviveSuspended = true
        showAd(.rewarded) { [weak self] in
            guard let self else { return }
            run.reviveSuspended = false
            player.update { $0.coins += bonus }
            run.doublePayout()
            router.showReward(symbol: "dollarsign.circle.fill", title: "COINS DOUBLED", detail: "+\(bonus) bonus coins")
        }
    }

    func playAgain() {
        run.cancelReviveTimer()
        let mode = run.simulation.config.mode
        if mode == .daily {
            router.toast("Daily is one attempt — back tomorrow")
            returnToHub()
            return
        }
        guard EnergySystem.canLaunch(mode, profile: player.profile) else {
            router.toast("Out of energy")
            returnToHub()
            return
        }
        maybeInterstitial { [weak self] in
            guard let self else { return }
            if !EnergySystem.canLaunch(mode, profile: player.profile) {
                router.toast("Out of energy")
                run.startAttract()
                router.select(.home)
                return
            }
            launch(mode)
        }
    }

    /// Pause menu: bank the current run and immediately launch the same mode again.
    func restartRun() {
        let mode = run.simulation.config.mode
        run.cancelReviveTimer()
        run.quit()
        guard mode != .daily else {
            returnToHub()
            return
        }
        // Banking may have queued level-up or duel pop-ups; the new countdown waits until they are collected.
        router.afterRewards { [weak self] in
            guard let self else { return }
            if EnergySystem.canLaunch(mode, profile: player.profile) {
                launch(mode)
            } else {
                router.toast("Out of energy")
                returnToHub()
            }
        }
    }

    func returnToHub() {
        run.cancelReviveTimer()
        maybeInterstitial { [weak self] in
            self?.run.startAttract()
            self?.router.select(.home)
        }
    }

    // MARK: - Ads

    private func maybeInterstitial(then body: @escaping @MainActor () -> Void) {
        let p = player.profile
        if p.isVIP || p.adsRemoved {
            body()
            return
        }
        var count = 0
        player.update { $0.interstitialCounter += 1; count = $0.interstitialCounter }
        if count % 2 == 0 {
            showAd(.interstitial, then: body)
        } else {
            body()
        }
    }

    private func showAd(_ kind: AdKind, then body: @escaping @MainActor () -> Void) {
        router.present(ads.makeRequest(kind: kind, onComplete: body))
    }

    func watchFreeGemAd() {
        guard DailySystem.canWatchFreeGemAd(player.profile) else {
            router.toast("No free videos left today")
            return
        }
        showAd(.rewarded) { [weak self] in
            guard let self else { return }
            player.update { DailySystem.grantFreeGems(&$0) }
            router.showReward(symbol: "diamond.fill", tint: "#7EDCF2", title: "+\(DailySystem.freeGemAdReward) GEMS", detail: "Rewarded video complete")
        }
    }

    // MARK: - Shop

    /// Starts a real App Store purchase. The grant itself happens in `grant(_:)` when the verified
    /// transaction arrives, so an Ask to Buy approval that lands minutes later is handled identically.
    func purchase(_ product: StoreProduct) {
        guard !isPurchasing, !ShopSystem.isOwned(product, profile: player.profile) else { return }
        isPurchasing = true
        audio.play(.ui)
        Task { [weak self] in
            guard let self else { return }
            let outcome = await purchases.purchase(product)
            isPurchasing = false
            switch outcome {
            case .success:
                break
            case .cancelled:
                break
            case .pending:
                router.toast("Waiting for approval — it will unlock automatically")
            case .failed(let message):
                router.toast(message)
            }
        }
    }

    func restorePurchases() {
        guard !isRestoring else { return }
        isRestoring = true
        audio.play(.ui)
        Task { [weak self] in
            guard let self else { return }
            let ok = await purchases.restore()
            isRestoring = false
            let p = player.profile
            if !ok {
                router.toast("Could not reach the App Store")
            } else if p.isVIP || p.adsRemoved || p.founderBundleOwned {
                router.toast("Purchases restored")
            } else {
                router.toast("Nothing to restore on this Apple Account")
            }
        }
    }

    func manageSubscription() {
        Task { [weak self] in await self?.purchases.showManageSubscriptions() }
    }

    func buyBoost(_ kind: BoostKind) {
        var ok = false
        player.update { ok = ShopSystem.buyBoost(kind, profile: &$0) }
        if ok {
            audio.play(.ui)
            router.toast("\(kind.name) purchased")
        } else {
            router.toast("Not enough \(kind.price.currency.displayName)")
        }
    }

    func buyUpgrade(_ kind: UpgradeKind) {
        var ok = false
        player.update { ok = UpgradeSystem.buy(kind, profile: &$0) }
        if ok {
            audio.play(.ui)
            let level = player.profile.upgradeLevel(kind)
            router.showReward(symbol: kind.symbol, tint: "#7EDCF2", title: "\(kind.name.uppercased()) LV \(level)", detail: kind.detail)
        } else {
            router.toast("Not enough coins")
        }
    }

    func refillEnergy() {
        var ok = false
        player.update { ok = EnergySystem.refill(&$0) }
        router.toast(ok ? "Energy refilled" : "Not enough gems")
        if ok { audio.play(.ui) }
    }

    func raiseEnergyCap() {
        var ok = false
        player.update { ok = EnergySystem.raiseCap(&$0) }
        router.toast(ok ? "Energy cap raised" : "Not enough gems")
        if ok { audio.play(.ui) }
    }

    // MARK: - Crates

    func pull(count: Int) {
        var results: [PullResult]?
        player.update { results = GachaSystem.pull(count: count, profile: &$0, rng: &rng) }
        guard let results else {
            router.toast("Not enough gems")
            return
        }
        lastPulls = results
        for (i, r) in results.enumerated() {
            let rank = r.skin.rarity == .legendary ? 3 : r.skin.rarity == .epic ? 2 : 1
            Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(i * 55))
                self?.audio.play(.pull(rank))
            }
        }
        if let best = results.max(by: { $0.skin.rarity < $1.skin.rarity }), best.skin.rarity >= .epic {
            Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(count * 60 + 250))
                self?.router.showReward(symbol: best.skin.symbol, tint: best.skin.colorHex, title: "\(best.skin.rarity.displayName.uppercased())!",
                                        detail: best.skin.name + (best.isNew ? " — new rocket" : " — duplicate converted to coins"))
            }
        }
    }

    func equipSkin(_ id: String) {
        guard player.profile.owns(skinID: id) else { return }
        player.update { $0.equippedSkinID = id }
        audio.play(.ui)
        router.toast("Equipped: \(SkinCatalog.skin(id).name)")
    }

    // MARK: - Season pass

    func unlockPremiumPass() {
        var ok = false
        player.update { ok = SeasonPass.unlockPremium(&$0) }
        if ok {
            router.showReward(symbol: "trophy.fill", title: "PREMIUM UNLOCKED", detail: "Every premium tier reward is now yours")
        } else {
            router.toast("Not enough gems")
        }
    }

    func claimTier(_ tier: Int, premium: Bool) {
        var reward: TierReward?
        player.update { reward = SeasonPass.claim(tier: tier, premium: premium, profile: &$0) }
        guard let reward else { return }
        audio.play(.ui)
        haptics.light()
        let detail: String
        switch reward.kind {
        case .coins(let n): detail = "+\(n) coins"
        case .gems(let n): detail = "+\(n) gems"
        case .crate: detail = "A free crate pull — \(GachaSystem.singlePrice.amount) gems added"
        }
        router.showReward(symbol: reward.symbol, tint: reward.tintHex, title: "TIER \(tier) CLAIMED", detail: detail)
    }

    func claimMission(_ id: String) {
        var reward: MissionReward?
        player.update { reward = SeasonPass.claimMission(id: id, profile: &$0) }
        guard let reward else { return }
        router.showReward(symbol: "checkmark.circle.fill", tint: "#7EDCF2", title: "MISSION CLAIMED",
                          detail: (reward.gems > 0 ? "+\(reward.gems) gems" : "+\(reward.coins) coins") + " · +\(SeasonPass.missionClaimSP) SP")
    }

    // MARK: - Dailies

    func claimDailyLogin() {
        var reward: DailyLoginReward?
        player.update { reward = DailySystem.claimLogin(&$0) }
        guard let reward else { return }
        haptics.success()
        let symbol = reward.skinID != nil ? "gift.fill" : reward.gems > 0 ? "diamond.fill" : "circle.circle.fill"
        let tint = reward.skinID != nil ? "#B48CFF" : reward.gems > 0 ? "#7EDCF2" : "#F2B544"
        let detail = reward.skinID != nil ? "Sunset rocket unlocked" : reward.gems > 0 ? "+\(reward.gems) gems" : "+\(reward.coins) coins"
        router.showReward(symbol: symbol, tint: tint, title: "DAY \(reward.day) CLAIMED", detail: detail)
    }

    func spinWheel(free: Bool) {
        guard !isWheelSpinning else { return }
        if free {
            guard !player.profile.wheelSpunToday else {
                router.toast("Free spin already used today")
                return
            }
            player.update { $0.wheelSpunToday = true }
            performSpin()
        } else {
            showAd(.rewarded) { [weak self] in self?.performSpin() }
        }
    }

    private func performSpin() {
        let prize = DailySystem.spinWheel(rng: &rng)
        let segment = 360.0 / Double(WheelPrize.wheel.count)
        isWheelSpinning = true
        // Land the pointer on the prize from wherever the wheel currently rests.
        let target = 360 - (Double(prize.id) * segment + segment / 2)
        let rest = wheelAngle.truncatingRemainder(dividingBy: 360)
        wheelAngle += 360 * 5 + (target - rest + 360).truncatingRemainder(dividingBy: 360)
        audio.play(.wheelSpin)
        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(3500))
            guard let self else { return }
            isWheelSpinning = false
            player.update { DailySystem.apply(prize: prize, to: &$0) }
            haptics.success()
            switch prize.kind {
            case .coins(let n): router.showReward(symbol: "circle.circle.fill", title: "+\(n) COINS", detail: "Fortune spin")
            case .gems(let n): router.showReward(symbol: "diamond.fill", tint: "#7EDCF2", title: "+\(n) GEMS", detail: "Fortune spin")
            case .boost(let b): router.showReward(symbol: b.symbol, tint: b.colorHex, title: "\(b.name.uppercased()) ×1", detail: "Fortune spin")
            }
        }
    }

    // MARK: - Duels

    func challenge(_ rival: String) {
        var duel: Duel?
        player.update { duel = DuelSystem.challenge(rival: rival, profile: &$0, rng: &rng) }
        guard let duel else { return }
        audio.play(.ui)
        router.toast("\(rival) posted \(GameFormat.grouped(duel.rivalScore)) — beat it in \(Duel.attempts) runs")
    }

    // MARK: - Settings

    func resetProgress() {
        player.wipe()
        equippedBoost = nil
        lastPulls = []
        syncPreferences()
        router.closeSheet()
        router.toast("Progress wiped — fresh start")
    }
}
