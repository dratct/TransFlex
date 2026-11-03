import AppKit

/// Settings and History share one level and cascade by 24pt, so the window
/// opened last is in front and never exactly covers the other one.
@MainActor
enum UtilityWindowPlacement {
    static let cascadeOffset: CGFloat = 24

    /// Centres `window`, or puts it 24pt down and right of the frontmost other
    /// utility window. Call before the window is first shown.
    static func place(_ window: NSWindow) {
        window.level = .floating
        window.center()
        let front = NSApp.orderedWindows.first {
            $0 !== window && $0.isVisible && $0.level == .floating && !($0 is NSPanel)
        }
        if let front {
            window.setFrameOrigin(cascadedOrigin(size: window.frame.size, below: front.frame))
        }
    }

    /// Top-left corner 24pt right of and 24pt below `other`'s top-left corner.
    static func cascadedOrigin(size: NSSize, below other: NSRect) -> NSPoint {
        NSPoint(x: other.minX + cascadeOffset, y: other.maxY - cascadeOffset - size.height)
    }
}
