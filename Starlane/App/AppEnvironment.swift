import Foundation
import StarlaneCore

/// Composition root. Builds every dependency once and exposes the coordinator to SwiftUI.
final class AppEnvironment {
    let coordinator: GameCoordinator

    init(coordinator: GameCoordinator) {
        self.coordinator = coordinator
    }

    /// Production wiring: JSON persistence, synthesised audio, system haptics, AdMob behind Google's
    /// consent flow, and the real StoreKit 2 storefront.
    static func live() -> AppEnvironment {
        let store: any ProfileStore = (try? FileProfileStore.standard()) ?? InMemoryProfileStore()
        let audio = SynthAudioService()
        let haptics = SystemHapticsService()
        let player = PlayerStore(store: store)
        let run = RunController(audio: audio, haptics: haptics)
        let router = UIRouter()
        let consent = UMPConsentService()
        let coordinator = GameCoordinator(player: player, run: run, router: router, audio: audio, haptics: haptics,
                                          ads: GoogleAdService(consent: consent), consent: consent,
                                          purchases: StoreKitPurchaseService())
        return AppEnvironment(coordinator: coordinator)
    }

    /// Silent, in-memory wiring for previews and tests. Nothing is charged and nothing is requested
    /// from an ad network: the ad screen is the local placeholder.
    static func preview(profile: PlayerProfile = PlayerProfile()) -> AppEnvironment {
        let audio = SilentAudioService()
        let haptics = SilentHapticsService()
        let player = PlayerStore(store: InMemoryProfileStore(initial: profile))
        let run = RunController(audio: audio, haptics: haptics)
        let router = UIRouter()
        let ads = SimulatedAdService()
        ads.router = router
        let coordinator = GameCoordinator(player: player, run: run, router: router, audio: audio, haptics: haptics,
                                          ads: ads, consent: NoConsentService(),
                                          purchases: SimulatedPurchaseService())
        return AppEnvironment(coordinator: coordinator)
    }
}
