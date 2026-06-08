import KeyboardShortcuts
import SwiftUI

@MainActor
struct WelcomeHotkeyView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Set your global hotkey")
                    .font(.system(size: 17, weight: .semibold))
                Text("Press this anywhere to open \(AppIdentity.current.displayName).")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                Image(systemName: "keyboard.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.brandAccent)
                    .frame(width: 28)
                Text("Open \(AppIdentity.current.displayName)")
                    .font(.system(size: 13))
                Spacer()
                KeyboardShortcuts.Recorder(for: .openPopup)
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.regularMaterial)
            )

            HStack(spacing: 6) {
                Image(systemName: "info.circle")
                    .font(.system(size: 11))
                Text("You can change this later in Settings → Hotkeys.")
                    .font(.system(size: 12))
            }
            .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(.horizontal, 32)
        .padding(.top, 28)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
