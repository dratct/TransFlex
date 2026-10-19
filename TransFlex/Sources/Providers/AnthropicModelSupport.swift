import Foundation

/// Which request parameters each Claude model family accepts. Newer models
/// return 400 for `temperature`/`top_p` and older ones for `output_config.effort`,
/// so both are gated per family. Unknown IDs get neither — a missing tuning
/// parameter degrades quality, a rejected one fails the request.
/// See docs/decisions/2026-10-19-anthropic-effort-and-sampling-290c.md.
public enum AnthropicModelSupport {
    public static let defaultEffort = "low"

    private static let samplingFamilies: Set<String> = [
        "claude-opus-4-6", "claude-sonnet-4-6",
        "claude-opus-4-5", "claude-sonnet-4-5", "claude-haiku-4-5",
        "claude-opus-4-1", "claude-opus-4", "claude-sonnet-4",
    ]

    private static let allEffortLevels = ["low", "medium", "high", "xhigh", "max"]

    private static let effortLevelsByFamily: [String: [String]] = [
        "claude-fable-5-1": allEffortLevels,
        "claude-fable-5": allEffortLevels,
        "claude-mythos-5-1": allEffortLevels,
        "claude-opus-5-5": allEffortLevels,
        "claude-opus-5": allEffortLevels,
        "claude-opus-4-8": allEffortLevels,
        "claude-opus-4-7": allEffortLevels,
        "claude-sonnet-5-5": allEffortLevels,
        "claude-sonnet-5": allEffortLevels,
        // Opus 4.5 takes effort only behind the `effort-2025-11-24` beta header; left out.
        "claude-opus-4-6": ["low", "medium", "high", "max"],
        "claude-sonnet-4-6": ["low", "medium", "high", "max"],
    ]

    /// Reduces dated, Bedrock-prefixed or Vertex-style IDs to their family:
    /// `anthropic.claude-haiku-4-5-20251001-v1:0` → `claude-haiku-4-5`.
    static func family(of modelID: String) -> String {
        var id = modelID.lowercased()
        if let dot = id.range(of: "claude-") {
            id = String(id[dot.lowerBound...])
        }
        if let at = id.firstIndex(of: "@") {
            id = String(id[..<at])
        }
        if let range = id.range(of: #"-\d{8}.*$"#, options: .regularExpression) {
            id.removeSubrange(range)
        }
        if let range = id.range(of: #"-v\d+(:\d+)?$"#, options: .regularExpression) {
            id.removeSubrange(range)
        }
        return id
    }

    public static func acceptsSampling(_ modelID: String) -> Bool {
        samplingFamilies.contains(family(of: modelID))
    }

    /// Effort levels the model accepts; empty when it rejects `effort`.
    public static func effortLevels(_ modelID: String) -> [String] {
        effortLevelsByFamily[family(of: modelID)] ?? []
    }

    /// The effort to send: `nil` when the model rejects effort, `defaultEffort`
    /// when none was chosen, otherwise the requested level clamped down to the
    /// highest one the model accepts (a preset saved with `xhigh` keeps working
    /// after switching to a 4.6 model).
    static func resolvedEffort(_ requested: String?, for modelID: String) -> String? {
        let levels = effortLevels(modelID)
        guard !levels.isEmpty else { return nil }
        guard let requested, let rank = allEffortLevels.firstIndex(of: requested) else {
            return defaultEffort
        }
        return levels.last { allEffortLevels.firstIndex(of: $0)! <= rank } ?? defaultEffort
    }
}
