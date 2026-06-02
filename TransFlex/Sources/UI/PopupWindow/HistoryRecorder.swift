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
        let durationMs = startTime.map { Int(Date().timeIntervalSince($0) * 1000) }
        let entry = HistoryEntry(
            presetID: preset.id,
            providerID: preset.providerID,
            modelID: preset.modelID,
            inputText: inputText.isEmpty ? nil : inputText,
            outputText: outputText,
            hadImage: hadImage,
            durationMs: durationMs,
            tokenCount: inputTokens + outputTokens
        )
        Task { [weak self] in
            do {
                try self?.historyStore?.insert(entry)
            } catch {
                Self.logger.error("History insert failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}
