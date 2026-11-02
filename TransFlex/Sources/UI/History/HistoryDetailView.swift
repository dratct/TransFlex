import AppKit
import SwiftUI

/// One past translation, laid out like the popup's two halves.
struct HistoryDetailView: View {
    let entry: HistoryEntry?
    let onDelete: (UUID) -> Void

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
        HStack(spacing: Spacing.s) {
            Text(entry.createdAt.formatted(date: .abbreviated, time: .shortened))
                .font(.headline)
            Text(meta(entry))
                .font(.callout)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .lineLimit(1)
            Spacer(minLength: Spacing.s)
            Button("Delete") { onDelete(entry.id) }
            Button("Copy") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(entry.outputText, forType: .string)
            }
            .buttonStyle(.borderedProminent)
        }
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

    private func meta(_ entry: HistoryEntry) -> String {
        var parts = [entry.modelID]
        if let ms = entry.durationMs {
            parts.append((Double(ms) / 1000).formatted(.number.precision(.fractionLength(1))) + " s")
        }
        if let tokens = entry.tokenCount { parts.append("\(tokens.formatted()) tokens") }
        if entry.hadImage { parts.append("image") }
        return "· " + parts.joined(separator: " · ")
    }
}
