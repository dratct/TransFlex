import XCTest
@testable import TransFlex

final class AnthropicModelSupportTests: XCTestCase {
    func testFamilyStripsDateBedrockAndVertexForms() {
        XCTAssertEqual(AnthropicModelSupport.family(of: "claude-haiku-4-5"), "claude-haiku-4-5")
        XCTAssertEqual(AnthropicModelSupport.family(of: "claude-haiku-4-5-20251001"), "claude-haiku-4-5")
        XCTAssertEqual(AnthropicModelSupport.family(of: "anthropic.claude-haiku-4-5-20251001-v1:0"), "claude-haiku-4-5")
        XCTAssertEqual(AnthropicModelSupport.family(of: "anthropic.claude-opus-5-5"), "claude-opus-5-5")
        XCTAssertEqual(AnthropicModelSupport.family(of: "claude-opus-4-5@20251101"), "claude-opus-4-5")
        XCTAssertEqual(AnthropicModelSupport.family(of: "claude-sonnet-4-20250514"), "claude-sonnet-4")
    }

    func testSamplingOnlyForModelsThatAcceptIt() {
        XCTAssertTrue(AnthropicModelSupport.acceptsSampling("claude-haiku-4-5-20251001"))
        XCTAssertTrue(AnthropicModelSupport.acceptsSampling("claude-sonnet-4-6"))
        XCTAssertFalse(AnthropicModelSupport.acceptsSampling("claude-opus-5-5"))
        XCTAssertFalse(AnthropicModelSupport.acceptsSampling("claude-sonnet-5-5"))
        XCTAssertFalse(AnthropicModelSupport.acceptsSampling("claude-opus-4-7"))
        XCTAssertFalse(AnthropicModelSupport.acceptsSampling("claude-unknown-9"))
    }

    func testEffortLevelsPerFamily() {
        XCTAssertEqual(AnthropicModelSupport.effortLevels("claude-opus-5-5"), ["low", "medium", "high", "xhigh", "max"])
        XCTAssertEqual(AnthropicModelSupport.effortLevels("claude-sonnet-4-6"), ["low", "medium", "high", "max"])
        XCTAssertEqual(AnthropicModelSupport.effortLevels("claude-opus-4-5-20251101"), [])
        XCTAssertEqual(AnthropicModelSupport.effortLevels("claude-haiku-4-5"), [])
        XCTAssertEqual(AnthropicModelSupport.effortLevels("claude-unknown-9"), [])
    }

    func testResolvedEffortDefaultsAndClamps() {
        XCTAssertEqual(AnthropicModelSupport.resolvedEffort(nil, for: "claude-opus-5-5"), "low")
        XCTAssertEqual(AnthropicModelSupport.resolvedEffort("high", for: "claude-opus-5-5"), "high")
        XCTAssertEqual(AnthropicModelSupport.resolvedEffort("xhigh", for: "claude-sonnet-4-6"), "high")
        XCTAssertEqual(AnthropicModelSupport.resolvedEffort("medium", for: "claude-sonnet-4-6"), "medium")
        XCTAssertEqual(AnthropicModelSupport.resolvedEffort("bogus", for: "claude-opus-5-5"), "low")
        XCTAssertNil(AnthropicModelSupport.resolvedEffort("high", for: "claude-haiku-4-5"))
        XCTAssertNil(AnthropicModelSupport.resolvedEffort(nil, for: "claude-unknown-9"))
    }

    func testPresetSavedBeforeEffortStillDecodes() throws {
        let preset = Preset(name: "Old", providerID: "anthropic", modelID: "claude-opus-5-5", systemPrompt: "t")
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(preset)) as? [String: Any])
        json.removeValue(forKey: "effort")
        let decoded = try JSONDecoder().decode(Preset.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertNil(decoded.effort)
        XCTAssertEqual(decoded.name, "Old")
    }
}
