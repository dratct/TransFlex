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
    private let replaceCoordinator: QuickReplaceCoordinator
    private let replaceHUD = ReplaceHUD()
    private var cancellables: Set<AnyCancellable> = []

    public convenience init() {
        self.init(presetStore: PresetStore())
    }

    init(presetStore: PresetStore, historyStore: HistoryStore? = nil) {
        self.presetStore = presetStore
        let frame = NSRect(origin: .zero, size: Self.defaultSize)
        self.panel = PopupPanel(contentRect: frame)

        let keychain = KeychainStore()
        let service = TranslationService(
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
            keychain: keychain,
            hasAPIKey: { preset in
                guard PopupViewModel.keyedProviderIDs.contains(preset.providerID) else { return true }
                return keychain.exists("provider.\(preset.providerID).apiKey")
            }
        )
        vm.historyStore = historyStore
        self.replaceCoordinator = QuickReplaceCoordinator(translationService: service, selection: selection)
        self.replaceCoordinator.historyStore = historyStore
        self.replaceCoordinator.escapeHold = GlobalEscapeHold()
        self.panel.onHide = { [weak self, weak vm] in
            self?.hideClock.recordHide(outputOnly: vm?.isOutputOnly ?? false)
            self?.autoDismisser?.stop()
        }
        vm.onDismissRequest = { [weak self] in self?.hide() }
        self.panel.onCopyCommand = { [weak vm] in vm?.copyResultIfShown() ?? false }
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

    /// Activates a preset by ID. Cancels any in-flight stream.
    public func activatePreset(id: UUID) {
        guard let vm = viewModel else { return }
        vm.switchPreset(id)
    }

    /// Copies the frontmost app's selection, then shows only its translation.
    /// The panel is hidden first: while it is key, ⌘C would hit the popup.
    public func quickTranslate(presetID: UUID) {
        hide()
        Task { @MainActor in
            do {
                let text = try await selection.copySelection()
                viewModel?.startQuickTranslation(text: text, presetID: presetID)
                showOutputOnly()
            } catch {
                showQuickError(error, presetID: presetID)
            }
        }
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
                if error as? SelectionCapture.Failure == .accessibilityNotGranted {
                    replaceHUD.hide()
                    showQuickError(error, presetID: presetID)
                    return
                }
                replaceHUD.showFailed(
                    message: ReplaceHUD.failureMessage(for: error),
                    onOpenPopup: { [weak self] in self?.showQuickError(error, presetID: presetID) },
                    onRetry: { [weak self] in self?.quickReplace(presetID: presetID) }
                )
            }
        }
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

        viewModel?.openPopup(keepingDraft: hideClock.keepsDraft(policy: PopupResetPolicyStore.load()))

        let reference = point ?? NSEvent.mouseLocation
        panel.setFrame(frame(.popup, onScreenContaining: reference), display: true)
        panel.orderFrontRegardless()
        panel.makeKey()

        // TextEditor cannot become first responder until the panel is key.
        viewModel?.requestInputFocus()

        autoDismisser?.start()

        let elapsedMs = Double(ticksToNanos(mach_absolute_time() - start)) / 1_000_000.0
        // A warning, not an assert: the first show after launch lays out the
        // SwiftUI content cold and can pass 150 ms on a busy machine.
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
        case .stop: vm.cancelStream()
        case .backToText: vm.dismissError()
        case .close: hide()
        }
    }

    private func showQuickError(_ error: Error, presetID: UUID) {
        if error as? SelectionCapture.Failure == .accessibilityNotGranted {
            viewModel?.presentAccessibilityRequired(presetID: presetID)
        } else {
            viewModel?.presentQuickError(ErrorMessageHelper.friendly(error), presetID: presetID)
        }
        showOutputOnly()
    }

    private func showOutputOnly() {
        panel.setFrame(frame(.outputOnly, onScreenContaining: NSEvent.mouseLocation), display: true)
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
