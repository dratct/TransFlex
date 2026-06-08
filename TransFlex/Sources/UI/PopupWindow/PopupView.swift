import SwiftUI
import AppKit

extension Color {
    /// App accent for primary actions and focus rings.
    static let brandAccent = Color(red: 0.13, green: 0.70, blue: 0.55)
}

@MainActor
struct PopupView: View {
    @StateObject private var viewModel: PopupViewModel
    @State private var showFirstRun = false
    @FocusState private var inputFocused: Bool

    init(viewModel: PopupViewModel) {
        self._viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ZStack {
            VisualEffectBackground()

            VStack(spacing: 0) {
                headerBar
                    .padding(.horizontal, 14)
                    .padding(.top, 12)
                    .padding(.bottom, 8)

                GeometryReader { geo in
                    let isWide = geo.size.width >= 720
                    Group {
                        if isWide {
                            HStack(alignment: .top, spacing: 10) {
                                inputSection
                                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                                PopupOutputSection(viewModel: viewModel)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                            }
                        } else {
                            VStack(spacing: 8) {
                                inputSection
                                    .frame(maxHeight: isIdle ? .infinity : 140)
                                PopupOutputSection(viewModel: viewModel)
                                    .frame(maxHeight: .infinity)
                            }
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.top, 4)

                footerBar
                    .padding(.horizontal, 14)
                    .padding(.top, 8)
                    .padding(.bottom, 10)
            }

            VStack {
                Spacer()
                HStack {
                    Spacer()
                    if viewModel.showToast {
                        ToastView(message: "Copied")
                            .padding(.trailing, 18)
                            .padding(.bottom, 56)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            }
            .allowsHitTesting(false)
            .animation(.easeInOut(duration: 0.18), value: viewModel.showToast)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .tint(.brandAccent)
        .onAppear {
            if !viewModel.hasProviderKeyConfigured() {
                showFirstRun = true
            }
            inputFocused = true
        }
        .onChange(of: viewModel.inputFocusRequest) { _ in
            // Wait for state-driven view swaps before focusing TextEditor.
            DispatchQueue.main.async { inputFocused = true }
        }
        .sheet(isPresented: $showFirstRun) {
            FirstRunWizardView(viewModel: viewModel)
        }
        .alert("Estimated Cost", isPresented: $viewModel.showCostConfirmation) {
            Button("Cancel", role: .cancel) { viewModel.cancelCostConfirmation() }
            Button("Continue") { viewModel.confirmCostAndTranslate() }
        } message: {
            Text("Image translation may cost more than $0.05. Continue?")
        }
    }

    private var isIdle: Bool {
        if case .idle = viewModel.state { return true }
        return false
    }

    private var headerBar: some View {
        HStack(spacing: 8) {
            PresetPickerView(viewModel: viewModel)
            Spacer()
            AttachButton(
                onChooseFile: { viewModel.chooseImageFile() },
                onPaste: { viewModel.pasteImageFromClipboard() }
            )
            Button {
                AppCommands.openSettings()
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 13, weight: .medium))
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .keyboardShortcut(",", modifiers: .command)
        }
    }

    private var inputSection: some View {
        ImageDropZone { image, source, fileSizeBytes in
            viewModel.attachImage(image, source: source, fileSizeBytes: fileSizeBytes)
        } content: {
            if let imageInput = viewModel.attachedImage {
                ImagePreviewCard(
                    image: imageInput.source,
                    sourceType: imageInput.sourceType,
                    canRemove: isIdle,
                    onRemove: { viewModel.removeAttachedImage() }
                )
            } else {
                inputEditor
            }
        }
    }

    private var inputEditor: some View {
        Group {
            if case .idle = viewModel.state {
                ZStack(alignment: .topLeading) {
                    TextEditor(text: $viewModel.inputText)
                        .font(.system(size: 14))
                        .scrollContentBackground(.hidden)
                        .focused($inputFocused)
                        .background(ScrollViewOverlayStyler())

                    if viewModel.inputText.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Type or paste text to translate…")
                                .font(.system(size: 14))
                                .foregroundStyle(.tertiary)

                            if viewModel.attachedImage == nil {
                                HStack(spacing: 6) {
                                    Image(systemName: "paperclip")
                                        .font(.system(size: 11))
                                    Text("Attach an image  ·  ⌘⇧V to paste")
                                        .font(.system(size: 11))
                                }
                                .foregroundStyle(.tertiary)
                                .opacity(0.7)
                            }
                        }
                        .padding(.leading, 5)
                        .allowsHitTesting(false)
                    }
                }
                .frame(minHeight: 140, maxHeight: .infinity)
                .padding(10)
                .background(Color(nsColor: .textBackgroundColor).opacity(0.35))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color(nsColor: .separatorColor).opacity(0.4), lineWidth: 1)
                )
            } else {
                ScrollView {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "quote.opening")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.tertiary)
                            .padding(.top, 3)
                        Text(viewModel.inputText)
                            .font(.system(size: 12))
                            .lineSpacing(2)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .background(Color.white.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
            }
        }
    }

    private var footerBar: some View {
        HStack {
            if let cost = viewModel.costEstimate {
                Text(cost)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            footerActions
        }
        .padding(.top, 4)
    }

    private var footerActions: some View {
        HStack(spacing: 10) {
            switch viewModel.state {
            case .idle:
                actionButton("Translate", keys: ["⌘", "⏎"], tint: .brandAccent) {
                    viewModel.translate()
                }
                .keyboardShortcut(.return, modifiers: .command)
            case .streaming:
                actionButton("Stop", keys: ["⎋"], tint: .orange) { viewModel.cancelStream() }
                    .keyboardShortcut(.escape, modifiers: [])
            case .done(let result):
                actionButton("New", keys: ["⌘", "N"], tint: .blue) {
                    viewModel.startNewTranslation()
                }
                .keyboardShortcut("n", modifiers: .command)
                actionButton("Copy", keys: ["⇧", "⌘", "C"], tint: .purple) {
                    viewModel.copyToClipboard(result)
                }
                .keyboardShortcut("c", modifiers: [.command, .shift])
                actionButton("Re-translate", keys: ["⌘", "R"], tint: .brandAccent) {
                    viewModel.translate()
                }
                .keyboardShortcut("r", modifiers: .command)
            case .error(_, let partial):
                if let partial {
                    actionButton("Continue", keys: ["⌘", "P"], tint: .blue) {
                        viewModel.inputText = partial
                        viewModel.translate()
                    }
                    .keyboardShortcut("p", modifiers: .command)
                }
                actionButton("Dismiss", keys: ["⌘", "."], tint: .gray) {
                    viewModel.dismissError()
                }
                .keyboardShortcut(".", modifiers: .command)
                actionButton("Retry", keys: ["⌘", "⏎"], tint: .brandAccent) {
                    viewModel.translate()
                }
                .keyboardShortcut(.return, modifiers: .command)
            }
        }
    }

    /// Shared footer action button with stable shortcut-hint layout.
    private func actionButton(
        _ title: String,
        keys: [String],
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(title)
                    .fixedSize()
                KeyHintBadge(keys: keys, tone: .secondary)
            }
            .font(.system(size: 13, weight: .medium))
            .fixedSize(horizontal: true, vertical: false)
        }
        .controlSize(.large)
        .tint(tint)
    }

}

/// Forces the enclosing TextEditor scroll view to use overlay scrollers.
private struct ScrollViewOverlayStyler: NSViewRepresentable {
    func makeNSView(context: Context) -> ProbeView { ProbeView() }
    func updateNSView(_ nsView: ProbeView, context: Context) { nsView.applyStyle() }

    final class ProbeView: NSView {
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            applyStyle()
        }

        func applyStyle() {
            DispatchQueue.main.async { [weak self] in
                guard let self, let scrollView = self.findEnclosingTextEditorScrollView() else { return }
                scrollView.scrollerStyle = .overlay
                scrollView.autohidesScrollers = true
                scrollView.hasHorizontalScroller = false
            }
        }

        // TextEditor's NSScrollView lives as a sibling-of-ancestor in the SwiftUI
        // host hierarchy, possibly nested. Walk up superviews; at each level run
        // a depth-first search for the first NSScrollView that contains an
        // NSTextView (avoids matching unrelated scroll views).
        private func findEnclosingTextEditorScrollView() -> NSScrollView? {
            var node: NSView? = superview
            while let current = node {
                if let found = Self.deepFindTextEditorScrollView(in: current) { return found }
                node = current.superview
            }
            return nil
        }

        private static func deepFindTextEditorScrollView(in view: NSView) -> NSScrollView? {
            if let scroll = view as? NSScrollView, scroll.documentView is NSTextView {
                return scroll
            }
            for sub in view.subviews {
                if let found = deepFindTextEditorScrollView(in: sub) { return found }
            }
            return nil
        }
    }
}
