import SwiftUI
import StarlaneCore

/// "Supply": VIP, gem packs, bundles, boosts and energy. Real-money rows go through StoreKit;
/// boosts, energy and crates are spent from the in-game wallet.
struct ShopScreen: View {
    @Environment(GameCoordinator.self) private var coordinator

    var body: some View {
        let p = coordinator.player.profile
        let vipOwned = ShopSystem.isOwned(.vip, profile: p)
        GameScreen("Supply", kicker: "Shop", tab: .shop) {
            Button {
                if vipOwned { coordinator.manageSubscription() } else { coordinator.purchase(.vip) }
            } label: {
                HStack(spacing: 14) {
                    LineIcon(name: "crown", size: 22, color: Theme.gold)
                        .frame(width: 44, height: 44)
                        .background(RoundedRectangle(cornerRadius: Theme.radiusSmall).fill(Theme.gold.opacity(0.14)))
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text("VIP Pass").display(22, color: Theme.gold)
                            Tag(vipOwned ? "Active" : "Best value", color: Theme.gold)
                        }
                        Text(StoreProduct.vip.detail).font(.body(11.5)).foregroundStyle(Theme.muted).lineLimit(2)
                        if !vipOwned, let intro = coordinator.introOffer(for: .vip) {
                            Text(intro).capsLabel(9, color: Theme.ice)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(vipOwned ? "Active" : coordinator.priceAmount(for: .vip)).display(20)
                        Text(vipRenewalNote(p)).capsLabel(9, color: Theme.faint)
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 14)
                .background(Theme.panel2)
                .overlay(ChamferShape(cut: 14).stroke(Theme.gold, lineWidth: 1))
                .clipShape(ChamferShape(cut: 14))
            }
            .buttonStyle(PressScaleStyle())
            .disabled(coordinator.isPurchasing)

            SectionRule("Gems")
            let packs = StoreProduct.gemPacks
            HStack(spacing: 8) {
                ForEach(packs.prefix(2)) { GemCard(product: $0) }
            }
            HStack(spacing: 8) {
                ForEach(packs.dropFirst(2).prefix(2)) { GemCard(product: $0) }
            }

            SectionRule("Bundles")
            ProductRow(product: .founderBundle, icon: "gift", tint: Theme.flare, tag: Tag("Best starter"), kind: .flare)
            ProductRow(product: .piggyBank, icon: "banknote", tint: Theme.gold, subtitleOverride: "Fills as you play · \(GameFormat.grouped(ShopSystem.piggyBankValue(p))) coins inside")
            ProductRow(product: .removeAds, icon: "circle.slash", tint: Theme.muted)

            SectionRule("Boosts · spend coins")
            ForEach(BoostKind.allCases) { boost in
                ItemRow(symbol: boost.lineIcon, tint: Color(hex: boost.colorHex), title: boost.name, subtitle: "\(boost.detail) · owned ×\(p.inventoryCount(boost))") {
                    Button { coordinator.buyBoost(boost) } label: { PriceLabel(price: boost.price) }
                        .buttonStyle(.pill(.ghost))
                }
            }

            SectionRule("Energy")
            ItemRow(symbol: "bolt", tint: Theme.flare, title: "Instant refill", subtitle: p.isEnergyFull ? "Energy is already full" : "Fill energy to \(p.maxEnergy) right now") {
                Button { coordinator.refillEnergy() } label: { if p.isEnergyFull { Text("Full") } else { PriceLabel(price: EnergySystem.refillPrice) } }
                    .buttonStyle(.pill(.ghost, disabled: p.isEnergyFull))
                    .disabled(p.isEnergyFull)
            }
            let adsLeft = DailySystem.freeGemAdsPerDay - p.freeGemAdsWatchedToday
            ItemRow(symbol: "film", tint: Theme.ice, title: "Free gems", subtitle: "Watch a short video for \(DailySystem.freeGemAdReward) gems · \(max(0, adsLeft)) left today") {
                Button(adsLeft <= 0 ? "Done" : "Watch") { coordinator.watchFreeGemAd() }
                    .buttonStyle(.pill(.ice, disabled: adsLeft <= 0))
                    .disabled(adsLeft <= 0)
            }
            SectionRule("Purchases")
            ItemRow(symbol: "arrow.clockwise", tint: Theme.muted, title: "Restore purchases",
                    subtitle: "Brings back VIP, Remove Ads and bundles") {
                Button(coordinator.isRestoring ? "…" : "Restore") { coordinator.restorePurchases() }
                    .buttonStyle(.pill(.ghost, disabled: coordinator.isRestoring))
                    .disabled(coordinator.isRestoring)
            }
            // Apple requires the renewal terms to be visible next to an auto-renewable subscription.
            Text(Self.subscriptionTerms)
                .font(.body(11)).foregroundStyle(Theme.faint).lineSpacing(2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 4)
            HStack(spacing: 14) {
                Link("Terms of Use", destination: LegalLinks.terms)
                Link("Privacy Policy", destination: LegalLinks.privacy)
            }
            .font(.body(11, weight: .semibold))
            .foregroundStyle(Theme.muted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 2)
        }
    }

    private static let subscriptionTerms = "VIP Pass is an auto-renewable subscription billed monthly to your Apple Account. It renews automatically unless cancelled at least 24 hours before the end of the current period. Manage or cancel it in Settings › Apple Account › Subscriptions. Gems, bundles and the Piggy Bank are one-time purchases."

    private func vipRenewalNote(_ p: PlayerProfile) -> String {
        guard p.isVIP else { return "per month" }
        guard let date = p.vipRenewalDate else { return "manage" }
        return "renews \(date.formatted(.dateTime.month(.abbreviated).day()))"
    }
}

/// App Store Connect requires both links on any app that sells a subscription.
enum LegalLinks {
    static let terms = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    static let privacy = URL(string: "https://ravosolutions.com/starlane/privacy")!
}

private struct GemCard: View {
    @Environment(GameCoordinator.self) private var coordinator
    let product: StoreProduct

    var body: some View {
        let popular = product.badge == "POPULAR"
        let amount: Int = { if case .gems(let n) = product.grant { return n } else { return 0 } }()
        let bonus = product.detail.split(separator: "·").dropFirst().first.map { $0.trimmingCharacters(in: .whitespaces) }
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                GemIcon(size: 18)
                Text(GameFormat.grouped(amount)).display(28).monospacedDigit()
            }
            Text(bonus ?? "Starter").capsLabel(9, color: bonus == nil ? Theme.faint : Theme.ice)
            HStack {
                Text(coordinator.priceAmount(for: product)).display(18, color: Theme.gold)
                Spacer()
                Button("Buy") { coordinator.purchase(product) }
                    .buttonStyle(.pill(.ghost))
                    .disabled(coordinator.isPurchasing)
            }
            .padding(.top, 6)
        }
        .padding(.horizontal, 12).padding(.top, 14).padding(.bottom, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .panel(border: popular ? Theme.flare : Theme.line)
        .overlay(alignment: .topTrailing) {
            if popular { FilledTag(text: "Popular").padding(.trailing, 10) }
        }
    }
}

private struct ProductRow: View {
    @Environment(GameCoordinator.self) private var coordinator
    let product: StoreProduct
    let icon: String
    var tint: Color = Theme.muted
    var tag: Tag? = nil
    var kind: PillButtonStyle.Kind = .ghost
    var subtitleOverride: String? = nil

    var body: some View {
        let owned = ShopSystem.isOwned(product, profile: coordinator.player.profile)
        ItemRow(symbol: icon, tint: tint, title: product.name, subtitle: subtitleOverride ?? product.detail, tag: owned ? nil : tag) {
            Button(owned ? "Owned" : coordinator.priceLabel(for: product)) { coordinator.purchase(product) }
                .buttonStyle(.pill(kind, disabled: owned || coordinator.isPurchasing))
                .disabled(owned || coordinator.isPurchasing)
        }
    }
}
