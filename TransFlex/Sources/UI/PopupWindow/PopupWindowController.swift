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
    private let defaults: UserDefaults
    private let selection: SelectionCapture
    private let copySelectionOverride: (@MainActor () async throws -> String)?
    private let replaceCoordinator: QuickReplaceCoordinator
    let replaceHUD: ReplaceHUD
    private var cancellables: Set<AnyCancellable> = []
    /// True while a pinned popup is ordered out and straight back in, so
    /// `onHide` does not take it for a real hide.
    private var isReorderingPinned = false

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
        selection: SelectionCapture? = nil,
        translationService: TranslationService? = nil,
        pasteboard: PasteboardHelper = PasteboardHelper(),
        defaults: UserDefaults = .standard,
        secretCheck: SecretCheck? = nil
    ) {
        let secretCheck = secretCheck ?? .live(defaults: defaults)
        let escapeHold = escapeHold ?? GlobalEscapeHold()
        self.presetStore = presetStore
        self.defaults = defaults
        self.copySelectionOverride = copySelection
        let selection = selection ?? SelectionCapture()
        self.selection = selection
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
            },
            secretCheck: secretCheck
        )
        vm.historyStore = historyStore
        self.replaceCoordinator = QuickReplaceCoordinator(
            translationService: service, selection: selection, secretCheck: secretCheck
        )
        self.replaceCoordinator.historyStore = historyStore
        self.replaceCoordinator.escapeHold = escapeHold
        self.panel.onHide = { [weak self, weak vm] in
            guard self?.isReorderingPinned != true else { return }
            vm?.popupDidHide()
            self?.hideClock.recordHide(outputOnly: vm?.isOutputOnly ?? false)
            self?.autoDismisser?.stop()
            // Every way of hiding ends here, so no close path can leave a pin behind.
            vm?.unpin()
        }
        vm.onDismissRequest = { [weak self] in self?.hide() }
        vm.onOutputOnlyFailure = { [weak self, weak vm] error in
            // Pinned: the error card with Retry is already in the popup, and stays.
            guard let vm, !vm.isPinned, let presetID = vm.selectedPresetID else { return }
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
        self.panel.onPinCommand = { [weak vm] in vm?.togglePin() }
        self.panel.onEscape = { [weak self] in self?.handleEscape() }
        self.viewModel = vm

        let popupView = PopupView(viewModel: vm)
        let host = NSHostingController(rootView: popupView)
        host.view.frame = frame
        self.panel.contentViewController = host

        self.autoDismisser = WindowAutoDismisser(window: panel, label: "popup", isPinned: { [weak vm] in vm?.isPinned ?? false })
        observeOutputOnlyLayout(vm)
    }

    public var isVisible: Bool { panel.isVisible }
    var panelFrame: NSRect { panel.frame }

    // MARK: - Pin

    var isPinned: Bool { viewModel?.isPinned ?? false }

    func togglePin() {
        viewModel?.togglePin()
    }

    /// Puts the panel where a drag would; tests cannot drag.
    func movePanel(toTopLeft topLeft: NSPoint) {
        panel.setFrameTopLeftPoint(topLeft)
    }

    var viewModelForTesting: PopupViewModel? { viewModel }
    var isPanelKey: Bool { panel.isKeyWindow }
    var panelKeyRequests: Int { panel.keyRequests }
    /// The view a click lands on; `point` is measured from the panel's top-left.
    func hitView(atTopLeftOffset point: NSPoint) -> NSView? {
        guard let content = panel.contentView else { return nil }
        content.layoutSubtreeIfNeeded()
        let inWindow = NSPoint(x: point.x, y: panel.frame.height - point.y)
        return content.hitTest(content.superview?.convert(inWindow, from: nil) ?? inWindow)
    }

    /// What the auto-dismisser does when another app comes forward; tests
    /// cannot activate one.
    func otherAppCameForward(bundleID: String?) {
        autoDismisser?.evaluate(frontmostBundleID: bundleID, source: "test")
    }

    /// Activates a preset by ID; a stream in flight stops and keeps its text.
    public func activatePreset(id: UUID) {
        guard let vm = viewModel else { return }
        vm.switchPreset(id)
    }

    /// A preset's Open shortcut: selects the preset and gives the popup the
    /// keyboard, opening it first when it is hidden.
    public func openForPreset(id: UUID) {
        activatePreset(id: id)
        guard panel.isVisible else { return show() }
        // Only a pinned popup is visible without the keyboard.
        panel.makeKey()
        if viewModel?.isOutputOnly == true {
            // No editor to focus: AppKit would ring the preset picker.
            panel.makeFirstResponder(nil)
        } else {
            viewModel?.requestInputFocus()
        }
    }

    /// Copies the frontmost app's selection, then shows only its translation.
    /// The panel is hidden first: while it is key, ⌘C would hit the popup.
    /// A pinned popup refuses instead, and keeps what it shows.
    public func quickTranslate(presetID: UUID) {
        if isPinned {
            // The banner would take the place of a Replace run's capsule.
            guard !replaceHUD.isRunning else { return NSSound.beep() }
            replaceHUD.hideBanner()
            replaceHUD.showSelectionFailed(.pinned) {}
            return
        }
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
    /// The popup appears only to report a failure. A pinned popup stays.
    public func quickReplace(presetID: UUID) {
        guard let preset = presetStore.presets.first(where: { $0.id == presetID }) else { return }
        // A repeated press while a run is active must not paste twice.
        guard !replaceCoordinator.isRunning else { return NSSound.beep() }
        if isPinned {
            releaseKeyKeepingPin()
        } else {
            hide()
        }
        replaceHUD.showTranslating(presetName: preset.name) { [weak self] in
            self?.replaceCoordinator.cancel()
        }
        finishReplace(presetID: presetID) { [replaceCoordinator] in
            try await replaceCoordinator.run(preset: preset)
        }
    }

    private func finishReplace(presetID: UUID, _ run: @escaping @MainActor () async throws -> Bool) {
        Task { @MainActor in
            do {
                _ = try await run()
                replaceHUD.showReplaced()
            } catch is CancellationError {
                replaceHUD.hide()
            } catch let found as QuickReplaceCoordinator.SecretFound {
                // Not logged: nothing failed, and the log has no use for it.
                showReplaceSecretFound(found.match, presetID: presetID)
            } catch {
                Self.logger.error("Quick replace failed: \(error.localizedDescription.redactingSecrets(), privacy: .private)")
                reportReplaceFailure(error, presetID: presetID)
            }
        }
    }

    /// The Secret check always reports through the banner: an unpinned popup
    /// was hidden before the run, and a pinned one keeps its content.
    private func showReplaceSecretFound(_ match: SecretMatch, presetID: UUID) {
        guard let preset = presetStore.presets.first(where: { $0.id == presetID }) else {
            return replaceCoordinator.discardParked()
        }
        replaceHUD.showSecretFound(
            match,
            providerName: ProviderRegistry.shared.displayName(for: preset.providerID),
            onSendAnyway: { [weak self] in
                guard let self else { return }
                replaceHUD.showTranslating(presetName: preset.name) { [weak self] in
                    self?.replaceCoordinator.cancel()
                }
                finishReplace(presetID: presetID) { [replaceCoordinator] in
                    try await replaceCoordinator.runSendingAnyway(preset: preset)
                }
            },
            onDismiss: { [weak self] in self?.replaceCoordinator.discardParked() }
        )
    }

    /// The banner reports to someone still in the other app; with the popup
    /// open, the error goes there and Esc stays with the popup. A pinned
    /// popup keeps its translation, so only the permission card goes into it.
    func reportReplaceFailure(_ error: Error, presetID: UUID) {
        if (panel.isVisible && !isPinned) || error as? SelectionCapture.Failure == .accessibilityNotGranted {
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
        // Opening is a fresh Popup at its usual frame: a pin does not carry over.
        viewModel?.unpin()

        viewModel?.openPopup(keepingDraft: hideClock.keepsDraft(policy: PopupResetPolicyStore.load(from: defaults)))

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
    /// then gives the popup the keyboard back. A pinned popup stays without
    /// it: the user is working in the app behind.
    public func keepThroughOtherWindowClose() {
        guard panel.isVisible else { return }
        autoDismisser?.stop()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self, self.panel.isVisible else { return }
            self.panel.orderFrontRegardless()
            if self.isPinned {
                // The key check normally rides on the popup becoming key.
                self.viewModel?.recheckProviderKey()
            } else {
                self.panel.makeKey()
            }
            self.autoDismisser?.start()
        }
    }

    // MARK: - Private

    /// A pinned popup that is key would receive the ⌘C meant for the other
    /// app. Ordering it out and back in, without making it key, hands the
    /// keyboard back to that app's window.
    private func releaseKeyKeepingPin() {
        guard panel.isKeyWindow else { return }
        isReorderingPinned = true
        defer { isReorderingPinned = false }
        panel.orderOut(nil)
        panel.orderFrontRegardless()
    }

    private func handleEscape() {
        guard let vm = viewModel else { return hide() }
        switch PopupEscape.action(for: vm.state, isOutputOnly: vm.isOutputOnly) {
        case .stop: vm.stop()
        case .backToText: vm.dismissError()
        case .close: hide()
        }
    }

    private func showQuickError(_ error: Error, presetID: UUID) {
        // A pinned Popup is replaced where it stands, with no hide to start
        // the Draft's clock.
        if panel.isVisible, viewModel?.isOutputOnly == false {
            hideClock.recordHide(outputOnly: false)
        }
        if error as? SelectionCapture.Failure == .accessibilityNotGranted {
            viewModel?.presentAccessibilityRequired(presetID: presetID)
        } else {
            viewModel?.presentQuickFailure(error, presetID: presetID)
        }
        showOutputOnly()
    }

    /// Opens at the size `source` predicts, or the shortest frame without one.
    /// A pinned popup takes that size where it is, and is not made key: the
    /// user is in another app.
    private func showOutputOnly(source: String? = nil) {
        let start = mach_absolute_time()
        replaceHUD.hideBanner()
        let staysPinned = isPinned
        let mouse = NSEvent.mouseLocation
        var target: NSRect
        if let source, let visible = screen(containing: mouse)?.visibleFrame {
            target = PopupFrame.predicted(
                textHeight: { SourceTextEstimate.height(of: source, width: $0) },
                chromeHeight: PopupFrame.outputOnlyChrome,
                in: visible
            )
        } else {
            target = frame(.outputOnly, onScreenContaining: mouse)
        }
        let current = panel.frame
        if staysPinned,
           let visible = screen(containing: NSPoint(x: current.midX, y: current.midY))?.visibleFrame {
            target = PopupFrame.pinned(
                size: target.size, topLeft: NSPoint(x: current.minX, y: current.maxY), in: visible
            )
        }
        panel.setFrame(target, display: true)
        let elapsedMs = Double(ticksToNanos(mach_absolute_time() - start)) / 1_000_000.0
        if elapsedMs < 150 {
            Self.logger.info("Output-only show in \(elapsedMs, privacy: .public) ms")
        } else {
            Self.logger.warning("Output-only show exceeded 150ms target: \(elapsedMs, privacy: .public) ms")
        }
        panel.orderFrontRegardless()
        if !staysPinned {
            panel.makeKey()
            // No input editor here, so AppKit would focus the preset picker and
            // draw a focus ring on it. Footer shortcuts still reach the window.
            panel.makeFirstResponder(nil)
        }
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

        vm.onShowInput = { [weak self, weak vm] in
            guard let self, self.panel.isVisible else { return }
            let current = self.panel.frame
            let center = NSPoint(x: current.midX, y: current.midY)
            if vm?.isPinned == true, let visible = self.screen(containing: center)?.visibleFrame {
                self.panel.setFrame(PopupFrame.pinned(
                    size: PopupFrame.initial(.popup, in: visible).size,
                    topLeft: NSPoint(x: current.minX, y: current.maxY),
                    in: visible
                ), display: true)
            } else {
                self.panel.setFrame(self.frame(.popup, onScreenContaining: center), display: true)
            }
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
