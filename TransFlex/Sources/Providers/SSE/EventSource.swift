import Foundation

/// Wraps `URLSession.bytes(for:)` and produces decoded `SSEEvent`s.
///
/// Throws `LLMError.server(...)` for non-2xx responses (body fully drained,
/// then redacted before exposure). Honors cancellation between byte chunks.
/// Retries the connection once on transient `URLError` codes — flaky cell /
/// captive-portal scenarios should not surface as hard failures to the UI.
public enum EventSource {
    private static let chunkSize = 4096
    private static let retryDelayNanos: UInt64 = 250_000_000  // 250ms
    private static let transientCodes: Set<URLError.Code> = [
        .timedOut,
        .networkConnectionLost,
        .cannotConnectToHost,
        .dnsLookupFailed,
    ]

    public static func stream(
        request: URLRequest,
        session: URLSession = .shared
    ) -> AsyncThrowingStream<SSEEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let (bytes, response) = try await openWithRetry(request: request, session: session)
                    try Task.checkCancellation()
                    if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                        let body = try await drain(bytes)
                        continuation.finish(throwing: mapHTTPStatus(http, body: body))
                        return
                    }

                    let parser = SSEParser()
                    var buffer = Data()
                    buffer.reserveCapacity(chunkSize)

                    for try await byte in bytes {
                        buffer.append(byte)
                        if buffer.count >= chunkSize || byte == 0x0A {
                            for event in parser.feed(buffer) {
                                continuation.yield(event)
                            }
                            buffer.removeAll(keepingCapacity: true)
                        }
                        try Task.checkCancellation()
                    }
                    if !buffer.isEmpty {
                        for event in parser.feed(buffer) {
                            continuation.yield(event)
                        }
                    }
                    if let tail = parser.flush() {
                        continuation.yield(tail)
                    }
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish(throwing: LLMError.cancelled)
                } catch let urlError as URLError where urlError.code == .cancelled {
                    continuation.finish(throwing: LLMError.cancelled)
                } catch let urlError as URLError {
                    let detail = urlError.localizedDescription.redactingSecrets()
                    continuation.finish(throwing: LLMError.network(detail))
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private static func openWithRetry(
        request: URLRequest,
        session: URLSession
    ) async throws -> (URLSession.AsyncBytes, URLResponse) {
        do {
            return try await session.bytes(for: request)
        } catch let urlError as URLError where transientCodes.contains(urlError.code) {
            try Task.checkCancellation()
            try? await Task.sleep(nanoseconds: retryDelayNanos)
            try Task.checkCancellation()
            return try await session.bytes(for: request)
        }
    }

    private static func drain(_ bytes: URLSession.AsyncBytes) async throws -> String {
        var data = Data()
        for try await byte in bytes {
            data.append(byte)
            if data.count > 64 * 1024 {
                bytes.task.cancel()
                break
            }
        }
        let raw = String(data: data, encoding: .utf8) ?? ""
        return raw.redactingSecrets()
    }

    private static func mapHTTPStatus(_ http: HTTPURLResponse, body: String) -> LLMError {
        switch http.statusCode {
        case 401, 403: return .auth
        case 429:
            let retryAfter = parseRetryAfter(http.value(forHTTPHeaderField: "Retry-After"))
            return .rateLimit(retryAfterSeconds: retryAfter)
        default:
            return .server(status: http.statusCode, body: body)
        }
    }

    /// Parses RFC 7231 `Retry-After`: integer seconds (the LLM-gateway form)
    /// or HTTP-date (rare for inference APIs but spec-permitted).
    static func parseRetryAfter(_ value: String?) -> Double? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        if let seconds = Double(trimmed), seconds >= 0 {
            return seconds
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        if let date = formatter.date(from: trimmed) {
            return max(0, date.timeIntervalSinceNow)
        }
        return nil
    }
}
