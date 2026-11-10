/// Why a provider with a key shows only its built-in model list.
enum ModelListFailure {
    static func reason(for error: Error, providerName: String) -> String {
        switch error as? LLMError {
        case .auth: return "The key was rejected."
        case .offline: return "You’re offline."
        case .network: return "Couldn’t reach \(providerName)."
        default: return "\(providerName) couldn’t list its models."
        }
    }
}
