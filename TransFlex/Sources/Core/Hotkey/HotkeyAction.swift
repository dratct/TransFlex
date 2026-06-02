import Foundation
import KeyboardShortcuts

/// Discrete hotkey triggers exposed by the app.
public enum HotkeyAction: Hashable {
    case openPopup
    case preset(UUID)
}

extension KeyboardShortcuts.Name {
    /// Default global popup hotkey: ⌥Q. User-rebindable in Settings → Hotkeys.
    static let openPopup = Self(
        "openPopup",
        default: .init(.q, modifiers: [.option])
    )

    /// Per-preset hotkey name. Stable across launches via the UUID string.
    static func preset(_ id: UUID) -> Self {
        Self("preset.\(id.uuidString)")
    }
}
