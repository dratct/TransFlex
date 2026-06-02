import Foundation

public enum LLMEvent: Sendable, Equatable {
    case textDelta(String)
    case usage(input: Int, output: Int)
    case stop(reason: StopReason)
    case error(LLMError)
}

public enum StopReason: Sendable, Equatable {
    case complete
    case lengthCap
    case contentFilter
    case cancelled
    case providerError(String)
}

public enum LLMError: Error, Sendable, Equatable {
    case auth
    case rateLimit(retryAfterSeconds: Double?)
    case network(String)
    case decode(String)
    case cancelled
    case server(status: Int, body: String)
    case invalidResponse(String)
    case providerMessage(String)
}

extension LLMError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .auth: return "Authentication failed. Check the API key."
        case .rateLimit(let retry):
            if let retry { return "Rate limited. Retry after \(Int(retry))s." }
            return "Rate limited."
        case .network(let detail): return "Network error: \(detail)"
        case .decode(let detail): return "Response decoding failed: \(detail)"
        case .cancelled: return "Request cancelled."
        case .server(let status, let body): return "Server error \(status): \(body)"
        case .invalidResponse(let detail): return "Invalid response: \(detail)"
        case .providerMessage(let detail): return "Provider error: \(detail)"
        }
    }
}
