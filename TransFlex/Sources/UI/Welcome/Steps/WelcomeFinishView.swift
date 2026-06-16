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

                if hotkeyKeys.isEmpty {
                    Text("—")
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
                } else {
                    HStack(spacing: 6) {
                        ForEach(0..<hotkeyKeys.count, id: \.self) { index in
                            Text(hotkeyKeys[index])
                                .font(.system(size: 14, design: .monospaced))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .fill(Color(nsColor: .controlBackgroundColor).opacity(0.6))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                                )

                            if index < hotkeyKeys.count - 1 {
                                Text("+")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            HStack(spacing: 6) {
                Image("MenuBarIcon")
                    .resizable()
                    .renderingMode(.template)
                    .scaledToFit()
                    .frame(width: 12, height: 12)
                Text("Look for the \(AppIdentity.current.displayName) icon in the menu bar.")
                    .font(.system(size: 12))
            }
            .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(.top, 24)
        .frame(maxWidth: .infinity)
    }

    private var hotkeyKeys: [String] {
        guard let shortcut = KeyboardShortcuts.getShortcut(for: .openPopup) else {
            return []
        }
        var keys: [String] = []
        let mods = shortcut.modifiers

        if mods.contains(.control) {
            keys.append("⌃")
        }
        if mods.contains(.option) {
            keys.append("⌥")
        }
        if mods.contains(.shift) {
            keys.append("⇧")
        }
        if mods.contains(.command) {
            keys.append("⌘")
        }

        let desc = shortcut.description
        var keySymbol = desc
        for modifier in ["⌃", "⌥", "⇧", "⌘"] {
            keySymbol = keySymbol.replacingOccurrences(of: modifier, with: "")
        }
        keySymbol = keySymbol.trimmingCharacters(in: .whitespacesAndNewlines)

        if !keySymbol.isEmpty {
            keys.append(keySymbol)
        }
        return keys
    }
}
