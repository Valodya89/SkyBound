import SwiftUI
import SkyBoundCore

struct SeasonScreen: View {
    @Environment(GameCoordinator.self) private var coordinator
    @State private var resetText = ""

    var body: some View {
        let p = coordinator.player.profile
        let tier = SeasonPass.tier(for: p)
        let progress = SeasonPass.tierProgress(for: p)
        GameScreen("Season 1", kicker: "Skyward", tab: .pass) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("Tier \(String(format: "%02d", tier))").display(30)
                        Text("of \(SeasonPass.tierCount)").capsLabel(color: Theme.faint)
                    }
                    Spacer()
                    Text("\(progress) / \(SeasonPass.xpPerTier) SP").capsLabel().monospacedDigit()
                }
                ProgressBar(fraction: Double(progress) / Double(SeasonPass.xpPerTier), color: Theme.flare, height: 6)
                Text(p.passPremium ? "Premium track. Both rows are yours at every tier." : "Free track. Premium unlocks both rows at every tier.")
                    .font(.body(12)).foregroundStyle(Theme.muted)
            }
            .padding(.horizontal, 16).padding(.vertical, 14)
            .panel()

            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(1...SeasonPass.tierCount, id: \.self) { t in
                            TierColumn(tier: t, profile: p) { premium in coordinator.claimTier(t, premium: premium) }
                                .id(t)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .onAppear { proxy.scrollTo(max(1, min(SeasonPass.tierCount, tier + 1)), anchor: .center) }
            }
            HStack(spacing: 10) {
                Text("Free").capsLabel(color: Theme.ice)
                Ruler()
                Text("Premium").capsLabel(color: Theme.gold)
            }
            if !p.passPremium {
                Button { coordinator.unlockPremiumPass() } label: {
                    HStack {
                        Text("Unlock premium")
                        Spacer()
                        HStack(spacing: 5) {
                            AmountLabel(SeasonPass.premiumPrice.amount, .gems, size: 15, tint: Theme.flareInk)
                            Text("· All \(SeasonPass.tierCount) tiers")
                        }
                        .font(.body(13, weight: .bold)).tracking(0.5)
                    }
                }
                .buttonStyle(.primary(Theme.gold, height: 52, size: 24))
            }

            SectionRule("Today's missions", trailing: "Reset \(resetText)")
            ForEach(p.missions) { m in
                MissionRow(mission: m) { coordinator.claimMission(m.id) }
            }
        }
        .task {
            while !Task.isCancelled {
                resetText = GameFormat.longClock(GameFormat.secondsUntilMidnight(from: coordinator.player.clock.now))
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }
}

private struct MissionRow: View {
    let mission: Mission
    let claim: () -> Void

    var body: some View {
        let m = mission
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .firstTextBaseline) {
                    Text(m.title).font(.body(13.5, weight: .bold)).foregroundStyle(Theme.text).lineLimit(1)
                    Spacer()
                    Text("+\(SeasonPass.missionClaimSP) SP · \(m.reward.label)").capsLabel(9, color: Theme.ice)
                }
                ProgressBar(fraction: m.fraction, color: m.isDone ? Theme.flare : Theme.ice)
            }
            if m.isClaimed {
                Text("Done").capsLabel(color: Theme.faint)
            } else if m.canClaim {
                Button("Claim", action: claim).buttonStyle(.pill(.flare))
            } else {
                Text("\(GameFormat.grouped(min(m.progress, m.goal))) / \(GameFormat.grouped(m.goal))").capsLabel(color: Theme.faint).monospacedDigit()
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .panel(border: m.canClaim ? Theme.flare : Theme.line)
    }
}

private struct TierColumn: View {
    let tier: Int
    let profile: PlayerProfile
    let claim: (Bool) -> Void

    var body: some View {
        let current = SeasonPass.tier(for: profile)
        let reached = tier <= current
        let isNext = tier == current + 1
        VStack(spacing: 6) {
            Text(String(format: "%02d", tier))
                .display(16, color: isNext ? Theme.flare : reached ? Theme.text : Theme.faint)
                .padding(.bottom, 2)
                .overlay(alignment: .bottom) { Rectangle().fill(Theme.flare).frame(height: 2).opacity(isNext ? 1 : 0) }
            TierBox(reward: SeasonPass.reward(tier: tier, premium: false), reached: reached,
                    claimed: profile.claimedFreeTiers.contains(tier), locked: false, premium: false) { claim(false) }
            TierBox(reward: SeasonPass.reward(tier: tier, premium: true), reached: reached && profile.passPremium,
                    claimed: profile.claimedPremiumTiers.contains(tier), locked: !profile.passPremium, premium: true) { claim(true) }
        }
        .frame(width: 62)
    }
}

private struct TierBox: View {
    let reward: TierReward
    let reached: Bool
    let claimed: Bool
    let locked: Bool
    let premium: Bool
    let action: () -> Void

    var body: some View {
        let claimable = reached && !claimed && !locked
        let accent = premium ? Theme.gold : Theme.ice
        Button(action: action) {
            VStack(spacing: 5) {
                if locked {
                    LineIcon(name: "lock", size: 14, color: Theme.faint)
                } else if let c = reward.currency {
                    CurrencyIcon(currency: c, size: 16)
                } else {
                    LineIcon(name: "shippingbox", size: 16, color: Color(hex: reward.tintHex))
                }
                Text(locked ? "" : reward.label).capsLabel(8.5, color: Theme.muted, tracking: 0.3).monospacedDigit()
            }
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .panel(raised: reached && !locked, border: claimable || (claimed && !locked) ? accent : Theme.line)
            .overlay(alignment: .topTrailing) {
                if claimed { LineIcon(name: "checkmark", size: 11, color: accent, weight: .bold).padding(3) }
            }
        }
        .buttonStyle(PressScaleStyle())
        .disabled(!claimable)
    }
}
