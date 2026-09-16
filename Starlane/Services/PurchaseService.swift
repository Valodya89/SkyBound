import Foundation
import StarlaneCore

/// How a purchase attempt ended.
enum PurchaseOutcome: Sendable, Equatable {
    /// The App Store charged the player and the transaction was verified. Granting happens through
    /// `PurchaseService.onTransaction`, not here.
    case success
    /// The player dismissed the sheet.
    case cancelled
    /// Ask to Buy / SCA: the transaction will arrive later through `onTransaction`.
    case pending
    /// Nothing was charged. The message is safe to show.
    case failed(String)
}

/// One verified transaction that has not been granted yet.
struct StoreTransactionInfo: Sendable {
    let product: StoreProduct
    /// Stable identifier used to make granting idempotent.
    let transactionID: String
    /// `true` when this is a restore or a re-download rather than a fresh charge.
    let isRestore: Bool
}

/// Localised storefront copy for one product, as returned by StoreKit.
struct StoreDisplay: Sendable, Hashable {
    /// e.g. "£6.99" — already formatted for the player's storefront.
    var price: String
    /// e.g. "/mo" for a subscription, empty otherwise.
    var periodSuffix: String = ""
    /// Free-trial or intro-offer line, when the player is eligible.
    var introOffer: String?

    var priceWithPeriod: String { price + periodSuffix }
}

/// Abstracts the storefront so the app layer never imports StoreKit directly.
protocol PurchaseService: AnyObject {
    /// Localised display info keyed by product identifier. Empty until `start()` has loaded the catalog.
    var display: [String: StoreDisplay] { get }
    /// `true` once the product catalog came back from the App Store.
    var isReady: Bool { get }

    /// Called for every verified transaction — a fresh purchase, a restore, an Ask to Buy approval or a
    /// purchase made on another device. Return `true` once the entitlement has been persisted; the
    /// transaction is only finished after that, so an interrupted grant is retried on the next launch.
    var onTransaction: ((StoreTransactionInfo) -> Bool)? { get set }
    /// Called whenever the App Store's view of ownership changes, including when a subscription lapses
    /// or a purchase is refunded.
    var onEntitlements: ((StoreEntitlements) -> Void)? { get set }

    /// Loads the catalog, replays unfinished transactions and starts listening for updates.
    func start()
    func purchase(_ product: StoreProduct) async -> PurchaseOutcome
    /// Re-reads entitlements and replays undelivered transactions. Cheap and silent — safe to call every
    /// time the app comes to the foreground, so a renewal or cancellation made elsewhere is picked up.
    func refresh() async
    /// Restores non-consumables and the subscription. Unlike `refresh()` this asks the App Store to sync,
    /// which may prompt for the Apple Account, so only call it from an explicit Restore button.
    /// Returns `false` when the App Store refused.
    func restore() async -> Bool
    /// Opens the system sheet for managing the VIP subscription.
    func showManageSubscriptions() async
}

/// Offline stand-in used by previews, tests and SwiftUI previews. Always succeeds, never charges.
final class SimulatedPurchaseService: PurchaseService {
    var display: [String: StoreDisplay] = [:]
    private(set) var isReady = true
    var onTransaction: ((StoreTransactionInfo) -> Bool)?
    var onEntitlements: ((StoreEntitlements) -> Void)?
    private var counter = 0

    func start() {
        display = Dictionary(uniqueKeysWithValues: StoreProduct.all.map {
            ($0.id, StoreDisplay(price: $0.priceLabel))
        })
    }

    func purchase(_ product: StoreProduct) async -> PurchaseOutcome {
        try? await Task.sleep(for: .milliseconds(350))
        counter += 1
        _ = onTransaction?(StoreTransactionInfo(product: product, transactionID: "sim-\(product.id)-\(counter)", isRestore: false))
        return .success
    }

    func refresh() async {}

    func restore() async -> Bool { true }

    func showManageSubscriptions() async {}
}
