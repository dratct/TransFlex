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
            case .server(let status, let body) where (400..<500).contains(status):
                return "The provider rejected the request: \(providerReason(body) ?? "HTTP \(status)")"
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
            case .targetLost:
                return "The text you selected is no longer selected — you switched apps or the page changed — so nothing was pasted. The translation is on the clipboard: select the text again and press ⌘V."
            case .pasteNotApplied:
                return "The app didn’t accept the paste, so the text was not replaced. The translation is on the clipboard — press ⌘V to paste it yourself."
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

    /// `error.message` from an OpenAI-, Anthropic- or Gemini-style error body.
    private static func providerReason(_ body: String) -> String? {
        guard let data = body.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let error = json["error"] as? [String: Any],
              let message = error["message"] as? String,
              !message.isEmpty
        else { return nil }
        return message.count > 300 ? String(message.prefix(300)) + "…" : message
    }
}
