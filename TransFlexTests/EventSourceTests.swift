import XCTest
@testable import TransFlex

final class EventSourceTests: XCTestCase {
    override func tearDown() {
        RetryURLProtocol.reset()
        super.tearDown()
    }

    // MARK: Retry-After parsing

    func testParseRetryAfterSeconds() {
        XCTAssertEqual(EventSource.parseRetryAfter("17"), 17)
        XCTAssertEqual(EventSource.parseRetryAfter("0"), 0)
        XCTAssertEqual(EventSource.parseRetryAfter("  42 "), 42)
    }

    func testParseRetryAfterEmptyOrNil() {
        XCTAssertNil(EventSource.parseRetryAfter(nil))
        XCTAssertNil(EventSource.parseRetryAfter(""))
        XCTAssertNil(EventSource.parseRetryAfter("   "))
    }

    func testParseRetryAfterRejectsNegative() {
        XCTAssertNil(EventSource.parseRetryAfter("-5"))
    }

    func testParseRetryAfterHTTPDate() {
        // 1 hour in the future, formatted per RFC 7231.
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        let date = Date().addingTimeInterval(3600)
        let parsed = EventSource.parseRetryAfter(formatter.string(from: date))
        XCTAssertNotNil(parsed)
        XCTAssertGreaterThan(parsed ?? 0, 3500)
    }

    // MARK: 429 → rateLimit with Retry-After

    func testRateLimitPropagatesRetryAfter() async {
        let session = RetryURLProtocol.makeSession()
        RetryURLProtocol.script = [
            .response(status: 429, headers: ["Retry-After": "30"], body: Data("slow down".utf8)),
        ]
        let req = URLRequest(url: URL(string: "https://example.com/x")!)
        do {
            for try await _ in EventSource.stream(request: req, session: session) {}
            XCTFail("expected throw")
        } catch let err as LLMError {
            XCTAssertEqual(err, .rateLimit(retryAfterSeconds: 30))
        } catch {
            XCTFail("wrong error type: \(error)")
        }
    }

    // MARK: Retry on transient URLError

    func testRetryOnceAfterTransientNetworkError() async throws {
        let session = RetryURLProtocol.makeSession()
        RetryURLProtocol.script = [
            .urlError(.timedOut),
            .response(
                status: 200,
                headers: nil,
                body: Data("data: {\"choices\":[{\"delta\":{\"content\":\"ok\"}}]}\n\n".utf8)
            ),
        ]
        let req = URLRequest(url: URL(string: "https://example.com/x")!)
        var datas: [String] = []
        for try await event in EventSource.stream(request: req, session: session) {
            datas.append(event.data)
        }
        XCTAssertTrue(datas.contains { $0.contains("\"ok\"") }, "got: \(datas)")
        XCTAssertEqual(RetryURLProtocol.attempts, 2)
    }

    func testNonTransientURLErrorDoesNotRetry() async {
        let session = RetryURLProtocol.makeSession()
        RetryURLProtocol.script = [
            .urlError(.unsupportedURL),
        ]
        let req = URLRequest(url: URL(string: "https://example.com/x")!)
        do {
            for try await _ in EventSource.stream(request: req, session: session) {}
            XCTFail("expected throw")
        } catch let llm as LLMError {
            if case .network = llm { /* ok */ } else { XCTFail("wrong: \(llm)") }
        } catch {
            XCTFail("wrong error: \(error)")
        }
        XCTAssertEqual(RetryURLProtocol.attempts, 1)
    }
}

// MARK: - Test helper protocol with scripted multi-attempt behavior

final class RetryURLProtocol: URLProtocol {
    enum Step {
        case urlError(URLError.Code)
        case response(status: Int, headers: [String: String]?, body: Data)
    }

    static var script: [Step] = []
    nonisolated(unsafe) static var attempts: Int = 0
    private static let lock = NSLock()

    static func reset() {
        lock.lock(); defer { lock.unlock() }
        script = []
        attempts = 0
    }

    static func makeSession() -> URLSession {
        let cfg = URLSessionConfiguration.ephemeral
        cfg.protocolClasses = [RetryURLProtocol.self]
        return URLSession(configuration: cfg)
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let step: Step? = RetryURLProtocol.lock.withLock {
            RetryURLProtocol.attempts += 1
            return RetryURLProtocol.script.isEmpty ? nil : RetryURLProtocol.script.removeFirst()
        }
        guard let step else {
            client?.urlProtocol(self, didFailWithError: URLError(.unknown))
            return
        }
        switch step {
        case .urlError(let code):
            client?.urlProtocol(self, didFailWithError: URLError(code))
        case .response(let status, let headers, let body):
            let resp = HTTPURLResponse(
                url: request.url!,
                statusCode: status,
                httpVersion: "HTTP/1.1",
                headerFields: headers
            )!
            client?.urlProtocol(self, didReceive: resp, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: body)
            client?.urlProtocolDidFinishLoading(self)
        }
    }

    override func stopLoading() {}
}

private extension NSLock {
    func withLock<T>(_ block: () -> T) -> T {
        lock(); defer { unlock() }
        return block()
    }
}
