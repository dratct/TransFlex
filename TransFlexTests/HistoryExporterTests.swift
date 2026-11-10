import XCTest
@testable import TransFlex

@MainActor
final class HistoryExporterTests: XCTestCase {
    private let sample = [
        HistoryEntry(
            presetID: UUID(),
            providerID: "openai",
            modelID: "gpt-test",
            inputText: "Hello",
            outputText: "Xin chào",
            hadImage: false,
            durationMs: 120,
            tokenCount: 42,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000)
        ),
    ]

    func testWriteToUnwritablePathThrows() {
        let missingFolder = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("transflex-history.json")

        XCTAssertThrowsError(try HistoryExporter.write(sample, as: .json, to: missingFolder))
    }

    func testWriteSavesTheEncodedEntries() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).md")
        defer { try? FileManager.default.removeItem(at: url) }

        try HistoryExporter.write(sample, as: .markdown, to: url)

        XCTAssertTrue(try String(contentsOf: url, encoding: .utf8).contains("Xin chào"))
    }
}
