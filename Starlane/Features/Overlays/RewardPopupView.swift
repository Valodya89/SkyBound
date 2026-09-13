import SwiftUI

/// Full-screen moment used for every grant (rewards, purchases, level-ups).
struct RewardPopupView: View {
    @Environment(GameCoordinator.self) private var coordinator
    let popup: RewardPopup
    @State private var appeared = false

    var body: some View {
        ZStack {
            Theme.bg.opacity(0.88).ignoresSafeArea()
            VStack(spacing: 18) {
                HStack(spacing: 12) {
                    Ruler(height: 12, spacing: 6, majorEvery: 5)
                    Text(popup.title).capsLabel(color: Theme.flare).fixedSize()
                    Ruler(height: 12, spacing: 6, majorEvery: 5)
                }
                ZStack {
                    ChamferShape(cut: 14).fill(Theme.panel2)
                    ChamferShape(cut: 14).stroke(Theme.line2, lineWidth: 1)
                    ChamferShape(cut: 8).fill(Theme.panel).padding(10)
                    ChamferShape(cut: 8).stroke(Theme.line, lineWidth: 1).padding(10)
                    icon
                }
                .frame(width: 150, height: 150)
                Text(popup.detail)
                    .font(.display(34))
                    .textCase(.uppercase)
                    .foregroundStyle(Theme.text)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .minimumScaleFactor(0.6)
                    .padding(.horizontal, 12)
                Button("Collect") {
                    coordinator.audio.play(.ui)
                    coordinator.router.dismissReward()
                }
                .buttonStyle(.primary(height: 56, size: 26))
                .padding(.top, 6)
            }
            .padding(.horizontal, 28)
            .scaleEffect(appeared ? 1 : 0.7)
            .opacity(appeared ? 1 : 0)
            .onAppear {
                withAnimation(.spring(duration: 0.4, bounce: 0.3)) { appeared = true }
                coordinator.audio.play(.win)
            }
        }
    }

    @ViewBuilder
    private var icon: some View {
        switch popup.symbol {
        case "circle.circle.fill": CoinIcon(size: 64)
        case "diamond.fill": GemIcon(size: 64)
        default:
            Image(systemName: popup.symbol)
                .font(.system(size: 54, weight: .medium))
                .foregroundStyle(Color(hex: popup.tintHex))
        }
    }
}
