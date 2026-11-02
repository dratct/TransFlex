import AppKit
import SwiftUI

/// The History search box. An AppKit search field because macOS 13 SwiftUI has
/// no way to see ↓ in a text field (`onKeyPress` is macOS 14+), and ↓ is how
/// the keyboard leaves the search for the list.
struct HistorySearchField: NSViewRepresentable {
    @Binding var query: String
    /// Bumped by the window's ⌘F to put the cursor back here.
    var focusRequest: Int
    var onMoveDown: () -> Void

    func makeNSView(context: Context) -> NSSearchField {
        let field = NSSearchField()
        field.placeholderString = "Search history..."
        field.delegate = context.coordinator
        field.target = context.coordinator
        field.action = #selector(Coordinator.searchChanged(_:))
        field.sendsSearchStringImmediately = true
        return field
    }

    func updateNSView(_ field: NSSearchField, context: Context) {
        context.coordinator.parent = self
        if field.stringValue != query { field.stringValue = query }
        if context.coordinator.lastFocusRequest != focusRequest {
            context.coordinator.lastFocusRequest = focusRequest
            DispatchQueue.main.async { field.window?.makeFirstResponder(field) }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    final class Coordinator: NSObject, NSSearchFieldDelegate {
        var parent: HistorySearchField
        var lastFocusRequest: Int

        init(parent: HistorySearchField) {
            self.parent = parent
            self.lastFocusRequest = parent.focusRequest
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSSearchField else { return }
            parent.query = field.stringValue
        }

        /// The clear button changes the text without a text-change notification.
        @objc func searchChanged(_ field: NSSearchField) {
            if parent.query != field.stringValue { parent.query = field.stringValue }
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
            guard selector == #selector(NSResponder.moveDown(_:)) else { return false }
            parent.onMoveDown()
            return true
        }
    }
}
