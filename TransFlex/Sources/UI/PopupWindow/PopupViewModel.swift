import AppKit
import Foundation
import OSLog

@MainActor
final class PopupViewModel: ObservableObject {
    private static let logger = Logger(subsystem: "io.aiaz.transflex", category: "PopupViewModel")

    @Published var state: PopupState = .idle
    @Published var inputText: String = "" {
        didSet { if inputText != oldValue, !inputText.isEmpty { attachError = nil } }
    }
    @Published var selectedPresetID: UUID?
    @Published var costEstimate: String?
    @Published var showToast: Bool = false
    @Published var attachedImage: ImageInput?
    /// Why the last attach failed, shown under the Original column.
    @Published var attachError: String?
    @Published var showCostConfirmation: Bool = false
    /// Counter the view observes via `.onChange` to drive `@FocusState`. The
    /// value itself is meaningless — only the change matters, so a monotonic
    /// counter (rather than Bool) avoids the "already true → no event" trap
    /// when the view should re-focus on a subsequent reopen.
    @Published var inputFocusRequest: Int = 0
    /// Selection-translate mode: the popup shows only the result. Cleared by
    /// `reset()`, `showInput()` and `openPopup(keepingDraft:)`.
    @Published private(set) var isOutputOnly: Bool = false
    /// Natural height of the output content and the height it is given,
    /// reported by the view so the controller can grow the panel to fit.
    @Published var outputContentHeight: CGFloat = 0
    @Published var outputVisibleHeight: CGFloat = 0

    private var pendingImageTranslation: ImageInput?
    /// What the user had typed before an image replaced it; removing the
    /// image brings it back.
    private var textBeforeImage: String?
    /// The Popup's Draft and result, set aside while a selection shortcut
    /// uses the panel; `openPopup(keepingDraft:)` hands it back.
    private var popupSession: PopupSession?

    private struct PopupSession {
        let text: String
        let image: ImageInput?
        let presetID: UUID?
        let state: PopupState
        let costEstimate: String?
    }

    private let translationService: TranslationService
    private let presetStore: PresetStore
    private let pasteboard: PasteboardHelper
    private let keychain: KeychainStore
    private let defaults: UserDefaults
    weak var historyStore: HistoryStore? {
        didSet { historyRecorder.historyStore = historyStore }
    }
    var onDismissRequest: (() -> Void)?
    var onShowInput: (() -> Void)?
    private let historyRecorder = HistoryRecorder()

    private let isAccessibilityGranted: () -> Bool
    private let hasAPIKey: (Preset) -> Bool
    private let openAccessibilitySettingsAction: () -> Void
    private var accessibilityPoll: Task<Void, Never>?

    private var activeTask: Task<Void, Never>?
    private var translationStart: Date?
    private var translationSequence = 0

    init(
        translationService: TranslationService,
        presetStore: PresetStore,
        pasteboard: PasteboardHelper = PasteboardHelper(),
        keychain: KeychainStore = KeychainStore(),
        defaults: UserDefaults = .standard,
        isAccessibilityGranted: @escaping () -> Bool = AccessibilityPermission.isGranted,
        openAccessibilitySettings: @escaping () -> Void = AccessibilityPermission.openSettings,
        hasAPIKey: @escaping (Preset) -> Bool = { _ in true }
    ) {
        self.isAccessibilityGranted = isAccessibilityGranted
        self.hasAPIKey = hasAPIKey
        self.openAccessibilitySettingsAction = openAccessibilitySettings
        self.translationService = translationService
        self.presetStore = presetStore
        self.pasteboard = pasteboard
        self.keychain = keychain
        self.defaults = defaults
        self.selectedPresetID = presetStore.presets.first?.id
    }

    /// General setting "Copy result automatically"; off unless set.
    static let copyResultAutomaticallyKey = "copyResultAutomatically"

    var presets: [Preset] { presetStore.presets }
    var selectedPreset: Preset? {
        presets.first { $0.id == selectedPresetID }
    }

    func attachImage(_ image: NSImage, source: ImageSource) {
        handleAttach(image: image, source: source, fileSizeBytes: nil)
    }

    func attachImage(_ image: NSImage, source: ImageSource, fileSizeBytes: Int?) {
        handleAttach(image: image, source: source, fileSizeBytes: fileSizeBytes)
    }

    func removeAttachedImage() {
        attachedImage = nil
        if inputText.isEmpty, let typed = textBeforeImage { inputText = typed }
        textBeforeImage = nil
    }

    /// Opens NSOpenPanel asynchronously and attaches the picked image. The
    /// file-size byte count returned by the picker feeds into the 20 MB
    /// guard before any encode work happens.
    func chooseImageFile() {
        Task { @MainActor in
            guard let picked = await ImageFilePicker.choose() else { return }
            if let errorMessage = picked.errorMessage {
                attachError = errorMessage
                return
            }
            guard let image = picked.image else { return }
            handleAttach(image: image, source: .file, fileSizeBytes: picked.fileSizeBytes)
        }
    }

    /// Reads `NSPasteboard.general` directly so the menu item works without
    /// needing the TextEditor to have focus (which `.onPasteCommand` requires).
    /// Falls back to file-URL on the pasteboard for cases like "Copy" from
    /// Finder which only exposes the URL, not raw image data.
    /// ⌘⇧V: attach the clipboard image and translate it at once.
    func pasteImageAndTranslate() {
        guard pasteImageFromClipboard() else { return }
        translate()
    }

    /// Reads the injected pasteboard, not the TextEditor's paste, so the
    /// shortcut works whatever holds focus. A Finder copy carries only the
    /// file URL, which is read as a fallback.
    @discardableResult
    func pasteImageFromClipboard() -> Bool {
        guard let image = pasteboard.readImage() ?? pasteboard.readFileURLImage() else {
            attachError = "Clipboard does not contain an image."
            return false
        }
        return handleAttach(image: image, source: .paste, fileSizeBytes: nil)
    }

    /// A failure leaves the text, the result and the state as they were and
    /// says why under the Original column.
    @discardableResult
    private func handleAttach(image: NSImage, source: ImageSource, fileSizeBytes: Int?) -> Bool {
        if let preset = selectedPreset, !preset.supportsVision {
            attachError = Self.visionOffMessage
            return false
        }
        switch ImageTranslationCoordinator.validateAndWrap(image, source: source, fileSizeBytes: fileSizeBytes) {
        case .ok(let input):
            attachError = nil
            attachedImage = input
            // Image-only mode: the preview hides the editor, so the typed
            // text is set aside rather than sent unseen.
            if !inputText.isEmpty { textBeforeImage = inputText }
            inputText = ""
            return true
        case .tooLarge(let reason):
            attachError = reason
        case .unsupportedFormat:
            attachError = "Unsupported image format."
        }
        return false
    }

    /// Shown when a file drop is refused before it is read.
    func reportAttachRejected(_ reason: String) {
        attachError = reason
    }

    /// Providers that cannot work without an API key. OpenAI-compatible
    /// endpoints (local servers) may run without one.
    static let keyedProviderIDs = ["openai", "anthropic", "gemini"]

    static let visionOffMessage =
        "This preset can't read images. Turn on Reads images in Settings → Presets, or switch to a preset that has it on."

    var canAttachImages: Bool { selectedPreset?.supportsVision ?? false }

    func translate() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasImage = attachedImage != nil
        guard !text.isEmpty || hasImage, let preset = selectedPreset else { return }
        guard hasAPIKey(preset) else {
            cancelStream()
            state = .missingKey(providerID: preset.providerID)
            return
        }

        if let imageInput = attachedImage {
            let estimate = ImageTranslationCoordinator.preflightCost(
                imageInput: imageInput, model: preset.modelID
            )
            if let estimate, estimate > ImageTranslationCoordinator.costConfirmationThreshold {
                pendingImageTranslation = imageInput
                showCostConfirmation = true
                return
            }
        }

        executeTranslation(text: text, imageInput: attachedImage, preset: preset)
    }

    func confirmCostAndTranslate() {
        guard let imageInput = pendingImageTranslation,
              let preset = selectedPreset
        else { return }
        showCostConfirmation = false
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        executeTranslation(text: text, imageInput: imageInput, preset: preset)
        pendingImageTranslation = nil
    }

    func cancelCostConfirmation() {
        showCostConfirmation = false
        pendingImageTranslation = nil
    }

    private func executeTranslation(text: String, imageInput: ImageInput?, preset: Preset) {
        cancelStream()
        translationSequence &+= 1
        let sequence = translationSequence
        let startedAt = Date()
        translationStart = startedAt

        let task = Task { [weak self] in
            guard let self else { return }
            var accumulated = ""
            var inputTokens = 0
            var outputTokens = 0

            self.state = .streaming(accumulated: "")

            let input: TranslationInput
            do {
                if let imageInput {
                    input = try ImageTranslationCoordinator.buildInput(
                        imageInput: imageInput,
                        providerID: preset.providerID,
                        accompanyingText: text
                    )
                } else {
                    input = .text(text)
                }
            } catch {
                self.state = .error(message: ErrorMessageHelper.friendly(error), partial: nil)
                return
            }

            let stream = self.translationService.translate(input: input, preset: preset)

            do {
                for try await event in stream {
                    guard !Task.isCancelled, self.translationSequence == sequence else { return }
                    switch event {
                    case .textDelta(let chunk):
                        accumulated.append(chunk)
                        self.state = .streaming(accumulated: accumulated)
                    case .usage(let input, let output):
                        inputTokens = input
                        outputTokens = output
                    case .stop:
                        break
                    case .error(let llmError):
                        throw llmError
                    }
                }
                guard self.translationSequence == sequence else { return }
                self.state = .done(result: accumulated)
                self.updateCost(model: preset.modelID, input: inputTokens, output: outputTokens, hadImage: imageInput != nil)
                self.autoCopyIfEnabled(accumulated)
                self.historyRecorder.record(
                    preset: preset, inputText: text, outputText: accumulated,
                    inputTokens: inputTokens, outputTokens: outputTokens,
                    hadImage: imageInput != nil, startTime: startedAt
                )
            } catch is CancellationError {
                guard self.translationSequence == sequence else { return }
                self.state = .idle
            } catch {
                guard self.translationSequence == sequence else { return }
                Self.logger.error("Stream error: \(error.localizedDescription.redactingSecrets(), privacy: .private)")
                let message = ErrorMessageHelper.friendly(
                    error, providerName: ProviderRegistry.shared.displayName(for: preset.providerID)
                )
                if accumulated.isEmpty, case LLMError.auth = error {
                    self.state = .keyRejected(providerID: preset.providerID)
                } else {
                    self.state = .error(message: message, partial: accumulated.isEmpty ? nil : accumulated)
                }
            }
        }
        activeTask = task
    }

    /// Ask the view to move keyboard focus into the input editor. Safe to
    /// call repeatedly; each call bumps `inputFocusRequest` so SwiftUI fires
    /// `.onChange` even when the editor was already focused.
    func requestInputFocus() {
        inputFocusRequest &+= 1
    }

    /// Stop button and Esc while streaming.
    func stop() {
        guard case .streaming(let received) = state else { return cancelStream() }
        cancelStream()
        guard !received.isEmpty else { return }
        state = .done(result: received, stopped: true)
        // Usage arrives with the last event, so a stopped run has no cost to show.
        costEstimate = nil
    }

    func cancelStream() {
        activeTask?.cancel()
        activeTask = nil
        translationSequence &+= 1
        if case .streaming = state {
            state = .idle
        }
    }

    /// User-initiated "start over" — clears input, drops any prior result, and
    /// re-focuses the editor. Distinct from `reset()` only in that it always
    /// requests focus (the auto-reset path runs before the popup is key, where
    /// requesting focus would no-op).
    func startNewTranslation() {
        showInput()
        reset()
        requestInputFocus()
    }

    /// Clears the popup back to a fresh idle session. Called when the popup is
    /// re-opened after enough idle time that the previous translation is no
    /// longer relevant. Cancels in-flight work so a stale stream cannot bleed
    /// results into the next session.
    func reset() {
        cancelStream()
        accessibilityPoll?.cancel()
        accessibilityPoll = nil
        inputText = ""
        attachedImage = nil
        attachError = nil
        textBeforeImage = nil
        pendingImageTranslation = nil
        showCostConfirmation = false
        showToast = false
        costEstimate = nil
        translationStart = nil
        isOutputOnly = false
        outputContentHeight = 0
        // outputVisibleHeight is kept: the scroll view reports it only when it
        // changes, so a zero would stick when the next open has the same frame.
        popupSession = nil
        state = .idle
    }

    /// Resets for a selection shortcut. The Popup's own session is set aside
    /// first; a second shortcut in a row keeps the one already set aside.
    private func resetForSelection() {
        let session: PopupSession?
        if isOutputOnly {
            session = popupSession
        } else {
            let kept: PopupState
            switch state {
            case .done, .error(_, .some): kept = state
            default: kept = .idle
            }
            session = PopupSession(
                text: inputText, image: attachedImage, presetID: selectedPresetID,
                state: kept, costEstimate: kept == .idle ? nil : costEstimate
            )
        }
        reset()
        popupSession = session
    }

    /// Translates text captured from another app and shows only the result.
    func startQuickTranslation(text: String, presetID: UUID) {
        resetForSelection()
        selectedPresetID = presetID
        inputText = text
        isOutputOnly = true
        translate()
    }

    /// Translates a History entry again in the full popup, with the preset it
    /// was made with. Starts a fresh session, so the draft that was open is
    /// replaced the same way a reopen after the idle time replaces it.
    func translateAgain(text: String, presetID: UUID) {
        reset()
        selectedPresetID = presetID
        inputText = text
        translate()
    }

    /// Surfaces a selection-translate failure in the output-only popup.
    /// Replace's Open Popup and selection failures with no banner: a rejected
    /// key gets its own card, anything else the error card.
    func presentQuickFailure(_ error: Error, presetID: UUID) {
        presentQuickError(ErrorMessageHelper.friendly(error), presetID: presetID)
        if case LLMError.auth = error, let preset = selectedPreset {
            state = .keyRejected(providerID: preset.providerID)
        }
    }

    /// Which Settings tab ⌘, opens from this state.
    static func settingsTab(for state: PopupState) -> SettingsTab {
        switch state {
        case .missingKey, .keyRejected: return .providers
        default: return .general
        }
    }

    /// Called when the popup becomes key: a key saved meanwhile clears the
    /// missing-key card.
    func recheckProviderKey() {
        guard case .missingKey = state, let preset = selectedPreset, hasAPIKey(preset) else { return }
        // Idle needs the input editor, which output-only mode hides.
        showInput()
        state = .idle
    }

    func presentQuickError(_ message: String, presetID: UUID) {
        resetForSelection()
        selectedPresetID = presetID
        isOutputOnly = true
        state = .error(message: message, partial: nil)
    }

    /// User asked to see the source text: back to the normal two-pane popup.
    /// Shows the permission card and watches for the grant, so the card can
    /// confirm without the user pressing anything. Keeps watching while the
    /// popup is hidden behind System Settings; gives up after `maxPolls`.
    func presentAccessibilityRequired(
        presetID: UUID,
        pollInterval: UInt64 = 1_000_000_000,
        maxPolls: Int = 300
    ) {
        resetForSelection()
        selectedPresetID = presetID
        isOutputOnly = true
        state = .accessibilityRequired(granted: false)
        accessibilityPoll = Task { [weak self] in
            for _ in 0..<maxPolls {
                try? await Task.sleep(nanoseconds: pollInterval)
                guard let self, !Task.isCancelled else { return }
                if self.isAccessibilityGranted() {
                    self.state = .accessibilityRequired(granted: true)
                    return
                }
            }
        }
    }

    func openAccessibilitySettings() {
        openAccessibilitySettingsAction()
    }

    func showInput() {
        guard isOutputOnly else { return }
        isOutputOnly = false
        popupSession = nil
        onShowInput?()
    }

    /// Opening the Popup. After a selection shortcut the Popup gets back its
    /// own Draft and result when `keepingDraft`, otherwise it starts empty;
    /// it never shows what the shortcut produced. `keepingDraft` comes from
    /// Keep last translation, timed from the Popup's own last hide.
    func openPopup(keepingDraft: Bool) {
        if isOutputOnly {
            let session = popupSession
            reset()
            if let session {
                selectedPresetID = session.presetID ?? selectedPresetID
                if keepingDraft {
                    inputText = session.text
                    attachedImage = session.image
                    state = session.state
                    costEstimate = session.costEstimate
                }
            }
        } else if !keepingDraft {
            reset()
        }
    }

    /// The shown result and its cost stay until ⌘↩ translates with the new
    /// preset; a stream in flight stops and keeps what arrived. Cards about
    /// the old preset (missing key, errors) go away.
    func switchPreset(_ id: UUID) {
        stop()
        selectedPresetID = id
        if case .done = state { return }
        state = .idle
        costEstimate = nil
    }

    func dismissError() {
        if case let .error(_, partial?) = state {
            state = .done(result: partial)
        } else {
            // Idle needs the input editor, which output-only mode hides.
            showInput()
            state = .idle
        }
    }

    /// ⌘C while a translation is shown copies the whole result. Returns false
    /// otherwise, so the key goes on to the editor's own copy.
    @discardableResult
    func copyResultIfShown() -> Bool {
        guard case .done(let result, _) = state else { return false }
        copyToClipboard(result)
        return true
    }

    /// ⌘↩ while the Popup shows a result translates the source again. Returns
    /// false otherwise, so the key goes on to the state's own button.
    @discardableResult
    func translateAgainIfShown() -> Bool {
        guard case .done = state, !isOutputOnly else { return false }
        translate()
        return true
    }

    func copyToClipboard(_ text: String) {
        pasteboard.writeText(text)
        triggerToast(autoDismiss: true)
    }

    /// Used only by the first-run wizard gate. Probes existence via
    /// `KeychainStore.exists(_:)` so macOS does not surface an authentication
    /// prompt just to decide whether the wizard should appear.
    func hasProviderKeyConfigured() -> Bool {
        if UserDefaults.standard.bool(forKey: "hasCompletedFirstRun") { return true }

        if Self.keyedProviderIDs.contains(where: { keychain.exists("provider.\($0).apiKey") }) {
            UserDefaults.standard.set(true, forKey: "hasCompletedFirstRun")
            return true
        }
        let compatIDs = ProviderRegistry.shared.allProviderIDs.filter { $0.hasPrefix("openai-compatible:") }
        for id in compatIDs {
            let instanceId = String(id.dropFirst("openai-compatible:".count))
            if keychain.exists("provider.openai-compatible.\(instanceId).apiKey") {
                UserDefaults.standard.set(true, forKey: "hasCompletedFirstRun")
                return true
            }
        }
        return false
    }

    private func autoCopyIfEnabled(_ text: String) {
        guard defaults.bool(forKey: Self.copyResultAutomaticallyKey) else { return }
        pasteboard.writeText(text)
        triggerToast()
    }

    private func triggerToast(autoDismiss: Bool = false) {
        showToast = true
        Task {
            try? await Task.sleep(nanoseconds: 800_000_000)
            showToast = false
            if autoDismiss {
                try? await Task.sleep(nanoseconds: 200_000_000)
                onDismissRequest?()
            }
        }
    }

    private func updateCost(model: String, input: Int, output: Int, hadImage: Bool) {
        guard input + output > 0 else {
            costEstimate = nil
            return
        }
        let cost = CostTable.estimate(model: model, input: input, output: output, hadImage: hadImage)
        costEstimate = CostFormat.tokens(input + output) + " · " + CostFormat.usd(cost)
    }

}

enum PopupState: Equatable {
    case idle
    case streaming(accumulated: String)
    /// `stopped`: the user pressed Stop; the text is what arrived before it.
    case done(result: String, stopped: Bool = false)
    case error(message: String, partial: String?)
    /// A selection shortcut needs the Accessibility grant; `granted` flips
    /// once the user enables it in System Settings.
    case accessibilityRequired(granted: Bool)
    /// The preset's provider needs a key and none is saved; nothing was sent.
    case missingKey(providerID: String)
    /// The provider refused the saved key (HTTP 401/403); nothing was translated.
    case keyRejected(providerID: String)
}
