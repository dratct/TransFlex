import AppKit
import Combine
import OSLog
import SwiftUI

/// Owns the single warm `PopupPanel` instance and drives show/hide lifecycle.
@MainActor
public final class PopupWindowController {
    private static let logger = Logger(subsystem: "io.aiaz.transflex", category: "Popup")

    private let panel: PopupPanel
    private static let defaultSize = NSSize(width: 480, height: 320)

    private var viewModel: PopupViewModel?
    private var hideClock = PopupHideClock()
    private var autoDismisser: WindowAutoDismisser?
    private let presetStore: PresetStore
    private let selection = SelectionCapture()
    private let copySelectionOverride: (@MainActor () async throws -> String)?
    private let replaceCoordinator: QuickReplaceCoordinator
    let replaceHUD: ReplaceHUD
    private var cancellables: Set<AnyCancellable> = []

    public convenience init() {
        self.init(presetStore: PresetStore())
    }

    /// One `escapeHold` serves both the run and the failure banner, so only
    /// one of them registers Esc at a time.
    init(
        presetStore: PresetStore,
        historyStore: HistoryStore? = nil,
        escapeHold: EscapeHold? = nil,
        hud: ReplaceHUD? = nil,
        copySelection: (@MainActor () async throws -> String)? = nil,
        translationService: TranslationService? = nil,
        pasteboard: PasteboardHelper = PasteboardHelper(),
        defaults: UserDefaults = .standard
    ) {
        let escapeHold = escapeHold ?? GlobalEscapeHold()
        self.presetStore = presetStore
        self.copySelectionOverride = copySelection
        self.replaceHUD = hud ?? ReplaceHUD(escapeHold: escapeHold)
        let frame = NSRect(origin: .zero, size: Self.defaultSize)
        self.panel = PopupPanel(contentRect: frame)

        let keychain = KeychainStore()
        let service = translationService ?? TranslationService(
            registry: ProviderRegistry.shared,
            apiKey: { preset in
                if preset.providerID.hasPrefix("openai-compatible:") {
                    let instanceId = String(preset.providerID.dropFirst("openai-compatible:".count))
                    return (try? keychain.get("provider.openai-compatible.\(instanceId).apiKey")) ?? ""
                }
                return (try? keychain.get("provider.\(preset.providerID).apiKey")) ?? ""
            }
        )
        let vm = PopupViewModel(
            translationService: service,
            presetStore: presetStore,
            pasteboard: pasteboard,
            keychain: keychain,
            defaults: defaults,
            hasAPIKey: { preset in
                guard PopupViewModel.keyedProviderIDs.contains(preset.providerID) else { return true }
                return keychain.exists("provider.\(preset.providerID).apiKey")
            }
        )
        vm.historyStore = historyStore
        self.replaceCoordinator = QuickReplaceCoordinator(translationService: service, selection: selection)
        self.replaceCoordinator.historyStore = historyStore
        self.replaceCoordinator.escapeHold = escapeHold
        self.panel.onHide = { [weak self, weak vm] in
            self?.hideClock.recordHide(outputOnly: vm?.isOutputOnly ?? false)
            self?.autoDismisser?.stop()
        }
        vm.onDismissRequest = { [weak self] in self?.hide() }
        vm.onOutputOnlyFailure = { [weak self, weak vm] error in
            guard let vm, let presetID = vm.selectedPresetID else { return }
            self?.showSelectionFailure(error, presetID: presetID, copiedText: vm.inputText)
        }
        self.panel.onCopyCommand = { [weak vm] in vm?.copyResultIfShown() ?? false }
        self.panel.onOpenSettings = { [weak vm] in
            AppCommands.openSettings(tab: vm.map { PopupViewModel.settingsTab(for: $0.state) } ?? .general)
        }
        // Back from Settings with a key saved: the missing-key card clears.
        NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification, object: self.panel)
            .sink { [weak vm] _ in vm?.recheckProviderKey() }
            .store(in: &cancellables)
        self.panel.onTranslateAgainCommand = { [weak vm] in vm?.translateAgainIfShown() ?? false }
        self.panel.onEscape = { [weak self] in self?.handleEscape() }
        self.viewModel = vm

        let popupView = PopupView(viewModel: vm)
        let host = NSHostingController(rootView: popupView)
        host.view.frame = frame
        self.panel.contentViewController = host

        self.autoDismisser = WindowAutoDismisser(window: panel, label: "popup")
        observeOutputOnlyLayout(vm)
    }

    public var isVisible: Bool { panel.isVisible }

    /// Activates a preset by ID; a stream in flight stops and keeps its text.
    public func activatePreset(id: UUID) {
        guard let vm = viewModel else { return }
        vm.switchPreset(id)
    }

    /// Copies the frontmost app's selection, then shows only its translation.
    /// The panel is hidden first: while it is key, ⌘C would hit the popup.
    public func quickTranslate(presetID: UUID) {
        hide()
        replaceHUD.hideBanner()
        Task { @MainActor in
            do {
                let text = try await copySelectedText()
                translateSelection(text, presetID: presetID)
            } catch {
                showSelectionFailure(error, presetID: presetID, copiedText: nil)
            }
        }
    }

    private func translateSelection(_ text: String, presetID: UUID) {
        viewModel?.startQuickTranslation(text: text, presetID: presetID)
        showOutputOnly(source: text)
    }

    /// A banner for what the user can fix elsewhere or retry; the popup only
    /// for cards that need it. Retry reuses the copied text: by then the
    /// selection may be gone.
    private func showSelectionFailure(_ error: Error, presetID: UUID, copiedText: String?) {
        let providerID = presetStore.presets.first { $0.id == presetID }?.providerID ?? ""
        switch SelectionFailure.route(for: error, providerName: ProviderRegistry.shared.displayName(for: providerID)) {
        case .ignore:
            return
        case .popupCard:
            showQuickError(error, presetID: presetID)
        case .banner where replaceHUD.isRunning:
            // The HUD shows a Replace run; the banner would take its place.
            showQuickError(error, presetID: presetID)
        case .banner(let banner):
            hide()
            replaceHUD.showSelectionFailed(banner) { [weak self] in
                guard let self else { return }
                if let copiedText {
                    translateSelection(copiedText, presetID: presetID)
                } else {
                    quickTranslate(presetID: presetID)
                }
            }
        }
    }

    private func copySelectedText() async throws -> String {
        if let copySelectionOverride { return try await copySelectionOverride() }
        return try await selection.copySelection()
    }

    /// Translates the frontmost app's selection and pastes the result over it.
    /// The popup appears only to report a failure.
    public func quickReplace(presetID: UUID) {
        guard let preset = presetStore.presets.first(where: { $0.id == presetID }) else { return }
        // A repeated press while a run is active must not paste twice.
        guard !replaceCoordinator.isRunning else { return NSSound.beep() }
        hide()
        replaceHUD.showTranslating(presetName: preset.name) { [weak self] in
            self?.replaceCoordinator.cancel()
        }
        Task { @MainActor in
            do {
                try await replaceCoordinator.run(preset: preset)
                replaceHUD.showReplaced()
            } catch is CancellationError {
                replaceHUD.hide()
            } catch {
                Self.logger.error("Quick replace failed: \(error.localizedDescription.redactingSecrets(), privacy: .private)")
                reportReplaceFailure(error, presetID: presetID)
            }
        }
    }

    /// The banner reports to someone still in the other app; with the popup
    /// open, the error goes there and Esc stays with the popup.
    func reportReplaceFailure(_ error: Error, presetID: UUID) {
        if panel.isVisible || error as? SelectionCapture.Failure == .accessibilityNotGranted {
            replaceHUD.hide()
            showQuickError(error, presetID: presetID)
            return
        }
        let providerID = presetStore.presets.first { $0.id == presetID }?.providerID ?? ""
        replaceHUD.showFailed(
            message: ReplaceHUD.failureMessage(
                for: error, providerName: ProviderRegistry.shared.displayName(for: providerID)
            ),
            onOpenPopup: { [weak self] in self?.showQuickError(error, presetID: presetID) },
            onRetry: { [weak self] in self?.quickReplace(presetID: presetID) }
        )
    }

    /// Hides the Replace failure banner and gives Esc back, before another
    /// TransFlex window opens.
    public func hideReplaceBanner() {
        replaceHUD.hideBanner()
    }

    /// Shows the full popup and translates a History entry's text again.
    public func translateAgain(text: String, presetID: UUID) {
        show()
        viewModel?.translateAgain(text: text, presetID: presetID)
    }

    /// Toggles popup visibility. If shown, brings to front and focuses.
    public func toggle() {
        if panel.isVisible {
            hide()
        } else {
            show()
        }
    }

    /// Shows popup centered on the screen containing `point` (or the cursor
    /// when nil), sized to 60% of that screen's visible frame. Resizing on
    /// every show adapts to monitor changes between invocations.
    public func show(at point: NSPoint? = nil) {
        let start = mach_absolute_time()
        replaceHUD.hideBanner()

        viewModel?.openPopup(keepingDraft: hideClock.keepsDraft(policy: PopupResetPolicyStore.load()))

        let reference = point ?? NSEvent.mouseLocation
        panel.setFrame(frame(.popup, onScreenContaining: reference), display: true)
        panel.orderFrontRegardless()
        panel.makeKey()

        // TextEditor cannot become first responder until the panel is key.
        viewModel?.requestInputFocus()

        autoDismisser?.start()

        let elapsedMs = Double(ticksToNanos(mach_absolute_time() - start)) / 1_000_000.0
        // The first show after launch lays out the SwiftUI content cold and can
        // pass 150 ms on a busy machine, so a slow show is reported, not fatal.
        if elapsedMs < 150 {
            Self.logger.info("Popup show in \(elapsedMs, privacy: .public) ms")
        } else {
            Self.logger.warning("Popup show exceeded 150ms target: \(elapsedMs, privacy: .public) ms")
        }
    }

    public func hide() {
        panel.orderOut(nil)
    }

    /// Ignores the activation that follows another TransFlex window closing,
    /// then gives the popup the keyboard back.
    public func keepThroughOtherWindowClose() {
        guard panel.isVisible else { return }
        autoDismisser?.stop()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self, self.panel.isVisible else { return }
            self.panel.orderFrontRegardless()
            self.panel.makeKey()
            self.autoDismisser?.start()
        }
    }

    // MARK: - Private

    private func handleEscape() {
        guard let vm = viewModel else { return hide() }
        switch PopupEscape.action(for: vm.state, isOutputOnly: vm.isOutputOnly) {
        case .stop: vm.stop()
        case .backToText: vm.dismissError()
        case .close: hide()
        }
    }

    private func showQuickError(_ error: Error, presetID: UUID) {
        if error as? SelectionCapture.Failure == .accessibilityNotGranted {
            viewModel?.presentAccessibilityRequired(presetID: presetID)
        } else {
            viewModel?.presentQuickFailure(error, presetID: presetID)
        }
        showOutputOnly()
    }

    /// Opens at the size `source` predicts, or the shortest frame without one.
    private func showOutputOnly(source: String? = nil) {
        let start = mach_absolute_time()
        replaceHUD.hideBanner()
        let mouse = NSEvent.mouseLocation
        if let source, let visible = screen(containing: mouse)?.visibleFrame {
            panel.setFrame(PopupFrame.predicted(
                textHeight: { SourceTextEstimate.height(of: source, width: $0) },
                chromeHeight: PopupFrame.outputOnlyChrome,
                in: visible
            ), display: true)
        } else {
            panel.setFrame(frame(.outputOnly, onScreenContaining: mouse), display: true)
        }
        let elapsedMs = Double(ticksToNanos(mach_absolute_time() - start)) / 1_000_000.0
        if elapsedMs < 150 {
            Self.logger.info("Output-only show in \(elapsedMs, privacy: .public) ms")
        } else {
            Self.logger.warning("Output-only show exceeded 150ms target: \(elapsedMs, privacy: .public) ms")
        }
        panel.orderFrontRegardless()
        panel.makeKey()
        // No input editor here, so AppKit would focus the preset picker and
        // draw a focus ring on it. Footer shortcuts still reach the window.
        panel.makeFirstResponder(nil)
        autoDismisser?.start()
        DispatchQueue.main.async { [weak self] in self?.fitOutputOnly() }
    }

    /// Grows the output-only panel with its content, and returns to the
    /// normal size once the user asks to see the input again.
    private func observeOutputOnlyLayout(_ vm: PopupViewModel) {
        vm.$outputContentHeight
            .combineLatest(vm.$outputVisibleHeight)
            .throttle(for: .milliseconds(80), scheduler: RunLoop.main, latest: true)
            .sink { [weak self] _, _ in self?.fitOutputOnly() }
            .store(in: &cancellables)

        // The popup hides when System Settings comes forward; bring it back
        // to confirm the grant the user just made there.
        vm.$state
            .removeDuplicates()
            .filter { $0 == .accessibilityRequired(granted: true) }
            .sink { [weak self] _ in
                guard let self, !self.panel.isVisible else { return }
                self.showOutputOnly()
            }
            .store(in: &cancellables)

        vm.onShowInput = { [weak self] in
            guard let self, self.panel.isVisible else { return }
            let center = NSPoint(x: self.panel.frame.midX, y: self.panel.frame.midY)
            self.panel.setFrame(self.frame(.popup, onScreenContaining: center), display: true)
        }
    }

    /// Not gated on visibility: the first layout happens in `setFrame`, before
    /// the panel is ordered front, and a dropped measurement never repeats.
    private func fitOutputOnly() {
        guard let vm = viewModel, vm.isOutputOnly,
              let screenFrame = screen(containing: NSPoint(x: panel.frame.midX, y: panel.frame.midY))?.visibleFrame,
              let grown = PopupFrame.grown(
                  current: panel.frame,
                  outputContentHeight: vm.outputContentHeight,
                  outputVisibleHeight: vm.outputVisibleHeight,
                  in: screenFrame
              )
        else { return }
        panel.setFrame(grown, display: true, animate: false)
    }

    private func screen(containing point: NSPoint) -> NSScreen? {
        NSScreen.screens.first { NSMouseInRect(point, $0.frame, false) }
            ?? NSScreen.main
            ?? NSScreen.screens.first
    }

    /// The mode's frame on the screen containing `point`. Falls back to primary
    /// then first screen if `point`'s screen yields no visible frame (display
    /// reconfig race).
    private func frame(_ mode: PopupFrame.Mode, onScreenContaining point: NSPoint) -> NSRect {
        guard let visible = screen(containing: point)?.visibleFrame else {
            return NSRect(origin: .zero, size: Self.defaultSize)
        }
        return PopupFrame.initial(mode, in: visible)
    }

    /// Cached `mach_timebase_info` — values are constant for the process lifetime.
    private static let timebase: mach_timebase_info_data_t = {
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        return info
    }()

    private func ticksToNanos(_ ticks: UInt64) -> UInt64 {
        ticks * UInt64(Self.timebase.numer) / UInt64(Self.timebase.denom)
    }
}

struct VisualEffectBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        // `.popover` adapts cleanly to light/dark and has the right translucency
        // for a floating utility surface — `.hudWindow` was too dark/uniform in
        // light mode and made the card look dead.
        view.material = .popover
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
