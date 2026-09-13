import SwiftUI
import StarlaneCore

/// Simulated ad: a placeholder creative and a claim button that unlocks when the timer ends.
struct MockAdView: View {
    @Environment(GameCoordinator.self) private var coordinator
    let request: AdRequest

    @State private var isLoaded = false
    @State private var secondsLeft = 0
    @State private var isReady = false

    var body: some View {
        ZStack {
            Color(hex: "#07090D").ignoresSafeArea()
            VStack(spacing: 12) {
                HStack {
                    Text("Simulated ad").capsLabel(color: Theme.faint)
                        .padding(.horizontal, 8).padding(.vertical, 6)
                        .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(Theme.line, lineWidth: 1))
                    Spacer()
                    HStack(spacing: 8) {
                        Text(isLoaded ? "\(secondsLeft)" : "…").display(18, color: Theme.muted).monospacedDigit()
                        Text(request.kind == .rewarded ? "Reward in" : "Skip in").capsLabel(color: Theme.faint)
                    }
                    .padding(.horizontal, 12)
                    .frame(height: 36)
                    .overlay(RoundedRectangle(cornerRadius: Theme.radiusSmall).strokeBorder(Theme.line2, lineWidth: 1))
                    .opacity(isReady ? 0 : 1)
                }
                VStack(spacing: 20) {
                    if isLoaded {
                        LineIcon(name: request.creative.symbol, size: 40, color: Theme.muted, weight: .regular)
                            .frame(width: 96, height: 96)
                            .background(RoundedRectangle(cornerRadius: Theme.radius).fill(Theme.panel3))
                        VStack(spacing: 8) {
                            Text(request.creative.name).display(28)
                            Text(request.creative.blurb)
                                .font(.body(12.5)).foregroundStyle(Theme.muted)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: 240)
                        }
                        Button("Install · free") { coordinator.router.toast("Mock ad. Nothing installs.") }
                            .buttonStyle(.outline(color: Theme.muted, height: 40, size: 16))
                            .frame(width: 180)
                    } else {
                        ProgressView().progressViewStyle(.circular).tint(Theme.muted).scaleEffect(1.4)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .panel()
                VStack(spacing: 8) {
                    Button(action: finish) {
                        HStack {
                            Text(request.kind == .rewarded ? "Claim reward" : "Skip")
                            Spacer()
                            Text(isReady ? "Ready" : "Locked · \(secondsLeft)s").font(.body(12, weight: .semibold)).tracking(0.7).textCase(.uppercase)
                        }
                    }
                    .buttonStyle(.outline(isReady ? Theme.flare : Theme.line2, color: isReady ? Theme.flare : Theme.faint))
                    .disabled(!isReady)
                    Text("No ad network is contacted. Closing early forfeits the reward.")
                        .font(.body(11)).foregroundStyle(Theme.faint)
                }
            }
            .padding(16)
        }
        .task { await runTimeline() }
    }

    private func runTimeline() async {
        try? await Task.sleep(for: .milliseconds(900))
        isLoaded = true
        secondsLeft = request.kind.gateSeconds
        while secondsLeft > 0 {
            try? await Task.sleep(for: .seconds(1))
            secondsLeft -= 1
        }
        isReady = true
    }

    private func finish() {
        guard isReady else { return }
        coordinator.audio.play(.ui)
        coordinator.router.finishAd()
    }
}
