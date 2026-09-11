import SwiftUI
import SkyBoundCore

/// 540×760 run card rendered with `ImageRenderer` for sharing.
struct ShareCardView: View {
    let summary: RunSummary
    let biome: Biome
    let skin: Skin

    var body: some View {
        ZStack(alignment: .top) {
            LinearGradient(colors: [Color(biome.skyTop), Color(biome.skyMid), Color(biome.skyBottom)], startPoint: .top, endPoint: .bottom)
            Stars()
            Circle().fill(Color(biome.hillNear)).frame(width: 150, height: 150)
                .overlay(Ellipse().stroke(Color(biome.edge).opacity(0.8), lineWidth: 6).frame(width: 260, height: 60).rotationEffect(.degrees(-16)))
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.top, 150).padding(.trailing, 40)
            Corridor().fill(Color(biome.road)).frame(height: 300).frame(maxHeight: .infinity, alignment: .bottom)
                .overlay(alignment: .bottom) { Corridor().stroke(Color(biome.edge).opacity(0.7), lineWidth: 3).frame(height: 300) }
            VStack(spacing: 0) {
                Text("SkyBound").capsLabel(14, color: .white.opacity(0.85), tracking: 6).padding(.top, 48)
                HStack(spacing: 10) {
                    RocketMark(size: 26, color: Color(hex: skin.colorHex))
                    Text(summary.mode.config.name).display(22)
                }
                .padding(.top, 14)
                Text(GameFormat.grouped(summary.score))
                    .display(136)
                    .monospacedDigit()
                    .shadow(color: .black.opacity(0.45), radius: 0, y: 6)
                    .minimumScaleFactor(0.5)
                    .padding(.top, 50)
                Text("Final score").capsLabel(13, color: .white.opacity(0.8)).padding(.top, 2)
                Spacer()
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(136), spacing: 24), count: 3), spacing: 16) {
                    stat("\(GameFormat.grouped(summary.distance)) m", "Distance")
                    stat("\(summary.coins)", "Coins")
                    stat("×\(summary.bestCombo)", "Combo")
                    stat("\(summary.nearMisses)", "Near miss")
                    stat("\(summary.bossesDefeated)", "Bosses")
                    stat("\(summary.zonesReached)", "Sectors")
                }
                Spacer()
                Text("\(biome.zoneLabel) · \(biome.name)").capsLabel(11, color: .white.opacity(0.85))
                Text("\(Date.now.formatted(date: .abbreviated, time: .omitted))  ·  simulated prototype")
                    .font(.body(10, weight: .semibold)).foregroundStyle(.white.opacity(0.5)).padding(.top, 4).padding(.bottom, 26)
            }
        }
        .frame(width: 540, height: 760)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 4) {
            Text(value).display(26)
            Text(label).capsLabel(10, color: .white.opacity(0.65))
        }
        .frame(width: 136, height: 76)
        .background(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous).fill(.black.opacity(0.35)))
    }

    private struct Stars: View {
        var body: some View {
            Canvas { ctx, size in
                var x: UInt32 = 11
                for i in 0..<90 {
                    x = x &* 1103515245 &+ 12345
                    let fx = Double(x % 1000) / 1000
                    x = x &* 1103515245 &+ 12345
                    let fy = Double(x % 1000) / 1000
                    let r = 0.8 + Double(i % 3) * 0.6
                    ctx.fill(Path(ellipseIn: CGRect(x: fx * size.width, y: fy * size.height * 0.6, width: r * 2, height: r * 2)),
                             with: .color(.white.opacity(0.35 + Double(i % 4) * 0.15)))
                }
            }
        }
    }

    private struct Corridor: Shape {
        func path(in rect: CGRect) -> Path {
            var p = Path()
            p.move(to: CGPoint(x: rect.midX - rect.width * 0.1, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.midX + rect.width * 0.1, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            p.closeSubpath()
            return p
        }
    }
}

/// Presents the rendered card with a native share sheet.
struct ShareCardOverlay: View {
    @Environment(GameCoordinator.self) private var coordinator
    let image: UIImage

    var body: some View {
        ZStack {
            Theme.bg.opacity(0.92).ignoresSafeArea()
                .onTapGesture { coordinator.router.shareImage = nil }
            VStack(spacing: 16) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 290)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .shadow(color: .black.opacity(0.7), radius: 28, y: 18)
                HStack(spacing: 10) {
                    ShareLink(item: Image(uiImage: image), preview: SharePreview("SkyBound run card", image: Image(uiImage: image))) {
                        Text("Share").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.primary(height: 48, size: 20))
                    Button("Close") { coordinator.router.shareImage = nil }
                        .buttonStyle(.outline(color: Theme.muted))
                }
                .frame(maxWidth: 290)
            }
            .padding(24)
        }
    }
}
