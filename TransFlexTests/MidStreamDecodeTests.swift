import XCTest
@testable import TransFlex

/// A single dirty packet (bad JSON in the middle of a stream) must not kill
/// an otherwise-successful generation. All three streaming adapters must
/// emit `LLMEvent.error(.decode)` and keep going.
final class MidStreamDecodeTests: XCTestCase {
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

    func testOpenAIContinuesAfterMalformedChunk() async throws {
        // First valid → malformed JSON → valid → done.
        let body = """
        data: {"choices":[{"delta":{"content":"Hi"}}]}

        data: {not json

        data: {"choices":[{"delta":{"content":" you"},"finish_reason":"stop"}]}

        data: [DONE]


        """
        MockURLProtocol.handler = { req in
            let resp = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: nil)!
            return (resp, Data(body.utf8))
        }
        let provider = OpenAIProvider(session: session)
        let config = ProviderConfig(model: "gpt-4o-mini", apiKey: "sk-test")
        let stream = provider.stream(messages: [.init(role: .user, content: "hi")], image: nil, config: config)

        var deltas: [String] = []
        var sawDecodeError = false
        var stop: StopReason?
        for try await event in stream {
            switch event {
            case .textDelta(let s): deltas.append(s)
            case .error(.decode): sawDecodeError = true
            case .error: XCTFail("unexpected error variant")
            case .stop(let r): stop = r
            case .usage: break
            }
        }
        XCTAssertEqual(deltas.joined(), "Hi you")
        XCTAssertTrue(sawDecodeError)
        XCTAssertEqual(stop, .complete)
    }

    func testGeminiContinuesAfterMalformedChunk() async throws {
        let body = """
        data: {"candidates":[{"content":{"parts":[{"text":"A"}]}}]}

        data: {bad

        data: {"candidates":[{"content":{"parts":[{"text":"B"}],"role":"model"},"finishReason":"STOP"}]}


        """
        MockURLProtocol.handler = { req in
            let resp = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: nil)!
            return (resp, Data(body.utf8))
        }
        let provider = GeminiProvider(session: session)
        let config = ProviderConfig(model: "gemini-2.0-flash", apiKey: "AIzaTest")
        let stream = provider.stream(messages: [.init(role: .user, content: "hi")], image: nil, config: config)

        var deltas: [String] = []
        var sawDecodeError = false
        for try await event in stream {
            if case .textDelta(let s) = event { deltas.append(s) }
            if case .error(.decode) = event { sawDecodeError = true }
        }
        XCTAssertEqual(deltas.joined(), "AB")
        XCTAssertTrue(sawDecodeError)
    }

    func testAnthropicContinuesAfterMalformedChunk() async throws {
        let body = """
        event: content_block_delta
        data: {"type":"content_block_delta","delta":{"text":"X"}}

        event: content_block_delta
        data: {junk

        event: content_block_delta
        data: {"type":"content_block_delta","delta":{"text":"Y"}}

        event: message_delta
        data: {"type":"message_delta","delta":{"stop_reason":"end_turn"}}


        """
        MockURLProtocol.handler = { req in
            let resp = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: nil)!
            return (resp, Data(body.utf8))
        }
        let provider = AnthropicProvider(session: session)
        let config = ProviderConfig(model: "claude-3-5-sonnet-latest", apiKey: "sk-ant-test")
        let stream = provider.stream(messages: [.init(role: .user, content: "hi")], image: nil, config: config)

        var deltas: [String] = []
        var sawDecodeError = false
        var stop: StopReason?
        for try await event in stream {
            switch event {
            case .textDelta(let s): deltas.append(s)
            case .error(.decode): sawDecodeError = true
            case .stop(let r): stop = r
            default: break
            }
        }
        XCTAssertEqual(deltas.joined(), "XY")
        XCTAssertTrue(sawDecodeError)
        XCTAssertEqual(stop, .complete)
    }

    func testAnthropicToolUseMappedToProviderError() async throws {
        let body = """
        event: content_block_delta
        data: {"type":"content_block_delta","delta":{"text":"hi"}}

        event: message_delta
        data: {"type":"message_delta","delta":{"stop_reason":"tool_use"}}


        """
        MockURLProtocol.handler = { req in
            let resp = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: nil)!
            return (resp, Data(body.utf8))
        }
        let provider = AnthropicProvider(session: session)
        let config = ProviderConfig(model: "claude-3-5-sonnet-latest", apiKey: "sk-ant-test")
        let stream = provider.stream(messages: [.init(role: .user, content: "hi")], image: nil, config: config)

        var stop: StopReason?
        for try await event in stream {
            if case .stop(let r) = event { stop = r }
        }
        guard case .providerError(let detail) = stop else {
            return XCTFail("expected providerError, got \(String(describing: stop))")
        }
        XCTAssertEqual(detail, "tool_use unsupported")
    }
}
