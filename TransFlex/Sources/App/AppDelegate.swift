import AppKit
import OSLog

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private static let logger = Logger(subsystem: "io.aiaz.transflex", category: "AppDelegate")
    /// Direct access path for code that can't reach AppDelegate via injection
    /// (e.g. NSPanel subclasses, bare AppKit helpers). SwiftUI may wrap
    /// `NSApp.delegate` so casting that is unreliable; this is the canonical
    /// way to reach the live AppDelegate instance from anywhere.
    static private(set) weak var shared: AppDelegate?
    private let launchStart = ProcessInfo.processInfo.systemUptime

    override init() {
        super.init()
        Self.shared = self
    }

    private var statusBarController: StatusBarController?
    private var popupWindowController: PopupWindowController?
    private var hotkeyManager: GlobalHotkeyManager?
    let presetStore = PresetStore()
    let providersStore = ProvidersStore()
    private(set) lazy var settingsWindowController = SettingsWindowController(presetStore: presetStore)
    private var historyStore: HistoryStore?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        // Register persisted OpenAI-compat endpoints into the shared registry
        // before any popup/translation path can run. Without this, compat
        // presets fail with `unknownProvider` until Settings is opened once.
        providersStore.registerAllWithRegistry()

        do {
            try DefaultPresets.seedIfNeeded(into: presetStore)
        } catch {
            Self.logger.error("preset seed failed: \(error.localizedDescription, privacy: .private)")
        }

        let historyStore: HistoryStore
        do {
            historyStore = try HistoryStore()
        } catch {
            Self.logger.error("History init failed, using in-memory fallback: \(error.localizedDescription, privacy: .private)")
            do {
                historyStore = try HistoryStore(inMemory: true)
            } catch {
                fatalError("Cannot create migrated in-memory history database")
            }
        }
        self.historyStore = historyStore

        let popup = PopupWindowController(
            presetStore: presetStore,
            historyStore: historyStore
        )
        let hotkey = GlobalHotkeyManager()
        hotkey.register(.openPopup) { [weak popup] in
            popup?.toggle()
        }

        // Register preset hotkeys (Option+1..9)
        for (index, preset) in presetStore.presets.prefix(9).enumerated() {
            let action = HotkeyAction.preset(preset.id)
            hotkey.register(action) { [weak popup] in
                popup?.activatePreset(at: index)
                if !(popup?.isVisible ?? false) {
                    popup?.show()
                }
            }
        }

        self.popupWindowController = popup
        self.hotkeyManager = hotkey
        self.statusBarController = StatusBarController(
            popupWindowController: popup,
            historyWindowController: HistoryWindowController(store: historyStore)
        )

        let defaults = UserDefaults.standard
        if !defaults.bool(forKey: "hasShownWelcome") {
            if defaults.bool(forKey: "hasCompletedFirstRun") {
                defaults.set(true, forKey: "hasShownWelcome")
            } else {
                WelcomeWindowController.shared.show(onFinish: { [weak self] in
                    self?.popupWindowController?.show()
                })
            }
        }

        let elapsedMs = (ProcessInfo.processInfo.systemUptime - launchStart) * 1000
        Self.logger.info("Launch finished in \(elapsedMs, privacy: .public) ms")
    }

    func applicationWillTerminate(_ notification: Notification) {
        Self.logger.info("App terminating")
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
