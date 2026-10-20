import AppKit
import ApplicationServices

/// The Accessibility grant that lets the app post ⌘C/⌘V into other apps.
enum AccessibilityPermission {
    /// What System Settings calls the pane; macOS 27 renamed Accessibility.
    static var settingsPaneName: String {
        let renamed = OperatingSystemVersion(majorVersion: 27, minorVersion: 0, patchVersion: 0)
        return ProcessInfo.processInfo.isOperatingSystemAtLeast(renamed)
            ? "Device Control and Data Access"
            : "Accessibility"
    }

    /// The pane lists apps by bundle name ("TransFlexDev"), not display name.
    static var listedAppName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? AppIdentity.current.displayName
    }

    static func isGranted() -> Bool {
        AXIsProcessTrusted()
    }

    /// Opens the Accessibility pane of Privacy & Security. The prompt call comes first
    /// because it is what adds the app to that list; without it the user has
    /// to find the app with the + button.
    static func openSettings() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}
