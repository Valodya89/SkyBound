import Foundation
import StarlaneCore

enum AdKind: Sendable {
    case rewarded
    case interstitial

    /// Seconds before the skip/claim button unlocks.
    var gateSeconds: Int {
        switch self {
        case .rewarded: 5
        case .interstitial: 4
        }
    }
}

/// A request to show an ad. The UI presents it; `onComplete` fires when the player claims/skips.
struct AdRequest: Identifiable {
    let id = UUID()
    let kind: AdKind
    let creative: MockAd
    let onComplete: @MainActor () -> Void
}

/// Picks creatives for the simulated ad network. Swap for a real SDK adapter without touching the UI.
protocol AdService: AnyObject {
    func makeRequest(kind: AdKind, onComplete: @escaping @MainActor () -> Void) -> AdRequest
}

final class MockAdService: AdService {
    private var rng = SystemRandomSource()

    func makeRequest(kind: AdKind, onComplete: @escaping @MainActor () -> Void) -> AdRequest {
        let creative = MockAd.catalog[rng.nextIndex(count: MockAd.catalog.count)]
        return AdRequest(kind: kind, creative: creative, onComplete: onComplete)
    }
}
