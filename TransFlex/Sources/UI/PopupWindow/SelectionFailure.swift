import Foundation

/// What a Translate Selection failure banner says.
struct SelectionBanner: Equatable {
    let title: String
    let message: String
    let canRetry: Bool
}

enum SelectionFailureRoute: Equatable {
    case banner(SelectionBanner)
    /// Needs the popup: the permission card, a rejected key, a broken preset.
    case popupCard
    case ignore
}

/// Where a Translate Selection failure goes (DESIGN.md › Translate Selection).
enum SelectionFailure {
    static func route(for error: Error, providerName: String) -> SelectionFailureRoute {
        if error is CancellationError { return .ignore }
        if let failure = error as? SelectionCapture.Failure {
            if failure == .accessibilityNotGranted { return .popupCard }
            return .banner(SelectionBanner(title: "Nothing selected", message: "Select some text first.", canRetry: false))
        }
        if error is TranslationError { return .popupCard }
        guard let llm = error as? LLMError else {
            return .banner(SelectionBanner(title: "Couldn't translate", message: ErrorMessageHelper.friendly(error), canRetry: true))
        }
        let trouble = SelectionBanner(title: "\(providerName) is having trouble", message: "Try again in a moment.", canRetry: true)
        switch llm {
        case .cancelled: return .ignore
        case .auth: return .popupCard
        case .offline:
            return .banner(SelectionBanner(title: "You're offline", message: "Check your connection and try again.", canRetry: true))
        case .network:
            return .banner(SelectionBanner(title: "Couldn't reach \(providerName)", message: "Try again in a moment.", canRetry: true))
        case .server(let status, let body) where (400..<500).contains(status):
            let reason = ErrorMessageHelper.providerReason(body) ?? "HTTP \(status)"
            return .banner(SelectionBanner(title: "\(providerName) refused the request", message: reason, canRetry: true))
        case .providerMessage(let reason):
            return .banner(SelectionBanner(title: "\(providerName) refused the request", message: reason, canRetry: true))
        case .server, .rateLimit, .decode, .invalidResponse:
            return .banner(trouble)
        }
    }
}
