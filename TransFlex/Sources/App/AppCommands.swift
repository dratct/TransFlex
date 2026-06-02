import AppKit
import OSLog

@MainActor
enum AppCommands {
    private static let logger = Logger(subsystem: "io.aiaz.transflex", category: "Commands")

    /// Single entry point for opening the app-owned Settings window.
    static func openSettings(tab: SettingsTab = .general) {
        guard let controller = AppDelegate.shared?.settingsWindowController else {
            logger.error("openSettings: AppDelegate.shared is nil — delegate not yet wired")
            return
        }
        controller.show(tab: tab)
    }
}
