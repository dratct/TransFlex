import Foundation

/// Resolves the provider for a preset and forwards a streaming translation.
/// Pure orchestrator — emits `LLMEvent`s; persistence and UI side effects
/// stay with the caller.
public final class TranslationService: Sendable {
    public typealias ProviderResolver = @Sendable (_ providerID: String) throws -> LLMProvider
    public typealias APIKeyResolver = @Sendable (_ preset: Preset) -> String

    private let resolveProvider: ProviderResolver
    private let resolveAPIKey: APIKeyResolver

    /// `apiKey` returns the Keychain-loaded value for `preset`'s provider.
    /// An empty string is allowed for endpoints accepting unauthenticated
    /// access (e.g. local Ollama via OpenAI-compatible).
    public init(
        provider: @escaping ProviderResolver,
        apiKey: @escaping APIKeyResolver
    ) {
        self.resolveProvider = provider
        self.resolveAPIKey = apiKey
    }

    public convenience init(
        registry: ProviderRegistry,
        apiKey: @escaping APIKeyResolver
    ) {
        self.init(
            provider: { id in try registry.provider(for: id) },
            apiKey: apiKey
        )
    }

    public func translate(input: TranslationInput, preset: Preset) -> AsyncThrowingStream<LLMEvent, Error> {
        AsyncThrowingStream { continuation in
            let provider: LLMProvider
            do {
                provider = try resolveProvider(preset.providerID)
            } catch ProviderError.unknownProvider {
                continuation.finish(throwing: TranslationError.providerMissing(providerID: preset.providerID))
                return
            } catch {
                continuation.finish(throwing: error)
                return
            }

            let task = Task {
                do {
                    if case .image = input, !preset.supportsVision {
                        continuation.finish(throwing: TranslationError.visionUnsupported(
                            providerID: preset.providerID,
                            modelID: preset.modelID
                        ))
                        return
                    }

                    let messages = PromptBuilder.build(preset: preset, input: input)
                    let imageData: Data? = {
                        if case .image(let data, _) = input { return data }
                        return nil
                    }()

                    let config = ProviderConfig(
                        model: preset.modelID,
                        apiKey: self.resolveAPIKey(preset),
                        temperature: preset.temperature,
                        topP: preset.topP,
                        maxTokens: preset.maxTokens,
                        extraBodyJSON: preset.extraBody ?? ""
                    )

                    for try await event in provider.stream(messages: messages, image: imageData, config: config) {
                        continuation.yield(event)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
