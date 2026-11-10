import Foundation

/// What Esc does in the popup. It always does something, whatever holds focus:
/// stop a stream, leave a notice card for the text behind it, or close.
enum PopupEscape: Equatable {
    case stop
    case backToText
    case close

    static func action(for state: PopupState, isOutputOnly: Bool) -> PopupEscape {
        switch state {
        case .streaming:
            return .stop
        case .error(_, nil), .missingKey, .keyRejected:
            return isOutputOnly ? .close : .backToText
        case .idle, .done, .error, .accessibilityRequired:
            return .close
        }
    }
}
