import XCTest
@testable import TransFlex

final class PromptBuilderTests: XCTestCase {
    private func makePreset(systemPrompt: String, vision: Bool = false) -> Preset {
        Preset(
            name: "p", providerID: "openai", modelID: "gpt-4o-mini",
            systemPrompt: systemPrompt, supportsVision: vision
        )
    }

    func testTextInputProducesSystemAndUser() {
        let preset = makePreset(systemPrompt: "Translate the input.")
        let messages = PromptBuilder.build(preset: preset, input: .text("Hello"))
        XCTAssertEqual(messages.count, 2)
        XCTAssertEqual(messages[0].role, .system)
        XCTAssertEqual(messages[0].content, "Translate the input.")
        XCTAssertEqual(messages[1].role, .user)
        XCTAssertEqual(messages[1].content, "Hello")
    }

    func testEmptySystemPromptOmitsSystemMessage() {
        let preset = makePreset(systemPrompt: "   \n  ")
        let messages = PromptBuilder.build(preset: preset, input: .text("hi"))
        XCTAssertEqual(messages.count, 1)
        XCTAssertEqual(messages[0].role, .user)
    }

    func testImageInputUsesAccompanyingText() {
        let preset = makePreset(systemPrompt: "OCR this.", vision: true)
        let messages = PromptBuilder.build(
            preset: preset,
            input: .image(Data([0x89, 0x50]), accompanyingText: "translate to EN")
        )
        XCTAssertEqual(messages.last?.role, .user)
        XCTAssertEqual(messages.last?.content, "translate to EN")
    }

    func testImageInputWithNilTextProducesDefaultInstruction() {
        let preset = makePreset(systemPrompt: "OCR.", vision: true)
        let messages = PromptBuilder.build(
            preset: preset,
            input: .image(Data(), accompanyingText: nil)
        )
        XCTAssertEqual(messages.last?.content, "Translate the content in this image.")
    }

    func testImageInputWithBlankTextProducesDefaultInstruction() {
        let preset = makePreset(systemPrompt: "OCR.", vision: true)
        let messages = PromptBuilder.build(
            preset: preset,
            input: .image(Data(), accompanyingText: "   \n  ")
        )
        XCTAssertEqual(messages.last?.content, "Translate the content in this image.")
    }

    func testDeterministicSnapshotForBuiltin() {
        let preset = DefaultPresets.builtins[0]
        let m1 = PromptBuilder.build(preset: preset, input: .text("xin chào"))
        let m2 = PromptBuilder.build(preset: preset, input: .text("xin chào"))
        XCTAssertEqual(m1, m2)
    }
}
