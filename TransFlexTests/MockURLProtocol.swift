import Foundation

/// URLProtocol that returns a canned response + body to whichever
/// `URLRequest` it intercepts. Tests register a handler before each call.
final class MockURLProtocol: URLProtocol {
    typealias Handler = (URLRequest) -> (HTTPURLResponse, Data)

    static var handler: Handler?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = MockURLProtocol.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        let (response, body) = handler(request)
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        // Ship in two chunks to exercise the parser's mid-stream buffering.
        let mid = body.count / 2
        if mid > 0 {
            client?.urlProtocol(self, didLoad: body.prefix(mid))
            client?.urlProtocol(self, didLoad: body.suffix(body.count - mid))
        } else {
            client?.urlProtocol(self, didLoad: body)
        }
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

enum MockSession {
    static func make() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: config)
    }
}
