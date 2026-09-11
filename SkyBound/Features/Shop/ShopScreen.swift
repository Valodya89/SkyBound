import SwiftUI
import SkyBoundCore

/// "Supply": VIP, gem packs, bundles, boosts and energy. Every purchase is simulated.
struct ShopScreen: View {
    @Environment(GameCoordinator.self) private var coordinator

    var body: some View {
        let p = coordinator.player.profile
        let vipOwned = ShopSystem.isOwned(.vip, profile: p)
        GameScreen("Supply", kicker: "Shop", tab: .shop) {
            Button {
                coordinator.purchase(.vip)
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
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(vipOwned ? "Active" : "$6.99").display(20)
                        Text(vipOwned ? "renews monthly" : "per month").capsLabel(9, color: Theme.faint)
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 14)
                .background(Theme.panel2)
                .overlay(ChamferShape(cut: 14).stroke(Theme.gold, lineWidth: 1))
                .clipShape(ChamferShape(cut: 14))
            }
            .buttonStyle(PressScaleStyle())
            .disabled(vipOwned || coordinator.isPurchasing)

            SectionRule("Gems")
            let packs = StoreProduct.gemPacks
            HStack(spacing: 8) {
                ForEach(packs.prefix(2)) { GemCard(product: $0) }
            }
            HStack(spacing: 8) {
                ForEach(packs.dropFirst(2).prefix(2)) { GemCard(product: $0) }
            }

            SectionRule("Bundles")
            ProductRow(product: .founderBundle, icon: "gift", tint: Theme.flare, tag: Tag("70% off"), strike: "$19.99", kind: .flare)
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
            ItemRow(symbol: "bolt", tint: Theme.flare, title: "Instant refill", subtitle: "Fill energy to \(p.maxEnergy) right now") {
                Button { coordinator.refillEnergy() } label: { PriceLabel(price: EnergySystem.refillPrice) }
                    .buttonStyle(.pill(.ghost))
            }
            let adsLeft = DailySystem.freeGemAdsPerDay - p.freeGemAdsWatchedToday
            ItemRow(symbol: "film", tint: Theme.ice, title: "Free gems", subtitle: "Watch a short video for \(DailySystem.freeGemAdReward) gems · \(max(0, adsLeft)) left today") {
                Button(adsLeft <= 0 ? "Done" : "Watch") { coordinator.watchFreeGemAd() }
                    .buttonStyle(.pill(.ice, disabled: adsLeft <= 0))
                    .disabled(adsLeft <= 0)
            }
            Text("Simulated storefront. Nothing here charges real money.")
                .font(.body(11.5)).foregroundStyle(Theme.faint)
                .padding(.top, 4)
        }
    }
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
                Text(product.priceLabel).display(18, color: Theme.gold)
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
    var strike: String? = nil
    var kind: PillButtonStyle.Kind = .ghost
    var subtitleOverride: String? = nil

    var body: some View {
        let owned = ShopSystem.isOwned(product, profile: coordinator.player.profile)
        ItemRow(symbol: icon, tint: tint, title: product.name, subtitle: subtitleOverride ?? product.detail, tag: owned ? nil : tag) {
            VStack(alignment: .trailing, spacing: 2) {
                if let strike, !owned {
                    Text(strike).font(.body(10)).strikethrough().foregroundStyle(Theme.faint)
                }
                Button(owned ? "Owned" : product.priceLabel) { coordinator.purchase(product) }
                    .buttonStyle(.pill(kind, disabled: owned || coordinator.isPurchasing))
                    .disabled(owned || coordinator.isPurchasing)
            }
        }
    }
}
