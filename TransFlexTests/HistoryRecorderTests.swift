import XCTest
@testable import TransFlex

/// History keeps the same cost the popup showed when the translation finished.
@MainActor
final class HistoryRecorderTests: XCTestCase {
    private func entry(model: String, input: Int, output: Int, hadImage: Bool = false) -> HistoryEntry {
        HistoryRecorder.makeEntry(
            preset: Preset(name: "Natural", providerID: "openai", modelID: model, systemPrompt: "Translate"),
            inputText: "Hello", outputText: "Xin chào",
            inputTokens: input, outputTokens: output, hadImage: hadImage,
            durationMs: 800, now: Date(timeIntervalSince1970: 1_700_000_000)
        )
    }

    func testPricedModelStoresThePopupsEstimate() throws {
        let saved = entry(model: "gpt-4o", input: 40, output: 56, hadImage: true)

        let expected = try XCTUnwrap(CostTable.estimate(model: "gpt-4o", input: 40, output: 56, hadImage: true))
        XCTAssertEqual(try XCTUnwrap(saved.costUSD), expected, accuracy: 1e-12)
        XCTAssertEqual(saved.inputTokens, 40)
        XCTAssertEqual(saved.outputTokens, 56)
        XCTAssertEqual(saved.tokenCount, 96)
        XCTAssertEqual(saved.durationMs, 800)
    }

    func testModelWithNoPriceStoresNoCost() {
        XCTAssertNil(entry(model: "gpt-6-luna", input: 40, output: 56).costUSD)
    }

    func testNoUsageFromTheProviderStoresNoCost() {
        let saved = entry(model: "gpt-4o", input: 0, output: 0)

        XCTAssertNil(saved.costUSD)
        XCTAssertNil(saved.inputTokens)
        XCTAssertNil(saved.outputTokens)
    }
}
