import AppKit

/// Settings and History share one level and cascade by 24pt, so the window
/// opened last is in front and never exactly covers the other one.
@MainActor
enum UtilityWindowPlacement {
    static let cascadeOffset: CGFloat = 24

    private static let windows = NSHashTable<NSWindow>.weakObjects()
    private static var activationObservers: [NSObjectProtocol] = []

    /// Centres `window`, or puts it 24pt down and right of the frontmost other
    /// utility window. Call before the window is first shown.
    static func place(_ window: NSWindow) {
        track(window)
        window.level = NSApp.isActive ? .floating : .normal
        window.center()
        let front = NSApp.orderedWindows.first {
            $0 !== window && $0.isVisible && windows.contains($0)
        }
        if let front {
            window.setFrameOrigin(cascadedOrigin(size: window.frame.size, below: front.frame))
        }
    }

    /// While TransFlex is active these windows float, so one opened from the
    /// popup stays above it; when another app comes forward they drop to the
    /// normal level and never cover that app.
    private static func track(_ window: NSWindow) {
        windows.add(window)
        guard activationObservers.isEmpty else { return }
        let center = NotificationCenter.default
        activationObservers = [
            center.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { _ in
                MainActor.assumeIsolated { setLevel(.floating) }
            },
            center.addObserver(forName: NSApplication.didResignActiveNotification, object: nil, queue: .main) { _ in
                MainActor.assumeIsolated { setLevel(.normal) }
            },
        ]
    }

    private static func setLevel(_ level: NSWindow.Level) {
        for window in windows.allObjects { window.level = level }
    }

    /// Top-left corner 24pt right of and 24pt below `other`'s top-left corner.
    static func cascadedOrigin(size: NSSize, below other: NSRect) -> NSPoint {
        NSPoint(x: other.minX + cascadeOffset, y: other.maxY - cascadeOffset - size.height)
    }
}
