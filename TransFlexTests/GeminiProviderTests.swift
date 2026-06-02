import XCTest
@testable import TransFlex

final class GeminiProviderTests: XCTestCase {
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

    func testStreamYieldsTextAndUsage() async throws {
        let body = """
        data: {"candidates":[{"content":{"parts":[{"text":"Bonjour"}]}}]}

        data: {"candidates":[{"content":{"parts":[{"text":" monde"}],"role":"model"},"finishReason":"STOP"}],"usageMetadata":{"promptTokenCount":5,"candidatesTokenCount":2}}


        """
        MockURLProtocol.handler = { req in
            let resp = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: nil)!
            return (resp, Data(body.utf8))
        }

        let provider = GeminiProvider(session: session)
        let config = ProviderConfig(model: "gemini-2.0-flash", apiKey: "AIzaTest")
        let stream = provider.stream(messages: [.init(role: .user, content: "hello")], image: nil, config: config)

        var deltas: [String] = []
        var usage: (Int, Int)?
        var stop: StopReason?
        for try await event in stream {
            switch event {
            case .textDelta(let s): deltas.append(s)
            case .usage(let i, let o): usage = (i, o)
            case .stop(let r): stop = r
            case .error: XCTFail("unexpected error")
            }
        }
        XCTAssertEqual(deltas.joined(), "Bonjour monde")
        XCTAssertEqual(usage?.0, 5)
        XCTAssertEqual(usage?.1, 2)
        XCTAssertEqual(stop, .complete)
    }

    func testRoleMappingAssistantToModel() {
        let body = GeminiRequestBuilder.body(
            messages: [
                .init(role: .user, content: "hi"),
                .init(role: .assistant, content: "hello"),
                .init(role: .user, content: "again"),
            ],
            image: nil,
            temperature: 0.3,
            maxTokens: nil
        )
        let contents = body["contents"] as? [[String: Any]]
        XCTAssertEqual(contents?[1]["role"] as? String, "model")
    }

    func testSystemInstructionSeparated() {
        let body = GeminiRequestBuilder.body(
            messages: [
                .init(role: .system, content: "translate"),
                .init(role: .user, content: "hi"),
            ],
            image: nil,
            temperature: 0.3,
            maxTokens: 256
        )
        XCTAssertNotNil(body["systemInstruction"])
        let contents = body["contents"] as? [[String: Any]]
        XCTAssertEqual(contents?.count, 1)
    }

    func testAvailableModelsFiltersGenerateContentAndStripsPrefix() async throws {
        var capturedKey: String?
        var capturedPath: String?
        MockURLProtocol.handler = { req in
            capturedKey = req.value(forHTTPHeaderField: "x-goog-api-key")
            capturedPath = req.url?.path
            let resp = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: nil)!
            let body = Data(#"""
            {"models":[
              {"name":"models/gemini-3-pro","displayName":"Gemini 3 Pro","supportedGenerationMethods":["generateContent"]},
              {"name":"models/embedding-001","displayName":"Embedding","supportedGenerationMethods":["embedContent"]}
            ]}
            """#.utf8)
            return (resp, body)
        }
        let provider = GeminiProvider(session: session)
        let models = try await provider.availableModels(apiKey: "AIza-live")

        XCTAssertEqual(capturedKey, "AIza-live")
        XCTAssertEqual(capturedPath, "/v1beta/models")
        XCTAssertEqual(models.map(\.id), ["gemini-3-pro"])
        XCTAssertEqual(models.first?.name, "Gemini 3 Pro")
        XCTAssertEqual(models.first?.source, .fetched)
        XCTAssertEqual(models.first?.supportsVision, false)
    }

    func testAvailableModelsEmptyKeyReturnsFallback() async throws {
        let provider = GeminiProvider(session: session)
        let models = try await provider.availableModels(apiKey: "")
        XCTAssertEqual(models, provider.localModels)
    }

    func testAvailableModelsErrorReturnsFallback() async throws {
        MockURLProtocol.handler = { req in
            let resp = HTTPURLResponse(url: req.url!, statusCode: 403, httpVersion: "HTTP/1.1", headerFields: nil)!
            return (resp, Data())
        }
        let provider = GeminiProvider(session: session)
        let models = try await provider.availableModels(apiKey: "bad")
        XCTAssertEqual(models, provider.localModels)
    }
}
