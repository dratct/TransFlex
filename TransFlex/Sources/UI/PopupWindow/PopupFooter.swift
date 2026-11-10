import SwiftUI

/// Which buttons the popup shows per state (DESIGN.md › Popup states).
/// Pure, so the table is tested without a window.
enum PopupFooter {
    enum Action: Hashable {
        case showText, translate, stop, new, translateAgain, copyAndClose
        case backToText, openSystemSettings, done
        /// Strip action after a partial result.
        case retry

        var title: String {
            switch self {
            case .showText: return "Show text"
            case .translate: return "Translate"
            case .stop: return "Stop"
            case .new: return "New"
            case .translateAgain: return "Translate again"
            case .copyAndClose: return "Copy & Close"
            case .backToText: return "Back to text"
            case .openSystemSettings: return "Open System Settings"
            case .done: return "Done"
            case .retry: return "Retry"
            }
        }

        var keys: [String] {
            switch self {
            case .showText: return ["⌘", "I"]
            case .translate, .translateAgain, .openSystemSettings, .done, .retry: return ["⌘", "↩"]
            case .stop, .backToText: return ["esc"]
            case .new: return ["⌘", "N"]
            case .copyAndClose: return ["⌘", "C"]
            }
        }
    }

    struct Item: Equatable {
        let action: Action
        let prominence: FooterAction.Prominence
    }

    /// Footer buttons, left to right. `isWide` is false under 720pt, where
    /// Translate again keeps ⌘↩ but loses its button.
    static func items(for state: PopupState, isOutputOnly: Bool, isWide: Bool = true) -> [Item] {
        let showText: [Item] = isOutputOnly ? [Item(action: .showText, prominence: .plain)] : []
        switch state {
        case .idle:
            return showText + [Item(action: .translate, prominence: .primary)]
        case .streaming:
            return showText + [Item(action: .stop, prominence: .secondary)]
        case .done:
            if isOutputOnly {
                return showText + [Item(action: .copyAndClose, prominence: .primary)]
            }
            let again: [Item] = isWide ? [Item(action: .translateAgain, prominence: .secondary)] : []
            return [Item(action: .new, prominence: .plain)] + again
                + [Item(action: .copyAndClose, prominence: .primary)]
        case .error(_, .some):
            return isOutputOnly ? showText : [Item(action: .new, prominence: .plain)]
        case .error(_, nil), .missingKey:
            // Esc closes the Output-only popup, so it offers ⌘I instead.
            return isOutputOnly ? showText : [Item(action: .backToText, prominence: .plain)]
        case .accessibilityRequired(granted: false):
            return [Item(action: .openSystemSettings, prominence: .primary)]
        case .accessibilityRequired(granted: true):
            return [Item(action: .done, prominence: .primary)]
        }
    }

    /// The `Notice` strip's buttons after a partial result.
    static let partialStripItems = [
        Item(action: .retry, prominence: .primary),
    ]
}
