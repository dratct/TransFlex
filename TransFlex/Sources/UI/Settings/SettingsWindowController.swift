import AppKit
import SwiftUI

/// App-owned Settings window for menu-bar and popup command paths.
@MainActor
final class SettingsWindowController {
    private var window: NSWindow?
    private let presetStore: PresetStore
    private let tabState = SettingsTabState()
    private var autoDismisser: WindowAutoDismisser?
    private var windowDelegate: SettingsWindowDelegate?

    init(presetStore: PresetStore) {
        self.presetStore = presetStore
    }

    func show(tab: SettingsTab = .general) {
        tabState.selected = tab
        let win = window ?? makeWindow()
        window = win
        DockVisibilityController.shared.showDockIcon(for: .settings)
        NSApp.activate(ignoringOtherApps: true)
        win.makeKeyAndOrderFront(nil)
        win.orderFrontRegardless()

        if autoDismisser == nil {
            autoDismisser = WindowAutoDismisser(window: win, label: "settings") {
                DockVisibilityController.shared.hideDockIcon(for: .settings)
            }
        }
        autoDismisser?.start()
    }

    private func makeWindow() -> NSWindow {
        let view = SettingsRoot(tabState: tabState)
            .environmentObject(presetStore)
            .tint(.brandAccent)
        let host = NSHostingController(rootView: view)
        let win = NSWindow(contentViewController: host)
        win.title = "\(AppIdentity.current.displayName) Settings"
        win.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        win.isReleasedWhenClosed = false
        win.level = .floating
        win.setContentSize(NSSize(width: 720, height: 520))
        win.center()
        let delegate = SettingsWindowDelegate { [weak self] in
            self?.autoDismisser?.stop()
            DockVisibilityController.shared.hideDockIcon(for: .settings)
        }
        win.delegate = delegate
        windowDelegate = delegate
        return win
    }
}

/// Minimal delegate that forwards `windowWillClose` to a closure. Kept as a
/// concrete class because `NSWindow.delegate` is `weak` and a closure-only
/// adapter would deallocate immediately.
@MainActor
private final class SettingsWindowDelegate: NSObject, NSWindowDelegate {
    private let onClose: () -> Void

    init(onClose: @escaping () -> Void) {
        self.onClose = onClose
    }

    nonisolated func windowWillClose(_ notification: Notification) {
        Task { @MainActor in
            self.onClose()
        }
    }
}
