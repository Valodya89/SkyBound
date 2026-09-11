import SwiftUI
import SkyBoundCore

/// The home screen: pilot strip and readouts over the live world, the launch deck at the bottom.
struct DeckView: View {
    @Environment(GameCoordinator.self) private var coordinator

    var body: some View {
        VStack(spacing: 0) {
            PilotStrip()
                .padding(.horizontal, 16)
                .padding(.top, 8)
            readouts
                .padding(.horizontal, 16)
                .padding(.top, 14)
            Spacer(minLength: 0)
            if coordinator.player.isOfferVisible {
                OfferTicket()
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            LaunchDeck()
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
                .background {
                    LinearGradient(colors: [Theme.bg.opacity(0), Theme.bg], startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 0.45))
                        .padding(.top, -150)
                        .allowsHitTesting(false)
                }
            BottomNav(active: .home)
        }
    }

    private var readouts: some View {
        let p = coordinator.player.profile
        let biome = coordinator.run.simulation.biome
        let mode = p.selectedMode.config.isHidden ? GameMode.classic : p.selectedMode
        return HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text(biome.zoneLabel).capsLabel(color: .white.opacity(0.7))
                Text(biome.name).display(22, color: Color(hex: "#FFE1C2"))
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                Text("Best · \(mode.config.name.split(separator: " ").first.map(String.init) ?? "")").capsLabel(color: .white.opacity(0.7))
                Text(GameFormat.grouped(p.best(for: mode))).display(22, color: Color(hex: "#FFE1C2")).monospacedDigit()
            }
        }
        .shadow(color: .black.opacity(0.35), radius: 4, y: 2)
    }
}

/// Avatar, name, level and XP on the left; wallet and settings on the right.
struct PilotStrip: View {
    @Environment(GameCoordinator.self) private var coordinator

    var body: some View {
        let p = coordinator.player.profile
        HStack(spacing: 10) {
            RocketMark(size: 26, color: Color(hex: p.equippedSkin.colorHex))
                .frame(width: 40, height: 40)
                .background(RoundedRectangle(cornerRadius: Theme.radiusSmall).fill(Theme.panel))
                .overlay(RoundedRectangle(cornerRadius: Theme.radiusSmall).strokeBorder(Theme.line2, lineWidth: 1))
            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(p.displayName).font(.body(14, weight: .bold)).foregroundStyle(Theme.text)
                    Text("LVL \(p.level)").capsLabel(color: Theme.flare)
                    if p.isVIP { LineIcon(name: "crown", size: 12, color: Theme.gold, weight: .bold) }
                }
                HStack(spacing: 6) {
                    ProgressBar(fraction: Progression.fraction(for: p), color: Theme.ice, height: 3).frame(width: 56)
                    Text("\(p.xp) / \(Progression.xpNeeded(forLevel: p.level))").capsLabel(9, color: Theme.faint).monospacedDigit()
                }
            }
            Spacer(minLength: 6)
            WalletView(compact: true)
            Button {
                coordinator.audio.play(.ui)
                coordinator.router.open(.settings)
            } label: {
                LineIcon(name: "gearshape", size: 16, color: Theme.muted)
                    .frame(width: 30, height: 30)
                    .background(RoundedRectangle(cornerRadius: Theme.radiusSmall).fill(Theme.panel))
                    .overlay(RoundedRectangle(cornerRadius: Theme.radiusSmall).strokeBorder(Theme.line2, lineWidth: 1))
            }
            .buttonStyle(PressScaleStyle())
            .accessibilityLabel("Settings")
        }
    }
}

/// Founder's bundle, shown as a slim ticket while the timer runs.
struct OfferTicket: View {
    @Environment(GameCoordinator.self) private var coordinator

    var body: some View {
        Button {
            coordinator.audio.play(.ui)
            coordinator.router.select(.shop)
        } label: {
            HStack(spacing: 0) {
                Rectangle().fill(Theme.flare).frame(width: 6)
                HStack(spacing: 12) {
                    LineIcon(name: "gift", size: 18, color: Theme.flare)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Founder's Bundle").font(.body(12.5, weight: .bold)).foregroundStyle(Theme.text).lineLimit(1)
                        Text("1,200 gems · Gilded Comet · 3 boosts").font(.body(11)).foregroundStyle(Theme.muted).lineLimit(1).minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("$5.99").display(18, color: Theme.gold)
                        Text("\(GameFormat.clock(coordinator.player.offerSecondsLeft)) left").capsLabel(9, color: Theme.faint).monospacedDigit()
                    }
                    .padding(.leading, 12)
                    .overlay(alignment: .leading) {
                        Rectangle().fill(.clear).frame(width: 1)
                            .overlay(Line().stroke(style: StrokeStyle(lineWidth: 1, dash: [3, 3])).foregroundStyle(Theme.line2))
                    }
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
            }
            .frame(maxWidth: 340)
            .fixedSize(horizontal: false, vertical: true)
            .background(RoundedRectangle(cornerRadius: Theme.radiusSmall).fill(Theme.panel))
            .overlay(RoundedRectangle(cornerRadius: Theme.radiusSmall).strokeBorder(Theme.line2, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall))
        }
        .buttonStyle(PressScaleStyle())
    }

    private struct Line: Shape {
        func path(in rect: CGRect) -> Path {
            var p = Path()
            p.move(to: CGPoint(x: rect.midX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
            return p
        }
    }
}

/// Energy, mode selector, launch and the daily strip.
struct LaunchDeck: View {
    @Environment(GameCoordinator.self) private var coordinator

    var body: some View {
        let p = coordinator.player.profile
        let mode = p.selectedMode.config.isHidden ? GameMode.classic : p.selectedMode
        let canLaunch = EnergySystem.canLaunch(mode, profile: p)
        VStack(spacing: 8) {
            energyRow(p)
            modeSelector(mode, profile: p)
            Button {
                coordinator.play()
            } label: {
                HStack(spacing: 6) {
                    Text("Launch")
                    Spacer()
                    HStack(spacing: 6) {
                        Text("\(mode.config.energyCost)")
                        EnergyIcon(size: 12, tint: Theme.flareInk)
                        Text(canLaunch ? "· Ready" : "· Low energy")
                    }
                    .font(.body(13, weight: .bold))
                    .tracking(0.5)
                }
            }
            .buttonStyle(.primary())
            DailyStrip()
        }
    }

    private func energyRow(_ p: PlayerProfile) -> some View {
        HStack(spacing: 10) {
            Text("Energy").capsLabel()
            SegmentBar(filled: p.energy, total: p.maxEnergy, height: 8, segmentWidth: p.maxEnergy > 8 ? 12 : 22)
            Text("\(p.energy) / \(p.maxEnergy)").display(16).monospacedDigit()
            Text(p.isEnergyFull ? "Full" : "").capsLabel(color: Theme.faint)
            Spacer()
            if !p.isEnergyFull {
                Text("1 in \(GameFormat.clock(p.energyTimer))").capsLabel(color: Theme.faint).monospacedDigit()
            }
        }
    }

    private func modeSelector(_ mode: GameMode, profile p: PlayerProfile) -> some View {
        let unlocked = GameMode.selectable.filter { $0.isUnlocked(atLevel: p.level) }
        let index = unlocked.firstIndex(of: mode) ?? 0
        func step(_ d: Int) {
            guard !unlocked.isEmpty else { return }
            let next = unlocked[(index + d + unlocked.count) % unlocked.count]
            coordinator.selectMode(next)
        }
        return HStack(spacing: 0) {
            Button { step(-1) } label: {
                LineIcon(name: "chevron.left", size: 22, color: Theme.muted, weight: .semibold).frame(width: 40, height: 52)
            }
            .buttonStyle(PressScaleStyle())
            .accessibilityLabel("Previous mode")
            Button {
                coordinator.audio.play(.ui)
                coordinator.router.open(.modes)
            } label: {
                VStack(spacing: 5) {
                    Text(mode.config.name).display(24)
                    Text(mode.config.tagline).font(.body(12)).foregroundStyle(Theme.muted).lineLimit(1)
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Button { step(1) } label: {
                LineIcon(name: "chevron.right", size: 22, color: Theme.muted, weight: .semibold).frame(width: 40, height: 52)
            }
            .buttonStyle(PressScaleStyle())
            .accessibilityLabel("Next mode")
        }
        .padding(.horizontal, 6)
        .frame(height: 64)
        .panel()
    }
}

/// Streak, spin and daily course in one row.
struct DailyStrip: View {
    @Environment(GameCoordinator.self) private var coordinator

    var body: some View {
        let p = coordinator.player.profile
        let reward = DailySystem.todayReward(p)
        let rewardText = reward.skinID != nil ? "Claim rocket" : reward.gems > 0 ? "Claim \(reward.gems) gems" : "Claim \(reward.coins)"
        HStack(spacing: 8) {
            cell(icon: "calendar", kicker: "Day \(p.loginStreakDay)", value: p.loginClaimedToday ? "Claimed" : rewardText, dot: !p.loginClaimedToday) {
                coordinator.router.open(.login)
            }
            cell(icon: "circle.hexagongrid", kicker: "Spin", value: p.wheelSpunToday ? "Used today" : "Free spin", dot: !p.wheelSpunToday) {
                coordinator.router.open(.wheel)
            }
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let left = GameFormat.longClock(GameFormat.secondsUntilMidnight(from: context.date))
                cell(icon: "timer", kicker: "Course", value: p.dailyChallengeDone ? "Done" : left, dot: false) {
                    coordinator.router.open(.dailyChallenge)
                }
            }
        }
    }

    private func cell(icon: String, kicker: String, value: String, dot: Bool, action: @escaping () -> Void) -> some View {
        Button {
            coordinator.audio.play(.ui)
            action()
        } label: {
            HStack(spacing: 8) {
                LineIcon(name: icon, size: 18, color: Theme.muted)
                VStack(alignment: .leading, spacing: 4) {
                    Text(kicker).capsLabel(9, color: Theme.faint)
                    Text(value).font(.body(12, weight: .semibold)).foregroundStyle(Theme.text).monospacedDigit().lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 10)
            .frame(height: 56)
            .panel()
            .overlay(alignment: .topTrailing) { if dot { DotBadge().padding(6) } }
        }
        .buttonStyle(PressScaleStyle())
    }
}
