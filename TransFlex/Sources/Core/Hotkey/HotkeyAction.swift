import Foundation
import KeyboardShortcuts

/// Discrete hotkey triggers exposed by the app.
public enum HotkeyAction: Hashable {
    case openPopup
    case preset(UUID)
    /// Translate the current selection and show only the result in the popup.
    case presetQuickPopup(UUID)
    /// Translate the current selection and paste the result over it.
    case presetQuickReplace(UUID)
}

extension KeyboardShortcuts.Name {
    /// Default global popup hotkey: ⌥Q. User-rebindable in Settings → Hotkeys.
    static let openPopup = Self(
        "openPopup",
        initial: .init(.q, modifiers: [.option])
    )

    /// Per-preset hotkey name. Stable across launches via the UUID string.
    static func preset(_ id: UUID) -> Self {
        Self("preset.\(id.uuidString)")
    }

    // KeyboardShortcuts 3.x rejects dots in names; `preset.<uuid>` predates
    // that rule and keeps its key so stored bindings survive.
    static func presetQuickPopup(_ id: UUID) -> Self {
        Self("preset-\(id.uuidString)-popup")
    }

    static func presetQuickReplace(_ id: UUID) -> Self {
        Self("preset-\(id.uuidString)-replace")
    }

    /// Every per-preset name, so add/remove paths cannot miss one.
    static func allPresetNames(_ id: UUID) -> [Self] {
        [.preset(id), .presetQuickPopup(id), .presetQuickReplace(id)]
    }
}
