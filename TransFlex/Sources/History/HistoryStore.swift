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

    convenience init(path: URL) throws {
        let database = try HistoryDatabase(path: path)
        self.init(dbQueue: database.dbQueue)
    }

    /// Today's spend: the sum of priced entries since the start of `now`'s
    /// day (nil when none is priced) and how many of today's entries have no price.
    func todayCost(now: Date, calendar: Calendar) throws -> (total: Double?, unpriced: Int) {
        let day = calendar.dateInterval(of: .day, for: now) ?? DateInterval(start: calendar.startOfDay(for: now), duration: 86_400)
        return try dbQueue.read { db in
            let row = try Row.fetchOne(db, sql: """
                SELECT SUM(cost_usd) AS total,
                       COUNT(*) - COUNT(cost_usd) AS unpriced
                FROM history_entry WHERE created_at >= ? AND created_at < ?
                """, arguments: [day.start.timeIntervalSince1970, day.end.timeIntervalSince1970])
            return (row?["total"], row?["unpriced"] ?? 0)
        }
    }

    func insert(_ entry: HistoryEntry) throws {
        try dbQueue.write { db in
            try entry.insert(db)
        }
    }

    func fetchPage(offset: Int, limit: Int = 50) throws -> [HistoryEntry] {
        try dbQueue.read { db in
            try HistoryEntry
                .order(HistoryEntry.Columns.createdAt.desc)
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
                .filter(HistoryEntry.Columns.createdAt < timestamp)
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
            try HistoryEntry.order(HistoryEntry.Columns.createdAt.desc).fetchAll(db)
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
