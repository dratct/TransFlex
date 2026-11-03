import XCTest
@testable import TransFlex

final class OpenAIProviderTests: XCTestCase {
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

    func testStreamYieldsTextDeltaAndUsageAndStop() async throws {
        let body = """
        data: {"choices":[{"delta":{"content":"Hello"},"finish_reason":null}]}

        data: {"choices":[{"delta":{"content":" world"},"finish_reason":"stop"}]}

        data: {"choices":[],"usage":{"prompt_tokens":11,"completion_tokens":2}}

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
        var usage: (Int, Int)?
        var stop: StopReason?
        for try await event in stream {
            switch event {
            case .textDelta(let s): deltas.append(s)
            case .usage(let i, let o): usage = (i, o)
            case .stop(let r): stop = r
            case .error: XCTFail("unexpected error event")
            }
        }
        XCTAssertEqual(deltas.joined(), "Hello world")
        XCTAssertEqual(usage?.0, 11)
        XCTAssertEqual(usage?.1, 2)
        XCTAssertEqual(stop, .complete)
    }

    func testAuthErrorMappedFromHttp401() async {
        MockURLProtocol.handler = { req in
            let resp = HTTPURLResponse(url: req.url!, statusCode: 401, httpVersion: "HTTP/1.1", headerFields: nil)!
            return (resp, Data("unauthorized".utf8))
        }
        let provider = OpenAIProvider(session: session)
        let config = ProviderConfig(model: "gpt-4o-mini", apiKey: "wrong")
        let stream = provider.stream(messages: [.init(role: .user, content: "hi")], image: nil, config: config)

        do {
            for try await _ in stream {}
            XCTFail("expected throw")
        } catch let err as LLMError {
            XCTAssertEqual(err, .auth)
        } catch {
            XCTFail("wrong error type: \(error)")
        }
    }

    func testRequestIncludesImageContentBlock() throws {
        let pixel = Data([0x89, 0x50, 0x4E, 0x47])
        let body = OpenAIRequestBuilder.body(
            model: "gpt-4o",
            messages: [.init(role: .user, content: "describe")],
            image: pixel,
            temperature: 0.3,
            maxTokens: nil,
            stream: true
        )
        let messages = body["messages"] as? [[String: Any]]
        let content = messages?.first?["content"] as? [[String: Any]]
        XCTAssertEqual(content?.count, 2)
        XCTAssertEqual(content?[0]["type"] as? String, "text")
        XCTAssertEqual(content?[1]["type"] as? String, "image_url")
    }

    func testAvailableModelsFetchesAndTagsFetched() async throws {
        var capturedAuth: String?
        var capturedPath: String?
        MockURLProtocol.handler = { req in
            capturedAuth = req.value(forHTTPHeaderField: "Authorization")
            capturedPath = req.url?.path
            let resp = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: nil)!
            let body = Data(#"{"data":[{"id":"gpt-5"},{"id":"gpt-4o"}]}"#.utf8)
            return (resp, body)
        }
        let provider = OpenAIProvider(session: session)
        let models = try await provider.availableModels(apiKey: "sk-live")

        XCTAssertEqual(capturedAuth, "Bearer sk-live")
        XCTAssertEqual(capturedPath, "/v1/models")
        XCTAssertEqual(models.map(\.id), ["gpt-5", "gpt-4o"])
        XCTAssertTrue(models.allSatisfy { $0.source == .fetched })
        XCTAssertTrue(models.allSatisfy { $0.supportsVision == false })
    }

    func testAvailableModelsEmptyKeyReturnsFallback() async throws {
        MockURLProtocol.handler = { _ in
            XCTFail("must not hit the network with an empty key")
            let resp = HTTPURLResponse(url: URL(string: "https://x")!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (resp, Data())
        }
        let provider = OpenAIProvider(session: session)
        let models = try await provider.availableModels(apiKey: "")
        XCTAssertEqual(models, provider.localModels)
        XCTAssertTrue(models.allSatisfy { $0.source == .fallback })
    }

    func testAvailableModelsFetchErrorReturnsFallback() async throws {
        MockURLProtocol.handler = { req in
            let resp = HTTPURLResponse(url: req.url!, statusCode: 401, httpVersion: "HTTP/1.1", headerFields: nil)!
            return (resp, Data("unauthorized".utf8))
        }
        let provider = OpenAIProvider(session: session)
        let models = try await provider.availableModels(apiKey: "bad")
        XCTAssertEqual(models, provider.localModels)
    }
    // MARK: - Sampling parameters

    private func capturedBody(config: ProviderConfig) async throws -> [String: Any] {
        var captured: Data?
        MockURLProtocol.handler = { req in
            captured = Self.readBody(req)
            let resp = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: nil)!
            return (resp, Data("data: [DONE]\n\n".utf8))
        }
        let provider = OpenAIProvider(session: session)
        for try await _ in provider.stream(messages: [.init(role: .user, content: "hi")], image: nil, config: config) {}
        let data = try XCTUnwrap(captured)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    /// URLProtocol hands the body over as `httpBodyStream`, not `httpBody`.
    private static func readBody(_ req: URLRequest) -> Data? {
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

    /// gpt-6-luna answers 400 "Unsupported value: 'temperature' … Only the
    /// default (1) value is supported" when a preset's temperature is sent.
    func testCurrentModelGetsNoSampling() async throws {
        let body = try await capturedBody(config: ProviderConfig(
            model: "gpt-6-luna", apiKey: "k", temperature: 0.3, topP: 0.9
        ))
        XCTAssertNil(body["temperature"])
        XCTAssertNil(body["top_p"])
    }

    func testGPT4oKeepsPresetSampling() async throws {
        let body = try await capturedBody(config: ProviderConfig(
            model: "gpt-4o-2024-08-06", apiKey: "k", temperature: 0.2, topP: 0.9
        ))
        XCTAssertEqual(body["temperature"] as? Double, 0.2)
        XCTAssertEqual(body["top_p"] as? Double, 0.9)
    }
}
