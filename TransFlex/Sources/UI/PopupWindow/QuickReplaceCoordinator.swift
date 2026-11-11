import Foundation

/// Translates the frontmost app's selection and pastes the result over it,
/// without showing the popup. Errors are thrown so the caller can surface them.
@MainActor
final class QuickReplaceCoordinator {
    struct EmptyResult: Error {}

    private let translationService: TranslationService
    private let selection: SelectionCapture
    private let historyRecorder = HistoryRecorder()
    private(set) var isRunning = false
    private var current: Task<Void, Error>?

    /// Holds Esc system-wide while a run is active, so Esc cancels it.
    var escapeHold: EscapeHold?

    var announcer: Announcing = VoiceOverAnnouncer()

    weak var historyStore: HistoryStore? {
        didSet { historyRecorder.historyStore = historyStore }
    }

    init(translationService: TranslationService, selection: SelectionCapture) {
        self.translationService = translationService
        self.selection = selection
    }

    /// Returns `false` without doing anything while a previous run is still
    /// in flight, so a repeated press cannot paste twice. Throws
    /// `CancellationError` after `cancel()`; nothing is pasted then.
    @discardableResult
    func run(preset: Preset) async throws -> Bool {
        guard !isRunning else { return false }
        isRunning = true
        let task = Task { try await replace(preset: preset) }
        current = task
        escapeHold?.hold { [weak self] in self?.cancel() }
        // Every way out — pasted, failed, empty, cancelled — lands here.
        defer {
            escapeHold?.release()
            current = nil
            isRunning = false
        }
        do {
            try await task.value
        } catch {
            if !(error is CancellationError) { announcer.announce("Couldn’t replace the selection") }
            throw error
        }
        announcer.announce("Replaced with the translation")
        return true
    }

    func cancel() {
        current?.cancel()
    }

    private func replace(preset: Preset) async throws {
        let copied = try await selection.copyForReplace()
        let original = copied.text
        try Task.checkCancellation()
        let startedAt = Date()
        var output = ""
        var inputTokens = 0
        var outputTokens = 0

        for try await event in translationService.translate(input: .text(original), preset: preset) {
            switch event {
            case .textDelta(let chunk):
                output.append(chunk)
            case .usage(let input, let outputCount):
                inputTokens = input
                outputTokens = outputCount
            case .stop:
                break
            case .error(let llmError):
                throw llmError
            }
        }
        // A cancelled stream just ends; it must never paste what it had so far.
        try Task.checkCancellation()

        let translated = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !translated.isEmpty else { throw EmptyResult() }

        try await selection.paste(
            Self.keepingEdgeWhitespace(of: original, around: translated),
            over: copied
        )
        historyRecorder.record(
            preset: preset, inputText: original, outputText: translated,
            inputTokens: inputTokens, outputTokens: outputTokens,
            hadImage: false, startTime: startedAt
        )
    }

    /// Selections often include a trailing newline (triple-click a line);
    /// models drop it, which would join the next line onto the replacement.
    static func keepingEdgeWhitespace(of original: String, around translated: String) -> String {
        let leading = original.prefix { $0.isWhitespace }
        let trailing = original.reversed().prefix { $0.isWhitespace }.reversed()
        return String(leading) + translated + String(trailing)
    }
}
