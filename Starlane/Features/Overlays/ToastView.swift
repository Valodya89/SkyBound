import SwiftUI

struct ToastView: View {
    let message: ToastMessage

    var body: some View {
        VStack {
            Spacer()
            Text(message.text)
                .font(.body(13, weight: .semibold))
                .foregroundStyle(Theme.text)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: Theme.radiusSmall).fill(Theme.panel2))
                .overlay(RoundedRectangle(cornerRadius: Theme.radiusSmall).strokeBorder(Theme.line2, lineWidth: 1))
                .frame(maxWidth: 320)
                .padding(.bottom, 108)
        }
        .transition(.opacity.combined(with: .offset(y: 10)))
        .allowsHitTesting(false)
    }
}
