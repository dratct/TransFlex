import XCTest
@testable import TransFlex

final class AnthropicProviderTests: XCTestCase {
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

    func testTypedEventsAccumulateText() async throws {
        let body = """
        event: message_start
        data: {"type":"message_start","message":{"usage":{"input_tokens":7}}}

        event: content_block_delta
        data: {"type":"content_block_delta","delta":{"type":"text_delta","text":"Xin "}}

        event: content_block_delta
        data: {"type":"content_block_delta","delta":{"type":"text_delta","text":"chào"}}

        event: message_delta
        data: {"type":"message_delta","delta":{"stop_reason":"end_turn"},"usage":{"output_tokens":3}}

        event: message_stop
        data: {"type":"message_stop"}


        """
        MockURLProtocol.handler = { req in
            let resp = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: nil)!
            return (resp, Data(body.utf8))
        }

        let provider = AnthropicProvider(session: session)
        let config = ProviderConfig(model: "claude-3-5-sonnet-latest", apiKey: "sk-ant-test")
        let stream = provider.stream(messages: [.init(role: .user, content: "hi")], image: nil, config: config)

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
        XCTAssertEqual(deltas.joined(), "Xin chào")
        XCTAssertEqual(usage?.0, 7)
        XCTAssertEqual(usage?.1, 3)
        XCTAssertEqual(stop, .complete)
    }

    func testRequestSplitsSystemAndConversation() {
        let messages: [ChatMessage] = [
            .init(role: .system, content: "translator"),
            .init(role: .user, content: "hello"),
        ]
        let (system, conversation) = AnthropicRequestBuilder.split(messages: messages)
        XCTAssertEqual(system, "translator")
        XCTAssertEqual(conversation.count, 1)
        XCTAssertEqual(conversation.first?.role, .user)
    }

    func testImageAttachedToLastUserMessage() {
        let pixel = Data([0x01, 0x02, 0x03])
        let body = AnthropicRequestBuilder.body(
            model: "claude-3-5-sonnet-latest",
            system: nil,
            conversation: [.init(role: .user, content: "what is this")],
            image: pixel,
            temperature: 0.3,
            maxTokens: 1024
        )
        let messages = body["messages"] as? [[String: Any]]
        let content = messages?.first?["content"] as? [[String: Any]]
        XCTAssertEqual(content?[0]["type"] as? String, "image")
        XCTAssertEqual(content?[1]["type"] as? String, "text")
    }

    func testAvailableModelsUsesDisplayNameAndApiKeyHeader() async throws {
        var capturedKey: String?
        var capturedVersion: String?
        var capturedPath: String?
        MockURLProtocol.handler = { req in
            capturedKey = req.value(forHTTPHeaderField: "x-api-key")
            capturedVersion = req.value(forHTTPHeaderField: "anthropic-version")
            capturedPath = req.url?.path
            let resp = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: nil)!
            let body = Data(#"{"data":[{"id":"claude-4","display_name":"Claude 4"}]}"#.utf8)
            return (resp, body)
        }
        let provider = AnthropicProvider(session: session)
        let models = try await provider.availableModels(apiKey: "sk-ant")

        XCTAssertEqual(capturedKey, "sk-ant")
        XCTAssertEqual(capturedVersion, "2023-06-01")
        XCTAssertEqual(capturedPath, "/v1/models")
        XCTAssertEqual(models.first?.id, "claude-4")
        XCTAssertEqual(models.first?.name, "Claude 4")
        XCTAssertEqual(models.first?.source, .fetched)
        XCTAssertEqual(models.first?.supportsVision, false)
    }

    func testAvailableModelsFallsBackToIdWhenDisplayNameMissing() async throws {
        MockURLProtocol.handler = { req in
            let resp = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: nil)!
            return (resp, Data(#"{"data":[{"id":"claude-x"}]}"#.utf8))
        }
        let provider = AnthropicProvider(session: session)
        let models = try await provider.availableModels(apiKey: "sk-ant")
        XCTAssertEqual(models.first?.name, "claude-x")
    }

    func testAvailableModelsEmptyKeyReturnsFallback() async throws {
        let provider = AnthropicProvider(session: session)
        let models = try await provider.availableModels(apiKey: "")
        XCTAssertEqual(models, provider.localModels)
    }

    func testAvailableModelsErrorReturnsFallback() async throws {
        MockURLProtocol.handler = { req in
            let resp = HTTPURLResponse(url: req.url!, statusCode: 401, httpVersion: "HTTP/1.1", headerFields: nil)!
            return (resp, Data())
        }
        let provider = AnthropicProvider(session: session)
        let models = try await provider.availableModels(apiKey: "bad")
        XCTAssertEqual(models, provider.localModels)
    }
}
