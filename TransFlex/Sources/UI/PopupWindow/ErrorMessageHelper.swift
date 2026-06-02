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
        if let te = error as? TranslationError {
            return te.localizedDescription
        }
        return error.localizedDescription
    }
}
