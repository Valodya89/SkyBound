import Foundation
import SkyBoundCore

/// Composition root. Builds every dependency once and exposes the coordinator to SwiftUI.
final class AppEnvironment {
    let coordinator: GameCoordinator

    init(coordinator: GameCoordinator) {
        self.coordinator = coordinator
    }

    /// Production wiring: JSON persistence, synthesised audio, system haptics, simulated ads and store.
    static func live() -> AppEnvironment {
        let store: any ProfileStore = (try? FileProfileStore.standard()) ?? InMemoryProfileStore()
        let audio = SynthAudioService()
        let haptics = SystemHapticsService()
        let player = PlayerStore(store: store)
        let run = RunController(audio: audio, haptics: haptics)
        let router = UIRouter()
        let coordinator = GameCoordinator(player: player, run: run, router: router, audio: audio, haptics: haptics,
                                          ads: MockAdService(), purchases: SimulatedPurchaseService())
        return AppEnvironment(coordinator: coordinator)
    }

    /// Silent, in-memory wiring for previews and tests.
    static func preview(profile: PlayerProfile = PlayerProfile()) -> AppEnvironment {
        let audio = SilentAudioService()
        let haptics = SilentHapticsService()
        let player = PlayerStore(store: InMemoryProfileStore(initial: profile))
        let run = RunController(audio: audio, haptics: haptics)
        let router = UIRouter()
        let coordinator = GameCoordinator(player: player, run: run, router: router, audio: audio, haptics: haptics,
                                          ads: MockAdService(), purchases: SimulatedPurchaseService())
        return AppEnvironment(coordinator: coordinator)
    }
}
