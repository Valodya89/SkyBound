import SwiftUI

/// Cold-launch sequence: the flight deck powering up before the hub appears. The ground colour matches the
/// static `LaunchBackground`, so the system launch screen hands over without a flash, and everything drawn on
/// top is the vocabulary used everywhere else — nebula wash and star field from the app icon, the launch
/// corridor, edge tick rulers, corner brackets, the rocket mark, a flare kicker over a display title, and one
/// ice segment bar counting the boot down.
///
/// Shown once per cold launch from `RootView`; `onFinish` fires after the rocket leaves.
struct SplashView: View {
    var onFinish: () -> Void

    /// Beat map in seconds from the first frame. `hold` is when the rocket leaves, `exit` how long that takes.
    private enum Beat {
        static let field = 0.05, horizon = 0.10, corridor = 0.18, rulers = 0.24, brackets = 0.30
        static let ignite = 0.36, word = 0.62, kicker = 0.80, boot = 0.86
        static let hold = 1.50, exit = 0.42
        static let segments = 6
    }

    @Environment(GameCoordinator.self) private var coordinator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var start = Date()
    @State private var field = 0.0      // nebula + star field
    @State private var horizon = 0.0    // planet arc rising
    @State private var corridor = 0.0   // launch corridor opening
    @State private var rulers = 0.0     // edge ticks
    @State private var brackets = 0.0   // corner brackets drawing in
    @State private var lift = 1.0       // rocket travel: 1 below the deck, 0 parked, negative gone
    @State private var glow = 0.0       // exhaust
    @State private var wipe = 0.0       // wordmark reveal
    @State private var kicker = 0.0
    @State private var boot = 0
    @State private var fade = 1.0       // everything except the rocket, on the way out

    var body: some View {
        ZStack {
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                ZStack {
                    Theme.bg
                    LinearGradient(colors: [Color(hex: "#141B2B"), Theme.bg], startPoint: .top, endPoint: .bottom)
                        .opacity(field)
                    nebula(w: w, h: h).opacity(field)
                    starField.opacity(field * 0.95)
                    horizonArc(w: w, h: h)
                    corridorLight(w: w, h: h)
                    edgeRulers(w: w, h: h).opacity(fade)
                    column(w: w, h: h)
                    bootStrip(w: w, h: h)
                }
            }
            .ignoresSafeArea()

            // Kept inside the safe area so the brackets frame the screen rather than the notch.
            SplashBrackets(progress: brackets)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .opacity(fade)
        }
        .contentShape(Rectangle())
        .accessibilityElement()
        .accessibilityLabel("Starlane")
        .task { await runSequence() }
    }

    // MARK: - Layers

    /// Two restrained washes: ice high and right, flare low and centred on the launch point.
    private func nebula(w: CGFloat, h: CGFloat) -> some View {
        ZStack {
            RadialGradient(colors: [Theme.ice.opacity(0.17), .clear], center: .center, startRadius: 0, endRadius: w * 0.8)
                .frame(width: w * 1.6, height: w * 1.6)
                .position(x: w * 0.78, y: h * 0.2)
            RadialGradient(colors: [Theme.flare.opacity(0.2), .clear], center: .center, startRadius: 0, endRadius: w * 0.7)
                .frame(width: w * 1.4, height: w * 1.4)
                .position(x: w * 0.5, y: h * 0.8)
        }
        .blendMode(.screen)
        .allowsHitTesting(false)
    }

    private var starField: some View {
        TimelineView(.animation(paused: reduceMotion)) { timeline in
            SplashStarfield(t: timeline.date.timeIntervalSince(start))
        }
        .blendMode(.screen)
    }

    /// Planet horizon at the base with an ice rim light, the same frame the icon uses.
    private func horizonArc(w: CGFloat, h: CGFloat) -> some View {
        let r = w * 1.35
        return ZStack {
            Circle().fill(LinearGradient(colors: [Color(hex: "#1B2436"), Theme.bg], startPoint: .top, endPoint: .bottom))
            Circle().strokeBorder(Theme.ice.opacity(0.85), lineWidth: 2)
            Circle().strokeBorder(Theme.ice.opacity(0.3), lineWidth: 26)
                .blur(radius: 20)
                .blendMode(.screen)
        }
        .frame(width: r * 2, height: r * 2)
        .position(x: w / 2, y: h * 0.86 + r)
        .offset(y: (1 - horizon) * 44)
        .opacity(horizon)
        .allowsHitTesting(false)
    }

    /// Light cone opening upward from the horizon, with dashed ice lane edges.
    private func corridorLight(w: CGFloat, h: CGFloat) -> some View {
        ZStack {
            CorridorCone()
                .fill(LinearGradient(stops: [.init(color: Theme.flare.opacity(0.3), location: 0),
                                             .init(color: Theme.flare.opacity(0.08), location: 0.45),
                                             .init(color: .clear, location: 1)],
                                     startPoint: .bottom, endPoint: .top))
            CorridorEdges()
                .stroke(Theme.ice.opacity(0.3), style: StrokeStyle(lineWidth: 1.5, dash: [8, 10]))
        }
        // Everything in the corridor thins out with altitude, so nothing runs into the top edge.
        .mask {
            LinearGradient(stops: [.init(color: .white, location: 0),
                                   .init(color: .white, location: 0.3),
                                   .init(color: .clear, location: 0.95)],
                           startPoint: .bottom, endPoint: .top)
        }
        .blendMode(.screen)
        .frame(width: w, height: h * 0.86)
        .frame(maxHeight: .infinity, alignment: .top)
        .scaleEffect(x: 1, y: corridor, anchor: .bottom)
        .opacity(corridor)
        .allowsHitTesting(false)
    }

    private func edgeRulers(w: CGFloat, h: CGFloat) -> some View {
        HStack {
            SplashEdgeRuler().frame(width: 24)
            Spacer(minLength: 0)
            SplashEdgeRuler(flipped: true).frame(width: 24)
        }
        .padding(.horizontal, 20)
        .frame(width: w, height: h * 0.4)
        .position(x: w / 2, y: h * 0.4)
        .scaleEffect(x: 1, y: 0.86 + rulers * 0.14)
        .opacity(rulers)
        .allowsHitTesting(false)
    }

    /// Rocket over the kicker, title, rule and boot bar — the same stack order as a `ScreenHeader`.
    private func column(w: CGFloat, h: CGFloat) -> some View {
        VStack(spacing: 0) {
            rocket(w: w)
            Text("Launch sequence")
                .capsLabel(11, color: Theme.flare)
                .opacity(kicker)
                .padding(.top, 30)
            Text("Starlane")
                .display(min(w * 0.17, 64))
                .tracking(2)
                .mask(alignment: .leading) { Rectangle().scaleEffect(x: wipe, anchor: .leading) }
                .shadow(color: Theme.flare.opacity(0.3), radius: 22)
                .padding(.top, 6)
            Ruler(height: 7, spacing: 7, color: Theme.line2, majorEvery: 4, majorColor: Theme.flare)
                .frame(width: min(w * 0.56, 220))
                .mask(alignment: .leading) { Rectangle().scaleEffect(x: wipe, anchor: .leading) }
                .padding(.top, 10)
        }
        .opacity(fade)
        .position(x: w / 2, y: h * 0.46)
        .allowsHitTesting(false)
    }

    /// Boot readout down on the planet, clear of the title block.
    private func bootStrip(w: CGFloat, h: CGFloat) -> some View {
        HStack(spacing: 10) {
            Text("Preflight").capsLabel(9.5, color: Theme.faint)
            SegmentBar(filled: boot, total: Beat.segments, color: Theme.ice, height: 5, spacing: 4, segmentWidth: 14)
                .fixedSize()
        }
        .opacity(kicker)
        .position(x: w / 2, y: h * 0.93)
        .allowsHitTesting(false)
    }

    private func rocket(w: CGFloat) -> some View {
        let size = min(w * 0.26, 104)
        return ZStack {
            TimelineView(.animation(paused: reduceMotion)) { timeline in
                let pulse = reduceMotion ? 1 : 0.88 + 0.12 * sin(timeline.date.timeIntervalSince(start) * 15)
                Circle()
                    .fill(RadialGradient(colors: [Theme.flare.opacity(0.55), Theme.flare.opacity(0.12), .clear],
                                         center: .center, startRadius: 0, endRadius: size * 0.7))
                    .frame(width: size * 1.7, height: size * 1.7)
                    .scaleEffect(pulse * (0.7 + glow * 0.3))
                    .offset(y: size * 0.44)
                    .blendMode(.screen)
            }
            LinearGradient(colors: [Theme.flare.opacity(0.55), .clear], startPoint: .top, endPoint: .bottom)
                .frame(width: size * 0.12, height: size * 1.6)
                .blur(radius: 5)
                .offset(y: size * 1.2)
                .blendMode(.screen)
                .opacity(0.4 + lift * 0.6)
            RocketMark(size: size, color: Theme.text, accent: Theme.flare)
        }
        .opacity(glow)
        .offset(y: lift * 260)
    }

    // MARK: - Sequence

    private func runSequence() async {
        guard !reduceMotion else {
            withAnimation(.easeOut(duration: 0.4)) {
                field = 1; horizon = 1; corridor = 1; rulers = 1; brackets = 1
                lift = 0; glow = 1; wipe = 1; kicker = 1
            }
            boot = Beat.segments
            try? await Task.sleep(for: .seconds(1.0))
            withAnimation(.easeIn(duration: 0.3)) { fade = 0 }
            try? await Task.sleep(for: .seconds(0.3))
            onFinish()
            return
        }

        withAnimation(.easeOut(duration: 0.6).delay(Beat.field)) { field = 1 }
        withAnimation(.easeOut(duration: 0.7).delay(Beat.horizon)) { horizon = 1 }
        withAnimation(.easeOut(duration: 0.55).delay(Beat.corridor)) { corridor = 1 }
        withAnimation(.easeOut(duration: 0.5).delay(Beat.rulers)) { rulers = 1 }
        withAnimation(.easeInOut(duration: 0.6).delay(Beat.brackets)) { brackets = 1 }
        withAnimation(.easeOut(duration: 0.3).delay(Beat.ignite)) { glow = 1 }
        withAnimation(.spring(duration: 0.85, bounce: 0.18).delay(Beat.ignite)) { lift = 0 }
        withAnimation(.easeOut(duration: 0.45).delay(Beat.word)) { wipe = 1 }
        withAnimation(.easeOut(duration: 0.4).delay(Beat.kicker)) { kicker = 1 }
        for i in 1...Beat.segments {
            withAnimation(.easeOut(duration: 0.1).delay(Beat.boot + Double(i) * 0.06)) { boot = i }
        }

        try? await Task.sleep(for: .seconds(Beat.ignite))
        coordinator.audio.play(.biome)
        coordinator.haptics.light()

        try? await Task.sleep(for: .seconds(Beat.hold - Beat.ignite))
        coordinator.audio.play(.countdownGo)
        coordinator.haptics.medium()
        withAnimation(.easeIn(duration: Beat.exit)) {
            lift = -1.8
            fade = 0
        }
        try? await Task.sleep(for: .seconds(Beat.exit))
        onFinish()
    }
}

// MARK: - Pieces

/// The launch corridor: a narrow trapezoid widening toward the base.
private struct CorridorCone: Shape {
    static let baseHalf: CGFloat = 0.17
    static let topHalf: CGFloat = 0.05

    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.midX - r.width * Self.baseHalf, y: r.maxY))
        p.addLine(to: CGPoint(x: r.midX + r.width * Self.baseHalf, y: r.maxY))
        p.addLine(to: CGPoint(x: r.midX + r.width * Self.topHalf, y: r.minY))
        p.addLine(to: CGPoint(x: r.midX - r.width * Self.topHalf, y: r.minY))
        p.closeSubpath()
        return p
    }
}

/// Just the two slanted lane edges of the corridor, so the dashes read as rails rather than a box.
private struct CorridorEdges: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.midX - r.width * CorridorCone.baseHalf, y: r.maxY))
        p.addLine(to: CGPoint(x: r.midX - r.width * CorridorCone.topHalf, y: r.minY))
        p.move(to: CGPoint(x: r.midX + r.width * CorridorCone.baseHalf, y: r.maxY))
        p.addLine(to: CGPoint(x: r.midX + r.width * CorridorCone.topHalf, y: r.minY))
        return p
    }
}

/// Tick ruler down one screen edge, every fourth tick long — the icon's edge motif.
private struct SplashEdgeRuler: View {
    var flipped = false

    var body: some View {
        let tick = Theme.ice
        return Canvas { ctx, size in
            let count = 13
            for i in 0..<count {
                let y = (size.height - 2) * CGFloat(i) / CGFloat(count - 1)
                let major = i % 4 == 0
                let len = major ? size.width : size.width * 0.45
                let x = flipped ? size.width - len : 0
                ctx.fill(Path(CGRect(x: x, y: y, width: len, height: 1.5)),
                         with: .color(tick.opacity(major ? 0.4 : 0.2)))
            }
        }
        .allowsHitTesting(false)
    }
}

/// The four corner brackets, drawn one after another as `progress` runs to 1.
private struct SplashBrackets: View {
    var progress: Double

    var body: some View {
        GeometryReader { geo in
            let leg: CGFloat = 28
            let r = CGRect(origin: .zero, size: geo.size)
            Path { p in
                p.move(to: CGPoint(x: r.minX, y: r.minY + leg))
                p.addLine(to: CGPoint(x: r.minX, y: r.minY))
                p.addLine(to: CGPoint(x: r.minX + leg, y: r.minY))

                p.move(to: CGPoint(x: r.maxX - leg, y: r.minY))
                p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
                p.addLine(to: CGPoint(x: r.maxX, y: r.minY + leg))

                p.move(to: CGPoint(x: r.maxX, y: r.maxY - leg))
                p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
                p.addLine(to: CGPoint(x: r.maxX - leg, y: r.maxY))

                p.move(to: CGPoint(x: r.minX + leg, y: r.maxY))
                p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
                p.addLine(to: CGPoint(x: r.minX, y: r.maxY - leg))
            }
            .trim(from: 0, to: progress)
            .stroke(Theme.flare.opacity(0.9), style: StrokeStyle(lineWidth: 2, lineCap: .square))
        }
        .allowsHitTesting(false)
    }
}

/// Deterministic star field that drifts down while the rocket climbs. `t` is seconds since the first frame.
private struct SplashStarfield: View {
    let t: Double

    private struct Star {
        let x, y, radius, alpha, speed, phase: CGFloat
        let isIce: Bool
    }

    private static let stars: [Star] = {
        var seed: UInt64 = 0x5EED_5B0D
        func rnd() -> CGFloat {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            return CGFloat((seed >> 33) & 0xFFFFFF) / CGFloat(0xFFFFFF)
        }
        return (0..<140).map { i in
            let ice = i % 19 == 0
            return Star(x: rnd(), y: rnd(),
                        radius: ice ? 1.7 + rnd() * 1.3 : 0.6 + rnd() * 1.1,
                        alpha: ice ? 0.9 : 0.22 + rnd() * 0.45,
                        speed: 0.006 + rnd() * 0.018,
                        phase: rnd() * 6.28,
                        isIce: ice)
        }
    }()

    var body: some View {
        let iceColor = Theme.ice
        let dust = Theme.text
        return Canvas { ctx, size in
            for s in Self.stars {
                let drift = (Double(s.y) + t * Double(s.speed)).truncatingRemainder(dividingBy: 1)
                let px = Double(s.x) * size.width
                let py = drift * size.height
                let alpha = Double(s.alpha) * (0.7 + 0.3 * sin(t * 2.2 + Double(s.phase)))
                let r = Double(s.radius)
                ctx.fill(Path(ellipseIn: CGRect(x: px - r, y: py - r, width: r * 2, height: r * 2)),
                         with: .color(s.isIce ? iceColor.opacity(alpha) : dust.opacity(alpha)))
                if s.isIce {
                    let l = r * 3.6
                    var cross = Path()
                    cross.move(to: CGPoint(x: px - l, y: py)); cross.addLine(to: CGPoint(x: px + l, y: py))
                    cross.move(to: CGPoint(x: px, y: py - l)); cross.addLine(to: CGPoint(x: px, y: py + l))
                    ctx.stroke(cross, with: .color(iceColor.opacity(alpha * 0.5)), lineWidth: 0.8)
                }
            }
        }
        .allowsHitTesting(false)
    }
}

#Preview {
    SplashView {}
        .environment(AppEnvironment.preview().coordinator)
        .preferredColorScheme(.dark)
}
