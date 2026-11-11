import Foundation

/// Which buttons the popup header shows (DESIGN.md › Pin).
/// Pure, so the table is tested without a window.
enum PopupHeader {
    enum Action: Hashable {
        case history, settings, pin, close
    }

    struct Item: Equatable {
        let action: Action
        let symbol: String
        /// The tooltip and the VoiceOver label.
        let title: String
        let keys: [String]
    }

    /// Header buttons, left to right.
    static func items(isPinned: Bool) -> [Item] {
        let items = [
            Item(action: .history, symbol: "clock.arrow.circlepath", title: "History", keys: ["⌘", "Y"]),
            Item(action: .settings, symbol: "gearshape", title: "Settings", keys: ["⌘", ","]),
            Item(action: .pin, symbol: isPinned ? "pin.fill" : "pin", title: isPinned ? "Unpin" : "Pin", keys: ["⌘", "P"]),
        ]
        // Esc sometimes stops a stream or goes back to the text, so a pinned
        // popup gets a button that always closes. It carries no key.
        return isPinned ? items + [Item(action: .close, symbol: "xmark", title: "Close", keys: [])] : items
    }
}
