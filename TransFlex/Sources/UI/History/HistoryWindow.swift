import AppKit
import OSLog
import SwiftUI

@MainActor
final class HistoryWindowController {
    private static let logger = Logger(subsystem: "io.aiaz.transflex", category: "HistoryWindow")

    private var window: NSWindow?
    private var windowDelegate: HistoryWindowDelegate?
    private let store: HistoryStore
    private let presetStore: PresetStore

    /// Wide enough that the detail shows Original and Translation side by side.
    static let defaultContentSize = NSSize(width: 1000, height: 560)

    init(store: HistoryStore, presetStore: PresetStore) {
        self.store = store
        self.presetStore = presetStore
    }

    func show() {
        DockVisibilityController.shared.showDockIcon(for: .history)
        NSApp.activate(ignoringOtherApps: true)

        if let existing = window, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            return
        }

        let contentView = HistorySplitView(store: store, presets: presetStore) { [weak self] in self?.window }
        let hosting = NSHostingController(rootView: contentView)

        let frame = NSRect(origin: .zero, size: Self.defaultContentSize)
        let newWindow = NSWindow(
            contentRect: frame,
            // NavigationSplitView lays itself out for content that runs under
            // the toolbar; without this it draws a second toolbar-high backdrop
            // over the top of the detail column.
            styleMask: [.titled, .closable, .resizable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        newWindow.title = "History"
        newWindow.contentViewController = hosting
        // Assigning the controller shrinks the window to the view's fitting
        // size, so set the intended size afterwards.
        newWindow.setContentSize(frame.size)
        UtilityWindowPlacement.place(newWindow)
        newWindow.isReleasedWhenClosed = false
        let delegate = HistoryWindowDelegate { [weak self] in
            self?.window = nil
            self?.windowDelegate = nil
            DockVisibilityController.shared.hideDockIcon(for: .history)
            AppCommands.keepPopupAfterWindowClose()
        }
        newWindow.delegate = delegate
        windowDelegate = delegate
        newWindow.makeKeyAndOrderFront(nil)

        self.window = newWindow
    }
}

@MainActor
private final class HistoryWindowDelegate: NSObject, NSWindowDelegate {
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
