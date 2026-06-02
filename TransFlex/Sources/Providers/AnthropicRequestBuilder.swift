import Foundation

enum AnthropicRequestBuilder {
    static func split(messages: [ChatMessage]) -> (system: String?, conversation: [ChatMessage]) {
        let system = messages.first(where: { $0.role == .system })?.content
        let conversation = messages.filter { $0.role != .system }
        return (system, conversation)
    }

    static func body(
        model: String,
        system: String?,
        conversation: [ChatMessage],
        image: Data?,
        temperature: Double,
        topP: Double? = nil,
        maxTokens: Int
    ) -> [String: Any] {
        var jsonMessages = messages(conversation: conversation, image: image)
        if conversation.lastIndex(where: { $0.role == .user }) == nil,
           let image {
            let mime = ImageMime.detect(image).rawValue
            jsonMessages.append(imageOnlyMessage(image: image, mime: mime))
        }

        var body: [String: Any] = [
            "model": model,
            "messages": jsonMessages,
            "max_tokens": maxTokens,
            "temperature": temperature,
            "stream": true,
        ]
        if let topP { body["top_p"] = topP }
        if let system { body["system"] = system }
        return body
    }

    private static func messages(conversation: [ChatMessage], image: Data?) -> [[String: Any]] {
        let lastUserIdx = conversation.lastIndex { $0.role == .user }
        let mime = image.map { ImageMime.detect($0).rawValue }
        return conversation.enumerated().map { idx, msg in
            guard idx == lastUserIdx, let image, let mime else {
                return ["role": msg.role.rawValue, "content": msg.content]
            }
            return [
                "role": msg.role.rawValue,
                "content": [
                    imageContent(image: image, mime: mime),
                    ["type": "text", "text": msg.content],
                ],
            ]
        }
    }

    private static func imageOnlyMessage(image: Data, mime: String) -> [String: Any] {
        [
            "role": "user",
            "content": [imageContent(image: image, mime: mime)],
        ]
    }

    private static func imageContent(image: Data, mime: String) -> [String: Any] {
        [
            "type": "image",
            "source": [
                "type": "base64",
                "media_type": mime,
                "data": image.base64EncodedString(),
            ],
        ]
    }
}
