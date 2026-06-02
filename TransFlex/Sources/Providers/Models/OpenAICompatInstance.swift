import Foundation

/// User-configurable OpenAI-compatible endpoint (Ollama, vLLM, LM Studio,
/// LocalAI, third-party gateways). Keys live in Keychain; `instanceId` links
/// this metadata to the stored secret.
public struct OpenAICompatInstance: Codable, Equatable, Sendable, Identifiable {
    public var id: String { instanceId }
    public let instanceId: String
    public let displayName: String
    public let baseURL: URL
    public let defaultModel: String?
    public let extraHeaderNames: [String]
    public let extraHeaders: [String: String]
    public let inputPricePer1k: Double?
    public let outputPricePer1k: Double?

    public init(
        instanceId: String,
        displayName: String,
        baseURL: URL,
        defaultModel: String? = nil,
        extraHeaderNames: [String]? = nil,
        extraHeaders: [String: String] = [:],
        inputPricePer1k: Double? = nil,
        outputPricePer1k: Double? = nil
    ) {
        self.instanceId = instanceId
        self.displayName = displayName
        self.baseURL = baseURL
        self.defaultModel = defaultModel
        self.extraHeaderNames = (extraHeaderNames ?? Array(extraHeaders.keys)).sorted()
        self.extraHeaders = extraHeaders
        self.inputPricePer1k = inputPricePer1k
        self.outputPricePer1k = outputPricePer1k
    }

    enum CodingKeys: String, CodingKey {
        case instanceId
        case displayName
        case baseURL
        case defaultModel
        case extraHeaderNames
        case extraHeaders
        case inputPricePer1k
        case outputPricePer1k
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let legacyHeaders = try container.decodeIfPresent([String: String].self, forKey: .extraHeaders) ?? [:]
        let names = try container.decodeIfPresent([String].self, forKey: .extraHeaderNames)

        self.instanceId = try container.decode(String.self, forKey: .instanceId)
        self.displayName = try container.decode(String.self, forKey: .displayName)
        self.baseURL = try container.decode(URL.self, forKey: .baseURL)
        self.defaultModel = try container.decodeIfPresent(String.self, forKey: .defaultModel)
        self.extraHeaderNames = (names ?? Array(legacyHeaders.keys)).sorted()
        self.extraHeaders = legacyHeaders
        self.inputPricePer1k = try container.decodeIfPresent(Double.self, forKey: .inputPricePer1k)
        self.outputPricePer1k = try container.decodeIfPresent(Double.self, forKey: .outputPricePer1k)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(instanceId, forKey: .instanceId)
        try container.encode(displayName, forKey: .displayName)
        try container.encode(baseURL, forKey: .baseURL)
        try container.encodeIfPresent(defaultModel, forKey: .defaultModel)
        try container.encode(extraHeaderNames, forKey: .extraHeaderNames)
        try container.encodeIfPresent(inputPricePer1k, forKey: .inputPricePer1k)
        try container.encodeIfPresent(outputPricePer1k, forKey: .outputPricePer1k)
    }
}
