import Foundation
import KeyboardShortcuts

/// A key combination belongs to one action. Recording it for another is
/// refused, naming the action that has it (CONTEXT.md › Rules).
enum ShortcutConflicts {
    static func owner(
        of shortcut: KeyboardShortcuts.Shortcut,
        excluding action: HotkeyAction,
        in bindings: [HotkeyAction: KeyboardShortcuts.Shortcut]
    ) -> HotkeyAction? {
        bindings.first { $0.key != action && $0.value == shortcut }?.key
    }

    /// The words the Settings rows use, so the user can find the owner.
    static func label(for action: HotkeyAction, presets: [Preset]) -> String {
        func named(_ id: UUID, _ row: String) -> String {
            let name = presets.first { $0.id == id }?.name ?? "Another preset"
            return "\(name) › \(row)"
        }
        switch action {
        case .openPopup: return "Open shortcut"
        case .preset(let id): return named(id, "Choose this preset")
        case .presetQuickPopup(let id): return named(id, "Translate selection")
        case .presetQuickReplace(let id): return named(id, "Replace selection")
        }
    }

    static func validate(
        _ shortcut: KeyboardShortcuts.Shortcut,
        for action: HotkeyAction,
        bindings: [HotkeyAction: KeyboardShortcuts.Shortcut],
        presets: [Preset]
    ) -> KeyboardShortcuts.ValidationResult {
        guard let owner = owner(of: shortcut, excluding: action, in: bindings) else { return .allow }
        return .disallow(reason: "Already used by \(label(for: owner, presets: presets)).")
    }

    /// For a recorder's `shortcutValidation`: checks against what is saved now.
    /// The recorder calls it on the main thread while it records.
    @MainActor
    static func validator(
        for action: HotkeyAction,
        presets: @escaping () -> [Preset]
    ) -> (KeyboardShortcuts.Shortcut) -> KeyboardShortcuts.ValidationResult {
        { shortcut in
            MainActor.assumeIsolated {
                let presets = presets()
                return validate(shortcut, for: action, bindings: savedBindings(presets: presets), presets: presets)
            }
        }
    }

    @MainActor
    private static func savedBindings(presets: [Preset]) -> [HotkeyAction: KeyboardShortcuts.Shortcut] {
        let actions = [HotkeyAction.openPopup] + presets.flatMap {
            [HotkeyAction.preset($0.id), .presetQuickPopup($0.id), .presetQuickReplace($0.id)]
        }
        var bindings: [HotkeyAction: KeyboardShortcuts.Shortcut] = [:]
        for action in actions {
            if let shortcut = KeyboardShortcuts.getShortcut(for: action.shortcutName) {
                bindings[action] = shortcut
            }
        }
        return bindings
    }
}
