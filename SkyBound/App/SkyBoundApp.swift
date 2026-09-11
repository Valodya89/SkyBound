import SwiftUI

@main
struct SkyBoundApp: App {
    @State private var environment = AppEnvironment.live()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(environment.coordinator)
                .preferredColorScheme(.dark)
                .statusBarHidden(true)
                .persistentSystemOverlays(.hidden)
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active: environment.coordinator.appDidBecomeActive()
            case .inactive, .background: environment.coordinator.appWillResignActive()
            @unknown default: break
            }
        }
    }
}
