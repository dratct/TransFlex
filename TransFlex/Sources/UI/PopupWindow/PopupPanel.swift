import AppKit

/// Floating, non-activating panel used as the translator popup.
///
/// Why a custom subclass: `NSPanel` returns `false` from `canBecomeKey` by
/// default when `.nonactivatingPanel` is set; we override so the search
/// `TextField` can receive keyboard input without stealing app focus.
final class PopupPanel: NSPanel {
    /// Called whenever the panel is hidden — covers all paths (controller
    /// `hide()`, ESC via `cancelOperation`, app-activation observer in
    /// `PopupWindowController`). The controller wires this to its
    /// `lastHiddenAt` clock so the user-configured `PopupResetPolicy` sees
    /// an accurate "time since last hide".
    var onHide: (() -> Void)?

    init(contentRect: NSRect) {
        // Borderless panel — no `.titled`, so AppKit draws no titlebar, no
        // hairline separator, no traffic-light area. Resize is still allowed
        // via `.resizable`; `.nonactivatingPanel` keeps focus in the host app.
        super.init(
            contentRect: contentRect,
            styleMask: [.nonactivatingPanel, .resizable],
            backing: .buffered,
            defer: false
        )

        self.level = .floating
        self.isFloatingPanel = true
        self.becomesKeyOnlyIfNeeded = true
        self.hidesOnDeactivate = false
        self.isMovableByWindowBackground = true
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        self.hasShadow = true
        self.isReleasedWhenClosed = false
        self.backgroundColor = .clear
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    /// Single chokepoint for hide notifications. AppKit calls `orderOut` from
    /// every dismiss path (our subclass methods, controller, system) so this
    /// override guarantees `onHide` fires exactly once per real transition
    /// to hidden — no events when the panel was already hidden.
    override func orderOut(_ sender: Any?) {
        let wasVisible = isVisible
        super.orderOut(sender)
        if wasVisible { onHide?() }
    }

    /// Pressing ESC dismisses (Cocoa "cancel" action).
    override func cancelOperation(_ sender: Any?) {
        orderOut(nil)
    }

    // Intentionally NOT overriding `resignKey` to dismiss: window-key
    // changes fire for same-process child UI (Settings, NSOpenPanel,
    // NSAlert, Welcome wizard) which would dismiss the popup unexpectedly.
    // Dismissal is driven by app-level activation in `PopupWindowController`.

    /// `⌘,` fallback. SwiftUI `.keyboardShortcut` on a Button can be eaten by
    /// a focused TextEditor, and `.nonactivatingPanel` apps don't route the
    /// shortcut via the system menu bar, so intercept directly at panel level.
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if mods == .command, event.charactersIgnoringModifiers == "," {
            AppCommands.openSettings()
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
}
