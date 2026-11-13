import Foundation

/// Translates the frontmost app's selection and pastes the result over it,
/// without showing the popup. Errors are thrown so the caller can surface them.
@MainActor
final class QuickReplaceCoordinator {
    struct EmptyResult: Error {}

    /// The Secret check stopped the selection; it carries what to show and
    /// never the text.
    struct SecretFound: Error, Equatable {
        let match: SecretMatch
    }

    private let translationService: TranslationService
    private let selection: SelectionCapture
    private let secretCheck: SecretCheck
    private let historyRecorder = HistoryRecorder()
    private(set) var isRunning = false
    private var current: Task<Void, Error>?
    /// The selection a `SecretFound` stopped, kept only until the banner
    /// closes or Send anyway resumes with it.
    private var parked: SelectionCapture.CopiedSelection?

    /// Holds Esc system-wide while a run is active, so Esc cancels it.
    var escapeHold: EscapeHold?

    var announcer: Announcing = VoiceOverAnnouncer()

    weak var historyStore: HistoryStore? {
        didSet { historyRecorder.historyStore = historyStore }
    }

    init(translationService: TranslationService, selection: SelectionCapture, secretCheck: SecretCheck? = nil) {
        self.translationService = translationService
        self.selection = selection
        self.secretCheck = secretCheck ?? .live(defaults: .standard)
    }

    /// Returns `false` without doing anything while a previous run is still
    /// in flight, so a repeated press cannot paste twice. Throws
    /// `CancellationError` after `cancel()`; nothing is pasted then. Throws
    /// `SecretFound` when the Secret check stops the selection: nothing was
    /// sent, and `runSendingAnyway` can resume with the same selection.
    @discardableResult
    func run(preset: Preset) async throws -> Bool {
        guard !isRunning else { return false }
        parked = nil
        return try await perform(preset: preset) { [self] in
            let copied = try await selection.copyForReplace()
            try Task.checkCancellation()
            if let match = secretCheck.match(in: copied.text, providerID: preset.providerID) {
                parked = copied
                throw SecretFound(match: match)
            }
            try await translateAndPaste(copied, preset: preset, recordsHistory: true)
        }
    }

    /// Send anyway on the Secret check banner: translates the selection the
    /// check stopped and pastes over it while it is still the selection,
    /// without saving to History. Returns `false` when no selection is waiting.
    @discardableResult
    func runSendingAnyway(preset: Preset) async throws -> Bool {
        guard !isRunning, let copied = parked else { return false }
        parked = nil
        return try await perform(preset: preset) { [self] in
            try await translateAndPaste(copied, preset: preset, recordsHistory: false)
        }
    }

    /// The banner closed without Send anyway: the selection is not kept.
    func discardParked() {
        parked = nil
    }

    func cancel() {
        current?.cancel()
    }

    private func perform(preset: Preset, _ work: @escaping @MainActor () async throws -> Void) async throws -> Bool {
        isRunning = true
        let task = Task { try await work() }
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
        } catch let found as SecretFound {
            let provider = ProviderRegistry.shared.displayName(for: preset.providerID)
            announcer.announce("\(found.match.kind) found. Not sent to \(provider).")
            throw found
        } catch {
            if !(error is CancellationError) { announcer.announce("Couldn’t replace the selection") }
            throw error
        }
        announcer.announce("Replaced with the translation")
        return true
    }

    private func translateAndPaste(
        _ copied: SelectionCapture.CopiedSelection, preset: Preset, recordsHistory: Bool
    ) async throws {
        let original = copied.text
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
        let replacement = Self.keepingEdgeWhitespace(of: original, around: translated)

        // Send anyway can come long after the copy: the banner waits with
        // no time limit, so the selection is confirmed before any ⌘V.
        if !recordsHistory {
            let stillSelected = await selection.isStillSelected(copied)
            try Task.checkCancellation()
            if !stillSelected {
                selection.leaveOnClipboard(replacement)
                throw SelectionCapture.Failure.targetLost
            }
        }

        try await selection.paste(replacement, over: copied)
        guard recordsHistory else { return }
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
