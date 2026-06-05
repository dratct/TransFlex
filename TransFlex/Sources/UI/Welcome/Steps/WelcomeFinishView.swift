import KeyboardShortcuts
import SwiftUI

@MainActor
struct WelcomeFinishView: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 8)

            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 56, weight: .semibold))
                .foregroundStyle(Color.green)
                .symbolRenderingMode(.hierarchical)

            Text("All set!")
                .font(.system(size: 22, weight: .semibold))

            VStack(spacing: 6) {
                Text("Hotkey")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .tracking(0.6)
                Text(currentHotkey)
                    .font(.system(size: 15, design: .monospaced))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color(nsColor: .controlBackgroundColor).opacity(0.6))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.white.opacity(0.06), lineWidth: 1)
                    )
            }

            HStack(spacing: 6) {
                Image("MenuBarIcon")
                    .resizable()
                    .renderingMode(.template)
                    .scaledToFit()
                    .frame(width: 12, height: 12)
                Text("Look for the TransFlex icon in the menu bar.")
                    .font(.system(size: 12))
            }
            .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(.top, 24)
        .frame(maxWidth: .infinity)
    }

    private var currentHotkey: String {
        KeyboardShortcuts.getShortcut(for: .openPopup)?.description ?? "—"
    }
}
