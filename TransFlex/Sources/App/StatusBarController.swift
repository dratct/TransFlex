import AppKit
import Combine
import KeyboardShortcuts
import OSLog

@MainActor
final class StatusBarController: NSObject {
    private static let logger = Logger(subsystem: "io.aiaz.transflex", category: "StatusBar")

    private let statusItem: NSStatusItem
    private weak var popupWindowController: PopupWindowController?
    private var historyWindowController: HistoryWindowController?
    private let updater: AppUpdater?
    private var updateItem: NSMenuItem?
    private var baseIcon: NSImage?
    private var updateCancellable: AnyCancellable?

    init(
        popupWindowController: PopupWindowController? = nil,
        historyWindowController: HistoryWindowController? = nil,
        updater: AppUpdater? = nil
    ) {
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.popupWindowController = popupWindowController
        self.historyWindowController = historyWindowController
        self.updater = updater
        super.init()
        configureButton()
        configureMenu()
        updateCancellable = updater?.$updateFound
            .receive(on: RunLoop.main)
            .sink { [weak self] found in self?.showUpdateFound(found) }
    }

    private func configureButton() {
        guard let button = statusItem.button else { return }
        let appName = AppIdentity.current.displayName
        let image = NSImage(named: "MenuBarIcon")
            ?? NSImage(systemSymbolName: "sparkle", accessibilityDescription: appName)
        image?.isTemplate = true
        image?.size = NSSize(width: 18, height: 18)
        baseIcon = image
        button.image = image
        button.toolTip = appName
    }

    private func showUpdateFound(_ found: Bool) {
        updateItem?.title = UpdateMenu.title(updateFound: found)
        guard let baseIcon else { return }
        statusItem.button?.image = found ? UpdateMenu.iconWithDot(baseIcon) : baseIcon
    }

    private func configureMenu() {
        let appName = AppIdentity.current.displayName
        let menu = NSMenu()
        let openItem = makeItem("Open Popup", action: #selector(openPopup), key: "")
        // Mirrors the user's recorded hotkey and follows later changes to it.
        openItem.setShortcut(for: .openPopup)
        menu.addItem(openItem)
        menu.addItem(makeItem("History", action: #selector(openHistory), key: "y"))
        menu.addItem(.separator())
        if updater != nil {
            let item = makeItem(UpdateMenu.title(updateFound: false), action: #selector(checkForUpdates), key: "")
            updateItem = item
            menu.addItem(item)
        }
        menu.addItem(makeItem("Settings…", action: #selector(openSettings), key: ","))
        menu.addItem(makeItem("Quit \(appName)", action: #selector(quit), key: "q"))
        statusItem.menu = menu
    }

    private func makeItem(_ title: String, action: Selector, key: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        // Text-only items: AppKit would otherwise add a symbol to Settings alone.
        // Swift 6.4 ships with the macOS 27 SDK that declares this property.
        #if compiler(>=6.4)
        if #available(macOS 27.0, *) {
            item.preferredImageVisibility = .hidden
        }
        #endif
        return item
    }

    @objc private func openPopup() {
        popupWindowController?.toggle()
    }

    @objc private func openSettings() {
        AppCommands.openSettings()
    }

    @objc private func openHistory() {
        // The popup floats above normal windows and would cover History.
        popupWindowController?.hide()
        historyWindowController?.show()
    }

    @objc private func checkForUpdates() {
        updater?.checkForUpdates()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

extension StatusBarController: NSMenuItemValidation {
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        guard menuItem.action == #selector(checkForUpdates) else { return true }
        // Sparkle refuses a second check while one is already on screen.
        return updater?.canCheckForUpdates ?? false
    }
}

enum UpdateMenu {
    static func title(updateFound: Bool) -> String {
        updateFound ? "Update Available…" : "Check for Updates…"
    }

    /// The menu bar icon with a badge dot in its top-right corner. Stays a
    /// template image so it follows the menu bar's light and dark appearance.
    static func iconWithDot(_ base: NSImage) -> NSImage {
        let size = base.size
        let diameter = (size.width * 0.38).rounded()
        let dot = NSRect(x: size.width - diameter, y: size.height - diameter, width: diameter, height: diameter)
        let image = NSImage(size: size, flipped: false) { rect in
            base.draw(in: rect)
            // Clear a ring around the dot so it reads apart from the glyph.
            NSGraphicsContext.current?.compositingOperation = .destinationOut
            NSBezierPath(ovalIn: dot.insetBy(dx: -1.5, dy: -1.5)).fill()
            NSGraphicsContext.current?.compositingOperation = .sourceOver
            NSColor.black.setFill()
            NSBezierPath(ovalIn: dot).fill()
            return true
        }
        image.isTemplate = true
        return image
    }
}
