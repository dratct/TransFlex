import Foundation

enum GeminiRequestBuilder {
    static func body(
        messages: [ChatMessage],
        image: Data?,
        temperature: Double,
        topP: Double? = nil,
        maxTokens: Int?
    ) -> [String: Any] {
        let systemPrompt = messages.first(where: { $0.role == .system })?.content
        let conversation = messages.filter { $0.role != .system }

        var body: [String: Any] = [
            "contents": contents(conversation: conversation, image: image),
            "generationConfig": generationConfig(
                temperature: temperature,
                topP: topP,
                maxTokens: maxTokens
            ),
        ]
        if let systemPrompt {
            body["systemInstruction"] = ["parts": [["text": systemPrompt]]]
        }
        return body
    }

    private static func contents(conversation: [ChatMessage], image: Data?) -> [[String: Any]] {
        let lastUserIdx = conversation.lastIndex { $0.role == .user }
        let mime = image.map { ImageMime.detect($0).rawValue }

        return conversation.enumerated().map { idx, msg in
            var parts: [[String: Any]] = []
            if idx == lastUserIdx, let image, let mime {
                parts.append([
                    "inline_data": [
                        "mime_type": mime,
                        "data": image.base64EncodedString(),
                    ],
                ])
            }
            parts.append(["text": msg.content])
            return [
                "role": msg.role == .assistant ? "model" : "user",
                "parts": parts,
            ]
        }
    }

    private static func generationConfig(
        temperature: Double,
        topP: Double?,
        maxTokens: Int?
    ) -> [String: Any] {
        var config: [String: Any] = ["temperature": temperature]
        if let topP { config["topP"] = topP }
        if let maxTokens { config["maxOutputTokens"] = maxTokens }
        return config
    }
}
