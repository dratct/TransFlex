import GRDB
import XCTest
@testable import TransFlex

@MainActor
final class HistoryStoreTests: XCTestCase {
    private var store: HistoryStore!

    override func setUp() async throws {
        store = try HistoryStore(inMemory: true)
    }

    private func entry(_ input: String, output: String, at seconds: TimeInterval) -> HistoryEntry {
        HistoryEntry(
            presetID: UUID(),
            providerID: "openai",
            modelID: "gpt-test",
            inputText: input,
            outputText: output,
            hadImage: true,
            durationMs: 120,
            tokenCount: 42,
            createdAt: Date(timeIntervalSince1970: seconds)
        )
    }

    func testInsertedEntryReadsBackUnchanged() throws {
        let saved = entry("Hello", output: "Xin chào", at: 1_700_000_000)
        try store.insert(saved)

        XCTAssertEqual(try store.fetchPage(offset: 0), [saved])
    }

    func testPagesAreNewestFirst() throws {
        let older = entry("one", output: "một", at: 1_700_000_000)
        let newer = entry("two", output: "hai", at: 1_700_000_100)
        try store.insert(older)
        try store.insert(newer)

        XCTAssertEqual(try store.fetchPage(offset: 0).map(\.id), [newer.id, older.id])
        XCTAssertEqual(try store.allEntries().map(\.id), [newer.id, older.id])
    }

    func testSearchMatchesInputAndOutput() throws {
        let meeting = entry("See you at the meeting", output: "Hẹn gặp ở cuộc họp", at: 1_700_000_000)
        try store.insert(meeting)
        try store.insert(entry("Ship it", output: "Phát hành", at: 1_700_000_100))

        XCTAssertEqual(try store.search(query: "meeting").map(\.id), [meeting.id])
        XCTAssertEqual(try store.search(query: "cuộc họp").map(\.id), [meeting.id])
    }

    func testPrefixSearchFindsLongerWord() throws {
        let saved = entry("A good translation", output: "Một bản dịch tốt", at: 1_700_000_000)
        try store.insert(saved)

        XCTAssertEqual(try store.search(query: "transl").map(\.id), [saved.id])
    }

    func testPunctuationActsAsSeparator() throws {
        let saved = entry("Visit example.com today", output: "Ghé example.com hôm nay", at: 1_700_000_000)
        try store.insert(saved)
        try store.insert(entry("An example of it", output: "Một ví dụ", at: 1_700_000_100))

        XCTAssertEqual(try store.search(query: "example.com").map(\.id), [saved.id])
    }

    func testSearchPagesPastFirstHundred() throws {
        for index in 0..<120 {
            try store.insert(entry("note \(index)", output: "ghi chú", at: 1_700_000_000 + TimeInterval(index)))
        }

        let first = try store.search(query: "note", offset: 0, limit: 100)
        let rest = try store.search(query: "note", offset: first.count, limit: 100)

        XCTAssertEqual(first.count, 100)
        XCTAssertEqual(rest.count, 20)
        XCTAssertEqual(rest.last?.inputText, "note 0")
    }

    func testInsertPostsChange() throws {
        let posted = expectation(forNotification: .historyDidChange, object: store)

        try store.insert(entry("Hello", output: "Xin chào", at: 1_700_000_000))

        wait(for: [posted], timeout: 1)
    }

    func testPruneDeletesOnlyEntriesOlderThanCutoff() throws {
        let old = entry("old", output: "cũ", at: 1_700_000_000)
        let recent = entry("new", output: "mới", at: 1_700_100_000)
        try store.insert(old)
        try store.insert(recent)

        let deleted = try store.prune(olderThan: Date(timeIntervalSince1970: 1_700_050_000))

        XCTAssertEqual(deleted, 1)
        XCTAssertEqual(try store.allEntries().map(\.id), [recent.id])
    }

    func testDeleteRemovesOneEntry() throws {
        let keep = entry("keep", output: "giữ", at: 1_700_000_000)
        let drop = entry("drop", output: "bỏ", at: 1_700_000_100)
        try store.insert(keep)
        try store.insert(drop)

        try store.delete(id: drop.id)

        XCTAssertEqual(try store.allEntries().map(\.id), [keep.id])
    }
}

final class HistoryExportFieldNameTests: XCTestCase {
    func testJSONExportKeepsCamelCaseFieldNames() throws {
        let entry = HistoryEntry(presetID: UUID(), providerID: "openai", modelID: "m", inputText: "a", outputText: "b")
        let json = try XCTUnwrap(String(data: JSONEncoder().encode(entry), encoding: .utf8))

        XCTAssertTrue(json.contains("\"presetID\""))
        XCTAssertTrue(json.contains("\"createdAt\""))
        XCTAssertFalse(json.contains("preset_id"))
    }
}

/// docs/decisions/2026-11-01-history-stores-cost-4000.md: v2 keeps each
/// translation's token split and cost; older rows keep NULL.
@MainActor
final class HistoryCostStorageTests: XCTestCase {
    private func priced(_ cost: Double?, at date: Date, model: String = "gpt-4o") -> HistoryEntry {
        HistoryEntry(
            presetID: UUID(), providerID: "openai", modelID: model,
            inputText: "in", outputText: "out", tokenCount: 30,
            inputTokens: 10, outputTokens: 20, costUSD: cost, createdAt: date
        )
    }

    func testV1DatabaseMigratesKeepingRows() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let path = dir.appendingPathComponent("history.sqlite")

        // A file as the v1 build left it: the real v1 migration (table, index,
        // full-text index and its triggers) in WAL mode, rows inserted through it.
        let v1 = try DatabaseQueue(path: path.path, configuration: HistoryDatabase.fileConfiguration())
        try HistoryDatabase.migrator.migrate(v1, upTo: "v1")
        try v1.write { db in
            try db.execute(sql: """
                INSERT INTO history_entry (id, preset_id, provider_id, model_id, input_text, output_text,
                                           had_image, duration_ms, token_count, created_at) VALUES
                  ('6F9619FF-8B86-D011-B42D-00C04FC964FF', '6F9619FF-8B86-D011-B42D-00C04FC964F0', 'openai', 'gpt-4o', 'alpha', 'b', 0, 800, 96, 1700000000),
                  ('6F9619FF-8B86-D011-B42D-00C04FC964FE', '6F9619FF-8B86-D011-B42D-00C04FC964F0', 'openai', 'gpt-4o', 'gamma', 'd', 0, 900, 50, 1700000100);
                """)
        }
        try v1.close()

        let store = try HistoryStore(path: path)
        let rows = try store.allEntries()

        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(Set(rows.map(\.inputText)), ["alpha", "gamma"])
        XCTAssertTrue(rows.allSatisfy { $0.costUSD == nil && $0.inputTokens == nil && $0.outputTokens == nil })
        XCTAssertEqual(try store.search(query: "alpha").map(\.inputText), ["alpha"])

        let fresh = priced(0.0004, at: Date(timeIntervalSince1970: 1_700_000_200))
        try store.insert(fresh)
        XCTAssertEqual(try store.fetchPage(offset: 0, limit: 1), [fresh])
        XCTAssertTrue(try store.search(query: "in").contains { $0.id == fresh.id })
    }

    func testInsertRoundTripsCostAndTokens() throws {
        let store = try HistoryStore(inMemory: true)
        let saved = priced(0.0004, at: Date(timeIntervalSince1970: 1_700_000_000))
        try store.insert(saved)

        XCTAssertEqual(try store.fetchPage(offset: 0), [saved])
    }

    func testTodayCostSumsPricedEntriesOnly() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Ho_Chi_Minh")!
        let now = calendar.date(from: DateComponents(year: 2026, month: 11, day: 2, hour: 15))!
        let store = try HistoryStore(inMemory: true)
        try store.insert(priced(0.0004, at: now.addingTimeInterval(-3_600)))
        try store.insert(priced(0.0011, at: calendar.startOfDay(for: now)))
        try store.insert(priced(nil, at: now.addingTimeInterval(-60), model: "unpriced-model"))
        try store.insert(priced(0.5, at: calendar.startOfDay(for: now).addingTimeInterval(-1)))
        try store.insert(priced(0.9, at: calendar.startOfDay(for: now).addingTimeInterval(86_400)))

        let today = try store.todayCost(now: now, calendar: calendar)

        XCTAssertEqual(try XCTUnwrap(today.total), 0.0015, accuracy: 1e-9)
        XCTAssertEqual(today.unpriced, 1)
    }

    func testTodayCostIsNilWhenNothingTodayIsPriced() throws {
        let store = try HistoryStore(inMemory: true)
        try store.insert(priced(nil, at: Date()))

        let today = try store.todayCost(now: Date(), calendar: .current)

        XCTAssertNil(today.total)
        XCTAssertEqual(today.unpriced, 1)
    }

    func testJSONExportWritesCostFieldsAndNullWhenUnpriced() throws {
        let data = try ExportFormat.json.encode([priced(nil, at: Date(timeIntervalSince1970: 0))])
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [[String: Any]]).first
        let row = try XCTUnwrap(object)

        XCTAssertEqual(row["inputTokens"] as? Int, 10)
        XCTAssertEqual(row["outputTokens"] as? Int, 20)
        XCTAssertTrue(row.keys.contains("costUSD"))
        XCTAssertTrue(row["costUSD"] is NSNull)
    }
}
