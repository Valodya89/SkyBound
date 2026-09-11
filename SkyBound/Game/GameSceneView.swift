import SpriteKit
import SwiftUI
import SkyBoundCore

/// Hosts the single SpriteKit scene that sits behind every screen (hub backdrop and gameplay).
///
/// The scene is created exactly once, on first appearance. Creating it in `init` would build a new scene every
/// time SwiftUI re-initialises this view, and even a discarded scene reports its placeholder size to the
/// shared controller.
struct GameSceneView: View {
    @Environment(GameCoordinator.self) private var coordinator
    @State private var scene: RunScene?

    var body: some View {
        ZStack {
            if let scene {
                SpriteView(scene: scene, preferredFramesPerSecond: 60, options: [.ignoresSiblingOrder])
                    .ignoresSafeArea()
                    .onChange(of: coordinator.player.profile.equippedSkinID) { _, id in
                        scene.applySkin(SkinCatalog.skin(id))
                    }
            } else {
                Theme.ink.ignoresSafeArea()
            }
        }
        .onAppear {
            guard scene == nil else { return }
            let s = RunScene(controller: coordinator.run)
            s.applySkin(coordinator.player.profile.equippedSkin)
            scene = s
        }
    }
}
