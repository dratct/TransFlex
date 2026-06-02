import Foundation
@testable import TransFlex

/// Configurable mock with a local model catalog. Used by the majority of
/// TranslationService tests that exercise the local-preflight code path.
final class MockLLMProvider: LLMProvider, @unchecked Sendable {
    let id = "mock"
    let maxImageDim = 1024

    var capturedMessages: [ChatMessage] = []
    var capturedImage: Data?
    var capturedConfig: ProviderConfig?
    var scriptedEvents: [LLMEvent] = []
    var scriptedError: Error?
    var scriptedModels: [Model] = [Model(id: "m1", name: "Mock", supportsVision: false)]

    var localModels: [Model]? { scriptedModels }
    func availableModels(apiKey: String) async throws -> [Model] { scriptedModels }

    func stream(
        messages: [ChatMessage],
        image: Data?,
        config: ProviderConfig
    ) -> AsyncThrowingStream<LLMEvent, Error> {
        capturedMessages = messages
        capturedImage = image
        capturedConfig = config
        let events = scriptedEvents
        let error = scriptedError
        return AsyncThrowingStream { continuation in
            for event in events { continuation.yield(event) }
            if let error { continuation.finish(throwing: error) } else { continuation.finish() }
        }
    }
}

/// Mock provider with `localModels == nil`, simulating OpenAI-compatible
/// endpoints where the catalog requires a `/models` network fetch. Tracks
/// whether `availableModels()` is called so tests can assert it is NOT
/// invoked on the hot translate path.
final class NoLocalCatalogMockProvider: LLMProvider, @unchecked Sendable {
    let id = "no-catalog-mock"
    let maxImageDim = 1024

    var availableModelsCalled = false
    var scriptedEvents: [LLMEvent] = []
    var scriptedError: Error?

    var localModels: [Model]? { nil }

    func availableModels(apiKey: String) async throws -> [Model] {
        availableModelsCalled = true
        return []
    }

    func stream(
        messages: [ChatMessage],
        image: Data?,
        config: ProviderConfig
    ) -> AsyncThrowingStream<LLMEvent, Error> {
        let events = scriptedEvents
        let error = scriptedError
        return AsyncThrowingStream { continuation in
            for event in events { continuation.yield(event) }
            if let error { continuation.finish(throwing: error) } else { continuation.finish() }
        }
    }
}
