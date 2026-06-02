import Foundation

/// Distinct from `LLMError`: `ProviderError` covers configuration / registry
/// failures detected before a request is dispatched. Stream-time failures
/// flow through `LLMError` instead.
public enum ProviderError: Error, Equatable {
    case unknownProvider(id: String)
    case missingAPIKey(providerID: String)
    case invalidConfiguration(String)
}

extension ProviderError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .unknownProvider(let id): return "Unknown provider id: \(id)"
        case .missingAPIKey(let id): return "Missing API key for provider: \(id)"
        case .invalidConfiguration(let detail): return "Invalid provider configuration: \(detail)"
        }
    }
}
