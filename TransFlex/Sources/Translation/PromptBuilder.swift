import Foundation

/// Assembles `[ChatMessage]` from a preset's system prompt + caller input.
/// Image bytes travel via `LLMProvider.stream(image:)`, not the message
/// array — providers handle vision encoding per their own wire format.
public enum PromptBuilder {
    public static func build(preset: Preset, input: TranslationInput) -> [ChatMessage] {
        var messages: [ChatMessage] = []
        let trimmedSystem = preset.systemPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedSystem.isEmpty {
            messages.append(ChatMessage(role: .system, content: trimmedSystem))
        }

        switch input {
        case .text(let text):
            messages.append(ChatMessage(role: .user, content: text))
        case .image(_, let accompanyingText):
            let trimmed = accompanyingText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let userContent = trimmed.isEmpty ? "Translate the content in this image." : trimmed
            messages.append(ChatMessage(role: .user, content: userContent))
        }

        return messages
    }
}
