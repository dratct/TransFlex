import Foundation

public final class OpenAIProvider: LLMProvider {
    public let id = "openai"
    public let maxImageDim = 1568

    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public var localModels: [Model]? {
        [
            Model(id: "gpt-4o-mini", name: "GPT-4o mini", supportsVision: true),
            Model(id: "gpt-4o", name: "GPT-4o", supportsVision: true),
            Model(id: "gpt-4-turbo", name: "GPT-4 Turbo", supportsVision: true),
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
        let baseURL = URL(string: "https://api.openai.com")!
        let url = baseURL.appendingPathComponent("v1/models")
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        HeaderApplicator.apply(
            to: &request,
            auth: [("Authorization", "Bearer \(apiKey)")],
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
            return Model(id: id, name: id, supportsVision: false, source: .fetched)
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
                    var stopReason: StopReason = .complete
                    for try await event in events {
                        if event.data == "[DONE]" {
                            continuation.yield(.stop(reason: stopReason))
                            continuation.finish()
                            return
                        }
                        OpenAIChunkDecoder.decode(event.data, continuation: continuation, stopReason: &stopReason)
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
        let baseURL = config.baseURL ?? URL(string: "https://api.openai.com")!
        let url = baseURL.appendingPathComponent("v1/chat/completions")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = config.timeoutSeconds
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        HeaderApplicator.apply(
            to: &request,
            auth: [("Authorization", "Bearer \(config.apiKey)")],
            extraGroups: [config.extraHeaders]
        )

        var body = OpenAIRequestBuilder.body(
            model: config.model,
            messages: messages,
            image: image,
            temperature: config.temperature,
            topP: config.topP,
            maxTokens: config.maxTokens,
            stream: true
        )
        ExtraBodyMerger.merge(&body, withJSON: config.extraBodyJSON)
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        return request
    }
}
