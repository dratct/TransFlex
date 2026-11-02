import Foundation
import GRDB
import OSLog

final class HistoryDatabase {
    private static let logger = Logger(subsystem: "io.aiaz.transflex", category: "HistoryDB")

    let dbQueue: DatabaseQueue

    convenience init() throws {
        let dbDir = Self.databaseDirectory()
        try FileManager.default.createDirectory(at: dbDir, withIntermediateDirectories: true)
        try self.init(path: Self.databasePath())
        try Self.excludeFromBackup()
    }

    /// Opens and migrates the file at `path`; tests use it to upgrade a file
    /// an older build wrote.
    init(path: URL) throws {
        self.dbQueue = try DatabaseQueue(path: path.path, configuration: Self.fileConfiguration())
        try Self.migrator.migrate(dbQueue)
    }

    static func fileConfiguration() -> Configuration {
        var config = Configuration()
        config.prepareDatabase { db in
            try db.execute(sql: "PRAGMA journal_mode=WAL")
        }
        return config
    }

    init(inMemory: Bool) throws {
        var config = Configuration()
        config.prepareDatabase { db in
            try db.execute(sql: "PRAGMA journal_mode=MEMORY")
        }

        self.dbQueue = try DatabaseQueue(configuration: config)
        try Self.migrator.migrate(dbQueue)
    }

    // MARK: - Paths

    private static func databaseDirectory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return AppIdentity.current.applicationSupportDirectory(baseURL: base)
    }

    static func databasePath() -> URL {
        databaseDirectory().appendingPathComponent("history.sqlite")
    }

    // MARK: - Migration

    static var migrator: DatabaseMigrator {
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

        // docs/decisions/2026-11-01-history-stores-cost-4000.md
        migrator.registerMigration("v2") { db in
            try db.execute(sql: """
                ALTER TABLE history_entry ADD COLUMN input_tokens INTEGER;
                ALTER TABLE history_entry ADD COLUMN output_tokens INTEGER;
                ALTER TABLE history_entry ADD COLUMN cost_usd REAL;
                """)
        }

        return migrator
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
