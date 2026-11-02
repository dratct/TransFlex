import XCTest
@testable import TransFlex

/// DESIGN.md › Components › ModelPicker: text models only, grouped by family,
/// newest first, and a custom-ID row.
final class ModelFamiliesTests: XCTestCase {
    private func models(_ ids: [String]) -> [Model] {
        ids.map { Model(id: $0, name: $0, supportsVision: false, source: .fetched) }
    }

    private func layout(_ ids: [String], query: String = "") -> [[String]] {
        ModelFamilies.groups(models(ids), matching: query).map { [$0.name] + $0.models.map(\.id) }
    }

    func testDropsModelsThatCannotTranslateText() {
        let ids = [
            "gpt-4o", "text-embedding-3-large", "tts-1-hd", "whisper-1", "omni-moderation-latest",
            "dall-e-3", "gpt-image-1", "gpt-4o-realtime-preview", "gpt-4o-mini-transcribe",
            "babbage-002", "davinci-002", "models/text-embedding-004", "models/imagen-3.0-generate-002",
        ]
        XCTAssertEqual(layout(ids), [["GPT-4", "gpt-4o"]])
    }

    func testGroupsByFamilyNewestFirst() {
        let ids = ["gpt-4o-mini", "gpt-5", "gpt-4.1", "gpt-5.2-mini", "gpt-6-luna", "gpt-4o", "gpt-5.2", "o3", "o4-mini"]
        XCTAssertEqual(layout(ids), [
            ["GPT-6", "gpt-6-luna"],
            ["GPT-5", "gpt-5.2", "gpt-5.2-mini", "gpt-5"],
            ["GPT-4", "gpt-4.1", "gpt-4o", "gpt-4o-mini"],
            ["o4", "o4-mini"],
            ["o3", "o3"],
        ])
    }

    func testDateStampsAreNotVersions() {
        XCTAssertEqual(ModelFamilies.version(of: "claude-opus-4-5-20251101"), [4, 5])
        XCTAssertEqual(ModelFamilies.version(of: "claude-3-5-sonnet-20241022"), [3, 5])
        XCTAssertEqual(ModelFamilies.version(of: "gpt-4o-2024-08-06"), [4])
        XCTAssertEqual(ModelFamilies.version(of: "models/gemini-2.5-flash-preview-05-20"), [2, 5])
        XCTAssertEqual(ModelFamilies.version(of: "llama3.1:8b"), [3, 1])
        XCTAssertEqual(
            layout(["gpt-4o-2024-05-13", "gpt-4o-2024-08-06"]),
            [["GPT-4", "gpt-4o-2024-08-06", "gpt-4o-2024-05-13"]]
        )
    }

    func testFamilyNamesForOtherProviders() {
        XCTAssertEqual(
            layout(["claude-3-5-haiku-20241022", "claude-sonnet-4-5-20250929", "claude-opus-4-1-20250805"]),
            [["Claude 4", "claude-sonnet-4-5-20250929", "claude-opus-4-1-20250805"], ["Claude 3", "claude-3-5-haiku-20241022"]]
        )
        XCTAssertEqual(ModelFamilies.family(of: "models/gemini-2.5-pro").name, "Gemini 2")
        XCTAssertEqual(ModelFamilies.family(of: "qwen2.5:7b").name, "Qwen 2")
        XCTAssertEqual(ModelFamilies.family(of: "mistral").name, "Mistral")
    }

    func testSearchMatchesEveryWordInIDOrName() {
        let list = [
            Model(id: "gpt-5.2-mini", name: "GPT-5.2 mini", supportsVision: false),
            Model(id: "gpt-5.2", name: "GPT-5.2", supportsVision: false),
            Model(id: "claude-sonnet-4-5", name: "Claude Sonnet 4.5", supportsVision: false),
        ]
        XCTAssertEqual(ModelFamilies.groups(list, matching: "GPT mini").flatMap(\.models).map(\.id), ["gpt-5.2-mini"])
        XCTAssertEqual(ModelFamilies.groups(list, matching: "sonnet 4.5").flatMap(\.models).map(\.id), ["claude-sonnet-4-5"])
        XCTAssertTrue(ModelFamilies.groups(list, matching: "llama").isEmpty)
    }

    func testCustomIDRowOnlyForAnIDTheListLacks() {
        let list = models(["gpt-5.2"])
        XCTAssertEqual(ModelFamilies.customID(for: " llama-4 ", in: list), "llama-4")
        XCTAssertEqual(ModelFamilies.customID(for: "gpt", in: list), "gpt")
        XCTAssertNil(ModelFamilies.customID(for: "gpt-5.2", in: list))
        XCTAssertNil(ModelFamilies.customID(for: "", in: list))
        XCTAssertNil(ModelFamilies.customID(for: "two words", in: list))
    }
}
