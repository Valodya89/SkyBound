import SwiftUI
import StarlaneCore

/// Rockets (collection), Workshop (upgrades) and the Orbital archive (crates).
struct HangarScreen: View {
    enum Tab: Int { case rockets, workshop, archive }
    @Environment(GameCoordinator.self) private var coordinator
    @State private var tab: Int

    init(initialTab: Tab) {
        _tab = State(initialValue: initialTab.rawValue)
    }

    var body: some View {
        GameScreen("Hangar", kicker: ["Rockets", "Workshop", "Archive"][tab], tab: .crates) {
            TabStrip(tabs: ["Rockets", "Workshop", "Archive crates"], selection: $tab)
                .padding(.bottom, 8)
            switch tab {
            case 1: WorkshopSection()
            case 2: ArchiveSection()
            default: RocketsSection()
            }
        }
    }
}

// MARK: - Rockets

private struct RocketsSection: View {
    @Environment(GameCoordinator.self) private var coordinator
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)

    var body: some View {
        let p = coordinator.player.profile
        let skin = p.equippedSkin
        HStack(spacing: 16) {
            RocketMark(size: 96, color: Color(hex: skin.colorHex))
                .frame(width: 110, height: 110)
            VStack(alignment: .leading, spacing: 6) {
                Text(skin.rarity.displayName).capsLabel(color: Color.rarity(skin.rarity))
                Text(skin.name).display(30)
                Text("Cosmetic. Never changes how it flies.").font(.body(12)).foregroundStyle(Theme.muted)
                Text("Flying now").capsLabel(color: Theme.faint)
                    .padding(.horizontal, 14).frame(height: 34)
                    .background(RoundedRectangle(cornerRadius: 3).fill(Theme.panel2))
                    .padding(.top, 6)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: Theme.radius, style: .continuous).fill(Theme.panel)
                BayGrid().clipShape(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
            }
        }
        .overlay(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous).strokeBorder(Theme.line, lineWidth: 1))

        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(SkinCatalog.all) { s in
                SkinTile(skin: s, owned: p.owns(skinID: s.id), equipped: p.equippedSkinID == s.id) {
                    coordinator.equipSkin(s.id)
                }
            }
        }
        .padding(.top, 2)
        Text("\(p.ownedSkinIDs.count) of \(SkinCatalog.all.count) rockets. New ones come from the archive crates, the season and day 7 of the streak.")
            .font(.body(11.5)).foregroundStyle(Theme.faint)
            .padding(.top, 4)
    }
}

/// Faint engineering grid behind the featured rocket.
private struct BayGrid: View {
    var body: some View {
        Canvas { ctx, size in
            var x: CGFloat = 0
            while x < size.width { ctx.fill(Path(CGRect(x: x, y: 0, width: 1, height: size.height)), with: .color(Theme.line.opacity(0.7))); x += 24 }
            var y: CGFloat = 0
            while y < size.height { ctx.fill(Path(CGRect(x: 0, y: y, width: size.width, height: 1)), with: .color(Theme.line.opacity(0.7))); y += 24 }
        }
        .allowsHitTesting(false)
    }
}

private struct SkinTile: View {
    let skin: Skin
    let owned: Bool
    let equipped: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                if owned {
                    RocketMark(size: 34, color: Color(hex: skin.colorHex), accent: .black.opacity(0.25))
                } else {
                    LineIcon(name: "lock", size: 18, color: Theme.faint).frame(height: 34)
                }
                Text(skin.name).capsLabel(8, color: owned ? Theme.text : Theme.faint, tracking: 0.3).minimumScaleFactor(0.6).padding(.horizontal, 3)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 84)
            .panel(raised: owned, border: equipped ? Theme.flare : Theme.line)
            .overlay(alignment: .topLeading) { RarityCorner(rarity: skin.rarity) }
            .overlay(alignment: .bottom) {
                if equipped {
                    FilledTag(text: "Flying").frame(maxWidth: .infinity)
                        .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: 3, bottomTrailingRadius: 3))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
            .opacity(owned ? 1 : 0.55)
        }
        .buttonStyle(PressScaleStyle())
        .disabled(!owned)
        .accessibilityLabel("\(skin.name), \(skin.rarity.displayName)\(owned ? "" : ", locked")")
    }
}

// MARK: - Workshop

private struct WorkshopSection: View {
    @Environment(GameCoordinator.self) private var coordinator

    var body: some View {
        let p = coordinator.player.profile
        HStack {
            Text("Permanent tuning, paid in coins.").font(.body(13)).foregroundStyle(Theme.muted)
            Spacer()
            Text("5 levels each").capsLabel(color: Theme.faint)
        }
        .padding(.horizontal, 2).padding(.bottom, 4)
        ForEach(UpgradeKind.allCases) { kind in
            let level = p.upgradeLevel(kind)
            let maxed = UpgradeSystem.isMaxed(kind, profile: p)
            HStack(spacing: 12) {
                IconTile(symbol: kind.lineIcon, size: 40)
                VStack(alignment: .leading, spacing: 5) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(kind.name).display(20)
                        Text("LV \(level)").capsLabel(color: Theme.faint)
                    }
                    Text(kind.detail).font(.body(11.5)).foregroundStyle(Theme.muted).lineLimit(1)
                    SegmentBar(filled: level, total: kind.maxLevel, height: 6, segmentWidth: 22).padding(.top, 2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Button { coordinator.buyUpgrade(kind) } label: {
                    if maxed { Text("Max") } else { PriceLabel(price: .coins(UpgradeSystem.price(kind, profile: p))) }
                }
                .buttonStyle(.pill(.ghost, disabled: maxed))
                .disabled(maxed)
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .panel()
        }
        SectionRule("Energy")
        let capMaxed = !EnergySystem.canRaiseCap(p)
        ItemRow(symbol: "bolt", tint: Theme.flare, title: "Energy cap +1", subtitle: capMaxed ? "Now \(p.maxEnergy) · every slot bought" : "Now \(p.maxEnergy) · \(EnergySystem.purchasableSlots - p.energySlotsBought) slots left") {
            Button { coordinator.raiseEnergyCap() } label: {
                if capMaxed { Text("Max") } else { PriceLabel(price: EnergySystem.capUpgradePrice(for: p)) }
            }
            .buttonStyle(.pill(.ghost, disabled: capMaxed))
            .disabled(capMaxed)
        }
    }
}

// MARK: - Archive crates

private struct ArchiveSection: View {
    @Environment(GameCoordinator.self) private var coordinator
    private let pullColumns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 5)

    var body: some View {
        let p = coordinator.player.profile
        HStack(alignment: .firstTextBaseline) {
            Text("Orbital archive").display(22)
            Spacer()
            Text("Season 1").capsLabel(color: Theme.faint)
        }
        Text("\(SkinCatalog.all.count) rockets. Cosmetic only. A ×10 opening guarantees a Rare or better; the \(GachaSystem.pityLimit)th opening without a Legendary is one.")
            .font(.body(12)).foregroundStyle(Theme.muted)
            .padding(.bottom, 4)
        SectionRule("Pity", trailing: "\(p.pityCounter) / \(GachaSystem.pityLimit) to Legendary")
        SegmentBar(filled: p.pityCounter, total: GachaSystem.pityLimit, height: 6, spacing: 2)
        HStack(spacing: 8) {
            Button { coordinator.pull(count: 1) } label: {
                HStack { Text("Open ×1"); Spacer(); AmountLabel(GachaSystem.singlePrice.amount, .gems, size: 15, tint: Theme.muted) }
            }
            .buttonStyle(.outline())
            .frame(width: 150)
            Button { coordinator.pull(count: 10) } label: {
                HStack { Text("Open ×10"); Spacer(); AmountLabel(GachaSystem.tenPrice.amount, .gems, size: 15, tint: Theme.flareInk) }
            }
            .buttonStyle(.primary(height: 48, size: 22))
        }
        .padding(.top, 4)
        HStack(spacing: 6) {
            ForEach(Rarity.allCases, id: \.self) { r in
                HStack(spacing: 6) {
                    Text("\(Int((r.dropRate * 100).rounded()))%").display(16, color: Color.rarity(r))
                    Text(r.displayName).capsLabel(8.5, color: Theme.faint)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .panel()
            }
        }
        if !coordinator.lastPulls.isEmpty {
            SectionRule("Last opening")
            LazyVGrid(columns: pullColumns, spacing: 8) {
                ForEach(Array(coordinator.lastPulls.enumerated()), id: \.element.id) { i, pull in
                    PullTile(pull: pull, delay: Double(i) * 0.055)
                }
            }
        }
    }
}

private struct PullTile: View {
    let pull: PullResult
    let delay: Double
    @State private var shown = false

    var body: some View {
        RocketMark(size: 30, color: Color(hex: pull.skin.colorHex), accent: .black.opacity(0.25))
            .frame(maxWidth: .infinity)
            .frame(height: 62)
            .panel(raised: true)
            .overlay(alignment: .topLeading) { RarityCorner(rarity: pull.skin.rarity) }
            .overlay(alignment: .bottom) {
                if pull.isNew { FilledTag(text: "New").padding(.bottom, 3) }
            }
            .clipShape(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
            .scaleEffect(shown ? 1 : 0.2)
            .opacity(shown ? 1 : 0)
            .onAppear {
                withAnimation(.spring(duration: 0.4, bounce: 0.45).delay(delay)) { shown = true }
            }
            .id(pull.id)
    }
}
