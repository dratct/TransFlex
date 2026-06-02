import AppKit
import Foundation
import OSLog

@MainActor
final class PopupViewModel: ObservableObject {
    private static let logger = Logger(subsystem: "io.aiaz.transflex", category: "PopupViewModel")

    @Published var state: PopupState = .idle
    @Published var inputText: String = ""
    @Published var selectedPresetID: UUID?
    @Published var costEstimate: String?
    @Published var showToast: Bool = false
    @Published var attachedImage: ImageInput?
    @Published var showCostConfirmation: Bool = false
    /// Counter the view observes via `.onChange` to drive `@FocusState`. The
    /// value itself is meaningless — only the change matters, so a monotonic
    /// counter (rather than Bool) avoids the "already true → no event" trap
    /// when the view should re-focus on a subsequent reopen.
    @Published var inputFocusRequest: Int = 0

    private var pendingImageTranslation: ImageInput?

    private let translationService: TranslationService
    private let presetStore: PresetStore
    private let pasteboard: PasteboardHelper
    private let keychain: KeychainStore
    weak var historyStore: HistoryStore? {
        didSet { historyRecorder.historyStore = historyStore }
    }
    var onDismissRequest: (() -> Void)?
    private let historyRecorder = HistoryRecorder()

    private var activeTask: Task<Void, Never>?
    private var translationStart: Date?
    private var translationSequence = 0

    init(
        translationService: TranslationService,
        presetStore: PresetStore,
        pasteboard: PasteboardHelper = PasteboardHelper(),
        keychain: KeychainStore = KeychainStore()
    ) {
        self.translationService = translationService
        self.presetStore = presetStore
        self.pasteboard = pasteboard
        self.keychain = keychain
        self.selectedPresetID = presetStore.presets.first?.id
    }

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
    }

    /// Opens NSOpenPanel asynchronously and attaches the picked image. The
    /// file-size byte count returned by the picker feeds into the 20 MB
    /// guard before any encode work happens.
    func chooseImageFile() {
        Task { @MainActor in
            guard let picked = await ImageFilePicker.choose() else { return }
            if let errorMessage = picked.errorMessage {
                state = .error(message: errorMessage, partial: nil)
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
    func pasteImageFromClipboard() {
        if let image = NSImage(pasteboard: .general) {
            handleAttach(image: image, source: .paste, fileSizeBytes: nil)
            return
        }
        let pb = NSPasteboard.general
        if let urls = pb.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
           let url = urls.first,
           let image = NSImage(contentsOf: url) {
            handleAttach(image: image, source: .paste, fileSizeBytes: nil)
            return
        }
        state = .error(message: "Clipboard không có ảnh", partial: nil)
    }

    private func handleAttach(image: NSImage, source: ImageSource, fileSizeBytes: Int?) {
        switch ImageTranslationCoordinator.validateAndWrap(image, source: source, fileSizeBytes: fileSizeBytes) {
        case .ok(let input):
            attachedImage = input
            // Image-only mode: any text typed before attach is hidden by
            // the preview anyway, so clear it to avoid sending phantom
            // accompanying text the user can no longer see/edit.
            inputText = ""
        case .tooLarge(let reason):
            state = .error(message: reason, partial: nil)
        case .unsupportedFormat:
            state = .error(message: "Định dạng ảnh không hỗ trợ", partial: nil)
        }
    }

    func translate() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasImage = attachedImage != nil
        guard !text.isEmpty || hasImage, let preset = selectedPreset else { return }

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
                if accumulated.isEmpty {
                    self.state = .error(message: ErrorMessageHelper.friendly(error), partial: nil)
                } else {
                    self.state = .error(message: ErrorMessageHelper.friendly(error), partial: accumulated)
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
        reset()
        requestInputFocus()
    }

    /// Clears the popup back to a fresh idle session. Called when the popup is
    /// re-opened after enough idle time that the previous translation is no
    /// longer relevant. Cancels in-flight work so a stale stream cannot bleed
    /// results into the next session.
    func reset() {
        cancelStream()
        inputText = ""
        attachedImage = nil
        pendingImageTranslation = nil
        showCostConfirmation = false
        showToast = false
        costEstimate = nil
        translationStart = nil
        state = .idle
    }

    func switchPreset(_ id: UUID) {
        cancelStream()
        selectedPresetID = id
        state = .idle
        costEstimate = nil
    }

    func dismissError() {
        if case let .error(_, partial?) = state {
            state = .done(result: partial)
        } else {
            state = .idle
        }
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

        let cloudIDs = ["openai", "anthropic", "gemini"]
        if cloudIDs.contains(where: { keychain.exists("provider.\($0).apiKey") }) {
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
        let cost = CostTable.estimate(model: model, input: input, output: output, hadImage: hadImage)
        if let cost {
            let formatted = String(format: "%.4f", cost)
            costEstimate = "\(formatted) USD · \(output) tok"
        } else if output > 0 {
            costEstimate = "\(output) tok"
        } else {
            costEstimate = nil
        }
    }

}

enum PopupState: Equatable {
    case idle
    case streaming(accumulated: String)
    case done(result: String)
    case error(message: String, partial: String?)
}
