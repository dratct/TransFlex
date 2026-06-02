import Foundation

/// A user-facing translation profile: provider/model selection plus the
/// system prompt that drives detect-and-translate behavior.
public struct Preset: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var hotkey: KeyCombo?
    public var providerID: String
    public var modelID: String
    public var systemPrompt: String
    public var temperature: Double
    public var topP: Double?
    public var maxTokens: Int?
    public var supportsVision: Bool
    public var extraBody: String?
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        hotkey: KeyCombo? = nil,
        providerID: String,
        modelID: String,
        systemPrompt: String,
        temperature: Double = 0.3,
        topP: Double? = nil,
        maxTokens: Int? = nil,
        supportsVision: Bool = false,
        extraBody: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.hotkey = hotkey
        self.providerID = providerID
        self.modelID = modelID
        self.systemPrompt = systemPrompt
        self.temperature = temperature
        self.topP = topP
        self.maxTokens = maxTokens
        self.supportsVision = supportsVision
        self.extraBody = extraBody
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
