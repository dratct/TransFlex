import Foundation

/// Pre-flight failures detected before a provider stream is opened. Network
/// / server errors flow through `LLMError` on the stream itself.
public enum TranslationError: Error, Equatable {
    case providerMissing(providerID: String)
    case modelMissing(providerID: String, modelID: String)
    case visionUnsupported(providerID: String, modelID: String)
}

extension TranslationError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .providerMissing(let id):
            return "Provider not configured: \(id). Open Settings → Providers to reassign."
        case .modelMissing(let pid, let model):
            return "Model \(model) not found on \(pid). Open Settings → Presets to select a valid model."
        case .visionUnsupported(let pid, let model):
            let provider = ProviderRegistry.shared.displayName(for: pid)
            return "This preset can't read images (\(provider) \(model)). Turn on Supports Vision in Settings → Presets, or switch to a preset that has it on."
        }
    }
}
