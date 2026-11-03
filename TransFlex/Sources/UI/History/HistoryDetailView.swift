import AppKit
import SwiftUI

/// One past translation, laid out like the popup's two halves.
struct HistoryDetailView: View {
    let entry: HistoryEntry?
    /// The entry's preset's current model, nil once that preset was deleted.
    var presetModelID: String?
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
                .padding(.horizontal, Spacing.xl)
            columns(entry)
        }
        .padding(.vertical, Spacing.xl)
        // A new entry starts with fresh copy buttons, not a lingering checkmark.
        .id(entry.id)
    }

    /// `TranslationColumns`, as in the popup: side by side from 720pt, stacked below.
    private func columns(_ entry: HistoryEntry) -> some View {
        GeometryReader { geo in
            Group {
                if let input = entry.inputText {
                    if geo.size.width >= ColumnLayout.sideBySideMinWidth {
                        let column = ((geo.size.width - 2 * Spacing.xl - ColumnLayout.gutter) / 2).rounded(.down)
                        HStack(spacing: 0) {
                            originalColumn(input)
                                .frame(width: column)
                            ColumnSeam(direction: .vertical)
                                .padding(.horizontal, ColumnLayout.gutter / 2)
                            translationColumn(entry.outputText)
                                .frame(width: column)
                        }
                    } else {
                        VStack(spacing: 0) {
                            originalColumn(input)
                                .frame(height: geo.size.height * ColumnLayout.stackedOriginalShare)
                            ColumnSeam(direction: .horizontal)
                                .padding(.vertical, ColumnLayout.gutter / 2)
                            translationColumn(entry.outputText)
                        }
                    }
                } else {
                    translationColumn(entry.outputText)
                }
            }
            .padding(.horizontal, Spacing.xl)
        }
    }

    private func originalColumn(_ text: String) -> some View {
        column(label: ColumnLabel(title: "Original", color: Color(nsColor: .tertiaryLabelColor)),
               copyLabel: "Copy original", text: text,
               font: ReadingType.original, lineSpacing: ReadingType.originalLineSpacing,
               color: Color(nsColor: .secondaryLabelColor))
    }

    private func translationColumn(_ text: String) -> some View {
        column(label: ColumnLabel(title: "Translation", color: .accentText),
               copyLabel: "Copy translation", text: text,
               font: ReadingType.translation, lineSpacing: ReadingType.translationLineSpacing,
               color: .primary)
    }

    /// The copy button sits beside the label, so a long text scrolls under it
    /// instead of pushing it out of reach.
    private func column(label: ColumnLabel, copyLabel: String, text: String,
                        font: Font, lineSpacing: CGFloat, color: Color) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            HStack {
                label
                Spacer(minLength: Spacing.s)
                CopyIconButton(text: text, label: copyLabel)
            }
            ScrollView {
                Text(text)
                    .font(font)
                    .lineSpacing(lineSpacing)
                    .foregroundStyle(color)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
        switch HistoryText.translateAgain(entry, presetModelID: presetModelID) {
        case .hidden:
            EmptyView()
        case .enabled:
            Button("Translate again") {
                AppCommands.translateAgain(text: entry.inputText ?? "", presetID: entry.presetID)
            }
        case .disabled(let reason):
            Button("Translate again") {}
                .disabled(true)
                .help(reason)
        }
    }
}
