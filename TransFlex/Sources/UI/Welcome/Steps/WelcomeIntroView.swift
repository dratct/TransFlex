import SwiftUI

@MainActor
struct WelcomeIntroView: View {
    var body: some View {
        VStack(spacing: 28) {
            Spacer().frame(height: 4)

            VStack(spacing: 12) {
                Image(systemName: "character.bubble.fill")
                    .font(.system(size: 64, weight: .semibold))
                    .foregroundStyle(Color.brandAccent)
                    .symbolRenderingMode(.hierarchical)

                Text("TransFlex")
                    .font(.system(.largeTitle, design: .rounded).weight(.bold))

                Text("Quick translation, anywhere on macOS.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                BulletCard(icon: "bolt.fill", label: "Global hotkey")
                BulletCard(icon: "arrow.left.arrow.right", label: "Multi-provider LLM")
                BulletCard(icon: "lock.shield.fill", label: "Keys stay local")
            }
            .padding(.horizontal, 28)

            Spacer()
        }
        .padding(.top, 24)
        .frame(maxWidth: .infinity)
    }
}

private struct BulletCard: View {
    let icon: String
    let label: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.brandAccent)
                .frame(height: 22)
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .multilineTextAlignment(.center)
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }
}
