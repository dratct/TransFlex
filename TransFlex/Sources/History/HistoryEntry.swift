import Foundation
import GRDB

public struct HistoryEntry: Codable, Identifiable, Sendable, Equatable {
    public var id: UUID
    public var presetID: UUID
    public var providerID: String
    public var modelID: String
    public var inputText: String?
    public var outputText: String
    public var hadImage: Bool
    public var durationMs: Int?
    public var tokenCount: Int?
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        presetID: UUID,
        providerID: String,
        modelID: String,
        inputText: String?,
        outputText: String,
        hadImage: Bool = false,
        durationMs: Int? = nil,
        tokenCount: Int? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.presetID = presetID
        self.providerID = providerID
        self.modelID = modelID
        self.inputText = inputText
        self.outputText = outputText
        self.hadImage = hadImage
        self.durationMs = durationMs
        self.tokenCount = tokenCount
        self.createdAt = createdAt
    }
}

extension HistoryEntry: FetchableRecord, PersistableRecord {
    public static let databaseTableName = "history_entry"

    enum CodingKeys: String, CodingKey {
        case id, presetID, providerID, modelID
        case inputText, outputText, hadImage
        case durationMs, tokenCount, createdAt
    }
}
