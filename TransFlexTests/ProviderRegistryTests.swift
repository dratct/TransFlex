import XCTest
@testable import TransFlex

final class ProviderRegistryTests: XCTestCase {
    func testCloudProviderResolvable() throws {
        let registry = ProviderRegistry()
        XCTAssertEqual(try registry.provider(for: "openai").id, "openai")
        XCTAssertEqual(try registry.provider(for: "anthropic").id, "anthropic")
        XCTAssertEqual(try registry.provider(for: "gemini").id, "gemini")
    }

    func testUnknownProviderThrows() {
        let registry = ProviderRegistry()
        XCTAssertThrowsError(try registry.provider(for: "made-up")) { err in
            XCTAssertEqual(err as? ProviderError, .unknownProvider(id: "made-up"))
        }
    }

    func testCompatInstanceLookup() throws {
        let registry = ProviderRegistry()
        let instance = OpenAICompatInstance(
            instanceId: "ollama-local",
            displayName: "Ollama",
            baseURL: URL(string: "http://localhost:11434/v1")!
        )
        try registry.registerCompatInstance(instance)

        let provider = try registry.provider(for: "openai-compatible:ollama-local")
        XCTAssertEqual(provider.id, "openai-compatible:ollama-local")
        XCTAssertNotNil(registry.compatInstance("ollama-local"))

        registry.unregisterCompatInstance("ollama-local")
        XCTAssertThrowsError(try registry.provider(for: "openai-compatible:ollama-local"))
    }

    func testRegisterRejectsNonHTTPScheme() {
        let registry = ProviderRegistry()
        let instance = OpenAICompatInstance(
            instanceId: "bad",
            displayName: "Bad",
            baseURL: URL(string: "file:///etc/hosts")!
        )
        XCTAssertThrowsError(try registry.registerCompatInstance(instance)) { err in
            guard case .invalidConfiguration = (err as? ProviderError) else {
                return XCTFail("expected .invalidConfiguration, got \(err)")
            }
        }
    }
}
