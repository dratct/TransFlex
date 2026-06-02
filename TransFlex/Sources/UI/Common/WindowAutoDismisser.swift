import AppKit
import OSLog

/// Auto-dismiss helper for floating utility windows on an LSUIElement host.
///
/// Behaviour mirrors Raycast / iTerm hotkey window: when the user activates
/// any other application — by clicking, ⌘Tab, dock launch, or anything else
/// that changes the frontmost app — the bound window orders itself out.
///
/// Why two signals: on `.accessory` activation policy plus
/// `.nonactivatingPanel`, neither `NSWindow.didResignKeyNotification` nor
/// `NSWorkspace.didActivateApplicationNotification` is sufficient on its own:
///
///   * `didResignKey` fires for **same-process** child UI (Settings ↔ popup)
///     which we do NOT want to dismiss on.
///   * `didActivateApplication` misses clicks that don't change frontmost
///     (e.g. clicking the desktop or Dock).
///
/// We combine `addGlobalMonitorForEvents` (mouse-down delivered to other
/// processes — desktop, Dock, other windows) with the workspace activation
/// notification (covers ⌘Tab / dock-launch where no mouse click hits us).
/// The global monitor never delivers events to our own process, so clicks
/// inside our windows are naturally ignored — no manual hit-testing.
///
/// Sticky exception: when the frontmost bundle ID is on
/// `PopupDismissPolicy.defaultSystemDialogAllowlist` (Touch ID, keychain ACL,
/// NSOpenPanel host, etc.), the window stays. This is identical to popup
/// behaviour and keeps Settings usable while a system sheet is up.
@MainActor
final class WindowAutoDismisser {
    private static let logger = Logger(subsystem: "io.aiaz.transflex", category: "AutoDismiss")

    private weak var window: NSWindow?
    private let label: String
    private var workspaceObserver: NSObjectProtocol?
    private var mouseMonitor: Any?

    /// `label` is used as a tag in OSLog output so popup vs Settings dismiss
    /// events are distinguishable in `make log`.
    init(window: NSWindow, label: String) {
        self.window = window
        self.label = label
    }

    deinit {
        if let observer = workspaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        if let monitor = mouseMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    /// Arms both observers. Idempotent — calling twice replaces existing
    /// observers so we never leak handlers.
    func start() {
        stop()

        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            Task { @MainActor in
                let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
                self?.evaluate(frontmostBundleID: app?.bundleIdentifier, source: "activation")
            }
        }

        mouseMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { [weak self] _ in
            Task { @MainActor in
                let id = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
                self?.evaluate(frontmostBundleID: id, source: "click")
            }
        }
    }

    /// Disarms both observers. Call from window-close handlers and on hide
    /// so we don't keep firing while the window is off-screen.
    func stop() {
        if let observer = workspaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            workspaceObserver = nil
        }
        if let monitor = mouseMonitor {
            NSEvent.removeMonitor(monitor)
            mouseMonitor = nil
        }
    }

    private func evaluate(frontmostBundleID bundleID: String?, source: String) {
        guard let window = window, window.isVisible else { return }

        let ownBundleID = Bundle.main.bundleIdentifier ?? ""
        Self.logger.debug("[\(self.label, privacy: .public)] \(source, privacy: .public) frontmost=\(bundleID ?? "nil", privacy: .private)")

        if bundleID == ownBundleID { return }

        if PopupDismissPolicy.shouldHide(activatedBundleID: bundleID, ownBundleID: ownBundleID) {
            window.orderOut(nil)
        }
    }
}
