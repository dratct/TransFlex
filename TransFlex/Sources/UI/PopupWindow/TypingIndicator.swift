import SwiftUI

/// Three-dot pulse shown while the model is thinking but has not emitted any
/// tokens yet. Anchors the empty streaming state so users see the request is
/// in flight rather than wondering if the popup hung.
struct TypingIndicator: View {
    @State private var animate = false

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(Color.secondary)
                    .frame(width: 7, height: 7)
                    .scaleEffect(animate ? 1.0 : 0.55)
                    .opacity(animate ? 1.0 : 0.45)
                    .animation(
                        .easeInOut(duration: 0.55)
                            .repeatForever(autoreverses: true)
                            .delay(Double(i) * 0.16),
                        value: animate
                    )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear { animate = true }
    }
}
