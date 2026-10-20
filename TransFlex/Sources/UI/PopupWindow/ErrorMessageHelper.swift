import Foundation

/// Maps LLM/Translation errors to user-facing strings.
enum ErrorMessageHelper {
    static func friendly(_ error: Error) -> String {
        if let llm = error as? LLMError {
            switch llm {
            case .auth: return "API key invalid. Update in Settings."
            case .rateLimit(let retry):
                if let s = retry { return "Rate limited — try in \(Int(s))s." }
                return "Rate limited — try again shortly."
            case .network: return "No internet connection."
            case .server: return "Provider issue. Try again."
            case .invalidResponse, .decode: return "Provider returned unexpected response."
            case .cancelled: return "Request cancelled."
            case .providerMessage(let msg): return msg
            }
        }
        if let failure = error as? SelectionCapture.Failure {
            switch failure {
            case .accessibilityNotGranted:
                return "Allow \(AccessibilityPermission.listedAppName) in System Settings → Privacy & Security → \(AccessibilityPermission.settingsPaneName), then press the shortcut again."
            case .noSelection:
                return "No text selected. Select some text, then press the shortcut again."
            }
        }
        if error is QuickReplaceCoordinator.EmptyResult {
            return "The provider returned an empty translation. Nothing was replaced."
        }
        if let te = error as? TranslationError {
            return te.localizedDescription
        }
        return error.localizedDescription
    }
}
