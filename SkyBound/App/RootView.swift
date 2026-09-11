import SwiftUI

/// Layer order (bottom → top): SpriteKit scene, deck or run UI, full-screen pages, ads, rewards, share card, toast.
struct RootView: View {
    @Environment(GameCoordinator.self) private var coordinator

    var body: some View {
        let run = coordinator.run
        let router = coordinator.router
        ZStack {
            GameSceneView()

            if run.isInRun {
                RunView()
                    .transition(.opacity)
            } else {
                DeckView()
                    .transition(.opacity.combined(with: .offset(y: 18)))
            }

            if let sheet = router.sheet, !run.isInRun {
                SheetHost(kind: sheet)
                    .zIndex(10)
            }

            if let ad = router.ad {
                MockAdView(request: ad)
                    .zIndex(20)
                    .transition(.opacity)
            }
            if let reward = router.reward {
                RewardPopupView(popup: reward)
                    .zIndex(30)
                    .transition(.opacity)
            }
            if let image = router.shareImage {
                ShareCardOverlay(image: image)
                    .zIndex(35)
                    .transition(.opacity)
            }
            if let toast = router.toast {
                ToastView(message: toast)
                    .zIndex(40)
            }
        }
        .background(Theme.bg)
        .animation(.easeInOut(duration: 0.3), value: run.isInRun)
        .animation(.spring(duration: 0.34, bounce: 0.05), value: router.sheet)
        .animation(.easeOut(duration: 0.25), value: router.reward?.id)
        .animation(.easeOut(duration: 0.25), value: router.ad?.id)
        .animation(.easeOut(duration: 0.22), value: router.toast)
        .animation(.easeOut(duration: 0.25), value: router.shareImage == nil)
        .onAppear { coordinator.appDidBecomeActive() }
    }
}

#Preview {
    RootView().environment(AppEnvironment.preview().coordinator)
}
