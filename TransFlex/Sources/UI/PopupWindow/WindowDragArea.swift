import AppKit
import SwiftUI

/// A stretch of a SwiftUI view that drags its window (DESIGN.md › Pin).
///
/// `isMovableByWindowBackground` is not enough for a hosted SwiftUI view:
/// the hosting view takes the mouse-down itself and the window stays put.
struct WindowDragArea: NSViewRepresentable {
    func makeNSView(context: Context) -> WindowDragView { WindowDragView() }
    func updateNSView(_ nsView: WindowDragView, context: Context) {}
}

final class WindowDragView: NSView {
    /// The popup is often not the key window, and its app is rarely in
    /// front: without this the first press is spent on focus and never drags.
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        window?.performDrag(with: event)
    }
}
