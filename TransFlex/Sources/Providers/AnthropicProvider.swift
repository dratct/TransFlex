import Foundation

public final class AnthropicProvider: LLMProvider {
    public let id = "anthropic"
    public let maxImageDim = 1568

    private let session: URLSession
    private let apiVersion = "2023-06-01"

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public var localModels: [Model]? {
        [
            Model(id: "claude-3-5-sonnet-latest", name: "Claude 3.5 Sonnet", supportsVision: true),
            Model(id: "claude-3-5-haiku-latest", name: "Claude 3.5 Haiku", supportsVision: true),
            Model(id: "claude-3-opus-latest", name: "Claude 3 Opus", supportsVision: true),
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
        let baseURL = URL(string: "https://api.anthropic.com")!
        let url = baseURL.appendingPathComponent("v1/models")
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        HeaderApplicator.apply(
            to: &request,
            auth: [("x-api-key", apiKey), ("anthropic-version", apiVersion)],
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
            throw LLMError.invalidResponse("non-HTTP response from /v1/models")
        }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            switch http.statusCode {
            case 401, 403: throw LLMError.auth
            default: throw LLMError.server(status: http.statusCode, body: body.redactingSecrets())
            }
        }
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let entries = json?["data"] as? [[String: Any]] ?? []
        return entries.compactMap { entry in
            guard let id = entry["id"] as? String else { return nil }
            let name = (entry["display_name"] as? String) ?? id
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
                        processEvent(
                            event,
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
        let baseURL = config.baseURL ?? URL(string: "https://api.anthropic.com")!
        let url = baseURL.appendingPathComponent("v1/messages")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = config.timeoutSeconds
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        HeaderApplicator.apply(
            to: &request,
            auth: [("x-api-key", config.apiKey), ("anthropic-version", apiVersion)],
            extraGroups: [config.extraHeaders]
        )

        let (system, conversation) = AnthropicRequestBuilder.split(messages: messages)
        var body = AnthropicRequestBuilder.body(
            model: config.model,
            system: system,
            conversation: conversation,
            image: image,
            temperature: config.temperature,
            topP: config.topP,
            maxTokens: config.maxTokens ?? 4096
        )
        ExtraBodyMerger.merge(&body, withJSON: config.extraBodyJSON)
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        return request
    }

    private func processEvent(
        _ event: SSEEvent,
        continuation: AsyncThrowingStream<LLMEvent, Error>.Continuation,
        inputTokens: inout Int,
        outputTokens: inout Int,
        stopReason: inout StopReason
    ) {
        guard let payload = event.data.data(using: .utf8) else { return }
        let parsed: Any?
        do {
            parsed = try JSONSerialization.jsonObject(with: payload, options: [])
        } catch {
            continuation.yield(.error(.decode(error.localizedDescription.redactingSecrets())))
            return
        }
        guard let json = parsed as? [String: Any] else { return }
        let type = json["type"] as? String ?? event.event ?? ""

        switch type {
        case "message_start":
            if let msg = json["message"] as? [String: Any], let usage = msg["usage"] as? [String: Any] {
                inputTokens = (usage["input_tokens"] as? Int) ?? inputTokens
            }
        case "content_block_delta":
            if let delta = json["delta"] as? [String: Any], let text = delta["text"] as? String, !text.isEmpty {
                continuation.yield(.textDelta(text))
            }
        case "message_delta":
            if let delta = json["delta"] as? [String: Any], let reason = delta["stop_reason"] as? String {
                stopReason = mapStopReason(reason)
            }
            if let usage = json["usage"] as? [String: Any] {
                outputTokens = (usage["output_tokens"] as? Int) ?? outputTokens
            }
        case "message_stop":
            break
        case "error":
            if let err = json["error"] as? [String: Any], let message = err["message"] as? String {
                continuation.yield(.error(.providerMessage(message.redactingSecrets())))
            }
        default:
            break
        }
    }

    private func mapStopReason(_ raw: String) -> StopReason {
        switch raw {
        case "end_turn", "stop_sequence": return .complete
        case "max_tokens": return .lengthCap
        case "refusal", "content_filtered": return .contentFilter
        // tool_use returns no user-visible text — surface as actionable error
        // instead of a misleading `.complete`.
        case "tool_use": return .providerError("tool_use unsupported")
        default: return .providerError(raw)
        }
    }
}
