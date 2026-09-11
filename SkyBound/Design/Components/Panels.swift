import SwiftUI
import SkyBoundCore

extension View {
    /// Flat panel: dark fill, 1 pt line, 6 pt radius.
    func panel(raised: Bool = false, border: Color = Theme.line, radius: CGFloat = Theme.radius) -> some View {
        self.background(RoundedRectangle(cornerRadius: radius, style: .continuous).fill(raised ? Theme.panel2 : Theme.panel))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(border, lineWidth: 1))
    }

    /// Corner brackets marking the selected thing.
    func cornerBrackets(_ color: Color = Theme.flare, visible: Bool = true) -> some View {
        overlay {
            if visible {
                ZStack {
                    Bracket().stroke(color, lineWidth: 2).frame(width: 12, height: 12)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    Bracket().stroke(color, lineWidth: 2).frame(width: 12, height: 12)
                        .rotationEffect(.degrees(180))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                }
                .allowsHitTesting(false)
            }
        }
    }
}

private struct Bracket: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        return p
    }
}

/// Tick ruler used as a section divider.
struct Ruler: View {
    var height: CGFloat = 8
    var spacing: CGFloat = 8
    var color: Color = Theme.line2
    var majorEvery: Int = 0
    var majorColor: Color = Theme.muted

    var body: some View {
        Canvas { ctx, size in
            var x: CGFloat = 0
            var i = 0
            while x < size.width {
                let major = majorEvery > 0 && i % majorEvery == 0
                ctx.fill(Path(CGRect(x: x, y: 0, width: 1, height: size.height)), with: .color(major ? majorColor : color))
                x += spacing
                i += 1
            }
        }
        .frame(height: height)
        .allowsHitTesting(false)
    }
}

/// "LABEL ||||||||| trailing" section header.
struct SectionRule: View {
    let title: String
    var trailing: String? = nil
    var trailingColor: Color = Theme.faint

    init(_ title: String, trailing: String? = nil, trailingColor: Color = Theme.faint) {
        self.title = title
        self.trailing = trailing
        self.trailingColor = trailingColor
    }

    var body: some View {
        HStack(spacing: 10) {
            Text(title).capsLabel()
            Ruler()
            if let trailing {
                Text(trailing).capsLabel(color: trailingColor).monospacedDigit()
            }
        }
        .padding(.top, 6)
    }
}

/// Discrete quantity: energy, boss health, pity, levels.
struct SegmentBar: View {
    let filled: Int
    let total: Int
    var color: Color = Theme.flare
    var height: CGFloat = 6
    var spacing: CGFloat = 3
    var segmentWidth: CGFloat? = nil

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(0..<max(total, 1), id: \.self) { i in
                Rectangle()
                    .fill(i < filled ? color : Theme.panel3)
                    .frame(width: segmentWidth, height: height)
                    .frame(maxWidth: segmentWidth == nil ? .infinity : nil)
            }
        }
        .animation(.easeOut(duration: 0.25), value: filled)
    }
}

/// Continuous quantity: XP, mission progress.
struct ProgressBar: View {
    let fraction: Double
    var color: Color = Theme.ice
    var height: CGFloat = 4
    var track: Color = Theme.panel3

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle().fill(track)
                Rectangle().fill(color).frame(width: max(0, min(1, fraction)) * geo.size.width)
            }
        }
        .frame(height: height)
        .animation(.spring(duration: 0.5), value: fraction)
    }
}

/// Rarity is a corner, never a border.
struct RarityCorner: View {
    let rarity: Rarity
    var size: CGFloat = 14

    var body: some View {
        Path { p in
            p.move(to: .zero)
            p.addLine(to: CGPoint(x: size, y: 0))
            p.addLine(to: CGPoint(x: 0, y: size))
            p.closeSubpath()
        }
        .fill(Color.rarity(rarity))
        .frame(width: size, height: size)
    }
}

/// Outlined uppercase tag: BOSSES, 70% OFF, BEST VALUE.
struct Tag: View {
    let text: String
    var color: Color = Theme.flare

    init(_ text: String, color: Color = Theme.flare) {
        self.text = text
        self.color = color
    }

    var body: some View {
        Text(text)
            .capsLabel(9, color: color)
            .padding(.horizontal, 5).padding(.vertical, 3)
            .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(color, lineWidth: 1))
    }
}

/// Filled corner badge: POPULAR, FLYING.
struct FilledTag: View {
    let text: String
    var color: Color = Theme.flare
    var ink: Color = Theme.flareInk

    var body: some View {
        Text(text)
            .capsLabel(8.5, color: ink)
            .padding(.horizontal, 6).padding(.vertical, 3)
            .background(color)
    }
}

/// Small flare dot: "something is waiting here".
struct DotBadge: View {
    var body: some View {
        Circle().fill(Theme.flare).frame(width: 6, height: 6)
    }
}

/// Square avatar with the first letter of a rival's name.
struct LetterAvatar: View {
    let name: String
    var size: CGFloat = 28

    var body: some View {
        Text(String(name.prefix(1)).uppercased())
            .font(.body(size * 0.43, weight: .bold))
            .foregroundStyle(Theme.text)
            .frame(width: size, height: size)
            .background(RoundedRectangle(cornerRadius: 3).fill(Theme.panel3))
    }
}

/// Big number over a small label.
struct StatColumn: View {
    let value: String
    let label: String
    var size: CGFloat = 22

    var body: some View {
        VStack(spacing: 5) {
            Text(value).display(size).monospacedDigit()
            Text(label).capsLabel(9.5, color: Theme.faint)
        }
        .frame(maxWidth: .infinity)
    }
}

/// Underlined tab strip used by Hangar and Ranks.
struct TabStrip: View {
    let tabs: [String]
    @Binding var selection: Int

    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabs.indices, id: \.self) { i in
                let on = i == selection
                Button {
                    withAnimation(.easeOut(duration: 0.18)) { selection = i }
                } label: {
                    Text(tabs[i])
                        .capsLabel(color: on ? Theme.text : Theme.faint)
                        .padding(.horizontal, i == 0 ? 0 : 14)
                        .padding(.trailing, i == 0 ? 14 : 0)
                        .padding(.vertical, 11)
                        .overlay(alignment: .bottom) {
                            Rectangle().fill(Theme.flare).frame(height: 2).opacity(on ? 1 : 0)
                        }
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.line).frame(height: 1) }
    }
}

/// Ledger row with a dotted leader between key and value.
struct LedgerRow: View {
    let key: String
    let value: String
    var color: Color = Theme.text

    var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: 8) {
            Text(key).font(.body(13)).foregroundStyle(Theme.muted)
            Line().stroke(style: StrokeStyle(lineWidth: 1, dash: [1, 3])).foregroundStyle(Theme.line2)
                .frame(height: 1).offset(y: -3)
            Text(value).display(20, color: color).monospacedDigit()
        }
    }

    private struct Line: Shape {
        func path(in rect: CGRect) -> Path {
            var p = Path()
            p.move(to: CGPoint(x: rect.minX, y: rect.midY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            return p
        }
    }
}
