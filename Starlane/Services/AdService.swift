import Foundation
import StarlaneCore

/// Every place the game can show an ad. One case per AdMob ad unit, so the dashboard reports
/// revenue, fill rate and eCPM per surface instead of lumping every rewarded video together.
enum AdPlacement: String, CaseIterable, Sendable {
    /// Results screen: watch a video to carry on from where the run ended.
    case revive
    /// Results screen: watch a video to double the coins the run banked.
    case doubleCoins
    /// Supply: three free videos a day, each worth a handful of gems.
    case freeGems
    /// Daily: a second turn on the fortune wheel after the free one is spent.
    case wheelSpin
    /// Between runs, when the player taps "play again".
    case runEnd
    /// Between runs, when the player leaves the results screen for the hub.
    case returnToHub

    var format: AdFormat {
        switch self {
        case .revive, .doubleCoins, .freeGems, .wheelSpin: .rewarded
        case .runEnd, .returnToHub: .interstitial
        }
    }

    /// Whether an empty ad request should still pay out.
    ///
    /// A revive and doubled coins cost the studio nothing, so a no-fill — which is Google's problem,
    /// not the player's — hands them over anyway. Gems and wheel spins are hard currency that the shop
    /// sells, so those stay locked to a real impression.
    var grantsWhenUnavailable: Bool {
        switch self {
        case .revive, .doubleCoins: true
        case .freeGems, .wheelSpin, .runEnd, .returnToHub: false
        }
    }
}

enum AdFormat: Sendable {
    case rewarded
    case interstitial
}

/// What came back from a presentation attempt.
enum AdOutcome: Sendable {
    /// A rewarded video reached the reward point, or an interstitial was shown and dismissed.
    case completed
    /// A rewarded video was closed before the reward point. Nothing is owed.
    case abandoned
    /// Nothing could be shown: no fill, no network, consent withheld, or the unit is not configured.
    case unavailable
}

/// The game's view of an ad network. `GoogleAdService` is the real one; `SimulatedAdService` keeps
/// previews and tests off the network.
@MainActor
protocol AdService: AnyObject {
    /// Initialises the SDK. Safe to call more than once; the first call wins.
    func start()
    /// Warms a placement so the player does not sit watching a spinner. Cheap to call repeatedly —
    /// a placement that is already loaded or loading is ignored.
    func preload(_ placement: AdPlacement)
    /// Presents the placement and waits for the player to finish with it.
    func show(_ placement: AdPlacement) async -> AdOutcome
}

/// A request for the simulated ad screen. Only `SimulatedAdService` produces these; real ads are
/// presented by the Google SDK in its own window, not by a SwiftUI view.
struct AdRequest: Identifiable {
    let id = UUID()
    let placement: AdPlacement
    let creative: MockAd
    let onFinish: @MainActor (AdOutcome) -> Void

    /// Seconds before the claim/skip button unlocks, mirroring a real video's reward point.
    var gateSeconds: Int { placement.format == .rewarded ? 5 : 4 }
}

/// Stands in for the network in SwiftUI previews and unit tests: it presents the placeholder creative
/// through the router and always "fills".
final class SimulatedAdService: AdService {
    /// Set by `AppEnvironment` once the router exists.
    weak var router: UIRouter?

    private var rng = SystemRandomSource()

    func start() {}

    func preload(_ placement: AdPlacement) {}

    func show(_ placement: AdPlacement) async -> AdOutcome {
        guard let router else { return .unavailable }
        let creative = MockAd.catalog[rng.nextIndex(count: MockAd.catalog.count)]
        return await withCheckedContinuation { continuation in
            // `finishAd` clears the request before calling back, so the continuation resumes once.
            router.present(AdRequest(placement: placement, creative: creative) { outcome in
                continuation.resume(returning: outcome)
            })
        }
    }
}
