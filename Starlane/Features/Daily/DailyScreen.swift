import SwiftUI
import StarlaneCore

/// Login streak, fortune spin and today's course on one page.
struct DailyScreen: View {
    enum Focus { case streak, spin, course }
    @Environment(GameCoordinator.self) private var coordinator
    let focus: Focus
    @State private var resetText = ""

    var body: some View {
        let p = coordinator.player.profile
        let reward = DailySystem.todayReward(p)
        ScrollViewReader { proxy in
            GameScreen("Daily", kicker: "Resets in \(resetText)") {
                SectionRule("Login streak", trailing: "Day 7 pays a rocket").id(Focus.streak)
                let shownDay = DailySystem.displayDay(p)
                HStack(spacing: 5) {
                    ForEach(DailyLoginReward.calendar) { r in
                        StreakDay(reward: r, state: p.loginClaimedToday
                                  ? (r.day <= shownDay ? .past : .future)
                                  : (r.day < shownDay ? .past : r.day == shownDay ? .today : .future))
                    }
                }
                Button { coordinator.claimDailyLogin() } label: {
                    HStack {
                        Text(p.loginClaimedToday ? "Day \(shownDay) claimed · back tomorrow" : "Claim day \(shownDay)")
                        Spacer()
                        if !p.loginClaimedToday {
                            if reward.skinID != nil {
                                Text("Rocket").font(.body(13, weight: .bold)).tracking(0.5)
                            } else {
                                AmountLabel(reward.gems > 0 ? reward.gems : reward.coins, reward.gems > 0 ? .gems : .coins, size: 15, tint: Theme.flareInk)
                            }
                        }
                    }
                }
                .buttonStyle(.primary(height: 50, size: 22))
                .disabled(p.loginClaimedToday)

                SectionRule("Fortune spin", trailing: p.wheelSpunToday ? "Free spin used" : "Free spin ready", trailingColor: p.wheelSpunToday ? Theme.faint : Theme.flare)
                    .padding(.top, 6)
                    .id(Focus.spin)
                HStack(spacing: 16) {
                    WheelView(angle: coordinator.wheelAngle)
                        .frame(width: 140, height: 140)
                    VStack(spacing: 8) {
                        Text("One free spin a day. Extra spins cost a short ad.")
                            .font(.body(12.5)).foregroundStyle(Theme.muted)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Button { coordinator.spinWheel(free: true) } label: {
                            HStack { Text("Spin free"); Spacer(); Text(p.wheelSpunToday ? "Used" : "1 left").font(.body(12, weight: .semibold)).tracking(0.7).textCase(.uppercase) }
                        }
                        .buttonStyle(.outline(Theme.flare, color: Theme.flare, height: 44))
                        .disabled(p.wheelSpunToday || coordinator.isWheelSpinning)
                        Button { coordinator.spinWheel(free: false) } label: {
                            HStack {
                                Text("Spin again")
                                Spacer()
                                HStack(spacing: 4) { LineIcon(name: "film", size: 14, color: Theme.muted); Text("AD") }
                                    .font(.body(12, weight: .semibold)).tracking(0.7).foregroundStyle(Theme.muted)
                            }
                        }
                        .buttonStyle(.outline(color: Theme.muted, height: 44))
                        .disabled(coordinator.isWheelSpinning)
                    }
                }
                .padding(.horizontal, 14).padding(.vertical, 12)
                .panel()

                SectionRule("Today's course", trailing: "Seed \(p.dailyChallengeSeed)")
                    .padding(.top, 6)
                    .id(Focus.course)
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Same stars for everyone").display(22)
                        Spacer()
                        Text("1 attempt").capsLabel(color: Theme.ice)
                    }
                    Text("Every obstacle and pickup falls in the same place for every pilot. No boosts, no revives.")
                        .font(.body(12)).foregroundStyle(Theme.muted)
                    HStack {
                        if p.dailyChallengeDone {
                            HStack(spacing: 10) {
                                Text("Your run").capsLabel(color: Theme.faint)
                                Text(GameFormat.grouped(p.dailyChallengeScore)).display(18).monospacedDigit()
                            }
                            Spacer()
                            Text("Played today").capsLabel(color: Theme.faint)
                        } else {
                            if let leader = DailySystem.challengeBoard(p).first {
                                HStack(spacing: 10) {
                                    Text("Leader").capsLabel(color: Theme.faint)
                                    Text("\(leader.name) · \(GameFormat.grouped(leader.score))").display(18).monospacedDigit()
                                }
                            }
                            Spacer()
                            Button("Fly the course") { coordinator.launch(.daily) }.buttonStyle(.pill(.ice))
                        }
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 14)
                .panel()
                SectionRule("Today's board")
                LeaderboardList(rows: DailySystem.challengeBoard(p))
            }
            .onAppear {
                if focus != .streak {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        withAnimation { proxy.scrollTo(focus, anchor: .top) }
                    }
                }
            }
        }
        .onAppear { coordinator.preload(.wheelSpin) }
        .task {
            while !Task.isCancelled {
                resetText = GameFormat.longClock(GameFormat.secondsUntilMidnight(from: coordinator.player.clock.now))
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }
}

private struct StreakDay: View {
    enum State { case past, today, future }
    let reward: DailyLoginReward
    let state: State

    var body: some View {
        VStack(spacing: 5) {
            Text("Day \(reward.day)").capsLabel(8.5, color: state == .today ? Theme.flare : Theme.faint, tracking: 0.4)
            Group {
                if reward.skinID != nil {
                    LineIcon(name: "star", size: 16, color: Theme.gold)
                } else if reward.gems > 0 {
                    GemIcon(size: 16)
                } else {
                    CoinIcon(size: 16)
                }
            }
            .frame(height: 16)
            Text(reward.skinID != nil ? "Rocket" : reward.gems > 0 ? "\(reward.gems)" : "\(reward.coins)")
                .display(14).monospacedDigit().minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 70)
        .panel(raised: state != .future, border: state == .past ? Theme.ice : state == .today ? Theme.flare : Theme.line)
        .overlay(alignment: .topTrailing) {
            if state == .past { LineIcon(name: "checkmark", size: 11, color: Theme.ice, weight: .bold).padding(3) }
        }
        .opacity(state == .future ? 0.6 : 1)
    }
}

/// Eight-slice wheel. Alternating dark slices with one flare highlight; spins with `angle`.
private struct WheelView: View {
    let angle: Double

    var body: some View {
        let prizes = WheelPrize.wheel
        let seg = 360.0 / Double(prizes.count)
        ZStack {
            ZStack {
                ForEach(prizes) { prize in
                    let start = Double(prize.id) * seg
                    WheelSlice(startAngle: .degrees(start - 90), endAngle: .degrees(start + seg - 90))
                        .fill(prize.id == 3 ? Theme.flare : prize.id % 2 == 0 ? Theme.panel3 : Color(hex: "#2A2233"))
                        .overlay(WheelSlice(startAngle: .degrees(start - 90), endAngle: .degrees(start + seg - 90)).stroke(Theme.bg, lineWidth: 2))
                    HStack(spacing: 2) {
                        Text(prizeText(prize)).display(13, color: prize.id == 3 ? Theme.flareInk : Theme.text)
                        if let c = prize.kind.currency {
                            CurrencyIcon(currency: c, size: 9)
                        }
                    }
                    .offset(y: -44)
                    .rotationEffect(.degrees(start + seg / 2))
                }
                Circle().fill(Theme.bg).frame(width: 28, height: 28)
                    .overlay(Circle().stroke(Theme.line2, lineWidth: 2))
            }
            .rotationEffect(.degrees(angle))
            .animation(.timingCurve(0.15, 0.9, 0.2, 1, duration: 3.4), value: angle)
            Triangle().fill(Theme.text).frame(width: 12, height: 10)
                .frame(maxHeight: .infinity, alignment: .top)
        }
    }

    private func prizeText(_ prize: WheelPrize) -> String {
        switch prize.kind {
        case .coins(let n): "\(n)"
        case .gems(let n): "\(n)"
        case .boost: "×1"
        }
    }

    private struct Triangle: Shape {
        func path(in rect: CGRect) -> Path {
            var p = Path()
            p.move(to: CGPoint(x: rect.midX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            p.closeSubpath()
            return p
        }
    }
}

private struct WheelSlice: Shape {
    let startAngle: Angle
    let endAngle: Angle

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let c = CGPoint(x: rect.midX, y: rect.midY)
        p.move(to: c)
        p.addArc(center: c, radius: rect.width / 2, startAngle: startAngle, endAngle: endAngle, clockwise: false)
        p.closeSubpath()
        return p
    }
}

/// Ranked rows shared by the daily board and the weekly leaderboard.
struct LeaderboardList: View {
    let rows: [DailySystem.BoardRow]

    var body: some View {
        VStack(spacing: 6) {
            ForEach(Array(rows.enumerated()), id: \.element.id) { i, row in
                HStack(spacing: 12) {
                    RankNumber(rank: i)
                    LetterAvatar(name: row.name)
                    HStack(spacing: 6) {
                        Text(row.isPlayer ? "Pilot" : row.name).font(.body(13.5, weight: row.isPlayer ? .bold : .medium)).foregroundStyle(Theme.text).lineLimit(1)
                        if row.isPlayer { Text("You").capsLabel(color: Theme.flare) }
                    }
                    Spacer()
                    Text(GameFormat.grouped(row.score)).display(20, color: row.isPlayer ? Theme.text : Theme.muted).monospacedDigit()
                }
                .padding(.horizontal, 12)
                .frame(height: 48)
                .panel(raised: row.isPlayer, border: row.isPlayer ? Theme.flare : Theme.line)
            }
        }
    }
}
