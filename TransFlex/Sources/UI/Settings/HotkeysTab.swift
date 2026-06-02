import KeyboardShortcuts
import SwiftUI

@MainActor
struct HotkeysTab: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                heroHeader

                SettingsSection(
                    "Global Hotkeys",
                    footer: "Per-preset hotkeys are configured in the Presets tab."
                ) {
                    SettingsRow(
                        icon: "rectangle.on.rectangle",
                        iconTint: .brandAccent,
                        label: "Open Popup",
                        caption: "Show the translation popup from anywhere."
                    ) {
                        KeyboardShortcuts.Recorder(for: .openPopup)
                    }
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 22)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var heroHeader: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.brandAccent.gradient)
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: "keyboard.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                )
            VStack(alignment: .leading, spacing: 2) {
                Text("Hotkeys")
                    .font(.system(size: 16, weight: .semibold))
                Text("System-wide keyboard shortcuts")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
}
