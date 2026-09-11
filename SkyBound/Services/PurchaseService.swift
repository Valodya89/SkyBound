import Foundation
import SkyBoundCore

/// Abstracts the storefront so StoreKit 2 can replace the simulation later.
protocol PurchaseService: AnyObject {
    /// Resolves once the "transaction" is confirmed. The simulated store always succeeds after a short delay.
    func purchase(_ product: StoreProduct) async -> Bool
}

final class SimulatedPurchaseService: PurchaseService {
    func purchase(_ product: StoreProduct) async -> Bool {
        try? await Task.sleep(for: .milliseconds(350))
        return true
    }
}
