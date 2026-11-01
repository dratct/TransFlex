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

    /// Columns of the `v1` migration are snake_case; the coding keys stay
    /// camelCase so the JSON export keeps its field names.
    private static let columnNames: [CodingKeys: String] = [
        .id: "id",
        .presetID: "preset_id",
        .providerID: "provider_id",
        .modelID: "model_id",
        .inputText: "input_text",
        .outputText: "output_text",
        .hadImage: "had_image",
        .durationMs: "duration_ms",
        .tokenCount: "token_count",
        .createdAt: "created_at",
    ]

    public static let databaseColumnEncodingStrategy = DatabaseColumnEncodingStrategy.custom { key in
        CodingKeys(stringValue: key.stringValue).flatMap { columnNames[$0] } ?? key.stringValue
    }

    public static let databaseColumnDecodingStrategy = DatabaseColumnDecodingStrategy.custom { column in
        if let key = columnNames.first(where: { $0.value == column })?.key { return key }
        return UnknownColumn(stringValue: column)
    }

    private struct UnknownColumn: CodingKey {
        var stringValue: String
        var intValue: Int? { nil }
        init(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { nil }
    }

    public enum Columns {
        static let createdAt = Column("created_at")
    }

    /// `created_at` is a REAL column; prune compares it with seconds since 1970.
    public static func databaseDateEncodingStrategy(for column: String) -> DatabaseDateEncodingStrategy {
        .timeIntervalSince1970
    }

    public static func databaseDateDecodingStrategy(for column: String) -> DatabaseDateDecodingStrategy {
        .timeIntervalSince1970
    }
}
