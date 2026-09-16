import Foundation
import Observation
import UIKit
import StarlaneCore

/// The five destinations in the bottom bar.
enum HubTab: String, CaseIterable, Identifiable {
    case home, crates, shop, pass, rank
    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: "Deck"
        case .crates: "Hangar"
        case .shop: "Shop"
        case .pass: "Season"
        case .rank: "Ranks"
        }
    }

    var icon: String {
        switch self {
        case .home: "house"
        case .crates: "shippingbox"
        case .shop: "bag"
        case .pass: "flag"
        case .rank: "trophy"
        }
    }
}

/// Every full-screen page that can sit over the deck. Several kinds share a screen and only differ by the
/// tab or section they open on (crates/upgrades → Hangar, login/wheel/dailyChallenge → Daily, duels/rank → Ranks).
enum SheetKind: String, Identifiable {
    case modes, dailyChallenge, duels, upgrades, shop, crates, pass, rank, login, wheel, settings
    var id: String { rawValue }

    var tab: HubTab {
        switch self {
        case .shop: .shop
        case .crates, .upgrades: .crates
        case .pass: .pass
        case .rank, .duels: .rank
        default: .home
        }
    }

    /// Tab-root pages keep the bottom bar; the rest (modes, dailies, settings) push over the deck.
    var isTabRoot: Bool { tab != .home }
}

struct RewardPopup: Identifiable {
    let id = UUID()
    /// SF Symbol shown large in the pop-up.
    let symbol: String
    /// Hex colour for the symbol.
    let tintHex: String
    let title: String
    let detail: String
    var onDismiss: (@MainActor () -> Void)? = nil
}

struct ToastMessage: Identifiable, Equatable {
    let id = UUID()
    let text: String
}

/// Presentation state that is not part of the game or the player: pages, popups, ads, toasts.
@Observable
final class UIRouter {
    private(set) var tab: HubTab = .home
    private(set) var sheet: SheetKind?
    private(set) var reward: RewardPopup?
    private(set) var ad: AdRequest?
    /// True from the moment an ad is asked for until it is gone, covering the load as well as the
    /// presentation. Freezes the scene and blocks a second ad from being started underneath.
    private(set) var isAdPending = false
    private(set) var toast: ToastMessage?
    var shareImage: UIImage?

    @ObservationIgnored private var rewardQueue: [RewardPopup] = []
    @ObservationIgnored private var afterRewardsQueue: [@MainActor () -> Void] = []
    @ObservationIgnored private var toastTask: Task<Void, Never>?

    // MARK: Tabs & pages

    func select(_ tab: HubTab) {
        self.tab = tab
        switch tab {
        case .home: sheet = nil
        case .shop: sheet = .shop
        case .crates: sheet = .crates
        case .pass: sheet = .pass
        case .rank: sheet = .rank
        }
    }

    func open(_ kind: SheetKind) {
        sheet = kind
        tab = kind.tab
    }

    func closeSheet() {
        sheet = nil
        tab = .home
    }

    // MARK: Rewards

    func showReward(_ popup: RewardPopup) {
        if reward == nil {
            reward = popup
        } else {
            rewardQueue.append(popup)
        }
    }

    func showReward(symbol: String, tint: String = "#F2B544", title: String, detail: String, onDismiss: (@MainActor () -> Void)? = nil) {
        showReward(RewardPopup(symbol: symbol, tintHex: tint, title: title, detail: detail, onDismiss: onDismiss))
    }

    func dismissReward() {
        let current = reward
        reward = rewardQueue.isEmpty ? nil : rewardQueue.removeFirst()
        current?.onDismiss?()
        if reward == nil {
            let pending = afterRewardsQueue
            afterRewardsQueue = []
            for body in pending { body() }
        }
    }

    /// Runs `body` now if nothing is being collected, otherwise once the last queued reward is dismissed.
    func afterRewards(_ body: @escaping @MainActor () -> Void) {
        if reward == nil { body() } else { afterRewardsQueue.append(body) }
    }

    // MARK: Ads

    func present(_ request: AdRequest) { ad = request }

    func finishAd(_ outcome: AdOutcome = .completed) {
        let current = ad
        ad = nil
        current?.onFinish(outcome)
    }

    func beginAdWait() { isAdPending = true }

    func endAdWait() { isAdPending = false }

    // MARK: Toasts

    func toast(_ text: String, seconds: Double = 1.9) {
        toast = ToastMessage(text: text)
        toastTask?.cancel()
        toastTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            self?.toast = nil
        }
    }
}
