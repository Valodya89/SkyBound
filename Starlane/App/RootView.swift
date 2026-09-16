import SwiftUI

/// Layer order (bottom → top): SpriteKit scene, deck or run UI, full-screen pages, ads, rewards, share card,
/// toast, cold-launch splash.
/// The bottom bar is rendered once here, as a safe-area inset under the deck and the tab-root pages, so switching
/// tabs only swaps the page content.
struct RootView: View {
    @Environment(GameCoordinator.self) private var coordinator
    /// Cold-launch only: the splash never comes back when the app returns from the background.
    @State private var showsSplash = true

    var body: some View {
        let run = coordinator.run
        let router = coordinator.router
        let showsNav = !run.isInRun && (router.sheet?.isTabRoot ?? true)
        ZStack {
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
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if showsNav {
                    BottomNav(active: router.tab)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.easeOut(duration: 0.22), value: showsNav)

            if let ad = router.ad {
                MockAdView(request: ad)
                    .zIndex(20)
                    .transition(.opacity)
            } else if router.isAdPending {
                AdLoadingOverlay()
                    .zIndex(20)
            }
            if let reward = router.reward {
                RewardPopupView(popup: reward)
                    .id(reward.id)
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
            if showsSplash {
                SplashView {
                    showsSplash = false
                    // Consent and the ad SDK wait for the splash: ATT is ignored while the app is
                    // not frontmost, and a form over the launch animation looks broken.
                    coordinator.startAdvertising()
                }
                    .zIndex(50)
                    .transition(.opacity)
            }
        }
        .background(Theme.bg)
        .animation(.easeInOut(duration: 0.3), value: run.isInRun)
        .animation(.easeOut(duration: 0.24), value: router.sheet)
        .animation(.easeOut(duration: 0.25), value: router.reward?.id)
        .animation(.easeOut(duration: 0.25), value: router.ad?.id)
        .animation(.easeOut(duration: 0.22), value: router.toast)
        .animation(.easeOut(duration: 0.25), value: router.shareImage == nil)
        .animation(.easeOut(duration: 0.32), value: showsSplash)
        .onAppear { coordinator.appDidBecomeActive() }
    }
}

#Preview {
    RootView().environment(AppEnvironment.preview().coordinator)
}
