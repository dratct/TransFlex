import SwiftUI

struct PopupOutputSection: View {
    @ObservedObject var viewModel: PopupViewModel

    // Token used to identify the bottom anchor inside the output ScrollView.
    // Updating the streamed text triggers a scrollTo(bottomAnchor) so the
    // newest tokens stay visible while the model streams.
    private let bottomAnchor = "popup-output-bottom"

    var body: some View {
        // Output is the hero of the popup: emerald accent strip on the leading
        // edge + faint brand-tinted fill. Stronger presence than the input
        // "source" card above so hierarchy reads source → result at a glance.
        HStack(alignment: .top, spacing: 0) {
            Rectangle()
                .fill(Color.brandAccent.opacity(0.55))
                .frame(width: 2)

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        switch viewModel.state {
                        case .idle:
                            Text("Translation will appear here")
                                .font(.system(size: 13))
                                .foregroundStyle(.tertiary)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        case .streaming(let accumulated):
                            if accumulated.isEmpty {
                                TypingIndicator()
                            } else {
                                StreamingTextView(text: accumulated, isStreaming: true)
                            }
                        case .done(let result):
                            StreamingTextView(text: result, isStreaming: false)
                        case .error(let message, let partial):
                            errorView(message: message, partial: partial)
                        }

                        Color.clear.frame(height: 1).id(bottomAnchor)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                }
                .onChange(of: streamingText) { _ in
                    // Pin the latest tokens to the bottom while the model
                    // streams. Animation is short so the cursor feels like a
                    // typewriter rather than a sudden jump on each chunk.
                    withAnimation(.linear(duration: 0.08)) {
                        proxy.scrollTo(bottomAnchor, anchor: .bottom)
                    }
                }
            }
        }
        .frame(minHeight: 80, maxHeight: .infinity)
        .background(Color.brandAccent.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.brandAccent.opacity(0.15), lineWidth: 1)
        )
    }

    /// Streaming text length is the only signal we need to drive auto-scroll;
    /// using the full string would re-fire `onChange` on every identical
    /// re-render, while length monotonically grows per token.
    private var streamingText: Int {
        if case .streaming(let acc) = viewModel.state { return acc.count }
        return 0
    }

    private func errorView(message: String, partial: String?) -> some View {
        // Error UI shows only the partial result (if any) + the error banner.
        // Action buttons (Continue / Dismiss / Retry) live in the popup footer
        // so the action area stays consistent across all states (idle has
        // Translate, done has Copy/Re-translate, error has Dismiss/Retry).
        VStack(alignment: .leading, spacing: 14) {
            if let partial {
                StreamingTextView(text: partial, isStreaming: false)
            }

            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.yellow)
                    .frame(width: 18)

                Text(message)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.65))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color(nsColor: .separatorColor).opacity(0.45), lineWidth: 1)
            )
        }
        .padding(.top, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
