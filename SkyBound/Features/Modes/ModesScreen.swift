import SwiftUI
import SkyBoundCore

/// "Choose a run": mode list, boost strip, launch.
struct ModesScreen: View {
    @Environment(GameCoordinator.self) private var coordinator

    var body: some View {
        let p = coordinator.player.profile
        let mode = p.selectedMode.config.isHidden ? GameMode.classic : p.selectedMode
        GameScreen("Choose a run", kicker: "Flight plan") {
            ForEach(GameMode.selectable) { m in
                ModeRow(mode: m, isSelected: m == mode, isLocked: !m.isUnlocked(atLevel: p.level), best: p.best(for: m)) {
                    coordinator.selectMode(m)
                }
            }
            SectionRule("Equip one boost", trailing: "Number = owned")
            HStack(spacing: 6) {
                BoostOption(symbol: "circle.slash", name: "None", count: nil, isSelected: coordinator.equippedBoost == nil) {
                    coordinator.equipBoost(nil)
                }
                ForEach(BoostKind.allCases) { boost in
                    BoostOption(symbol: boost.lineIcon, name: boost.name, count: p.inventoryCount(boost), isSelected: coordinator.equippedBoost == boost) {
                        coordinator.equipBoost(boost)
                    }
                }
            }
        } footer: {
            Button {
                coordinator.play()
            } label: {
                HStack(spacing: 6) {
                    Text("Launch")
                    Spacer()
                    HStack(spacing: 6) {
                        Text("\(mode.config.name.split(separator: " ").first.map(String.init) ?? "") · \(mode.config.energyCost)")
                        EnergyIcon(size: 12, tint: Theme.flareInk)
                    }
                    .font(.body(13, weight: .bold))
                    .tracking(0.5)
                }
            }
            .buttonStyle(.primary())
        }
    }
}

private struct ModeRow: View {
    let mode: GameMode
    let isSelected: Bool
    let isLocked: Bool
    let best: Int
    let action: () -> Void

    var body: some View {
        let c = mode.config
        Button(action: action) {
            HStack(spacing: 12) {
                IconTile(symbol: mode.lineIcon, tint: isSelected ? Theme.flare : Theme.muted, size: 40)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(c.name).display(20)
                        if c.hasBosses { Tag("Bosses") }
                    }
                    Text(c.tagline).font(.body(12)).foregroundStyle(Theme.muted).lineLimit(1)
                    Text("Best \(GameFormat.grouped(best)) · Payout ×\(GameFormat.multiplier(c.payout))")
                        .capsLabel(9.5, color: Theme.faint).monospacedDigit()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if isLocked {
                    HStack(spacing: 6) {
                        LineIcon(name: "lock", size: 14, color: Theme.faint)
                        Text("LVL \(c.unlockLevel)").capsLabel(color: Theme.faint)
                    }
                } else {
                    HStack(spacing: 4) {
                        Text("\(c.energyCost)").display(20).monospacedDigit()
                        EnergyIcon(size: 13)
                    }
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .panel(raised: isSelected, border: isSelected ? Theme.flare : Theme.line)
            .cornerBrackets(visible: isSelected)
            .opacity(isLocked ? 0.5 : 1)
        }
        .buttonStyle(PressScaleStyle())
        .disabled(isLocked)
    }
}

private struct BoostOption: View {
    let symbol: String
    let name: String
    let count: Int?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        let empty = count == 0
        Button(action: action) {
            VStack(spacing: 6) {
                LineIcon(name: symbol, size: 20, color: isSelected ? Theme.flare : Theme.muted)
                Text(name).capsLabel(9, color: isSelected ? Theme.text : Theme.muted).minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 64)
            .panel(raised: isSelected, border: isSelected ? Theme.flare : Theme.line)
            .overlay(alignment: .topTrailing) {
                if let count { Text("\(count)").display(13, color: Theme.ice).padding(.top, 4).padding(.trailing, 6) }
            }
            .opacity(empty ? 0.45 : 1)
        }
        .buttonStyle(PressScaleStyle())
        .disabled(empty)
    }
}

extension BoostKind {
    /// Line icon for the boost strip and shop.
    var lineIcon: String {
        switch self {
        case .magnet: "dot.radiowaves.left.and.right"
        case .slowmo: "hourglass"
        case .doubleCoin: "dollarsign"
        case .shield: "shield"
        case .headStart: "paperplane"
        }
    }
}

extension UpgradeKind {
    var lineIcon: String {
        switch self {
        case .coinValue: "dollarsign"
        case .magnetField: "dot.radiowaves.left.and.right"
        case .autoShield: "shield"
        case .scoreCore: "chart.line.uptrend.xyaxis"
        case .grazer: "bolt"
        }
    }
}
