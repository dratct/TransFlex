import XCTest
@testable import TransFlex

@MainActor
final class SettingsComponentsTests: XCTestCase {
    func test_endpointNeedsANameAndAValidURL() {
        XCTAssertTrue(OpenAICompatEditor.isValid(name: "Local Ollama", baseURL: "http://localhost:11434"))
        XCTAssertFalse(OpenAICompatEditor.isValid(name: "  ", baseURL: "http://localhost:11434"))
        XCTAssertFalse(OpenAICompatEditor.isValid(name: "Ollama", baseURL: ""))
        XCTAssertFalse(OpenAICompatEditor.isValid(name: "Ollama", baseURL: "localhost"), "a URL needs a scheme and host")
        XCTAssertFalse(OpenAICompatEditor.isValid(name: "Ollama", baseURL: "ftp://example.org"))
    }

    func test_providerInitials() {
        XCTAssertEqual(ProviderLogo.initials(of: "Local Ollama"), "LO")
        XCTAssertEqual(ProviderLogo.initials(of: "openrouter"), "OP")
        XCTAssertEqual(ProviderLogo.initials(of: "LM Studio (beta)"), "LS")
    }

    func test_keepLastTranslationOptionsReadPositively() {
        XCTAssertEqual(PopupResetPolicy.always.displayName, "Don’t keep")
        XCTAssertEqual(PopupResetPolicy.afterMinutes(1).displayName, "1 minute")
        XCTAssertEqual(PopupResetPolicy.afterMinutes(2).displayName, "2 minutes")
        XCTAssertEqual(PopupResetPolicy.never.displayName, "Always")
    }
}
