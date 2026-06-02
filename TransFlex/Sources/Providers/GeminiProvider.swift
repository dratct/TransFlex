import Foundation

public final class GeminiProvider: LLMProvider {
    public let id = "gemini"
    public let maxImageDim = 3072

    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public var localModels: [Model]? {
        [
            Model(id: "gemini-2.0-flash", name: "Gemini 2.0 Flash", supportsVision: true),
            Model(id: "gemini-1.5-pro", name: "Gemini 1.5 Pro", supportsVision: true),
            Model(id: "gemini-1.5-flash", name: "Gemini 1.5 Flash", supportsVision: true),
        ]
    }

    public func availableModels(apiKey: String) async throws -> [Model] {
        guard !apiKey.isEmpty else { return localModels! }
        do {
            return try await fetchModels(apiKey: apiKey)
        } catch {
            return localModels!
        }
    }

    private func fetchModels(apiKey: String) async throws -> [Model] {
        let baseURL = URL(string: "https://generativelanguage.googleapis.com")!
        let url = baseURL.appendingPathComponent("v1beta/models")
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        HeaderApplicator.apply(
            to: &request,
            auth: [("x-goog-api-key", apiKey)],
            extraGroups: []
        )

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let urlError as URLError {
            throw LLMError.network(urlError.localizedDescription.redactingSecrets())
        }
        guard let http = response as? HTTPURLResponse else {
            throw LLMError.invalidResponse("non-HTTP response from /v1beta/models")
        }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            switch http.statusCode {
            case 401, 403: throw LLMError.auth
            default: throw LLMError.server(status: http.statusCode, body: body.redactingSecrets())
            }
        }
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let entries = json?["models"] as? [[String: Any]] ?? []
        return entries.compactMap { entry in
            guard let rawName = entry["name"] as? String else { return nil }
            let methods = entry["supportedGenerationMethods"] as? [String] ?? []
            guard methods.contains("generateContent") else { return nil }
            let id = rawName.hasPrefix("models/") ? String(rawName.dropFirst("models/".count)) : rawName
            let name = (entry["displayName"] as? String) ?? id
            return Model(id: id, name: name, supportsVision: false, source: .fetched)
        }
    }

    public func stream(
        messages: [ChatMessage],
        image: Data?,
        config: ProviderConfig
    ) -> AsyncThrowingStream<LLMEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let request = try buildRequest(messages: messages, image: image, config: config)
                    let events = EventSource.stream(request: request, session: session)
                    var inputTokens = 0
                    var outputTokens = 0
                    var stopReason: StopReason = .complete
                    for try await event in events {
                        processChunk(
                            event.data,
                            continuation: continuation,
                            inputTokens: &inputTokens,
                            outputTokens: &outputTokens,
                            stopReason: &stopReason
                        )
                    }
                    if inputTokens > 0 || outputTokens > 0 {
                        continuation.yield(.usage(input: inputTokens, output: outputTokens))
                    }
                    continuation.yield(.stop(reason: stopReason))
                    continuation.finish()
                } catch let llm as LLMError {
                    continuation.finish(throwing: llm)
                } catch is CancellationError {
                    continuation.finish(throwing: LLMError.cancelled)
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func buildRequest(messages: [ChatMessage], image: Data?, config: ProviderConfig) throws -> URLRequest {
        let baseURL = config.baseURL ?? URL(string: "https://generativelanguage.googleapis.com")!
        var components = URLComponents(
            url: baseURL.appendingPathComponent("v1beta/models/\(config.model):streamGenerateContent"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [URLQueryItem(name: "alt", value: "sse")]
        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        request.timeoutInterval = config.timeoutSeconds
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // Header beats `?key=` — avoids leaking into URL access logs / proxies.
        HeaderApplicator.apply(
            to: &request,
            auth: [("x-goog-api-key", config.apiKey)],
            extraGroups: [config.extraHeaders]
        )

        var body = GeminiRequestBuilder.body(
            messages: messages,
            image: image,
            temperature: config.temperature,
            topP: config.topP,
            maxTokens: config.maxTokens
        )
        ExtraBodyMerger.merge(&body, withJSON: config.extraBodyJSON)
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        return request
    }

    private func processChunk(
        _ data: String,
        continuation: AsyncThrowingStream<LLMEvent, Error>.Continuation,
        inputTokens: inout Int,
        outputTokens: inout Int,
        stopReason: inout StopReason
    ) {
        guard let payload = data.data(using: .utf8) else { return }
        let parsed: Any?
        do {
            parsed = try JSONSerialization.jsonObject(with: payload, options: [])
        } catch {
            continuation.yield(.error(.decode(error.localizedDescription.redactingSecrets())))
            return
        }
        guard let json = parsed as? [String: Any] else { return }

        if let candidates = json["candidates"] as? [[String: Any]], let candidate = candidates.first {
            if let content = candidate["content"] as? [String: Any],
               let parts = content["parts"] as? [[String: Any]] {
                for part in parts {
                    if let text = part["text"] as? String, !text.isEmpty {
                        continuation.yield(.textDelta(text))
                    }
                }
            }
            if let finish = candidate["finishReason"] as? String {
                stopReason = mapStopReason(finish)
            }
        }
        if let usage = json["usageMetadata"] as? [String: Any] {
            inputTokens = (usage["promptTokenCount"] as? Int) ?? inputTokens
            outputTokens = (usage["candidatesTokenCount"] as? Int) ?? outputTokens
        }
    }

    private func mapStopReason(_ raw: String) -> StopReason {
        switch raw {
        case "STOP": return .complete
        case "MAX_TOKENS": return .lengthCap
        case "SAFETY", "RECITATION": return .contentFilter
        case "FINISH_REASON_UNSPECIFIED": return .complete
        default: return .providerError(raw)
        }
    }
}
