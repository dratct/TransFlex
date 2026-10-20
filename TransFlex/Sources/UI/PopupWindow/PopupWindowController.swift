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
    private var lastHiddenAt: Date?
    private var autoDismisser: WindowAutoDismisser?
    private let presetStore: PresetStore
    private let selection = SelectionCapture()
    private let replaceCoordinator: QuickReplaceCoordinator
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
            keychain: keychain
        )
        vm.historyStore = historyStore
        self.replaceCoordinator = QuickReplaceCoordinator(translationService: service, selection: selection)
        self.replaceCoordinator.historyStore = historyStore
        self.panel.onHide = { [weak self] in
            self?.lastHiddenAt = Date()
            self?.autoDismisser?.stop()
        }
        vm.onDismissRequest = { [weak self] in self?.hide() }
        self.panel.onCopyCommand = { [weak vm] in vm?.copyResultIfShown() ?? false }
        self.viewModel = vm

        let popupView = PopupView(viewModel: vm)
            .modifier(PopupEscapeModifier(viewModel: vm, onEscape: { [weak self] in self?.hide() }))
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
        hide()
        Task { @MainActor in
            do {
                if try await !replaceCoordinator.run(preset: preset) {
                    NSSound.beep()
                }
            } catch {
                Self.logger.error("Quick replace failed: \(error.localizedDescription.redactingSecrets(), privacy: .private)")
                showQuickError(error, presetID: presetID)
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

        resetIfStale()
        viewModel?.leaveOutputOnly()

        let reference = point ?? NSEvent.mouseLocation
        let frame = centeredFrame(onScreenContaining: reference, sizeRatio: 0.6)
        panel.setFrame(frame, display: true)
        panel.orderFrontRegardless()
        panel.makeKey()

        // TextEditor cannot become first responder until the panel is key.
        viewModel?.requestInputFocus()

        autoDismisser?.start()

        let elapsedMs = Double(ticksToNanos(mach_absolute_time() - start)) / 1_000_000.0
        Self.logger.info("Popup show in \(elapsedMs, privacy: .public) ms")
        #if DEBUG
        assert(elapsedMs < 150, "Popup show exceeded 150ms target: \(elapsedMs) ms")
        #endif
    }

    public func hide() {
        panel.orderOut(nil)
    }

    // MARK: - Private

    private func showQuickError(_ error: Error, presetID: UUID) {
        if error as? SelectionCapture.Failure == .accessibilityNotGranted {
            viewModel?.presentAccessibilityRequired(presetID: presetID)
        } else {
            viewModel?.presentQuickError(ErrorMessageHelper.friendly(error), presetID: presetID)
        }
        showOutputOnly()
    }

    private func showOutputOnly() {
        let reference = NSEvent.mouseLocation
        let visible = screen(containing: reference)?.visibleFrame
            ?? NSRect(origin: .zero, size: Self.defaultSize)
        panel.setFrame(QuickPopupSizing.initialFrame(in: visible), display: true)
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
            self.panel.setFrame(self.centeredFrame(onScreenContaining: center, sizeRatio: 0.6), display: true)
        }
    }

    /// Not gated on visibility: the first layout happens in `setFrame`, before
    /// the panel is ordered front, and a dropped measurement never repeats.
    private func fitOutputOnly() {
        guard let vm = viewModel, vm.isOutputOnly,
              let screenFrame = screen(containing: NSPoint(x: panel.frame.midX, y: panel.frame.midY))?.visibleFrame,
              let grown = QuickPopupSizing.grownFrame(
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

    /// Reset the view-model when the popup is opening fresh, governed by the
    /// user-configured `PopupResetPolicy`. Read on every show so changes in
    /// Settings take effect on the next open without requiring an app restart.
    private func resetIfStale() {
        guard let vm = viewModel else { return }
        let policy = PopupResetPolicyStore.load()
        if policy.shouldReset(lastHiddenAt: lastHiddenAt) {
            vm.reset()
        }
    }

    /// Center panel on the screen containing `point`, sized to `sizeRatio` of
    /// that screen's visible frame. Falls back to primary then first screen
    /// if `point`'s screen yields no visible frame (display reconfig race).
    private func centeredFrame(onScreenContaining point: NSPoint, sizeRatio: CGFloat) -> NSRect {
        guard let visible = screen(containing: point)?.visibleFrame else {
            return NSRect(origin: .zero, size: Self.defaultSize)
        }
        let size = NSSize(width: visible.width * sizeRatio, height: visible.height * sizeRatio)
        return NSRect(
            x: visible.midX - size.width / 2,
            y: visible.midY - size.height / 2,
            width: size.width,
            height: size.height
        )
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
