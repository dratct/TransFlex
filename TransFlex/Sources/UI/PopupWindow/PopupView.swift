import SwiftUI
import AppKit

/// The Popup and the Output-only popup: header, the `TranslationColumns`
/// (or a `Notice` card in their place), and the footer (DESIGN.md › Popup states).
@MainActor
struct PopupView: View {
    @StateObject private var viewModel: PopupViewModel
    @State private var showFirstRun = false
    @State private var isWide = true
    @FocusState private var inputFocused: Bool
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    init(viewModel: PopupViewModel) {
        self._viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ZStack {
            material

            VStack(spacing: 0) {
                headerBar
                    .padding(.horizontal, Spacing.l)
                    .padding(.top, Spacing.m)
                    .padding(.bottom, Spacing.l)

                sheet
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                if case .error(let message, .some) = viewModel.state {
                    partialStrip(message: message)
                        .padding(.horizontal, Spacing.l)
                        .padding(.top, Spacing.m)
                }

                footerBar
                    .padding(.horizontal, Spacing.l)
                    .padding(.vertical, Spacing.m)
            }

            VStack {
                Spacer()
                if viewModel.showToast {
                    Toast(message: "Copied")
                        .padding(.bottom, 64)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .frame(maxWidth: .infinity)
            .allowsHitTesting(false)
            .animation(Motion.stateSwap, value: viewModel.showToast)
        }
        .background(hiddenShortcuts)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: Radius.window, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.window, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .onAppear {
            if !viewModel.hasProviderKeyConfigured() {
                showFirstRun = true
            }
            inputFocused = true
        }
        .onChange(of: viewModel.inputFocusRequest) { _ in focusEditor() }
        .onChange(of: editorIsAvailable) { available in
            // The editor comes back after a stream, a notice card or ⌘I: focus
            // it, or AppKit hands focus to the preset picker (audit D4, D8).
            if available { focusEditor() }
        }
        .sheet(isPresented: $showFirstRun) {
            FirstRunWizardView()
        }
        .alert("Estimated Cost", isPresented: $viewModel.showCostConfirmation) {
            Button("Cancel", role: .cancel) { viewModel.cancelCostConfirmation() }
            Button("Continue") { viewModel.confirmCostAndTranslate() }
        } message: {
            Text("Image translation may cost more than $0.05. Continue?")
        }
    }

    // MARK: State

    private var isStreaming: Bool {
        if case .streaming = viewModel.state { return true }
        return false
    }

    private var hasInput: Bool {
        !viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || viewModel.attachedImage != nil
    }

    /// False while a `Notice` card stands in for the columns.
    private var showsColumns: Bool {
        switch viewModel.state {
        case .idle, .streaming, .done, .error(_, .some): return true
        case .error(_, nil), .missingKey, .keyRejected, .accessibilityRequired: return false
        }
    }

    private var editorIsAvailable: Bool {
        showsColumns && !isStreaming && !viewModel.isOutputOnly && viewModel.attachedImage == nil
    }

    private func focusEditor() {
        // Wait for state-driven view swaps before focusing the TextEditor.
        DispatchQueue.main.async {
            if viewModel.attachedImage == nil {
                inputFocused = true
            } else {
                // No editor behind an image preview: AppKit would otherwise
                // focus the preset picker, which then swallows ⌘⏎.
                NSApp.keyWindow?.makeFirstResponder(nil)
            }
        }
    }

    // MARK: Surfaces

    /// Near-opaque, because text sits on it with no box (DESIGN.md › Colors).
    @ViewBuilder
    private var material: some View {
        if reduceTransparency {
            Color(nsColor: .windowBackgroundColor)
        } else {
            ZStack {
                VisualEffectBackground()
                Color(nsColor: .windowBackgroundColor).opacity(colorScheme == .dark ? 0.93 : 0.94)
            }
        }
    }

    private var headerBar: some View {
        HStack(spacing: Spacing.s) {
            PresetPickerView(viewModel: viewModel)
                .focusable(false)
            Spacer()
            headerButton(symbol: "clock.arrow.circlepath", title: "History", keys: ["⌘", "Y"]) {
                // The popup floats above normal windows and would cover History.
                viewModel.onDismissRequest?()
                AppCommands.openHistory()
            }
            .keyboardShortcut("y", modifiers: .command)
            headerButton(symbol: "gearshape", title: "Settings", keys: ["⌘", ","]) {
                AppCommands.openSettings()
            }
            .keyboardShortcut(",", modifiers: .command)
        }
    }

    private func headerButton(symbol: String, title: String, keys: [String], action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .medium))
                .frame(width: 22, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .focusable(false)
        .help("\(title) · \(keys.joined())")
        .accessibilityLabel(title)
        .accessibilityHint(KeyHint.spokenLabel(for: keys))
    }

    @ViewBuilder
    private var sheet: some View {
        switch viewModel.state {
        case .missingKey(let providerID):
            MissingKeyNotice(providerID: providerID, presetName: viewModel.selectedPreset?.name)
                .padding(.horizontal, Spacing.l)
        case .keyRejected(let providerID):
            KeyRejectedNotice(providerID: providerID) {
                if hasInput {
                    footerButton(PopupFooter.Item(action: .retry, prominence: .secondary))
                }
            }
            .padding(.horizontal, Spacing.l)
        case .error(let message, nil):
            Notice(.card, tone: .error, symbol: "exclamationmark.triangle",
                   title: "Couldn’t translate", message: message) {
                if hasInput {
                    footerButton(PopupFooter.Item(action: .retry, prominence: .primary))
                }
            }
            .padding(.horizontal, Spacing.l)
        case .accessibilityRequired(let granted):
            ScrollView {
                AccessibilityPermissionCard(granted: granted)
                    .background(HeightReporter(label: "cardC") { viewModel.outputContentHeight = $0 })
                    // Centred like the notice cards while it fits; taller, it scrolls from the top.
                    .frame(minHeight: viewModel.outputVisibleHeight)
            }
            .background(HeightReporter(label: "cardV") { viewModel.outputVisibleHeight = $0 })
            .padding(.horizontal, Spacing.l)
        case .idle, .streaming, .done, .error:
            columns
        }
    }

    /// `TranslationColumns`: side by side from 720pt, stacked below.
    private var columns: some View {
        GeometryReader { geo in
            let wide = geo.size.width >= ColumnLayout.sideBySideMinWidth
            Group {
                if viewModel.isOutputOnly {
                    PopupOutputSection(viewModel: viewModel)
                } else if wide {
                    // Fixed, whole-point column widths: a share decided by the
                    // content would move the seam by a point between states.
                    let column = ((geo.size.width - 2 * ColumnLayout.sideMargin - ColumnLayout.gutter) / 2).rounded(.down)
                    HStack(spacing: 0) {
                        originalColumn
                            .frame(width: column)
                        ColumnSeam(direction: .vertical, fill: seamFill)
                            .padding(.horizontal, ColumnLayout.gutter / 2)
                        PopupOutputSection(viewModel: viewModel)
                            .frame(width: column)
                    }
                } else {
                    VStack(spacing: 0) {
                        originalColumn
                            .frame(height: geo.size.height * ColumnLayout.stackedOriginalShare)
                        ColumnSeam(direction: .horizontal, fill: seamFill)
                            .padding(.vertical, ColumnLayout.gutter / 2)
                        PopupOutputSection(viewModel: viewModel)
                    }
                }
            }
            .padding(.horizontal, ColumnLayout.sideMargin)
            .onAppear { isWide = wide }
            .onChange(of: wide) { isWide = $0 }
        }
    }

    private var seamFill: Double? {
        guard case .streaming(let accumulated) = viewModel.state else { return nil }
        return ColumnSeam.fill(translatedCount: accumulated.count, sourceCount: viewModel.inputText.count)
    }

    private var originalColumn: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            ColumnLabel(title: "Original", color: Color(nsColor: .tertiaryLabelColor))
            ImageDropZone { image, source, fileSizeBytes in
                viewModel.attachImage(image, source: source, fileSizeBytes: fileSizeBytes)
            } onRejected: { reason in
                viewModel.reportAttachRejected(reason)
            } content: {
                if let imageInput = viewModel.attachedImage {
                    ImagePreviewCard(
                        image: imageInput.source,
                        sourceType: imageInput.sourceType,
                        canRemove: !isStreaming,
                        onRemove: { viewModel.removeAttachedImage() }
                    )
                } else {
                    sourceEditor
                }
            }
            if let attachError = viewModel.attachError {
                Text(attachError)
                    .font(.system(size: 12))
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            } else if case .idle = viewModel.state, viewModel.attachedImage == nil, viewModel.canAttachImages {
                imageTip
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    /// Editable in every state except while a translation streams.
    private var sourceEditor: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $viewModel.inputText)
                .font(ReadingType.original)
                .lineSpacing(ReadingType.originalLineSpacing)
                .foregroundColor(Color(nsColor: .secondaryLabelColor))
                .scrollContentBackground(.hidden)
                .focused($inputFocused)
                .background(ScrollViewOverlayStyler())
                // NSTextView pads each line by 5pt; pull it back so the text
                // starts under the column label, like the placeholder.
                .padding(.leading, -5)
                .disabled(isStreaming)
                .opacity(isStreaming ? 0.55 : 1)

            if viewModel.inputText.isEmpty {
                Text("Type or paste text")
                    .font(.system(size: 17))
                    .foregroundStyle(.tertiary)
                    .allowsHitTesting(false)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var imageTip: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Spacing.xs) {
                Text("Images work too — drop one here, press")
                KeyHint(keys: ["⌘", "⇧", "V"])
                Text(", or")
                chooseFileLink
            }
            HStack(spacing: Spacing.xs) {
                Text("Images: drop, press")
                KeyHint(keys: ["⌘", "⇧", "V"])
                Text(", or")
                chooseFileLink
            }
        }
        .font(.system(size: 12))
        .foregroundStyle(.tertiary)
        .lineLimit(1)
    }

    private var chooseFileLink: some View {
        Button { viewModel.chooseImageFile() } label: {
            Text("choose a file").underline()
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color.accentText)
        .focusable(false)
    }

    private func partialStrip(message: String) -> some View {
        let provider = viewModel.selectedPreset
            .map { ProviderRegistry.shared.displayName(for: $0.providerID) } ?? "The provider"
        return Notice(.strip, tone: .error, symbol: "exclamationmark.triangle.fill",
                      title: "\(provider) stopped the translation", message: message) {
            ForEach(PopupFooter.partialStripItems, id: \.action) { footerButton($0) }
        }
    }

    // MARK: Footer

    private var footerBar: some View {
        HStack(spacing: Spacing.m) {
            footerMeta
            Spacer()
            ForEach(PopupFooter.items(for: viewModel.state, isOutputOnly: viewModel.isOutputOnly, isWide: isWide),
                    id: \.action) { footerButton($0) }
        }
    }

    @ViewBuilder
    private var footerMeta: some View {
        Group {
            switch viewModel.state {
            case .streaming:
                Text("Translating…")
            case .error(_, nil) where !viewModel.isOutputOnly, .missingKey where !viewModel.isOutputOnly,
                 .keyRejected where !viewModel.isOutputOnly:
                Text("Your text is kept")
            default:
                if let cost = viewModel.costEstimate {
                    Text(cost).monospacedDigit()
                }
            }
        }
        .font(.caption)
        .foregroundStyle(.tertiary)
    }

    private func footerButton(_ item: PopupFooter.Item) -> some View {
        FooterAction(item.action.title, keys: item.action.keys, prominence: item.prominence) {
            perform(item.action)
        }
        .keyboardShortcut(shortcut(for: item.action))
    }

    /// Esc, ⌘C and ⌘↩ after a result are caught by `PopupPanel`, whatever holds
    /// focus; stacked, Translate again keeps ⌘↩ that way without a button.
    private func shortcut(for action: PopupFooter.Action) -> KeyboardShortcut? {
        switch action {
        case .showText: return KeyboardShortcut("i", modifiers: .command)
        case .translate, .retry, .openSystemSettings, .done:
            return KeyboardShortcut(.return, modifiers: .command)
        case .new: return KeyboardShortcut("n", modifiers: .command)
        case .stop, .backToText, .copyAndClose, .translateAgain: return nil
        }
    }

    private func perform(_ action: PopupFooter.Action) {
        switch action {
        case .showText: viewModel.showInput()
        case .translate, .translateAgain, .retry: viewModel.translate()
        case .stop: viewModel.stop()
        case .new: viewModel.startNewTranslation()
        case .copyAndClose: viewModel.copyResultIfShown()
        case .backToText: viewModel.dismissError()
        case .openSystemSettings: viewModel.openAccessibilitySettings()
        case .done: viewModel.onDismissRequest?()
        }
    }

    /// Shortcuts with no visible button.
    @ViewBuilder
    private var hiddenShortcuts: some View {
        ZStack {
            if !viewModel.isOutputOnly {
                hiddenButton { viewModel.pasteImageAndTranslate() }
                    .keyboardShortcut("v", modifiers: [.command, .shift])
                hiddenButton { viewModel.chooseImageFile() }
                    .keyboardShortcut("o", modifiers: [.command, .shift])
            }
        }
    }

    private func hiddenButton(action: @escaping () -> Void) -> some View {
        Button("", action: action)
            .frame(width: 0, height: 0)
            .opacity(0)
            .accessibilityHidden(true)
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
