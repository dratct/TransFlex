import Foundation

enum OpenAIRequestBuilder {
    static func body(
        model: String,
        messages: [ChatMessage],
        image: Data?,
        temperature: Double,
        topP: Double? = nil,
        maxTokens: Int?,
        stream: Bool
    ) -> [String: Any] {
        var body: [String: Any] = [
            "model": model,
            "messages": requestMessages(messages: messages, image: image),
            "temperature": temperature,
            "stream": stream,
            "stream_options": ["include_usage": true],
        ]
        if let topP { body["top_p"] = topP }
        if let maxTokens { body["max_tokens"] = maxTokens }
        return body
    }

    private static func requestMessages(messages: [ChatMessage], image: Data?) -> [[String: Any]] {
        let lastUserIdx = messages.lastIndex { $0.role == .user }
        let mime = image.map { ImageMime.detect($0).rawValue }
        var jsonMessages: [[String: Any]] = messages.enumerated().map { idx, msg in
            guard idx == lastUserIdx, let image, let mime else {
                return ["role": msg.role.rawValue, "content": msg.content]
            }
            return [
                "role": msg.role.rawValue,
                "content": [
                    ["type": "text", "text": msg.content],
                    ["type": "image_url", "image_url": ["url": dataURL(image: image, mime: mime)]],
                ],
            ]
        }
        if lastUserIdx == nil, let image, let mime {
            jsonMessages.append([
                "role": "user",
                "content": [["type": "image_url", "image_url": ["url": dataURL(image: image, mime: mime)]]],
            ])
        }
        return jsonMessages
    }

    private static func dataURL(image: Data, mime: String) -> String {
        "data:\(mime);base64,\(image.base64EncodedString())"
    }
}
