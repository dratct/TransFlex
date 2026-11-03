import AppKit
import KeyboardShortcuts
import SwiftUI

enum ShortcutKeys {
    private static let order: [(NSEvent.ModifierFlags, String)] = [
        (.control, "⌃"), (.option, "⌥"), (.shift, "⇧"), (.command, "⌘"),
    ]

    /// One string per keycap, modifiers in menu order (⌃ ⌥ ⇧ ⌘), then the key.
    static func symbols(modifiers: NSEvent.ModifierFlags, key: String) -> [String] {
        order.filter { modifiers.contains($0.0) }.map(\.1) + (key.isEmpty ? [] : [key])
    }

    @MainActor
    static func symbols(for shortcut: KeyboardShortcuts.Shortcut) -> [String] {
        // `description` is the menu form ("⌥V"); what is left after the
        // modifier glyphs is the key.
        let key = order.reduce(shortcut.description) { $0.replacingOccurrences(of: $1.1, with: "") }
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return symbols(modifiers: shortcut.modifiers, key: key)
    }
}

/// A shortcut drawn as large keycaps ("⌥" "V"), for Welcome.
struct Keycaps: View {
    let keys: [String]

    var body: some View {
        HStack(spacing: Spacing.s) {
            if keys.isEmpty {
                Text("No shortcut")
                    .foregroundStyle(.secondary)
            }
            ForEach(Array(keys.enumerated()), id: \.offset) { _, key in
                Text(key)
                    .font(.system(size: 22, weight: .medium))
                    .frame(minWidth: 44, minHeight: 44)
                    .padding(.horizontal, key.count > 1 ? Spacing.s : 0)
                    .background(
                        RoundedRectangle(cornerRadius: Radius.pane, style: .continuous)
                            .fill(Color(nsColor: .textBackgroundColor))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.pane, style: .continuous)
                            .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 0.5)
                    )
                    .shadow(color: .black.opacity(0.08), radius: 0, y: 1)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(keys.isEmpty ? "No shortcut" : KeyHint.spokenLabel(for: keys))
    }
}
