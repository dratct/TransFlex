import AppKit
import OSLog

@MainActor
final class StatusBarController: NSObject {
    private static let logger = Logger(subsystem: "io.aiaz.transflex", category: "StatusBar")

    private let statusItem: NSStatusItem
    private weak var popupWindowController: PopupWindowController?
    private var historyWindowController: HistoryWindowController?

    init(popupWindowController: PopupWindowController? = nil, historyWindowController: HistoryWindowController? = nil) {
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.popupWindowController = popupWindowController
        self.historyWindowController = historyWindowController
        super.init()
        configureButton()
        configureMenu()
    }

    private func configureButton() {
        guard let button = statusItem.button else { return }
        let appName = AppIdentity.current.displayName
        let image = NSImage(named: "MenuBarIcon")
            ?? NSImage(systemSymbolName: "sparkle", accessibilityDescription: appName)
        image?.isTemplate = true
        image?.size = NSSize(width: 18, height: 18)
        button.image = image
        button.toolTip = appName
    }

    private func configureMenu() {
        let appName = AppIdentity.current.displayName
        let menu = NSMenu()
        menu.addItem(makeItem("Open Popup", action: #selector(openPopup), key: ""))
        menu.addItem(makeItem("Settings…", action: #selector(openSettings), key: ","))
        menu.addItem(makeItem("History", action: #selector(openHistory), key: ""))
        menu.addItem(.separator())
        menu.addItem(makeItem("Quit \(appName)", action: #selector(quit), key: "q"))
        statusItem.menu = menu
    }

    private func makeItem(_ title: String, action: Selector, key: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    @objc private func openPopup() {
        popupWindowController?.toggle()
    }

    @objc private func openSettings() {
        AppCommands.openSettings()
    }

    @objc private func openHistory() {
        historyWindowController?.show()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
