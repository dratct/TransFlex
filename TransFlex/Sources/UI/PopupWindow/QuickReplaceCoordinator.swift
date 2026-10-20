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

    weak var historyStore: HistoryStore? {
        didSet { historyRecorder.historyStore = historyStore }
    }

    init(translationService: TranslationService, selection: SelectionCapture) {
        self.translationService = translationService
        self.selection = selection
    }

    /// Returns `false` without doing anything while a previous run is still
    /// in flight, so a repeated press cannot paste twice.
    @discardableResult
    func run(preset: Preset) async throws -> Bool {
        guard !isRunning else { return false }
        isRunning = true
        defer { isRunning = false }

        let original = try await selection.copySelection()
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

        let translated = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !translated.isEmpty else { throw EmptyResult() }

        try await selection.paste(Self.keepingEdgeWhitespace(of: original, around: translated))
        historyRecorder.record(
            preset: preset, inputText: original, outputText: translated,
            inputTokens: inputTokens, outputTokens: outputTokens,
            hadImage: false, startTime: startedAt
        )
        return true
    }

    /// Selections often include a trailing newline (triple-click a line);
    /// models drop it, which would join the next line onto the replacement.
    static func keepingEdgeWhitespace(of original: String, around translated: String) -> String {
        let leading = original.prefix { $0.isWhitespace }
        let trailing = original.reversed().prefix { $0.isWhitespace }.reversed()
        return String(leading) + translated + String(trailing)
    }
}
