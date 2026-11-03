import SwiftUI

/// Shortcut hint drawn inside a button: one small capsule per key.
/// VoiceOver reads it as words ("Command Return") instead of glyphs.
struct KeyHint: View {
    let keys: [String]
    /// True inside a prominent (accent-filled) button.
    var onAccent = false

    var body: some View {
        HStack(spacing: 2) {
            ForEach(Array(keys.enumerated()), id: \.offset) { _, key in
                Text(key)
                    .font(.system(size: 10.5, weight: .medium))
                    .frame(minWidth: 17, minHeight: 17)
                    .padding(.horizontal, key.count > 1 ? 4 : 0)
                    .background(Capsule().fill(fill))
                    .opacity(0.85)
            }
        }
        .fixedSize()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Self.spokenLabel(for: keys))
    }

    private var fill: Color {
        onAccent ? .white.opacity(0.22) : Color.gray.opacity(0.16)
    }

    private static let spokenNames: [String: String] = [
        "⌘": "Command", "⇧": "Shift", "⌥": "Option", "⌃": "Control",
        "↩": "Return", "⏎": "Return", "esc": "Escape", "⌫": "Delete",
    ]

    static func spokenLabel(for keys: [String]) -> String {
        keys.map { spokenNames[$0] ?? $0 }.joined(separator: " ")
    }
}
