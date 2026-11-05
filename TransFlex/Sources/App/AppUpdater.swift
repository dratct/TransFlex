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
    /// Called when `canCheckForUpdates` changes, e.g. while a check is on screen.
    var onCanCheckChange: ((Bool) -> Void)? { get set }
    func checkForUpdates()
}

/// The one place the app talks to its update engine. Builds without a feed URL
/// (Debug, a future Mac App Store build) create no updater at all.
@MainActor
final class AppUpdater: ObservableObject {
    @Published private(set) var updateFound = false
    @Published private(set) var canCheckForUpdates: Bool

    private let driver: UpdaterDriver
    private let activateApp: () -> Void

    init(driver: UpdaterDriver, activateApp: (() -> Void)? = nil) {
        self.driver = driver
        self.activateApp = activateApp ?? { NSApp.activate(ignoringOtherApps: true) }
        self.canCheckForUpdates = driver.canCheckForUpdates
        driver.onUpdateFoundChange = { [weak self] found in
            self?.updateFound = found
        }
        driver.onCanCheckChange = { [weak self] canCheck in
            self?.canCheckForUpdates = canCheck
        }
    }

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

    /// Sparkle shows a scheduled find itself only when it may take focus (just
    /// after launch); otherwise the app badges it instead of an alert behind the
    /// app the user is typing in.
    nonisolated static func standardDriverShowsScheduledUpdate(immediateFocus: Bool) -> Bool {
        immediateFocus
    }

    nonisolated static func badgesUpdate(handledByStandardDriver: Bool, userInitiated: Bool) -> Bool {
        !handledByStandardDriver && !userInitiated
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
    var onCanCheckChange: ((Bool) -> Void)?
    private var controller: SPUStandardUpdaterController!
    private var canCheckObservation: NSKeyValueObservation?

    override init() {
        super.init()
        controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: self
        )
        canCheckObservation = controller.updater.observe(\.canCheckForUpdates, options: [.new]) { [weak self] updater, _ in
            let canCheck = updater.canCheckForUpdates
            Task { @MainActor in self?.onCanCheckChange?(canCheck) }
        }
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
        AppUpdater.standardDriverShowsScheduledUpdate(immediateFocus: immediateFocus)
    }

    nonisolated func standardUserDriverWillHandleShowingUpdate(
        _ handleShowingUpdate: Bool,
        forUpdate update: SUAppcastItem,
        state: SPUUserUpdateState
    ) {
        guard AppUpdater.badgesUpdate(handledByStandardDriver: handleShowingUpdate, userInitiated: state.userInitiated) else { return }
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
