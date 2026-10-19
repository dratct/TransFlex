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

    private static let emptyStream = """
    event: message_stop
    data: {"type":"message_stop"}


    """

    /// Runs one stream and returns the JSON body the provider sent. URLProtocol
    /// hands the body over as `httpBodyStream`, not `httpBody`.
    private func capturedBody(config: ProviderConfig) async throws -> [String: Any] {
        var captured: Data?
        MockURLProtocol.handler = { req in
            captured = Self.readBody(req)
            let resp = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: nil)!
            return (resp, Data(Self.emptyStream.utf8))
        }
        let provider = AnthropicProvider(session: session)
        for try await _ in provider.stream(messages: [.init(role: .user, content: "hi")], image: nil, config: config) {}
        let data = try XCTUnwrap(captured)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    fileprivate static func readBody(_ req: URLRequest) -> Data? {
        if let body = req.httpBody { return body }
        guard let stream = req.httpBodyStream else { return nil }
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            let n = stream.read(&buffer, maxLength: buffer.count)
            if n <= 0 { break }
            data.append(buffer, count: n)
        }
        return data
    }

    func testCurrentModelGetsEffortAndNoSampling() async throws {
        let body = try await capturedBody(config: ProviderConfig(
            model: "claude-opus-5-5", apiKey: "k", temperature: 0.3, topP: 0.9
        ))
        XCTAssertNil(body["temperature"])
        XCTAssertNil(body["top_p"])
        XCTAssertEqual((body["output_config"] as? [String: Any])?["effort"] as? String, "low")
        XCTAssertEqual(body["max_tokens"] as? Int, 16000)
    }

    func testHaikuGetsTemperatureAndNoEffort() async throws {
        let body = try await capturedBody(config: ProviderConfig(
            model: "claude-haiku-4-5-20251001", apiKey: "k", temperature: 0.3, effort: "high"
        ))
        XCTAssertEqual(body["temperature"] as? Double, 0.3)
        XCTAssertNil(body["top_p"])
        XCTAssertNil(body["output_config"])
    }

    func testExplicitTopPReplacesTemperatureOnClaude4() async throws {
        let body = try await capturedBody(config: ProviderConfig(
            model: "claude-sonnet-4-6", apiKey: "k", temperature: 0.3, topP: 0.9, effort: "xhigh"
        ))
        XCTAssertNil(body["temperature"])
        XCTAssertEqual(body["top_p"] as? Double, 0.9)
        XCTAssertEqual((body["output_config"] as? [String: Any])?["effort"] as? String, "high")
    }

    func testUnknownModelGetsNeitherSamplingNorEffort() async throws {
        let body = try await capturedBody(config: ProviderConfig(model: "claude-unknown-9", apiKey: "k"))
        XCTAssertNil(body["temperature"])
        XCTAssertNil(body["output_config"])
    }

    func testExtraBodyOutputConfigKeepsEffort() async throws {
        let body = try await capturedBody(config: ProviderConfig(
            model: "claude-opus-5-5", apiKey: "k", effort: "medium",
            extraBodyJSON: #"{"output_config":{"format":{"type":"text"}}}"#
        ))
        let output = try XCTUnwrap(body["output_config"] as? [String: Any])
        XCTAssertEqual(output["effort"] as? String, "medium")
        XCTAssertNotNil(output["format"])
    }

    func testPresetEffortReachesRequestThroughTranslationService() async throws {
        var captured: Data?
        MockURLProtocol.handler = { req in
            captured = Self.readBody(req)
            let resp = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: nil)!
            return (resp, Data(Self.emptyStream.utf8))
        }
        let provider = AnthropicProvider(session: session)
        let service = TranslationService(provider: { _ in provider }, apiKey: { _ in "k" })
        let preset = Preset(
            name: "P", providerID: "anthropic", modelID: "claude-opus-5-5",
            systemPrompt: "translate", effort: "high"
        )
        for try await _ in service.translate(input: .text("hi"), preset: preset) {}
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(captured)) as? [String: Any])
        XCTAssertEqual((body["output_config"] as? [String: Any])?["effort"] as? String, "high")
    }

    func testThinkingDeltasAreNotTranslationText() async throws {
        let body = """
        event: content_block_delta
        data: {"type":"content_block_delta","index":0,"delta":{"type":"thinking_delta","thinking":"hmm"}}

        event: content_block_delta
        data: {"type":"content_block_delta","index":0,"delta":{"type":"signature_delta","signature":"abc"}}

        event: content_block_delta
        data: {"type":"content_block_delta","index":1,"delta":{"type":"text_delta","text":"Xin chào"}}

        event: message_stop
        data: {"type":"message_stop"}


        """
        MockURLProtocol.handler = { req in
            let resp = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: nil)!
            return (resp, Data(body.utf8))
        }
        let provider = AnthropicProvider(session: session)
        let config = ProviderConfig(model: "claude-opus-5-5", apiKey: "k")
        var text = ""
        for try await event in provider.stream(messages: [.init(role: .user, content: "hi")], image: nil, config: config) {
            if case .textDelta(let s) = event { text += s }
        }
        XCTAssertEqual(text, "Xin chào")
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
