import Foundation
import GoogleMobileAds
import UIKit

/// AdMob, through the Google Mobile Ads SDK.
///
/// Responsibilities, in the order they matter:
/// 1. Never request anything until the consent flow says it may — `canRequestAds` covers GDPR, the
///    US state signals and ATT in one flag.
/// 2. Keep one ad warm per placement, because a player who taps "watch" and waits five seconds for a
///    spinner has already stopped caring about the reward.
/// 3. Report honestly. A rewarded ad only counts as `completed` when the SDK says the reward point
///    was reached; closing early is `abandoned`, and the caller owes nothing.
/// 4. Back off after failed loads instead of hammering the network, and never let an ad failure
///    block the game — every path ends in an `AdOutcome`, including "nothing to show".
final class GoogleAdService: AdService {
    private enum LoadedAd {
        case interstitial(InterstitialAd)
        case rewarded(RewardedAd)
    }

    private let consent: any ConsentService

    private var didStart = false
    private var ready: [AdPlacement: LoadedAd] = [:]
    private var loads: [AdPlacement: Task<Void, Never>] = [:]
    private var consecutiveFailures: [AdPlacement: Int] = [:]
    private var retryAfter: [AdPlacement: Date] = [:]
    /// Held for the lifetime of a presentation: the SDK keeps only a weak reference to the delegate.
    private var presentation: AdPresentation?

    init(consent: any ConsentService) {
        self.consent = consent
    }

    func start() {
        guard !didStart else { return }
        didStart = true
        let configuration = MobileAds.shared.requestConfiguration
        configuration.testDeviceIdentifiers = AdUnits.testDeviceIdentifiers
        // Starlane rates 4+/9+ on the App Store, so nothing above parental guidance may serve.
        configuration.maxAdContentRating = .parentalGuidance
        MobileAds.shared.start(completionHandler: nil)
    }

    // MARK: - Loading

    func preload(_ placement: AdPlacement) {
        guard ready[placement] == nil, loads[placement] == nil else { return }
        if let retry = retryAfter[placement], retry > Date() { return }
        loads[placement] = Task { [weak self] in
            guard let self else { return }
            await load(placement)
        }
    }

    /// Loads on demand, ignoring the backoff: the player is standing in front of the button.
    private func loadNow(_ placement: AdPlacement) async {
        if let inFlight = loads[placement] {
            await inFlight.value
            return
        }
        let task = Task { [weak self] in
            guard let self else { return }
            await load(placement)
        }
        loads[placement] = task
        await task.value
    }

    private func load(_ placement: AdPlacement) async {
        defer { loads[placement] = nil }
        guard consent.canRequestAds, let unitID = AdUnits.unitID(for: placement) else { return }
        do {
            switch placement.format {
            case .interstitial:
                ready[placement] = .interstitial(try await InterstitialAd.load(with: unitID, request: Request()))
            case .rewarded:
                ready[placement] = .rewarded(try await RewardedAd.load(with: unitID, request: Request()))
            }
            consecutiveFailures[placement] = nil
            retryAfter[placement] = nil
        } catch {
            // No fill is routine, not a bug: hold off a little longer after each failure in a row.
            let failures = (consecutiveFailures[placement] ?? 0) + 1
            consecutiveFailures[placement] = failures
            retryAfter[placement] = Date().addingTimeInterval(min(pow(2, Double(failures)), 64))
            print("[Ads] \(placement.rawValue) failed to load: \(error.localizedDescription)")
        }
    }

    // MARK: - Presenting

    func show(_ placement: AdPlacement) async -> AdOutcome {
        guard consent.canRequestAds, AdUnits.unitID(for: placement) != nil else { return .unavailable }
        if ready[placement] == nil { await loadNow(placement) }
        guard let ad = ready.removeValue(forKey: placement),
              let root = AdWindow.topViewController else { return .unavailable }

        let presentation = AdPresentation(format: placement.format)
        self.presentation = presentation
        let outcome = await withCheckedContinuation { continuation in
            presentation.begin(continuation)
            switch ad {
            case .interstitial(let interstitial):
                interstitial.fullScreenContentDelegate = presentation
                interstitial.present(from: root)
            case .rewarded(let rewarded):
                rewarded.fullScreenContentDelegate = presentation
                rewarded.present(from: root) { presentation.recordReward() }
            }
        }
        self.presentation = nil
        // Warm the next one while the player is still reading their reward pop-up.
        preload(placement)
        return outcome
    }
}

/// Bridges one full-screen presentation to the `async` caller. A rewarded ad resolves to `.completed`
/// only if the SDK reported the reward before the ad was dismissed.
@MainActor
private final class AdPresentation: NSObject, FullScreenContentDelegate {
    private let format: AdFormat
    private var continuation: CheckedContinuation<AdOutcome, Never>?
    private var earnedReward = false

    init(format: AdFormat) {
        self.format = format
    }

    func begin(_ continuation: CheckedContinuation<AdOutcome, Never>) {
        self.continuation = continuation
    }

    func recordReward() {
        earnedReward = true
    }

    func ad(_ ad: any FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: any Error) {
        print("[Ads] failed to present: \(error.localizedDescription)")
        finish(.unavailable)
    }

    func adDidDismissFullScreenContent(_ ad: any FullScreenPresentingAd) {
        guard format == .rewarded else {
            finish(.completed)
            return
        }
        finish(earnedReward ? .completed : .abandoned)
    }

    private func finish(_ outcome: AdOutcome) {
        continuation?.resume(returning: outcome)
        continuation = nil
    }
}
