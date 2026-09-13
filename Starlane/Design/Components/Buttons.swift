import SwiftUI

/// Rectangle with the top-right and bottom-left corners cut at 45°. The signature shape of every primary action.
struct ChamferShape: Shape {
    var cut: CGFloat = 14

    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - cut, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + cut))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX + cut, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - cut))
        p.closeSubpath()
        return p
    }
}

/// Diagonal stripes drawn along the bottom edge of primary buttons.
struct HazardStripes: View {
    var color: Color = .black.opacity(0.22)

    var body: some View {
        Canvas { ctx, size in
            var x: CGFloat = -size.height
            while x < size.width + size.height {
                var p = Path()
                p.move(to: CGPoint(x: x, y: 0))
                p.addLine(to: CGPoint(x: x + 6, y: 0))
                p.addLine(to: CGPoint(x: x + 6 - size.height, y: size.height))
                p.addLine(to: CGPoint(x: x - size.height, y: size.height))
                p.closeSubpath()
                ctx.fill(p, with: .color(color))
                x += 14
            }
        }
        .allowsHitTesting(false)
    }
}

/// Chamfered slab with a hazard strip: the one primary action on a screen.
struct PrimaryButtonStyle: ButtonStyle {
    var color: Color = Theme.flare
    var ink: Color = Theme.flareInk
    var height: CGFloat = 60
    var size: CGFloat = 30
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.display(size))
            .textCase(.uppercase)
            .foregroundStyle(ink)
            .lineLimit(1)
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(color)
            .overlay(alignment: .bottom) { HazardStripes().frame(height: 6) }
            .clipShape(ChamferShape(cut: 14))
            .contentShape(Rectangle())
            .opacity(isEnabled ? (configuration.isPressed ? 0.85 : 1) : 0.4)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static func primary(_ color: Color = Theme.flare, ink: Color = Theme.flareInk, height: CGFloat = 60, size: CGFloat = 30) -> PrimaryButtonStyle {
        PrimaryButtonStyle(color: color, ink: ink, height: height, size: size)
    }
}

/// Secondary action: a 1.5 pt outline, no fill.
struct OutlineButtonStyle: ButtonStyle {
    var border: Color = Theme.line2
    var color: Color = Theme.text
    var height: CGFloat = 48
    var size: CGFloat = 20
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.display(size))
            .textCase(.uppercase)
            .foregroundStyle(color)
            .lineLimit(1)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous).fill(configuration.isPressed ? Theme.panel2 : .clear))
            .overlay(RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous).strokeBorder(border, lineWidth: 1.5))
            .contentShape(Rectangle())
            .opacity(isEnabled ? 1 : 0.45)
    }
}

extension ButtonStyle where Self == OutlineButtonStyle {
    static func outline(_ border: Color = Theme.line2, color: Color = Theme.text, height: CGFloat = 48, size: CGFloat = 20) -> OutlineButtonStyle {
        OutlineButtonStyle(border: border, color: color, height: height, size: size)
    }
}

/// Compact action inside a row: BUY, CLAIM, FLY.
struct PillButtonStyle: ButtonStyle {
    enum Kind { case flare, ice, ghost, dim }
    var kind: Kind = .ghost
    @Environment(\.isEnabled) private var isEnabled

    private var background: Color {
        switch kind {
        case .flare: Theme.flare
        case .ice: Theme.ice
        case .ghost: Theme.panel3
        case .dim: Theme.panel2
        }
    }

    private var foreground: Color {
        switch kind {
        case .flare: Theme.flareInk
        case .ice: Theme.iceInk
        case .ghost: Theme.text
        case .dim: Theme.faint
        }
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.display(17))
            .textCase(.uppercase)
            .foregroundStyle(isEnabled ? foreground : Theme.faint)
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 14)
            .frame(height: 34)
            .background(RoundedRectangle(cornerRadius: 3).fill(isEnabled ? background : Theme.panel2))
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

extension ButtonStyle where Self == PillButtonStyle {
    static func pill(_ kind: PillButtonStyle.Kind, disabled: Bool = false) -> PillButtonStyle {
        PillButtonStyle(kind: disabled ? .dim : kind)
    }
}

/// Small scale-down feedback for tappable tiles.
struct PressScaleStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Square switch used in Settings.
struct DeckToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack {
                configuration.label
                Spacer()
                ZStack(alignment: configuration.isOn ? .trailing : .leading) {
                    RoundedRectangle(cornerRadius: 3).fill(configuration.isOn ? Theme.flare : Theme.panel3)
                        .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(configuration.isOn ? Theme.flareDeep : Theme.line2, lineWidth: 1))
                    RoundedRectangle(cornerRadius: 2).fill(configuration.isOn ? Theme.flareInk : Theme.muted)
                        .frame(width: 16, height: 16)
                        .padding(4)
                }
                .frame(width: 44, height: 24)
                .animation(.easeOut(duration: 0.15), value: configuration.isOn)
            }
        }
        .buttonStyle(.plain)
    }
}
