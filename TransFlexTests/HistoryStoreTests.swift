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
