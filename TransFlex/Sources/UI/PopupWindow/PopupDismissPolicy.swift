import Foundation

/// Decide whether the popup should auto-dismiss when another app activates.
/// Lives outside `PopupWindowController` so we can unit-test the policy
/// without an AppKit notification or `NSRunningApplication` instance.
enum PopupDismissPolicy {
    /// Bundle IDs of system processes that present transient overlays
    /// (auth sheets, notification banners, screen-capture indicator) which
    /// must NOT dismiss the popup. Evidence-based — extend via DEBUG logs.
    static let defaultSystemDialogAllowlist: Set<String> = [
        "com.apple.coreauthd",
        "com.apple.security.authtrampoline",
        "com.apple.SecurityAgent",
        "com.apple.LocalAuthentication.UIService",
        "com.apple.UserNotificationCenter",
        "com.apple.replayd",
        // Sandboxed NSOpenPanel/NSSavePanel host process. The image-attach
        // file picker activates this XPC service; without the allowlist
        // entry the popup would auto-dismiss the moment the picker opens.
        "com.apple.appkit.xpc.openAndSavePanelService",
    ]

    /// `nil`/empty bundle ID is treated as a real-app activation (hide).
    /// In practice every real `NSRunningApplication` has a bundleID; missing
    /// values come from anonymous helper processes we cannot whitelist.
    static func shouldHide(
        activatedBundleID: String?,
        ownBundleID: String,
        allowlist: Set<String> = defaultSystemDialogAllowlist
    ) -> Bool {
        guard let id = activatedBundleID, !id.isEmpty else { return true }
        if id == ownBundleID { return false }
        if allowlist.contains(id) { return false }
        return true
    }
}
