import AppKit
import SwiftUI

/// Replace Selection's only UI: a capsule beside the pointer while it runs and
/// after it pastes, and a banner when it fails. It never takes focus from the
/// app being edited (DESIGN.md › Replace Selection).
@MainActor
final class ReplaceHUD {
    enum Phase: Equatable {
        case translating(presetName: String)
        case replaced
        case failed(message: String)
        case selectionFailed(SelectionBanner)
    }

    @MainActor
    final class Model: ObservableObject {
        @Published var phase: Phase
        init(phase: Phase = .replaced) { self.phase = phase }
        var onCancel: () -> Void = {}
        var onOpenPopup: () -> Void = {}
        var onRetry: () -> Void = {}
        var onClose: () -> Void = {}
        var onHover: (Bool) -> Void = { _ in }
    }

    /// The capsule fades this long after "Replaced".
    static let replacedDuration: TimeInterval = 1.5

    let model = Model()
    private(set) var isShowing = false
    private let escapeHold: EscapeHold
    /// Set only while the failure banner holds Esc, so hiding the capsule
    /// during a run never releases the run's own hold.
    private var holdsEscape = false
    private var cancelFade: (() -> Void)?
    private lazy var panel: NSPanel = makePanel()

    /// Runs `work` after a delay; the returned closure cancels it.
    typealias Scheduler = (TimeInterval, @escaping () -> Void) -> () -> Void

    private let scheduler: Scheduler

    init(escapeHold: EscapeHold, scheduler: @escaping Scheduler = ReplaceHUD.afterDelay) {
        self.escapeHold = escapeHold
        self.scheduler = scheduler
    }

    static let afterDelay: Scheduler = { seconds, work in
        let item = DispatchWorkItem(block: work)
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: item)
        return { item.cancel() }
    }

    /// The Translate Selection banner hides itself this long after it shows.
    static let selectionBannerDuration: TimeInterval = 4

    /// Translate Selection's failure, near the top of the pointer's screen.
    /// It never holds Esc: it hides itself unless the pointer rests on it.
    func showSelectionFailed(_ banner: SelectionBanner, onRetry: @escaping () -> Void) {
        model.onRetry = { [weak self] in self?.hide(); onRetry() }
        model.onHover = { [weak self] inside in
            guard let self, case .selectionFailed = self.model.phase, self.isShowing else { return }
            if inside { self.stopFade() } else { self.fadeSelectionBanner() }
        }
        present(.selectionFailed(banner), placement: .top)
        fadeSelectionBanner()
    }

    func showTranslating(presetName: String, onCancel: @escaping () -> Void) {
        model.onCancel = onCancel
        present(.translating(presetName: presetName), placement: .besidePointer)
    }

    func showReplaced() {
        present(.replaced, placement: .whereItWas)
        schedule(after: Self.replacedDuration) { [weak self] in self?.hide() }
    }

    func showFailed(message: String, onOpenPopup: @escaping () -> Void, onRetry: @escaping () -> Void) {
        model.onOpenPopup = { [weak self] in self?.hide(); onOpenPopup() }
        model.onRetry = { [weak self] in self?.hide(); onRetry() }
        present(.failed(message: message), placement: .whereItWas)
        // The banner never fades, so Esc closes it from any app.
        escapeHold.hold { [weak self] in self?.hide() }
        holdsEscape = true
    }

    /// The capsule of a Replace run in progress is showing.
    var isRunning: Bool {
        guard isShowing, case .translating = model.phase else { return false }
        return true
    }

    /// Hides only a failure banner; a running capsule stays with its run.
    func hideBanner() {
        guard isShowing else { return }
        switch model.phase {
        case .failed, .selectionFailed: hide()
        case .translating, .replaced: break
        }
    }

    func hide() {
        stopFade()
        releaseEscape()
        isShowing = false
        panel.orderOut(nil)
    }

    /// The banner's text: what happened, then that the other app's text is
    /// untouched.
    static func failureMessage(for error: Error, providerName: String? = nil) -> String {
        if error is QuickReplaceCoordinator.EmptyResult {
            return "The provider returned nothing. Your text was left as it was."
        }
        if let failure = error as? SelectionCapture.Failure, [.pasteNotApplied, .targetLost].contains(failure) {
            return ErrorMessageHelper.friendly(error)
        }
        return ErrorMessageHelper.friendly(error, providerName: providerName) + " Nothing was changed."
    }

    // MARK: - Private

    private func releaseEscape() {
        guard holdsEscape else { return }
        holdsEscape = false
        escapeHold.release()
    }

    private enum Placement { case besidePointer, whereItWas, top }

    private func stopFade() {
        cancelFade?()
        cancelFade = nil
    }

    private func fadeSelectionBanner() {
        schedule(after: Self.selectionBannerDuration) { [weak self] in self?.hide() }
    }

    private func present(_ phase: Phase, placement: Placement) {
        stopFade()
        // A new run starts with `showTranslating`; the old banner's hold goes first.
        releaseEscape()
        isShowing = true
        model.phase = phase
        let host = panel.contentView!
        host.layoutSubtreeIfNeeded()
        let size = host.fittingSize
        let mouse = NSEvent.mouseLocation
        let frame: NSRect
        switch placement {
        case .top:
            frame = Self.frame(size: size, atTopOfScreenWith: mouse)
        case .whereItWas where panel.isVisible:
            let anchor = NSPoint(x: panel.frame.minX - 14, y: panel.frame.maxY + 14)
            frame = Self.frame(size: size, besidePointer: anchor)
        case .besidePointer, .whereItWas:
            frame = Self.frame(size: size, besidePointer: mouse)
        }
        panel.setFrame(frame, display: true)
        panel.orderFrontRegardless()
    }

    private func schedule(after seconds: TimeInterval, _ work: @escaping () -> Void) {
        stopFade()
        cancelFade = scheduler(seconds, work)
    }

    /// Centred near the top of the screen the pointer is on.
    static func frame(size: NSSize, atTopOfScreenWith point: NSPoint) -> NSRect {
        let screen = NSScreen.screens.first { $0.frame.contains(point) } ?? NSScreen.main
        guard let visible = screen?.visibleFrame else { return NSRect(origin: point, size: size) }
        return NSRect(
            x: visible.midX - size.width / 2, y: visible.maxY - 12 - size.height,
            width: size.width, height: size.height
        )
    }

    /// Down and right of the pointer, kept on the pointer's screen.
    static func frame(size: NSSize, besidePointer point: NSPoint) -> NSRect {
        var rect = NSRect(x: point.x + 14, y: point.y - 14 - size.height, width: size.width, height: size.height)
        let screen = NSScreen.screens.first { $0.frame.contains(point) } ?? NSScreen.main
        if let visible = screen?.visibleFrame {
            rect.origin.x = min(max(rect.minX, visible.minX + 8), visible.maxX - rect.width - 8)
            rect.origin.y = min(max(rect.minY, visible.minY + 8), visible.maxY - rect.height - 8)
        }
        return rect
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        model.onClose = { [weak self] in self?.hide() }
        panel.contentView = NSHostingView(rootView: ReplaceHUDView(model: model))
        return panel
    }
}

struct ReplaceHUDView: View {
    @ObservedObject var model: ReplaceHUD.Model

    var body: some View {
        switch model.phase {
        case .translating(let presetName):
            Button(action: model.onCancel) {
                capsule {
                    ProgressView().controlSize(.small)
                    Text("Translating with \(presetName)")
                    Text("esc to cancel").foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
            .help("Click or press esc to cancel")
            .accessibilityLabel("Translating with \(presetName). Press Escape to cancel.")
        case .replaced:
            capsule {
                Image(systemName: "checkmark").foregroundStyle(Color.accentColor)
                Text("Replaced · ⌘Z to undo")
            }
            .accessibilityLabel("Replaced. Command Z to undo.")
        case .failed(let message):
            banner(message: message)
        case .selectionFailed(let banner):
            selectionBanner(banner)
        }
    }

    private func capsule<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        HStack(spacing: Spacing.s) { content() }
            .font(.system(size: 12, weight: .medium))
            .padding(.horizontal, Spacing.m)
            .padding(.vertical, 7)
            .background(.regularMaterial, in: Capsule())
            .overlay(Capsule().stroke(Color(nsColor: .separatorColor).opacity(0.5), lineWidth: 0.5))
            .fixedSize()
            .padding(2)
    }

    private func selectionBanner(_ banner: SelectionBanner) -> some View {
        HStack(alignment: .top, spacing: Spacing.m) {
            SymbolTile(symbol: "exclamationmark.triangle.fill", color: .orange, size: 32)
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(banner.title).font(.headline)
                Text(banner.message)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if banner.canRetry {
                    HStack {
                        Spacer()
                        Button("Retry", action: model.onRetry).buttonStyle(.borderedProminent)
                    }
                    .padding(.top, Spacing.xs)
                }
            }
            Spacer(minLength: 0)
            closeButton
        }
        .padding(Spacing.l)
        .frame(width: 440)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Radius.window, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.window, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.5), lineWidth: 0.5)
        )
        .padding(2)
        .onHover { model.onHover($0) }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(banner.title). \(banner.message)")
    }

    private var closeButton: some View {
        Button(action: model.onClose) {
            Image(systemName: "xmark").font(.system(size: 10, weight: .bold))
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .accessibilityLabel("Close")
    }

    private func banner(message: String) -> some View {
        HStack(alignment: .top, spacing: Spacing.m) {
            SymbolTile(symbol: "exclamationmark.triangle.fill", color: .red, size: 32)
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Couldn’t replace the selection")
                    .font(.headline)
                Text(message)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: Spacing.s) {
                    Spacer()
                    Button("Open Popup", action: model.onOpenPopup)
                    Button("Retry", action: model.onRetry)
                        .buttonStyle(.borderedProminent)
                }
                .padding(.top, Spacing.xs)
            }
            closeButton
        }
        .padding(Spacing.l)
        .frame(width: 360)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Radius.window, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.window, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.5), lineWidth: 0.5)
        )
        .padding(2)
    }
}
