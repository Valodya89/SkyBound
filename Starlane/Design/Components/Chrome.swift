import SwiftUI
import StarlaneCore

/// Coins and gems with a "+" that opens the shop.
struct WalletView: View {
    @Environment(GameCoordinator.self) private var coordinator
    var compact = false

    var body: some View {
        let p = coordinator.player.profile
        HStack(spacing: 6) {
            chip(icon: AnyView(CoinIcon(size: 14)), value: GameFormat.compact(p.coins), plus: Theme.flare, plusInk: Theme.flareInk)
            chip(icon: AnyView(GemIcon(size: 14)), value: "\(p.gems)", plus: Theme.ice, plusInk: Theme.iceInk)
        }
        .layoutPriority(1)
    }

    private func chip(icon: AnyView, value: String, plus: Color, plusInk: Color) -> some View {
        Button {
            coordinator.audio.play(.ui)
            coordinator.router.select(.shop)
        } label: {
            HStack(spacing: 6) {
                icon
                Text(value).display(compact ? 16 : 17).monospacedDigit().fixedSize().contentTransition(.numericText())
                Image(systemName: "plus")
                    .font(.system(size: 10, weight: .black))
                    .foregroundStyle(plusInk)
                    .frame(width: 20, height: 20)
                    .background(RoundedRectangle(cornerRadius: 3).fill(plus))
            }
            .padding(.leading, 8).padding(.trailing, 4)
            .frame(height: compact ? 30 : 34)
            .background(RoundedRectangle(cornerRadius: Theme.radiusSmall).fill(Theme.panel))
            .overlay(RoundedRectangle(cornerRadius: Theme.radiusSmall).strokeBorder(Theme.line2, lineWidth: 1))
        }
        .buttonStyle(PressScaleStyle())
    }
}

/// Back chevron, kicker + title, wallet.
struct ScreenHeader: View {
    @Environment(GameCoordinator.self) private var coordinator
    let title: String
    var kicker: String? = nil
    var showsBack = true

    var body: some View {
        HStack(alignment: .center) {
            HStack(spacing: 10) {
                if showsBack {
                    Button {
                        coordinator.audio.play(.ui)
                        coordinator.router.closeSheet()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Theme.text)
                            .frame(width: 36, height: 36)
                            .overlay(RoundedRectangle(cornerRadius: Theme.radiusSmall).strokeBorder(Theme.line2, lineWidth: 1))
                    }
                    .buttonStyle(PressScaleStyle())
                    .accessibilityLabel("Back")
                }
                VStack(alignment: .leading, spacing: 5) {
                    if let kicker { Text(kicker).capsLabel(color: Theme.flare) }
                    Text(title).display(26)
                }
            }
            Spacer(minLength: 8)
            WalletView(compact: true)
        }
    }
}

/// Five destinations. The active one carries a flare bar on top.
struct BottomNav: View {
    @Environment(GameCoordinator.self) private var coordinator
    let active: HubTab

    var body: some View {
        let p = coordinator.player.profile
        HStack(spacing: 0) {
            ForEach(HubTab.allCases) { tab in
                let on = tab == active
                let color = on ? Theme.text : Theme.faint
                Button {
                    coordinator.audio.play(.ui)
                    coordinator.router.select(tab)
                } label: {
                    VStack(spacing: 5) {
                        LineIcon(name: tab.icon, size: 22, color: color, weight: on ? .semibold : .medium)
                        Text(tab.title).capsLabel(9.5, color: color)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .overlay(alignment: .top) {
                        Rectangle().fill(Theme.flare).frame(height: 2).padding(.horizontal, 14).opacity(on ? 1 : 0)
                    }
                    .overlay(alignment: .topTrailing) {
                        if tab.hasBadge(p) { DotBadge().padding(.top, 8).padding(.trailing, 18) }
                    }
                }
                .buttonStyle(PressScaleStyle())
            }
        }
        .padding(.horizontal, 6)
        .padding(.bottom, 2)
        .background(Theme.panel.ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .top) { Rectangle().fill(Theme.line).frame(height: 1) }
    }
}

/// Full-screen page: header, scrolling body, optional pinned footer. Pass `tab` for a tab-root screen: it then
/// has no back chevron, crossfades instead of pushing, and the root view keeps the bottom bar under it.
struct GameScreen<Content: View, Footer: View>: View {
    let title: String
    var kicker: String? = nil
    var tab: HubTab? = nil
    @ViewBuilder var content: Content
    @ViewBuilder var footer: Footer

    init(_ title: String, kicker: String? = nil, tab: HubTab? = nil,
         @ViewBuilder content: () -> Content, @ViewBuilder footer: () -> Footer = { EmptyView() }) {
        self.title = title
        self.kicker = kicker
        self.tab = tab
        self.content = content()
        self.footer = footer()
    }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            VStack(spacing: 0) {
                ScreenHeader(title: title, kicker: kicker, showsBack: tab == nil)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 12)
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 8) { content }
                        .padding(.horizontal, 16)
                        .padding(.top, 4)
                        .padding(.bottom, 24)
                }
                .scrollBounceBehavior(.basedOnSize)
                footer
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
            }
        }
        .transition(tab == nil
                    ? .asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                  removal: .move(edge: .trailing).combined(with: .opacity))
                    : .opacity)
    }
}

/// Icon tile at the leading edge of a row.
struct IconTile: View {
    let symbol: String
    var tint: Color = Theme.muted
    var size: CGFloat = 40

    var body: some View {
        LineIcon(name: symbol, size: size * 0.5, color: tint)
            .frame(width: size, height: size)
            .background(RoundedRectangle(cornerRadius: Theme.radiusSmall).fill(Theme.panel3))
    }
}

/// "icon · title/subtitle · trailing action" row.
struct ItemRow<Trailing: View>: View {
    let symbol: String
    var tint: Color = Theme.muted
    let title: String
    var subtitle: String? = nil
    var tag: Tag? = nil
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 12) {
            IconTile(symbol: symbol, tint: tint, size: 38)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(title).font(.body(13.5, weight: .bold)).foregroundStyle(Theme.text).lineLimit(1)
                    if let tag { tag }
                }
                if let subtitle {
                    Text(subtitle).font(.body(11.5)).foregroundStyle(Theme.muted).lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            trailing
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .panel()
    }
}
