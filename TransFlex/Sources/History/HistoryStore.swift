import Foundation
import GRDB
import OSLog

@MainActor
final class HistoryStore: ObservableObject {
    private static let logger = Logger(subsystem: "io.aiaz.transflex", category: "HistoryStore")

    private let dbQueue: DatabaseQueue

    init(dbQueue: DatabaseQueue) {
        self.dbQueue = dbQueue
    }

    convenience init() throws {
        let database = try HistoryDatabase()
        self.init(dbQueue: database.dbQueue)
    }

    convenience init(inMemory: Bool) throws {
        let database = try HistoryDatabase(inMemory: inMemory)
        self.init(dbQueue: database.dbQueue)
    }

    func insert(_ entry: HistoryEntry) throws {
        try dbQueue.write { db in
            try entry.insert(db)
        }
    }

    func fetchPage(offset: Int, limit: Int = 50) throws -> [HistoryEntry] {
        try dbQueue.read { db in
            try HistoryEntry
                .order(Column("createdAt").desc)
                .limit(limit, offset: offset)
                .fetchAll(db)
        }
    }

    func search(query: String, limit: Int = 100) throws -> [HistoryEntry] {
        let escaped = Self.escapeFTS(query)
        guard !escaped.isEmpty else { return [] }

        return try dbQueue.read { db in
            let sql = """
                SELECT h.* FROM history_entry h
                JOIN history_fts fts ON h.rowid = fts.rowid
                WHERE history_fts MATCH ?
                ORDER BY h.created_at DESC
                LIMIT ?
                """
            let pattern = "input_text:\(escaped) OR output_text:\(escaped)"
            return try HistoryEntry.fetchAll(db, sql: sql, arguments: [pattern, limit])
        }
    }

    func prune(olderThan cutoff: Date) throws -> Int {
        let timestamp = cutoff.timeIntervalSince1970
        return try dbQueue.write { db in
            let count = try HistoryEntry
                .filter(Column("createdAt") < timestamp)
                .deleteAll(db)
            return count
        }
    }

    func delete(id: UUID) throws {
        try dbQueue.write { db in
            _ = try HistoryEntry.deleteOne(db, key: id)
        }
    }

    func deleteAll() throws {
        try dbQueue.write { db in
            _ = try HistoryEntry.deleteAll(db)
            try db.execute(sql: "INSERT INTO history_fts(history_fts) VALUES ('rebuild')")
        }
    }

    func allEntries() throws -> [HistoryEntry] {
        try dbQueue.read { db in
            try HistoryEntry.order(Column("createdAt").desc).fetchAll(db)
        }
    }

    private static func escapeFTS(_ query: String) -> String {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        // FTS5 special characters that need escaping
        let special = CharacterSet(charactersIn: "\"'()*+-.:/\\|!{}[]^~:")
        let escaped = trimmed.unicodeScalars.map { scalar in
            special.contains(scalar) ? "" : String(scalar)
        }.joined()
        return "\"\(escaped)\""
    }
}
