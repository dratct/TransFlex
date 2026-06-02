import Foundation

public final class OpenAICompatibleProvider: LLMProvider {
    public let id: String
    public let maxImageDim = 1568

    private let session: URLSession
    private let instance: OpenAICompatInstance

    public init(instance: OpenAICompatInstance, session: URLSession = .shared) {
        self.instance = instance
        self.id = "openai-compatible:\(instance.instanceId)"
        self.session = session
    }

    public func listModels(apiKey: String) async throws -> [Model] {
        let url = instance.baseURL.appendingPathComponent("models")
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        var auth: [(String, String)] = []
        if !apiKey.isEmpty {
            auth.append(("Authorization", "Bearer \(apiKey)"))
        }
        HeaderApplicator.apply(to: &request, auth: auth, extraGroups: [instance.extraHeaders])

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let urlError as URLError {
            throw LLMError.network(urlError.localizedDescription.redactingSecrets())
        }
        guard let http = response as? HTTPURLResponse else {
            throw LLMError.invalidResponse("non-HTTP response from /models")
        }
        if !(200..<300).contains(http.statusCode) {
            let body = String(data: data, encoding: .utf8) ?? ""
            switch http.statusCode {
            case 401, 403: throw LLMError.auth
            default: throw LLMError.server(status: http.statusCode, body: body.redactingSecrets())
            }
        }
        let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
        let entries = json?["data"] as? [[String: Any]] ?? []
        return entries.compactMap { entry in
            guard let id = entry["id"] as? String else { return nil }
            return Model(id: id, name: id, supportsVision: false, source: .fetched)
        }
    }

    public var localModels: [Model]? { nil }

    public func availableModels(apiKey: String) async throws -> [Model] {
        try await listModels(apiKey: apiKey)
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
        let url = instance.baseURL.appendingPathComponent("chat/completions")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = config.timeoutSeconds
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var auth: [(String, String)] = []
        if !config.apiKey.isEmpty {
            auth.append(("Authorization", "Bearer \(config.apiKey)"))
        }
        HeaderApplicator.apply(
            to: &request,
            auth: auth,
            extraGroups: [instance.extraHeaders, config.extraHeaders]
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
