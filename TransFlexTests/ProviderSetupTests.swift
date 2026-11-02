import XCTest
@testable import TransFlex

/// The provider step shared by Welcome and the popup's first-run sheet.
@MainActor
final class ProviderSetupTests: XCTestCase {
    private struct Refused: Error {}

    func testChoicesAreTheThreeKeyedProvidersWithTheirKeyPages() {
        XCTAssertEqual(ProviderChoice.all.map(\.id), ["openai", "anthropic", "gemini"])
        XCTAssertEqual(ProviderChoice.all.map(\.name), ["OpenAI", "Anthropic", "Gemini"])
        XCTAssertEqual(ProviderChoice.all.map(\.detail), ["GPT models", "Claude models", "Google"])
        XCTAssertEqual(ProviderChoice.all.map(\.keyURL.absoluteString), [
            "https://platform.openai.com/api-keys",
            "https://platform.claude.com/settings/keys",
            "https://aistudio.google.com/apikey",
        ])
    }

    func testSavesTheKeyUnderTheSelectedProvider() {
        var saved: [(String, String)] = []
        var savedCount = 0
        let model = ProviderSetupModel(save: { saved.append(($0, $1)) }, onSaved: { savedCount += 1 })
        model.selected = "gemini"
        model.key = "AIza-test"

        XCTAssertTrue(model.save())
        XCTAssertEqual(saved.map(\.0), ["AIza-test"])
        XCTAssertEqual(saved.map(\.1), ["gemini"])
        XCTAssertEqual(savedCount, 1)
    }

    func testChangingProviderClearsTheTypedKey() {
        let model = ProviderSetupModel(save: { _, _ in }, onSaved: {})
        model.key = "sk-typed-for-openai"
        model.selected = "anthropic"
        XCTAssertEqual(model.key, "")
    }

    func testBlankKeyCannotBeSaved() {
        let model = ProviderSetupModel(save: { _, _ in XCTFail("must not save") }, onSaved: {})
        model.key = "   \n"
        XCTAssertFalse(model.canSave)
        XCTAssertFalse(model.save())
    }

    func testRetryAfterAFailureClearsTheError() {
        var refuse = true
        let model = ProviderSetupModel(save: { _, _ in if refuse { throw Refused() } }, onSaved: {})
        model.key = "sk-test"
        model.save()
        refuse = false

        XCTAssertTrue(model.save())
        XCTAssertNil(model.error)
    }

    func testEditingTheKeyClearsTheError() {
        let model = ProviderSetupModel(save: { _, _ in throw Refused() }, onSaved: {})
        model.key = "sk-test"
        model.save()
        model.key = "sk-test2"
        XCTAssertNil(model.error)
    }

    func testAFailedSaveShowsTheErrorAndStays() {
        var savedCount = 0
        let model = ProviderSetupModel(save: { _, _ in throw Refused() }, onSaved: { savedCount += 1 })
        model.key = "sk-test"

        XCTAssertFalse(model.save())
        XCTAssertNotNil(model.error)
        XCTAssertEqual(savedCount, 0)
    }
}
