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
    /// Nil for rows saved before `v2` and when the provider sent no usage.
    public var inputTokens: Int?
    public var outputTokens: Int?
    /// The estimate the popup showed, kept as it was; nil means "price unknown".
    public var costUSD: Double?
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
        inputTokens: Int? = nil,
        outputTokens: Int? = nil,
        costUSD: Double? = nil,
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
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.costUSD = costUSD
        self.createdAt = createdAt
    }
}

extension HistoryEntry: FetchableRecord, PersistableRecord {
    public static let databaseTableName = "history_entry"

    enum CodingKeys: String, CodingKey {
        case id, presetID, providerID, modelID
        case inputText, outputText, hadImage
        case durationMs, tokenCount, createdAt
        case inputTokens, outputTokens, costUSD
    }

    /// Writes every optional, nil as null: the JSON export promises the cost
    /// fields on every row, and GRDB stores the nulls as NULL columns.
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(presetID, forKey: .presetID)
        try c.encode(providerID, forKey: .providerID)
        try c.encode(modelID, forKey: .modelID)
        try c.encode(inputText, forKey: .inputText)
        try c.encode(outputText, forKey: .outputText)
        try c.encode(hadImage, forKey: .hadImage)
        try c.encode(durationMs, forKey: .durationMs)
        try c.encode(tokenCount, forKey: .tokenCount)
        try c.encode(inputTokens, forKey: .inputTokens)
        try c.encode(outputTokens, forKey: .outputTokens)
        try c.encode(costUSD, forKey: .costUSD)
        try c.encode(createdAt, forKey: .createdAt)
    }

    /// Migration columns are snake_case; the coding keys stay
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
        .inputTokens: "input_tokens",
        .outputTokens: "output_tokens",
        .costUSD: "cost_usd",
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
