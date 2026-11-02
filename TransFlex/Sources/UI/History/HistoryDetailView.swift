import AppKit
import SwiftUI

/// One past translation, laid out like the popup's two halves.
struct HistoryDetailView: View {
    let entry: HistoryEntry?
    /// False once the entry's preset was deleted: there is nothing to translate it with.
    var presetExists = true
    let onDelete: (UUID) -> Void

    @State private var confirmingDelete = false

    var body: some View {
        if let entry {
            detailContent(entry)
        } else {
            Text("Select a translation to see it here.")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func detailContent(_ entry: HistoryEntry) -> some View {
        VStack(alignment: .leading, spacing: Spacing.l) {
            header(entry)
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.xl) {
                    if let input = entry.inputText {
                        half(label: ColumnLabel(title: "Original", color: Color(nsColor: .tertiaryLabelColor)),
                             text: input, font: ReadingType.original, lineSpacing: ReadingType.originalLineSpacing)
                    }
                    half(label: ColumnLabel(title: "Translation", color: .accentText),
                         text: entry.outputText, font: ReadingType.translation, lineSpacing: ReadingType.translationLineSpacing)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(Spacing.xl)
    }

    private func header(_ entry: HistoryEntry) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.s) {
                Text(HistoryText.when(entry.createdAt))
                    .font(.headline)
                Spacer(minLength: Spacing.s)
                actions(entry)
            }
            // Full width below the buttons, so the cost is never the part cut off.
            Text(HistoryText.detailMeta(entry))
                .font(.callout)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .textSelection(.enabled)
        }
    }

    @ViewBuilder
    private func actions(_ entry: HistoryEntry) -> some View {
        Button("Delete…") { confirmingDelete = true }
            .confirmationDialog("Delete this translation?", isPresented: $confirmingDelete) {
                Button("Delete", role: .destructive) { onDelete(entry.id) }
            } message: {
                Text("It is removed from History. This can’t be undone.")
            }
        if let input = entry.inputText {
            Button("Translate again") { AppCommands.translateAgain(text: input, presetID: entry.presetID) }
                .disabled(!presetExists)
                .help(presetExists ? "" : "This preset was deleted.")
        }
        Button("Copy") {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(entry.outputText, forType: .string)
        }
        .buttonStyle(.borderedProminent)
    }

    private func half(label: ColumnLabel, text: String, font: Font, lineSpacing: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            label
            Text(text)
                .font(font)
                .lineSpacing(lineSpacing)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
