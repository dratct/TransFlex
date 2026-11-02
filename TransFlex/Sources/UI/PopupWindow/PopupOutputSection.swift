import SwiftUI

/// The Translation column: its label, then the streamed or finished text,
/// straight on the popup material. Notices never render here.
struct PopupOutputSection: View {
    @ObservedObject var viewModel: PopupViewModel

    // Updating the streamed text scrolls to this anchor so the newest tokens
    // stay visible while the model streams.
    private let bottomAnchor = "popup-output-bottom"

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            ColumnLabel(title: "Translation", color: .accentText, note: isPartial ? "incomplete" : nil)

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        content
                        Color.clear.frame(height: 1).id(bottomAnchor)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    // The Output-only popup grows from these two heights.
                    .background(HeightReporter { viewModel.outputContentHeight = $0 })
                }
                .background(HeightReporter { viewModel.outputVisibleHeight = $0 })
                .onChange(of: streamingLength) { _ in
                    withAnimation(.linear(duration: 0.08)) {
                        proxy.scrollTo(bottomAnchor, anchor: .bottom)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .streaming(let accumulated):
            if accumulated.isEmpty {
                TypingIndicator().padding(.top, Spacing.s)
            } else {
                StreamingTextView(text: accumulated, isStreaming: true)
            }
        case .done(let result):
            StreamingTextView(text: result, isStreaming: false)
        case .error(_, let partial?):
            StreamingTextView(text: partial, isStreaming: false)
        case .idle, .error, .missingKey, .accessibilityRequired:
            EmptyView()
        }
    }

    private var isPartial: Bool {
        if case .error(_, .some) = viewModel.state { return true }
        return false
    }

    /// Length alone drives auto-scroll: it grows with every token, while the
    /// full string would re-fire `onChange` on identical re-renders.
    private var streamingLength: Int {
        if case .streaming(let acc) = viewModel.state { return acc.count }
        return 0
    }
}

/// Reports its own height on appear and on every change. Preference keys do
/// not reliably leave the AppKit-backed `ScrollView`, so this writes directly.
private struct HeightReporter: View {
    let report: (CGFloat) -> Void

    var body: some View {
        GeometryReader { proxy in
            Color.clear
                .onAppear { report(proxy.size.height) }
                .onChange(of: proxy.size.height) { report($0) }
        }
    }
}
