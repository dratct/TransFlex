import AppKit
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

    public convenience init() {
        self.init(presetStore: PresetStore())
    }

    init(presetStore: PresetStore, historyStore: HistoryStore? = nil) {
        let frame = NSRect(origin: .zero, size: Self.defaultSize)
        self.panel = PopupPanel(contentRect: frame)
        self.panel.onHide = { [weak self] in
            self?.lastHiddenAt = Date()
            self?.autoDismisser?.stop()
        }

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
        vm.onDismissRequest = { [weak self] in self?.hide() }
        self.viewModel = vm

        let popupView = PopupView(viewModel: vm)
            .modifier(PopupEscapeModifier(viewModel: vm, onEscape: { [weak self] in self?.hide() }))
        let host = NSHostingController(rootView: popupView)
        host.view.frame = frame
        self.panel.contentViewController = host

        self.autoDismisser = WindowAutoDismisser(window: panel, label: "popup")
    }

    public var isVisible: Bool { panel.isVisible }

    /// Activates a preset by ID. Cancels any in-flight stream.
    public func activatePreset(id: UUID) {
        guard let vm = viewModel else { return }
        vm.switchPreset(id)
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
        let screen = NSScreen.screens.first { NSMouseInRect(point, $0.frame, false) }
            ?? NSScreen.main
            ?? NSScreen.screens.first
        guard let visible = screen?.visibleFrame else {
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
