import AppKit
import SwiftUI

/// A borderless copy icon that turns into a checkmark for a moment after it
/// copies, so a click with no other visible result still reads as done.
struct CopyIconButton: View {
    let text: String
    /// "Copy original", "Copy translation": the tooltip and VoiceOver name.
    let label: String

    @State private var copied = false
    @State private var resetTask: Task<Void, Never>?

    var body: some View {
        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
            copied = true
            resetTask?.cancel()
            resetTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                guard !Task.isCancelled else { return }
                copied = false
            }
        } label: {
            Image(systemName: copied ? "checkmark" : "doc.on.doc")
                .foregroundStyle(copied ? Color.accentText : .secondary)
                .frame(width: 16, height: 16)
        }
        .buttonStyle(.borderless)
        .help(label)
        .accessibilityLabel(copied ? "Copied" : label)
        .onDisappear { resetTask?.cancel() }
    }
}
