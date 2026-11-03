import Foundation
import OSLog

@MainActor
final class HistoryRecorder {
    private static let logger = Logger(subsystem: "io.aiaz.transflex", category: "HistoryRecorder")

    weak var historyStore: HistoryStore?

    func record(
        preset: Preset,
        inputText: String,
        outputText: String,
        inputTokens: Int,
        outputTokens: Int,
        hadImage: Bool,
        startTime: Date?
    ) {
        let now = Date()
        let entry = Self.makeEntry(
            preset: preset, inputText: inputText, outputText: outputText,
            inputTokens: inputTokens, outputTokens: outputTokens, hadImage: hadImage,
            durationMs: startTime.map { Int(now.timeIntervalSince($0) * 1000) }, now: now
        )
        Task { [weak self] in
            do {
                try self?.historyStore?.insert(entry)
            } catch {
                Self.logger.error("History insert failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    /// The cost is the estimate the popup showed, fixed at translation time.
    /// No usage from the provider (0 tokens) means no cost and no token split,
    /// shown as "price unknown" rather than $0.
    static func makeEntry(
        preset: Preset,
        inputText: String,
        outputText: String,
        inputTokens: Int,
        outputTokens: Int,
        hadImage: Bool,
        durationMs: Int?,
        now: Date
    ) -> HistoryEntry {
        let hasUsage = inputTokens + outputTokens > 0
        return HistoryEntry(
            presetID: preset.id,
            providerID: preset.providerID,
            modelID: preset.modelID,
            inputText: inputText.isEmpty ? nil : inputText,
            outputText: outputText,
            hadImage: hadImage,
            durationMs: durationMs,
            tokenCount: inputTokens + outputTokens,
            inputTokens: hasUsage ? inputTokens : nil,
            outputTokens: hasUsage ? outputTokens : nil,
            costUSD: hasUsage
                ? CostTable.estimate(model: preset.modelID, input: inputTokens, output: outputTokens, hadImage: hadImage)
                : nil,
            createdAt: now
        )
    }
}
