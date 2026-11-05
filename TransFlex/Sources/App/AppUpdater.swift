import AppKit
import Combine

/// What `AppUpdater` needs from the update engine; Sparkle in the app, a fake in tests.
@MainActor
protocol UpdaterDriver: AnyObject {
    var canCheckForUpdates: Bool { get }
    var automaticallyChecksForUpdates: Bool { get set }
    /// Called with `true` when a scheduled check finds an update the user has not seen,
    /// and with `false` once the user attends to it or the update session ends.
    var onUpdateFoundChange: ((Bool) -> Void)? { get set }
    func checkForUpdates()
}

/// The one place the app talks to its update engine. Builds without a feed URL
/// (Debug, a future Mac App Store build) create no updater at all.
@MainActor
final class AppUpdater: ObservableObject {
    @Published private(set) var updateFound = false

    private let driver: UpdaterDriver
    private let activateApp: () -> Void

    init(driver: UpdaterDriver, activateApp: (() -> Void)? = nil) {
        self.driver = driver
        self.activateApp = activateApp ?? { NSApp.activate(ignoringOtherApps: true) }
        driver.onUpdateFoundChange = { [weak self] found in
            self?.updateFound = found
        }
    }

    var canCheckForUpdates: Bool { driver.canCheckForUpdates }

    var automaticallyChecksForUpdates: Bool {
        get { driver.automaticallyChecksForUpdates }
        set {
            objectWillChange.send()
            driver.automaticallyChecksForUpdates = newValue
        }
    }

    func checkForUpdates() {
        // A menu bar app is not active when its menu is used; the update window
        // would open behind the frontmost app.
        activateApp()
        driver.checkForUpdates()
    }

    static func isEnabled(infoDictionary: [String: Any]) -> Bool {
        guard let feed = infoDictionary["SUFeedURL"] as? String else { return false }
        return !feed.trimmingCharacters(in: .whitespaces).isEmpty
    }

    static func makeForMainBundle() -> AppUpdater? {
        #if canImport(Sparkle)
        guard isEnabled(infoDictionary: Bundle.main.infoDictionary ?? [:]) else { return nil }
        return AppUpdater(driver: SparkleDriver())
        #else
        return nil
        #endif
    }
}

#if canImport(Sparkle)
import Sparkle

@MainActor
private final class SparkleDriver: NSObject, UpdaterDriver, SPUStandardUserDriverDelegate {
    var onUpdateFoundChange: ((Bool) -> Void)?
    private var controller: SPUStandardUpdaterController!

    override init() {
        super.init()
        controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: self
        )
    }

    var canCheckForUpdates: Bool { controller.updater.canCheckForUpdates }

    var automaticallyChecksForUpdates: Bool {
        get { controller.updater.automaticallyChecksForUpdates }
        set { controller.updater.automaticallyChecksForUpdates = newValue }
    }

    func checkForUpdates() {
        controller.checkForUpdates(nil)
    }

    // MARK: Gentle reminders — a scheduled find shows as a dot and a menu item
    // instead of an alert behind whatever app the user is typing in.

    nonisolated var supportsGentleScheduledUpdateReminders: Bool { true }

    nonisolated func standardUserDriverShouldHandleShowingScheduledUpdate(
        _ update: SUAppcastItem,
        andInImmediateFocus immediateFocus: Bool
    ) -> Bool {
        immediateFocus
    }

    nonisolated func standardUserDriverWillHandleShowingUpdate(
        _ handleShowingUpdate: Bool,
        forUpdate update: SUAppcastItem,
        state: SPUUserUpdateState
    ) {
        guard !state.userInitiated else { return }
        MainActor.assumeIsolated { onUpdateFoundChange?(true) }
    }

    nonisolated func standardUserDriverDidReceiveUserAttention(forUpdate update: SUAppcastItem) {
        MainActor.assumeIsolated { onUpdateFoundChange?(false) }
    }

    nonisolated func standardUserDriverWillFinishUpdateSession() {
        MainActor.assumeIsolated { onUpdateFoundChange?(false) }
    }
}
#endif
