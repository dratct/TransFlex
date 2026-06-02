import AppKit
import OSLog
import SwiftUI

@MainActor
final class HistoryWindowController {
    private static let logger = Logger(subsystem: "io.aiaz.transflex", category: "HistoryWindow")

    private var window: NSWindow?
    private let store: HistoryStore

    init(store: HistoryStore) {
        self.store = store
    }

    func show() {
        if let existing = window, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            return
        }

        let contentView = HistorySplitView(store: store)
        let hosting = NSHostingController(rootView: contentView)

        let frame = NSRect(x: 0, y: 0, width: 800, height: 500)
        let newWindow = NSWindow(
            contentRect: frame,
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        newWindow.title = "Translation History"
        newWindow.contentViewController = hosting
        newWindow.center()
        newWindow.isReleasedWhenClosed = false
        newWindow.makeKeyAndOrderFront(nil)

        self.window = newWindow
    }
}
