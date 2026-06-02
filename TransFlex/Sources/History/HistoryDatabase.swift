import Foundation
import GRDB
import OSLog

final class HistoryDatabase {
    private static let logger = Logger(subsystem: "io.aiaz.transflex", category: "HistoryDB")

    let dbQueue: DatabaseQueue

    init() throws {
        let dbDir = Self.databaseDirectory()
        try FileManager.default.createDirectory(at: dbDir, withIntermediateDirectories: true)

        var config = Configuration()
        config.prepareDatabase { db in
            try db.execute(sql: "PRAGMA journal_mode=WAL")
        }

        self.dbQueue = try DatabaseQueue(path: Self.databasePath().path, configuration: config)

        try migrate(dbQueue)
        try Self.excludeFromBackup()
    }

    init(inMemory: Bool) throws {
        var config = Configuration()
        config.prepareDatabase { db in
            try db.execute(sql: "PRAGMA journal_mode=MEMORY")
        }

        self.dbQueue = try DatabaseQueue(configuration: config)
        try migrate(dbQueue)
    }

    // MARK: - Paths

    private static func databaseDirectory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("TransFlex", isDirectory: true)
    }

    static func databasePath() -> URL {
        databaseDirectory().appendingPathComponent("history.sqlite")
    }

    // MARK: - Migration

    private func migrate(_ dbQueue: DatabaseQueue) throws {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("v1") { db in
            try db.execute(sql: """
                CREATE TABLE history_entry (
                    id TEXT PRIMARY KEY NOT NULL,
                    preset_id TEXT NOT NULL,
                    provider_id TEXT NOT NULL,
                    model_id TEXT NOT NULL,
                    input_text TEXT,
                    output_text TEXT NOT NULL,
                    had_image INTEGER NOT NULL DEFAULT 0,
                    duration_ms INTEGER,
                    token_count INTEGER,
                    created_at REAL NOT NULL
                )
                """)

            try db.execute(sql: """
                CREATE INDEX idx_history_created_at ON history_entry(created_at DESC)
                """)

            try db.execute(sql: """
                CREATE VIRTUAL TABLE history_fts USING fts5(
                    input_text, output_text,
                    content='history_entry', content_rowid='rowid',
                    tokenize='unicode61 remove_diacritics 2'
                )
                """)

            try db.execute(sql: """
                CREATE TRIGGER history_fts_insert AFTER INSERT ON history_entry BEGIN
                    INSERT INTO history_fts(rowid, input_text, output_text)
                    VALUES (NEW.rowid, NEW.input_text, NEW.output_text);
                END
                """)

            try db.execute(sql: """
                CREATE TRIGGER history_fts_delete AFTER DELETE ON history_entry BEGIN
                    INSERT INTO history_fts(history_fts, rowid, input_text, output_text)
                    VALUES ('delete', OLD.rowid, OLD.input_text, OLD.output_text);
                END
                """)

            try db.execute(sql: """
                CREATE TRIGGER history_fts_update AFTER UPDATE ON history_entry BEGIN
                    INSERT INTO history_fts(history_fts, rowid, input_text, output_text)
                    VALUES ('delete', OLD.rowid, OLD.input_text, OLD.output_text);
                    INSERT INTO history_fts(rowid, input_text, output_text)
                    VALUES (NEW.rowid, NEW.input_text, NEW.output_text);
                END
                """)
        }

        try migrator.migrate(dbQueue)
    }

    // MARK: - Backup exclusion

    private static func excludeFromBackup() throws {
        let dbPath = databasePath()
        let urls = [
            dbPath,
            dbPath.appendingPathExtension("wal"),
            dbPath.appendingPathExtension("shm")
        ]
        for url in urls {
            var resourceValues = URLResourceValues()
            resourceValues.isExcludedFromBackup = true
            var mutable = url
            try? mutable.setResourceValues(resourceValues)
        }
    }
}
