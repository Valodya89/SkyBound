import SwiftUI
import SkyBoundCore

/// Weekly board, duels and badges.
struct RanksScreen: View {
    enum Tab: Int { case weekly, duels, badges }
    @Environment(GameCoordinator.self) private var coordinator
    @State private var tab: Int

    init(initialTab: Tab) {
        _tab = State(initialValue: initialTab.rawValue)
    }

    var body: some View {
        GameScreen("Ranks", kicker: "This week", tab: .rank) {
            TabStrip(tabs: ["Weekly", "Duels", "Badges"], selection: $tab)
                .padding(.bottom, 8)
            switch tab {
            case 1: DuelsSection()
            case 2: BadgesSection()
            default: WeeklySection()
            }
        }
    }
}

private struct WeeklySection: View {
    @Environment(GameCoordinator.self) private var coordinator

    var body: some View {
        let rows = coordinator.player.leaderboard
        let me = rows.firstIndex { $0.isPlayer } ?? 0
        let gap = me > 0 ? rows[me - 1].score - rows[me].score : 0
        HStack {
            Text("Your best this week").font(.body(12.5)).foregroundStyle(Theme.muted)
            Spacer()
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("#\(me + 1)").display(22).monospacedDigit()
                if gap > 0 { Text("\(GameFormat.grouped(gap)) to #\(me)").capsLabel(color: Theme.faint).monospacedDigit() }
            }
        }
        .padding(.horizontal, 2).padding(.bottom, 4)
        LeaderboardList(rows: rows)
    }
}

private struct DuelsSection: View {
    @Environment(GameCoordinator.self) private var coordinator

    var body: some View {
        let p = coordinator.player.profile
        let open = p.duels.filter { $0.status == .open }
        let past = Array(p.duels.filter { $0.status != .open }.suffix(4))
        Text("Async score battles. \(Duel.attempts) attempts to beat their run.")
            .font(.body(12.5)).foregroundStyle(Theme.muted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 2).padding(.bottom, 4)
        if open.isEmpty, past.isEmpty {
            Text("No duels yet. Challenge someone below.")
                .font(.body(12.5)).foregroundStyle(Theme.faint)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 2)
        }
        ForEach(open + past) { duel in
            DuelRow(duel: duel) { coordinator.launch(.classic) }
        }
        SectionRule("Challenge a rival").padding(.top, 8)
        ForEach(Array(DuelSystem.challengeable.enumerated()), id: \.element) { _, name in
            let active = DuelSystem.hasOpenDuel(with: name, profile: p)
            HStack(spacing: 12) {
                LetterAvatar(name: name, size: 32)
                VStack(alignment: .leading, spacing: 3) {
                    Text(name).font(.body(13, weight: .semibold)).foregroundStyle(Theme.text)
                    HStack(spacing: 4) {
                        Text("\(Duel.attempts) attempts · win \(Duel.winReward)")
                        GemIcon(size: 11)
                    }
                    .font(.body(11)).foregroundStyle(Theme.muted)
                }
                Spacer()
                Button(active ? "In progress" : "Challenge") { coordinator.challenge(name) }
                    .buttonStyle(.pill(.ghost, disabled: active))
                    .disabled(active)
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .panel()
        }
    }
}

private struct DuelRow: View {
    let duel: Duel
    let play: () -> Void

    var body: some View {
        let color: Color = duel.status == .open ? Theme.ice : duel.status == .won ? Theme.flare : Theme.faint
        HStack(spacing: 12) {
            LetterAvatar(name: duel.rivalName, size: 36)
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(duel.rivalName).font(.body(13.5, weight: .bold)).foregroundStyle(Theme.text)
                    if duel.status == .open {
                        Text("\(duel.triesLeft) attempts left").capsLabel(color: Theme.faint).monospacedDigit()
                    }
                }
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(GameFormat.grouped(duel.rivalScore)).display(20, color: Theme.muted).monospacedDigit()
                    Text("vs").capsLabel(color: Theme.faint)
                    Text(GameFormat.grouped(duel.yourBest)).display(20).monospacedDigit()
                }
            }
            Spacer()
            switch duel.status {
            case .open: Button("Fly", action: play).buttonStyle(.pill(.ice))
            case .won: Text("Won").capsLabel(color: color)
            case .lost: Text("Lost").capsLabel(color: color)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous).fill(Theme.panel))
        .overlay(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous).strokeBorder(Theme.line, lineWidth: 1))
        .overlay(alignment: .leading) {
            Rectangle().fill(color).frame(width: 3).padding(.vertical, 1)
                .clipShape(UnevenRoundedRectangle(topLeadingRadius: Theme.radius, bottomLeadingRadius: Theme.radius))
        }
    }
}

private struct BadgesSection: View {
    @Environment(GameCoordinator.self) private var coordinator

    var body: some View {
        let p = coordinator.player.profile
        let done = p.achievements.filter(\.isDone).count
        HStack {
            Text("Earned \(done) of \(p.achievements.count)").font(.body(12.5)).foregroundStyle(Theme.muted)
            Spacer()
        }
        .padding(.horizontal, 2).padding(.bottom, 4)
        ForEach(p.achievements) { a in
            HStack(spacing: 12) {
                LineIcon(name: a.isDone ? "medal" : "circle.dashed", size: 22, color: a.isDone ? Theme.flare : Theme.faint)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(a.title).font(.body(13.5, weight: .bold)).foregroundStyle(Theme.text)
                        Spacer()
                        Text("\(GameFormat.grouped(min(a.progress, a.goal))) / \(GameFormat.grouped(a.goal))").capsLabel(9.5, color: Theme.faint).monospacedDigit()
                    }
                    ProgressBar(fraction: a.fraction, color: a.isDone ? Theme.flare : Theme.ice)
                    Text(a.detail).font(.body(11.5)).foregroundStyle(Theme.muted)
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .panel(border: a.isDone ? Theme.flare : Theme.line)
        }
    }
}
