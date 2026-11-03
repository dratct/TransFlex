import KeyboardShortcuts

/// Takes Esc away from every app while held. Replace Selection holds it only
/// while a run is active and must release it on every way out.
@MainActor
protocol EscapeHold: AnyObject {
    func hold(onPress: @escaping () -> Void)
    func release()
}

@MainActor
final class GlobalEscapeHold: EscapeHold {
    private static let name = KeyboardShortcuts.Name(
        "replaceSelectionCancel",
        initial: KeyboardShortcuts.Shortcut(.escape)
    )
    private var isHeld = false

    func hold(onPress: @escaping () -> Void) {
        release()
        isHeld = true
        KeyboardShortcuts.onKeyDown(for: Self.name, action: onPress)
    }

    /// Removing the last handler unregisters the hotkey, so Esc reaches
    /// other apps again.
    func release() {
        guard isHeld else { return }
        isHeld = false
        KeyboardShortcuts.removeHandler(for: Self.name)
    }
}
