import SwiftUI
import SkyBoundCore

struct ResultsView: View {
    @Environment(GameCoordinator.self) private var coordinator

    var body: some View {
        let run = coordinator.run
        let p = coordinator.player.profile
        let s = run.summary
        let outcome = run.outcome
        let mode = run.simulation.config.mode
        let timeUp = s?.endedByTimer ?? false
        let crashed = run.simulation.hasCrashed
        let tier = SeasonPass.tier(for: p)
        let tierProgress = SeasonPass.tierProgress(for: p)
        ZStack {
            Theme.bg.opacity(0.82).ignoresSafeArea()
            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(timeUp ? "Time's up" : "Run over") · \(mode.config.name)").capsLabel(color: Theme.flare)
                            Text(timeUp ? "Clean sprint. Bank it." : crashed ? "You clipped an asteroid at \(GameFormat.grouped(s?.distance ?? 0)) m." : "Banked from the pause menu at \(GameFormat.grouped(s?.distance ?? 0)) m.")
                                .font(.body(14)).foregroundStyle(Theme.muted)
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            Text(GameFormat.grouped(s?.score ?? 0))
                                .display(96)
                                .monospacedDigit()
                                .minimumScaleFactor(0.6)
                            Text("Final score").capsLabel()
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .overlay(alignment: .topTrailing) {
                            if let outcome, outcome.isPersonalBest || outcome.isNewModeBest {
                                BestStamp(text: outcome.isPersonalBest ? "New best" : "Mode best").padding(.top, 8)
                            }
                        }
                        VStack(spacing: 12) {
                            LedgerRow(key: "Distance", value: "\(GameFormat.grouped(s?.distance ?? 0)) m")
                            LedgerRow(key: "Coins collected", value: GameFormat.grouped(run.simulation.coins), color: Theme.gold)
                            LedgerRow(key: "Best combo", value: "×\(s?.bestCombo ?? 1)")
                            LedgerRow(key: "Near misses", value: "\(s?.nearMisses ?? 0)")
                            LedgerRow(key: "Bosses cleared", value: "\(s?.bossesDefeated ?? 0)")
                            LedgerRow(key: "Sectors reached", value: "\(s?.zonesReached ?? 1)")
                        }
                        .padding(16)
                        .panel()
                        HStack(spacing: 8) {
                            bankChip { CoinIcon(size: 13); Text("+\(GameFormat.grouped(run.simulation.coins))").display(17).monospacedDigit() }
                            bankChip { Text("+\(outcome?.passXPEarned ?? 0)").display(17).monospacedDigit(); Text("Season").capsLabel(9, color: Theme.ice) }
                            bankChip { Text("+\(outcome?.xpEarned ?? 0)").display(17).monospacedDigit(); Text("XP").capsLabel(9, color: Theme.ice) }
                        }
                        VStack(spacing: 8) {
                            HStack {
                                Text("Season · Tier \(String(format: "%02d", tier))").capsLabel(color: Theme.faint)
                                Spacer()
                                Text(tier >= SeasonPass.tierCount ? "Max tier" : "\(SeasonPass.xpPerTier - tierProgress) SP to next tier").capsLabel(color: Theme.faint).monospacedDigit()
                            }
                            ProgressBar(fraction: Double(tierProgress) / Double(SeasonPass.xpPerTier), color: Theme.ice)
                        }
                        .padding(.horizontal, 2)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 16)
                }
                VStack(spacing: 8) {
                    if run.canRevive || run.canDoublePayout || run.reviveWasOffered {
                        HStack(spacing: 8) {
                            if run.canRevive {
                                Button { coordinator.revive() } label: { adLabel("Revive") }
                                    .buttonStyle(.outline(Theme.ice, color: Theme.ice))
                                    .overlay(alignment: .bottomLeading) {
                                        GeometryReader { g in
                                            Rectangle().fill(Theme.ice).frame(width: g.size.width * run.reviveFraction, height: 3)
                                                .frame(maxHeight: .infinity, alignment: .bottom)
                                        }
                                        .allowsHitTesting(false)
                                    }
                                    .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall))
                            } else if run.reviveWasOffered {
                                // Keep the slot so "Launch again" never jumps under a finger mid-tap.
                                Button {} label: { Text("Revive closed").frame(maxWidth: .infinity) }
                                    .buttonStyle(.outline(color: Theme.faint))
                                    .disabled(true)
                            }
                            if run.canDoublePayout {
                                Button { coordinator.doubleCoins() } label: { adLabel("2× coins") }
                                    .buttonStyle(.outline())
                            }
                        }
                    }
                    Button {
                        coordinator.playAgain()
                    } label: {
                        HStack(spacing: 6) {
                            Text(mode == .daily ? "Back to deck" : "Launch again")
                            Spacer()
                            if mode != .daily {
                                HStack(spacing: 6) {
                                    Text("\(mode.config.name.split(separator: " ").first.map(String.init) ?? "") · \(mode.config.energyCost)")
                                    EnergyIcon(size: 12, tint: Theme.flareInk)
                                }
                                .font(.body(13, weight: .bold)).tracking(0.5)
                            }
                        }
                    }
                    .buttonStyle(.primary())
                    HStack(spacing: 28) {
                        Button { share() } label: {
                            HStack(spacing: 6) { LineIcon(name: "square.and.arrow.up", size: 15, color: Theme.muted); Text("Share run card") }
                        }
                        Button { coordinator.returnToHub() } label: {
                            HStack(spacing: 6) { LineIcon(name: "house", size: 15, color: Theme.muted); Text("Back to deck") }
                        }
                    }
                    .font(.body(13, weight: .semibold))
                    .foregroundStyle(Theme.muted)
                    .padding(.top, 8)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
            }
        }
        .animation(.easeOut(duration: 0.25), value: run.canRevive)
        .animation(.easeOut(duration: 0.25), value: run.canDoublePayout)
    }

    private func adLabel(_ text: String) -> some View {
        HStack {
            Text(text)
            Spacer()
            HStack(spacing: 4) { LineIcon(name: "film", size: 14, color: Theme.muted); Text("AD") }
                .font(.body(12, weight: .semibold)).tracking(0.7).foregroundStyle(Theme.muted)
        }
    }

    private func bankChip<C: View>(@ViewBuilder _ content: () -> C) -> some View {
        HStack(spacing: 6) { content() }
            .frame(maxWidth: .infinity)
            .frame(height: 36)
            .panel(raised: true)
    }

    private func share() {
        guard let s = coordinator.run.summary else { return }
        coordinator.audio.play(.ui)
        let card = ShareCardView(summary: s, biome: coordinator.run.simulation.biome, skin: coordinator.player.profile.equippedSkin)
        let renderer = ImageRenderer(content: card)
        renderer.scale = 2
        coordinator.router.shareImage = renderer.uiImage
    }
}

/// Rotated outline stamp next to the score.
private struct BestStamp: View {
    let text: String

    var body: some View {
        Text(text)
            .capsLabel(11, color: Theme.flare, tracking: 1.8)
            .padding(.horizontal, 8).padding(.vertical, 6)
            .background(Theme.bg.opacity(0.6))
            .overlay(Rectangle().strokeBorder(Theme.flare, lineWidth: 2))
            .rotationEffect(.degrees(-6))
    }
}
