import XCTest
@testable import TransFlex

final class OpenAICompatibleProviderTests: XCTestCase {
    private var session: URLSession!

    override func setUp() {
        super.setUp()
        session = MockSession.make()
    }

    override func tearDown() {
        MockURLProtocol.handler = nil
        session = nil
        super.tearDown()
    }

    func testAvailableModelsSendsBearerFromInjectedAPIKey() async throws {
        var capturedAuth: String?
        MockURLProtocol.handler = { req in
            capturedAuth = req.value(forHTTPHeaderField: "Authorization")
            let resp = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: nil)!
            let body = Data("{\"data\":[{\"id\":\"local-model\"}]}".utf8)
            return (resp, body)
        }
        let instance = OpenAICompatInstance(
            instanceId: "gw",
            displayName: "GW",
            baseURL: URL(string: "https://gw.example.com")!
        )
        let provider = OpenAICompatibleProvider(instance: instance, session: session)
        let models = try await provider.availableModels(apiKey: "sk-injected")
        XCTAssertEqual(models.first?.id, "local-model")
        XCTAssertEqual(models.first?.source, .fetched)
        XCTAssertEqual(capturedAuth, "Bearer sk-injected")
    }

    func testAvailableModelsOmitsAuthHeaderWhenAPIKeyEmpty() async throws {
        var sawAuth: String?
        MockURLProtocol.handler = { req in
            sawAuth = req.value(forHTTPHeaderField: "Authorization")
            let resp = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: nil)!
            return (resp, Data("{\"data\":[]}".utf8))
        }
        let instance = OpenAICompatInstance(
            instanceId: "gw",
            displayName: "GW",
            baseURL: URL(string: "https://gw.example.com")!
        )
        let provider = OpenAICompatibleProvider(instance: instance, session: session)
        _ = try await provider.availableModels(apiKey: "")
        XCTAssertNil(sawAuth)
    }

    func testStreamRejectsExtraHeaderOverridingAuthorization() async throws {
        var capturedAuth: String?
        MockURLProtocol.handler = { req in
            capturedAuth = req.value(forHTTPHeaderField: "Authorization")
            let resp = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: nil)!
            let body = Data("data: {\"choices\":[{\"delta\":{\"content\":\"hi\"}}]}\n\ndata: [DONE]\n\n".utf8)
            return (resp, body)
        }
        let instance = OpenAICompatInstance(
            instanceId: "gw",
            displayName: "GW",
            baseURL: URL(string: "https://gw.example.com")!,
            extraHeaders: ["Authorization": "Bearer attacker"]
        )
        let provider = OpenAICompatibleProvider(instance: instance, session: session)
        let config = ProviderConfig(model: "x", apiKey: "real-key")
        for try await _ in provider.stream(messages: [.init(role: .user, content: "hi")], image: nil, config: config) {}
        XCTAssertEqual(capturedAuth, "Bearer real-key")
    }
}
