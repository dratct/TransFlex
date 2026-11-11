import AppKit

/// Speaks a short status line to VoiceOver without moving its focus.
@MainActor
protocol Announcing {
    func announce(_ message: String)
}

/// Posts the line as a VoiceOver announcement; with VoiceOver off nothing is heard.
struct VoiceOverAnnouncer: Announcing {
    /// Default arguments are built outside the main actor.
    nonisolated init() {}

    func announce(_ message: String) {
        NSAccessibility.post(
            element: NSApp as Any,
            notification: .announcementRequested,
            userInfo: [
                .announcement: message,
                .priority: NSAccessibilityPriorityLevel.high.rawValue,
            ]
        )
    }
}
