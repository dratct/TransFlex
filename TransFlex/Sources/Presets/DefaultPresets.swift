import Foundation

/// Ship-default presets seeded on first launch. Treated as starter examples;
/// users are free to edit or delete them.
public enum DefaultPresets {
    public static let builtins: [Preset] = [
        Preset(
            name: "Natural EN ↔ VI",
            providerID: "openai",
            modelID: "gpt-4o-mini",
            systemPrompt: """
            You are a bilingual English ↔ Vietnamese translator. Detect the input \
            language. If English, translate to natural, fluent Vietnamese using \
            everyday register. If Vietnamese, translate to natural English. \
            Preserve emoji, names, code blocks, and URLs verbatim. Do not add \
            commentary, prefixes, or quotes — output only the translated text.
            """,
            temperature: 0.3,
            supportsVision: false
        ),
        Preset(
            name: "Technical Doc EN ↔ VI",
            providerID: "openai",
            modelID: "gpt-4o",
            systemPrompt: """
            You are a technical translator (English ↔ Vietnamese) for software \
            documentation. Detect input language and translate to the other. \
            Keep code blocks, inline `code`, identifiers, API names, CLI \
            commands, file paths, and English technical terms (e.g. "buffer", \
            "thread", "deadlock") UNTRANSLATED. Translate prose only. Output \
            only the translated text without commentary.
            """,
            temperature: 0.2,
            supportsVision: false
        ),
        Preset(
            name: "Any → English (Natural)",
            providerID: "openai",
            modelID: "gpt-4o-mini",
            systemPrompt: """
            You are a translator. Detect the input language automatically and \
            translate it to natural, fluent English. Preserve emoji, names, \
            code blocks, URLs, and proper nouns verbatim. If the input is \
            already English, return it unchanged. Do not add commentary, \
            prefixes, or quotes — output only the translated text.
            """,
            temperature: 0.3,
            supportsVision: false
        ),
    ]

    @MainActor
    public static func seedIfNeeded(into store: PresetStore) throws {
        guard store.presets.isEmpty else { return }
        try store.replaceAll(with: builtins)
    }
}
