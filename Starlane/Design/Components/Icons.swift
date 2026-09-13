import SwiftUI
import StarlaneCore

/// Line icon on the 24 grid: SF Symbol at medium weight so it reads as a stroke icon.
struct LineIcon: View {
    let name: String
    var size: CGFloat = 20
    var color: Color = Theme.muted
    var weight: Font.Weight = .medium

    var body: some View {
        Image(systemName: name)
            .font(.system(size: size * 0.85, weight: weight))
            .foregroundStyle(color)
            .frame(width: size, height: size)
    }
}

/// Coin: two-tone gold disc with an inner ring.
struct CoinIcon: View {
    var size: CGFloat = 14

    var body: some View {
        ZStack {
            Circle().fill(Theme.goldDeep)
            Circle().fill(Theme.gold).padding(size * 0.1)
            Circle().stroke(Theme.goldDeep, lineWidth: max(1, size * 0.09)).padding(size * 0.3)
        }
        .frame(width: size, height: size)
        .accessibilityLabel("coins")
    }
}

/// Gem: ice hexagon with faint facets.
struct GemIcon: View {
    var size: CGFloat = 14

    var body: some View {
        ZStack {
            Hexagon().fill(Theme.ice)
            Path { p in
                p.move(to: CGPoint(x: size / 2, y: size * 0.08))
                p.addLine(to: CGPoint(x: size / 2, y: size * 0.92))
                p.move(to: CGPoint(x: size * 0.1, y: size * 0.3))
                p.addLine(to: CGPoint(x: size / 2, y: size * 0.5))
                p.addLine(to: CGPoint(x: size * 0.9, y: size * 0.3))
            }
            .stroke(Theme.iceInk.opacity(0.45), lineWidth: max(0.8, size * 0.06))
        }
        .frame(width: size, height: size)
        .accessibilityLabel("gems")
    }

    private struct Hexagon: Shape {
        func path(in r: CGRect) -> Path {
            var p = Path()
            p.move(to: CGPoint(x: r.midX, y: r.minY + r.height * 0.05))
            p.addLine(to: CGPoint(x: r.maxX - r.width * 0.1, y: r.minY + r.height * 0.3))
            p.addLine(to: CGPoint(x: r.maxX - r.width * 0.1, y: r.maxY - r.height * 0.3))
            p.addLine(to: CGPoint(x: r.midX, y: r.maxY - r.height * 0.05))
            p.addLine(to: CGPoint(x: r.minX + r.width * 0.1, y: r.maxY - r.height * 0.3))
            p.addLine(to: CGPoint(x: r.minX + r.width * 0.1, y: r.minY + r.height * 0.3))
            p.closeSubpath()
            return p
        }
    }
}

struct EnergyIcon: View {
    var size: CGFloat = 12
    var tint: Color = Theme.flare

    var body: some View {
        Image(systemName: "bolt.fill")
            .font(.system(size: size, weight: .black))
            .foregroundStyle(tint)
            .accessibilityLabel("energy")
    }
}

struct CurrencyIcon: View {
    let currency: Currency
    var size: CGFloat = 14

    var body: some View {
        switch currency {
        case .coins: CoinIcon(size: size)
        case .gems: GemIcon(size: size)
        }
    }
}

/// "150 [coin]" inline amount in the display face.
struct AmountLabel: View {
    let amount: String
    let currency: Currency
    var size: CGFloat = 17
    var tint: Color = Theme.text

    init(_ amount: Int, _ currency: Currency, size: CGFloat = 17, tint: Color = Theme.text) {
        self.amount = GameFormat.grouped(amount)
        self.currency = currency
        self.size = size
        self.tint = tint
    }

    var body: some View {
        HStack(spacing: 5) {
            Text(amount).display(size, color: tint).monospacedDigit()
            CurrencyIcon(currency: currency, size: size * 0.72)
        }
    }
}

/// Price inside pill buttons.
struct PriceLabel: View {
    let price: Price

    var body: some View {
        HStack(spacing: 5) {
            Text(GameFormat.grouped(price.amount))
            CurrencyIcon(currency: price.currency, size: 12)
        }
    }
}

/// The player's rocket, drawn as vector art in the skin colour.
struct RocketMark: View {
    var size: CGFloat = 64
    var color: Color = Theme.text
    var accent: Color = Theme.flare

    var body: some View {
        Canvas { ctx, s in
            let k = s.width / 120
            func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * k, y: y * k) }
            var body = Path()
            body.move(to: pt(60, 4))
            body.addCurve(to: pt(76, 82), control1: pt(77, 22), control2: pt(82, 48))
            body.addLine(to: pt(44, 82))
            body.addCurve(to: pt(60, 4), control1: pt(38, 48), control2: pt(43, 22))
            body.closeSubpath()
            ctx.fill(body, with: .color(color))

            var fins = Path()
            fins.move(to: pt(46, 60)); fins.addLine(to: pt(26, 94)); fins.addLine(to: pt(46, 86)); fins.closeSubpath()
            fins.move(to: pt(74, 60)); fins.addLine(to: pt(94, 94)); fins.addLine(to: pt(74, 86)); fins.closeSubpath()
            ctx.fill(fins, with: .color(color.opacity(0.78)))

            ctx.fill(Path(ellipseIn: CGRect(x: 52 * k, y: 34 * k, width: 16 * k, height: 16 * k)), with: .color(accent))
            ctx.fill(Path(CGRect(x: 44 * k, y: 70 * k, width: 32 * k, height: 5 * k)), with: .color(accent))

            var flame = Path()
            flame.move(to: pt(50, 84)); flame.addLine(to: pt(60, 116)); flame.addLine(to: pt(70, 84)); flame.closeSubpath()
            ctx.fill(flame, with: .color(accent.opacity(0.9)))
            var core = Path()
            core.move(to: pt(55, 84)); core.addLine(to: pt(60, 102)); core.addLine(to: pt(65, 84)); core.closeSubpath()
            ctx.fill(core, with: .color(Color(hex: "#FFE1C2")))
        }
        .frame(width: size, height: size)
    }
}

/// Rank number: flare for the podium, faint below.
struct RankNumber: View {
    let rank: Int

    var body: some View {
        Text(String(format: "%02d", rank + 1))
            .display(20, color: rank < 3 ? Theme.flare : Theme.faint)
            .monospacedDigit()
            .frame(width: 28, alignment: .leading)
    }
}
