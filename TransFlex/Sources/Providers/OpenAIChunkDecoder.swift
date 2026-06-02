import Foundation

/// Decoder for the OpenAI `chat.completion.chunk` shape. Tolerates missing
/// `usage` / `stream_options` since OSS-compat servers (Ollama, vLLM) often
/// omit them — the spec calls these optional and silence is correct.
/// Malformed JSON inside one chunk is reported as `LLMEvent.error(.decode)`
/// and the stream continues; a single dirty packet from a proxy / SSE bridge
/// must not destroy a multi-second generation that is otherwise successful.
enum OpenAIChunkDecoder {
    static func decode(
        _ data: String,
        continuation: AsyncThrowingStream<LLMEvent, Error>.Continuation,
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

        if let usage = json["usage"] as? [String: Any] {
            let input = (usage["prompt_tokens"] as? Int) ?? 0
            let output = (usage["completion_tokens"] as? Int) ?? 0
            if input > 0 || output > 0 {
                continuation.yield(.usage(input: input, output: output))
            }
        }

        guard let choices = json["choices"] as? [[String: Any]], let choice = choices.first else { return }

        if let delta = choice["delta"] as? [String: Any], let text = delta["content"] as? String, !text.isEmpty {
            continuation.yield(.textDelta(text))
        }

        if let finish = choice["finish_reason"] as? String {
            stopReason = mapFinishReason(finish)
        }
    }

    static func mapFinishReason(_ raw: String) -> StopReason {
        switch raw {
        case "stop": return .complete
        case "length": return .lengthCap
        case "content_filter": return .contentFilter
        default: return .providerError(raw)
        }
    }
}
