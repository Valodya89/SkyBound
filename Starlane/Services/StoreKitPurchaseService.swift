import Foundation
import StoreKit
import UIKit
import StarlaneCore

/// StoreKit 2 storefront.
///
/// Responsibilities, in the order they matter:
/// 1. Load the catalog from `StoreProduct.allIDs` so the UI can show localised prices.
/// 2. Run a `Transaction.updates` listener for the whole app lifetime — Ask to Buy approvals, purchases
///    made on another device and renewals arrive there, not from `purchase()`.
/// 3. Only finish a transaction once the app has persisted the grant, so an interrupted grant is replayed
///    on the next launch instead of being lost.
/// 4. Rebuild entitlements from `Transaction.currentEntitlements` so a lapsed subscription or a refund
///    takes the perk away again.
final class StoreKitPurchaseService: PurchaseService {
    private(set) var display: [String: StoreDisplay] = [:]
    private(set) var isReady = false
    var onTransaction: ((StoreTransactionInfo) -> Bool)?
    var onEntitlements: ((StoreEntitlements) -> Void)?

    private var products: [String: Product] = [:]
    private var updatesTask: Task<Void, Never>?
    private var loadTask: Task<Void, Never>?
    /// Backoff for the catalog load; the App Store can be unreachable at launch.
    private var loadAttempt = 0

    deinit { updatesTask?.cancel() }

    func start() {
        guard updatesTask == nil else { return }
        // Started before the catalog load: a transaction can arrive before products are known.
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                guard let self else { return }
                await handle(update, isRestore: false)
            }
        }
        loadCatalog()
        Task { [weak self] in await self?.refresh() }
    }

    // MARK: - Catalog

    private func loadCatalog() {
        guard loadTask == nil else { return }
        loadTask = Task { [weak self] in
            guard let self else { return }
            defer { loadTask = nil }
            do {
                let fetched = try await Product.products(for: StoreProduct.allIDs)
                products = Dictionary(uniqueKeysWithValues: fetched.map { ($0.id, $0) })
                display = await Self.makeDisplay(for: fetched)
                isReady = !fetched.isEmpty
                if fetched.count != StoreProduct.allIDs.count {
                    let missing = Set(StoreProduct.allIDs).subtracting(fetched.map(\.id))
                    print("[Store] products missing from App Store Connect: \(missing.sorted().joined(separator: ", "))")
                }
                loadAttempt = 0
            } catch {
                // Offline or a transient StoreKit error: retry a few times, then leave the fallback labels up.
                loadAttempt += 1
                guard loadAttempt <= 4 else { return }
                try? await Task.sleep(for: .seconds(Double(loadAttempt) * 2))
                loadCatalog()
            }
        }
    }

    private static func makeDisplay(for products: [Product]) async -> [String: StoreDisplay] {
        var out: [String: StoreDisplay] = [:]
        for product in products {
            var entry = StoreDisplay(price: product.displayPrice)
            if let subscription = product.subscription {
                entry.periodSuffix = "/" + Self.periodSuffix(subscription.subscriptionPeriod)
                if let offer = subscription.introductoryOffer,
                   await subscription.isEligibleForIntroOffer {
                    entry.introOffer = Self.introDescription(offer)
                }
            }
            out[product.id] = entry
        }
        return out
    }

    private static func periodSuffix(_ period: Product.SubscriptionPeriod) -> String {
        let unit: String
        switch period.unit {
        case .day: unit = "day"
        case .week: unit = "wk"
        case .month: unit = "mo"
        case .year: unit = "yr"
        @unknown default: unit = "period"
        }
        return period.value > 1 ? "\(period.value) \(unit)" : unit
    }

    private static func introDescription(_ offer: Product.SubscriptionOffer) -> String {
        let length = "\(offer.period.value) \(Self.periodSuffix(offer.period))"
        switch offer.paymentMode {
        case .freeTrial: return "\(length) free, then"
        case .payAsYouGo: return "\(offer.displayPrice)/\(Self.periodSuffix(offer.period)) for \(offer.periodCount) periods, then"
        case .payUpFront: return "\(offer.displayPrice) for the first \(length), then"
        default: return "Intro offer available"
        }
    }

    // MARK: - Buying

    func purchase(_ product: StoreProduct) async -> PurchaseOutcome {
        guard let storeProduct = products[product.id] else {
            loadCatalog()
            return .failed("This item is not available right now. Check your connection and try again.")
        }
        do {
            // `appAccountToken` ties the transaction to this install for server-side validation later.
            let result = try await storeProduct.purchase(options: [.appAccountToken(Self.appAccountToken)])
            switch result {
            case .success(let verification):
                await handle(verification, isRestore: false)
                await refreshEntitlements()
                return .success
            case .userCancelled:
                return .cancelled
            case .pending:
                return .pending
            @unknown default:
                return .failed("The App Store returned an unexpected response.")
            }
        } catch let error as StoreKitError {
            switch error {
            case .userCancelled: return .cancelled
            case .networkError: return .failed("No connection to the App Store.")
            case .notAvailableInStorefront: return .failed("This item is not sold in your region.")
            case .notEntitled: return .failed("This account cannot make purchases.")
            default: return .failed("The purchase could not be completed.")
            }
        } catch {
            return .failed("The purchase could not be completed.")
        }
    }

    func refresh() async {
        await replayUnfinished()
        await refreshEntitlements()
    }

    func restore() async -> Bool {
        do {
            try await AppStore.sync()
        } catch {
            // A cancelled password prompt lands here too; the refresh below still runs.
            await refresh()
            return false
        }
        await refresh()
        return true
    }

    func showManageSubscriptions() async {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }) else { return }
        try? await AppStore.showManageSubscriptions(in: scene)
    }

    // MARK: - Transactions

    /// Grants a verified transaction and finishes it. Unverified transactions are left unfinished so
    /// StoreKit offers them again rather than granting on a forged payload.
    private func handle(_ result: VerificationResult<Transaction>, isRestore: Bool) async {
        guard case .verified(let transaction) = result else {
            print("[Store] dropped an unverified transaction")
            return
        }
        // A revoked or expired transaction is ownership news, not a grant.
        guard transaction.revocationDate == nil else {
            await transaction.finish()
            await refreshEntitlements()
            return
        }
        guard let product = StoreProduct.product(id: transaction.productID) else {
            // Unknown product (e.g. removed from the catalog): finishing stops it being replayed forever.
            await transaction.finish()
            return
        }
        let info = StoreTransactionInfo(product: product,
                                        transactionID: String(transaction.id),
                                        isRestore: isRestore || transaction.purchaseDate < Date(timeIntervalSinceNow: -300))
        let persisted = onTransaction?(info) ?? false
        // Only finish once the grant is on disk; otherwise it is replayed on the next launch.
        if persisted { await transaction.finish() }
    }

    /// Transactions StoreKit still considers undelivered — a grant that failed to persist last time, or a
    /// purchase made while the app was closed.
    private func replayUnfinished() async {
        for await result in Transaction.unfinished {
            await handle(result, isRestore: true)
        }
    }

    private func refreshEntitlements() async {
        var entitlements = StoreEntitlements()
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result, transaction.revocationDate == nil else { continue }
            switch transaction.productID {
            case StoreProduct.vip.id:
                // `currentEntitlements` already filters out expired subscriptions; the grace period is
                // honoured by the App Store, so anything still listed here is an active VIP.
                if let expiration = transaction.expirationDate, expiration < Date() { continue }
                entitlements.isVIP = true
                entitlements.vipExpiresAt = transaction.expirationDate
            case StoreProduct.removeAds.id:
                entitlements.adsRemoved = true
            case StoreProduct.founderBundle.id:
                entitlements.founderBundleOwned = true
            default:
                continue
            }
        }
        onEntitlements?(entitlements)
    }

    /// Stable per-install identifier sent with every purchase so receipts can be matched to a player later.
    private static let appAccountToken: UUID = {
        let key = "starlane.appAccountToken"
        if let existing = UserDefaults.standard.string(forKey: key), let uuid = UUID(uuidString: existing) {
            return uuid
        }
        let fresh = UUID()
        UserDefaults.standard.set(fresh.uuidString, forKey: key)
        return fresh
    }()
}
