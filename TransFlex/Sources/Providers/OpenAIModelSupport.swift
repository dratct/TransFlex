import Foundation

/// Which OpenAI models accept `temperature`/`top_p`. Reasoning models (o-series,
/// GPT-5 and later) answer 400 "Only the default (1) value is supported", so
/// sampling goes only to the GPT-3.5/GPT-4 families. Unknown IDs get none — a
/// missing tuning parameter degrades quality, a rejected one fails the request.
/// See docs/decisions/2026-11-01-openai-sampling-allow-list-94a1.md.
public enum OpenAIModelSupport {
    private static let samplingPrefixes = ["gpt-3.5", "gpt-4", "chatgpt-4o"]

    public static func acceptsSampling(_ modelID: String) -> Bool {
        let id = modelID.lowercased()
        return samplingPrefixes.contains { id.hasPrefix($0) }
    }
}
