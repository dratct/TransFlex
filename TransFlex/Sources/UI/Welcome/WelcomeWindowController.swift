import AppKit
import SwiftUI

/// Hosts the first-launch onboarding wizard in a dedicated NSWindow. Mirrors
/// `SettingsWindowController` so callers (currently AppDelegate) can
/// `WelcomeWindowController.shared.show()` and get a centered, non-resizable
/// titled window. Closing the window — via the red X or the final-step CTA —
/// marks `hasShownWelcome` so subsequent launches stay quiet.
@MainActor
final class WelcomeWindowController {
    static let shared = WelcomeWindowController()

    private var window: NSWindow?
    private var closeObserver: NSObjectProtocol?
    private var onFinishCallback: (() -> Void)?

    private init() {}

    func show(onFinish: (() -> Void)? = nil) {
        self.onFinishCallback = onFinish
        let win = window ?? makeWindow()
        window = win
        DockVisibilityController.shared.showDockIcon(for: .welcome)
        NSApp.activate(ignoringOtherApps: true)
        win.makeKeyAndOrderFront(nil)
        win.orderFrontRegardless()
    }

    private func makeWindow() -> NSWindow {
        let view = WelcomeView(onClose: { [weak self] invokedByFinish in
            self?.handleClose(invokedByFinish: invokedByFinish)
        })
        .tint(.brandAccent)

        let host = NSHostingController(rootView: view)
        let win = NSWindow(contentViewController: host)
        win.title = "Welcome to \(AppIdentity.current.displayName)"
        win.styleMask = [.titled, .closable]
        win.isReleasedWhenClosed = false
        win.setContentSize(NSSize(width: 620, height: 460))
        win.center()

        // Red-X / Cmd-W path: still mark welcome as shown but skip the
        // "Open Translator" callback.
        closeObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: win,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.markShown()
                self?.window = nil
                DockVisibilityController.shared.hideDockIcon(for: .welcome)
            }
        }
        return win
    }

    private func handleClose(invokedByFinish: Bool) {
        markShown()
        window?.close()
        if invokedByFinish {
            onFinishCallback?()
        }
    }

    private func markShown() {
        UserDefaults.standard.set(true, forKey: "hasShownWelcome")
    }
}
