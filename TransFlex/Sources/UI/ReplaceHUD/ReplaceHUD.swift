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
    }

    @MainActor
    final class Model: ObservableObject {
        @Published var phase: Phase
        init(phase: Phase = .replaced) { self.phase = phase }
        var onCancel: () -> Void = {}
        var onOpenPopup: () -> Void = {}
        var onRetry: () -> Void = {}
        var onClose: () -> Void = {}
    }

    /// The capsule fades this long after "Replaced".
    static let replacedDuration: TimeInterval = 1.5

    private let model = Model()
    private var fadeWork: DispatchWorkItem?
    private lazy var panel: NSPanel = makePanel()

    func showTranslating(presetName: String, onCancel: @escaping () -> Void) {
        model.onCancel = onCancel
        present(.translating(presetName: presetName), besidePointer: true)
    }

    func showReplaced() {
        present(.replaced, besidePointer: false)
        schedule(after: Self.replacedDuration) { [weak self] in self?.hide() }
    }

    func showFailed(message: String, onOpenPopup: @escaping () -> Void, onRetry: @escaping () -> Void) {
        model.onOpenPopup = { [weak self] in self?.hide(); onOpenPopup() }
        model.onRetry = { [weak self] in self?.hide(); onRetry() }
        present(.failed(message: message), besidePointer: false)
    }

    func hide() {
        fadeWork?.cancel()
        panel.orderOut(nil)
    }

    /// The banner's text: what happened, then that the other app's text is
    /// untouched.
    static func failureMessage(for error: Error) -> String {
        if error is QuickReplaceCoordinator.EmptyResult {
            return "The provider returned nothing. Your text was left as it was."
        }
        return ErrorMessageHelper.friendly(error) + " Nothing was changed."
    }

    // MARK: - Private

    private func present(_ phase: Phase, besidePointer: Bool) {
        fadeWork?.cancel()
        model.phase = phase
        let host = panel.contentView!
        host.layoutSubtreeIfNeeded()
        let size = host.fittingSize
        let anchor = besidePointer || !panel.isVisible
            ? NSEvent.mouseLocation
            : NSPoint(x: panel.frame.minX - 14, y: panel.frame.maxY + 14)
        panel.setFrame(Self.frame(size: size, besidePointer: anchor), display: true)
        panel.orderFrontRegardless()
    }

    private func schedule(after seconds: TimeInterval, _ work: @escaping () -> Void) {
        let item = DispatchWorkItem(block: work)
        fadeWork = item
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: item)
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
            Button(action: model.onClose) {
                Image(systemName: "xmark").font(.system(size: 10, weight: .bold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .accessibilityLabel("Close")
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
