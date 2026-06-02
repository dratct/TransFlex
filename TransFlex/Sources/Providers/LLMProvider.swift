import Foundation

/// A streaming chat-completion provider for translation requests.
///
/// Implementations MUST honor `Task.cancel()` by aborting the in-flight request
/// promptly (target <100ms). Streams emit `LLMEvent` values until natural
/// termination via `.stop(_:)` or thrown `LLMError`.
public protocol LLMProvider: Sendable {
    var id: String { get }

    /// Largest image dimension (in pixels) the provider's vision API accepts
    /// without server-side downscaling penalties. Caller must pre-resize.
    var maxImageDim: Int { get }

    /// Returns the model catalog. Cloud providers fetch from their list-models
    /// API when `apiKey` is non-empty, falling back to `localModels` on empty
    /// key or fetch error. OpenAI-compat providers always fetch `/models`.
    func availableModels(apiKey: String) async throws -> [Model]

    /// Models known synchronously without network I/O. Cloud providers return
    /// their static fallback catalog. Providers requiring network fetch return `nil`.
    var localModels: [Model]? { get }

    func stream(
        messages: [ChatMessage],
        image: Data?,
        config: ProviderConfig
    ) -> AsyncThrowingStream<LLMEvent, Error>
}

public struct ChatMessage: Sendable, Equatable {
    public let role: ChatRole
    public let content: String

    public init(role: ChatRole, content: String) {
        self.role = role
        self.content = content
    }
}

public enum ChatRole: String, Sendable, Equatable {
    case system, user, assistant
}

public enum ModelSource: String, Sendable, Equatable, Codable {
    case fetched
    case fallback
}

public struct Model: Sendable, Equatable, Codable {
    public let id: String
    public let name: String
    public let supportsVision: Bool
    public let source: ModelSource

    public init(id: String, name: String, supportsVision: Bool, source: ModelSource = .fallback) {
        self.id = id
        self.name = name
        self.supportsVision = supportsVision
        self.source = source
    }
}

public struct ProviderConfig: Sendable {
    public let model: String
    public let temperature: Double
    public let topP: Double?
    public let maxTokens: Int?
    public let timeoutSeconds: TimeInterval
    public let baseURL: URL?
    public let extraHeaders: [String: String]
    public let apiKey: String
    public let extraBodyJSON: String

    public init(
        model: String,
        apiKey: String,
        temperature: Double = 0.3,
        topP: Double? = nil,
        maxTokens: Int? = nil,
        timeoutSeconds: TimeInterval = 60,
        baseURL: URL? = nil,
        extraHeaders: [String: String] = [:],
        extraBodyJSON: String = ""
    ) {
        self.model = model
        self.apiKey = apiKey
        self.temperature = temperature
        self.topP = topP
        self.maxTokens = maxTokens
        self.timeoutSeconds = timeoutSeconds
        self.baseURL = baseURL
        self.extraHeaders = extraHeaders
        self.extraBodyJSON = extraBodyJSON
    }
}
