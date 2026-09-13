import SwiftUI
import StarlaneCore

/// Everything drawn over the scene during a run: HUD, boss bar, sector banner, pause and results.
struct RunView: View {
    @Environment(GameCoordinator.self) private var coordinator

    var body: some View {
        let run = coordinator.run
        ZStack {
            RunInputLayer()
            GeometryReader { geo in
                ZStack(alignment: .top) {
                    VStack(spacing: 14) {
                        RunHUD()
                        if let name = run.hud.bossName {
                            BossBar(name: name, health: run.hud.bossHealth).transition(.opacity)
                        }
                        // Tucked under the HUD, well above the horizon (42% of the screen) where obstacles spawn.
                        if let biome = run.biomeBanner {
                            SectorBanner(biome: biome)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                    BuffStack()
                        .padding(.trailing, 16)
                        .padding(.top, geo.size.height * 0.53)
                        .frame(maxWidth: .infinity, alignment: .trailing)

                    if run.showControlHint, run.phase == .playing || run.phase == .countdown {
                        ControlHintRow()
                            .padding(.horizontal, 16)
                            .frame(maxHeight: .infinity, alignment: .bottom)
                            .padding(.bottom, 12)
                            .transition(.opacity)
                    }
                }
            }
            .allowsHitTesting(false)
            .opacity(run.phase == .results ? 0 : 1)

            if run.phase == .playing {
                Button {
                    coordinator.audio.play(.ui)
                    run.pause()
                } label: {
                    LineIcon(name: "pause.fill", size: 18, color: Theme.text, weight: .bold)
                        .frame(width: 44, height: 44)
                        .background(RoundedRectangle(cornerRadius: Theme.radiusSmall).fill(Theme.bg.opacity(0.6)))
                        .overlay(RoundedRectangle(cornerRadius: Theme.radiusSmall).strokeBorder(.white.opacity(0.16), lineWidth: 1))
                }
                .accessibilityLabel("Pause")
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(.trailing, 16)
                .padding(.top, 8)
            }

            if let label = run.countdownLabel {
                CountdownView(label: label).allowsHitTesting(false)
            }
            if run.phase == .paused {
                PauseOverlay().transition(.opacity)
            }
            if run.phase == .results {
                ResultsView().transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.25), value: run.phase)
        .animation(.easeOut(duration: 0.25), value: run.hud.bossName)
        .animation(.easeOut(duration: 0.4), value: run.showControlHint)
    }
}

/// Swipe left/right to change lane, up to climb, down to dive; tap a side to move that way.
struct RunInputLayer: View {
    static let swipeDistance: CGFloat = 18
    static let tapDistance: CGFloat = 10
    @Environment(GameCoordinator.self) private var coordinator
    @State private var start: CGPoint?
    @State private var acted = false

    var body: some View {
        GeometryReader { geo in
            Color.clear
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0, coordinateSpace: .local)
                        .onChanged { v in
                            if start == nil {
                                start = v.startLocation
                                acted = false
                            }
                            guard !acted, let s = start else { return }
                            let dx = v.location.x - s.x, dy = v.location.y - s.y
                            if abs(dx) > RunInputLayer.swipeDistance, abs(dx) > abs(dy) {
                                coordinator.run.moveLane(dx > 0 ? 1 : -1)
                                acted = true
                            } else if abs(dy) > RunInputLayer.swipeDistance, abs(dy) > abs(dx) {
                                if dy < 0 { coordinator.run.jump() } else { coordinator.run.duck() }
                                acted = true
                            }
                        }
                        .onEnded { v in
                            let travel = hypot(v.translation.width, v.translation.height)
                            // A short flick that never crossed the swipe threshold is a tap; anything longer is ignored
                            // rather than misread as a lane change.
                            if !acted, travel < RunInputLayer.tapDistance, coordinator.run.acceptsTaps {
                                coordinator.run.moveLane(v.location.x < geo.size.width / 2 ? -1 : 1)
                            }
                            start = nil
                            acted = false
                        }
                )
        }
        .ignoresSafeArea()
    }
}

struct RunHUD: View {
    @Environment(GameCoordinator.self) private var coordinator

    var body: some View {
        let hud = coordinator.run.hud
        let timed = coordinator.run.simulation.mode.isTimed
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Score").capsLabel(color: .white.opacity(0.7))
                Text(GameFormat.grouped(hud.score))
                    .display(60)
                    .monospacedDigit()
                    .shadow(color: .black.opacity(0.35), radius: 0, y: 2)
                HStack(spacing: 8) {
                    Text("×\(hud.combo)").display(22, color: Theme.flare).monospacedDigit()
                    Text("Combo").capsLabel(color: .white.opacity(0.7))
                    ProgressBar(fraction: Double(hud.combo % 10) / 10, color: Theme.flare, height: 4, track: .black.opacity(0.4))
                        .frame(width: 64)
                }
                .padding(.top, 4)
                .opacity(hud.combo > 1 ? 1 : 0)
                .animation(.easeOut(duration: 0.18), value: hud.combo)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                if timed {
                    Text(hud.timerText).display(26, color: hud.timerWarning ? Theme.flare : Theme.text).monospacedDigit()
                        .shadow(color: .black.opacity(0.35), radius: 0, y: 2)
                    Text("Time left").capsLabel(color: .white.opacity(0.7))
                } else {
                    HStack(alignment: .lastTextBaseline, spacing: 3) {
                        Text(GameFormat.grouped(hud.distance)).display(26).monospacedDigit()
                        Text("m").display(16, color: .white.opacity(0.7))
                    }
                    .shadow(color: .black.opacity(0.35), radius: 0, y: 2)
                    Text("Distance").capsLabel(color: .white.opacity(0.7))
                }
            }
            .padding(.top, 54)
        }
        .shadow(color: .black.opacity(0.25), radius: 3, y: 1)
    }
}

/// Active buffs, stacked on the right edge.
struct BuffStack: View {
    @Environment(GameCoordinator.self) private var coordinator

    var body: some View {
        let hud = coordinator.run.hud
        VStack(alignment: .trailing, spacing: 6) {
            if hud.hasShield { chip { LineIcon(name: "shield", size: 16, color: Theme.ice); Text("Shield").capsLabel(color: Theme.ice) } }
            if hud.magnetSeconds > 0 {
                chip {
                    LineIcon(name: "dot.radiowaves.left.and.right", size: 16, color: Theme.flare)
                    Text("\(hud.magnetSeconds)s").display(16).monospacedDigit()
                    ProgressBar(fraction: Double(hud.magnetSeconds) / Double(max(hud.magnetTotalSeconds, 1)), color: Theme.flare, height: 4, track: .white.opacity(0.18)).frame(width: 36)
                }
            }
            if hud.slowmoSeconds > 0 {
                chip {
                    LineIcon(name: "hourglass", size: 16, color: Theme.ice)
                    Text("\(hud.slowmoSeconds)s").display(16).monospacedDigit()
                }
            }
            if hud.doubleCoins { chip { LineIcon(name: "dollarsign", size: 16, color: Theme.gold); Text("2×").display(16, color: Theme.gold) } }
            if hud.isVIP { chip { LineIcon(name: "crown", size: 16, color: Theme.gold); Text("VIP").capsLabel(color: Theme.gold) } }
        }
    }

    private func chip<C: View>(@ViewBuilder _ content: () -> C) -> some View {
        HStack(spacing: 8) { content() }
            .padding(.horizontal, 10)
            .frame(height: 34)
            .background(RoundedRectangle(cornerRadius: Theme.radiusSmall).fill(Theme.bg.opacity(0.6)))
            .overlay(RoundedRectangle(cornerRadius: Theme.radiusSmall).strokeBorder(.white.opacity(0.16), lineWidth: 1))
    }
}

struct BossBar: View {
    let name: String
    let health: Double

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text(name).capsLabel(color: Theme.text)
                Spacer()
                Text("\(Int((health * 100).rounded()))%").capsLabel(color: .white.opacity(0.7)).monospacedDigit()
            }
            SegmentBar(filled: Int((health * 10).rounded(.up)), total: 10, color: Theme.flare, height: 6)
        }
        .shadow(color: .black.opacity(0.4), radius: 3, y: 1)
    }
}

struct SectorBanner: View {
    let biome: Biome
    @State private var phase = 0.0

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 12) {
                Ruler().opacity(0.6)
                Text(biome.zoneLabel).capsLabel(color: .white.opacity(0.8))
                Ruler().opacity(0.6)
            }
            Text(biome.name).display(28, color: Color(hex: "#FFE1C2")).shadow(color: .black.opacity(0.4), radius: 0, y: 2)
        }
        .frame(maxWidth: .infinity)
        .opacity(phase)
        .offset(y: (1 - phase) * -8)
        .onAppear {
            withAnimation(.easeOut(duration: 0.35)) { phase = 1 }
            withAnimation(.easeIn(duration: 0.5).delay(1.5)) { phase = 0 }
        }
        .id(biome.id)
    }
}

struct ControlHintRow: View {
    var body: some View {
        HStack(spacing: 6) {
            cell(text: "Lane") { LineIcon(name: "chevron.left", size: 16, color: Theme.flare, weight: .bold); LineIcon(name: "chevron.right", size: 16, color: Theme.flare, weight: .bold) }
            cell(text: "Climb") { LineIcon(name: "chevron.up", size: 16, color: Theme.flare, weight: .bold) }
            cell(text: "Dive") { LineIcon(name: "chevron.down", size: 16, color: Theme.flare, weight: .bold) }
        }
    }

    private func cell<C: View>(text: String, @ViewBuilder glyph: () -> C) -> some View {
        HStack(spacing: 8) {
            HStack(spacing: 0) { glyph() }
            Text(text).capsLabel(color: .white.opacity(0.85))
        }
        .frame(maxWidth: .infinity)
        .frame(height: 40)
        .background(RoundedRectangle(cornerRadius: Theme.radiusSmall).fill(Theme.bg.opacity(0.55)))
        .overlay(RoundedRectangle(cornerRadius: Theme.radiusSmall).strokeBorder(.white.opacity(0.14), lineWidth: 1))
    }
}

struct CountdownView: View {
    let label: String
    @State private var scale = 2.1
    @State private var opacity = 0.0

    var body: some View {
        Text(label)
            .display(120)
            .shadow(color: .black.opacity(0.5), radius: 0, y: 6)
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeOut(duration: 0.4)) { scale = 1; opacity = 1 }
                withAnimation(.easeIn(duration: 0.32).delay(0.4)) { scale = 0.82; opacity = 0 }
            }
            .id(label)
    }
}

struct PauseOverlay: View {
    @Environment(GameCoordinator.self) private var coordinator

    var body: some View {
        let sim = coordinator.run.simulation
        let mode = sim.config.mode
        ZStack {
            Theme.bg.opacity(0.78).ignoresSafeArea()
            VStack(spacing: 14) {
                HStack(spacing: 12) {
                    Ruler(height: 12, spacing: 6, majorEvery: 5)
                    Text("Paused").display(44).fixedSize()
                    Ruler(height: 12, spacing: 6, majorEvery: 5)
                }
                HStack(spacing: 0) {
                    StatColumn(value: GameFormat.grouped(Int(sim.score)), label: "Score")
                    StatColumn(value: "\(GameFormat.grouped(Int(sim.distance))) m", label: "Distance")
                    StatColumn(value: "×\(sim.bestCombo)", label: "Best combo")
                    StatColumn(value: "\(sim.coins)", label: "Coins")
                }
                .padding(.vertical, 16).padding(.horizontal, 8)
                .panel()
                Spacer().frame(height: 6)
                Button {
                    coordinator.run.resume()
                } label: {
                    HStack { Text("Resume"); Spacer(); Text("Swipe to steer").font(.body(13, weight: .bold)).tracking(0.5) }
                }
                .buttonStyle(.primary())
                if mode != .daily {
                    Button {
                        coordinator.restartRun()
                    } label: {
                        HStack {
                            Text("Restart run")
                            Spacer()
                            HStack(spacing: 4) { Text("Costs \(mode.config.energyCost)"); EnergyIcon(size: 12, tint: Theme.muted) }
                                .font(.body(12, weight: .semibold)).tracking(0.7).foregroundStyle(Theme.muted).textCase(.uppercase)
                        }
                    }
                    .buttonStyle(.outline())
                }
                Button {
                    coordinator.run.quit()
                } label: {
                    HStack { Text("Quit to deck"); Spacer(); Text("Score is banked").font(.body(12, weight: .semibold)).tracking(0.7).textCase(.uppercase) }
                }
                .buttonStyle(.outline(color: Theme.muted))
            }
            .padding(.horizontal, 24)
        }
    }
}
