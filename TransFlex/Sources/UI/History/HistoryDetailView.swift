import SwiftUI

struct HistoryDetailView: View {
    let entry: HistoryEntry?
    let onRetranslate: ((HistoryEntry) -> Void)?
    let onDelete: ((UUID) -> Void)?

    var body: some View {
        Group {
            if let entry {
                detailContent(entry)
            } else {
                Text("Select a translation to view details")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func detailContent(_ entry: HistoryEntry) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                metaSection(entry)

                if let input = entry.inputText {
                    section(title: "Input") {
                        Text(input).textSelection(.enabled)
                    }
                }

                section(title: "Output") {
                    Text(entry.outputText).textSelection(.enabled)
                }

                HStack(spacing: 12) {
                    Button("Copy Output") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(entry.outputText, forType: .string)
                    }
                    if let onRetranslate {
                        Button("Re-translate") { onRetranslate(entry) }
                    }
                    Button("Delete", role: .destructive) { onDelete?(entry.id) }
                }
                .padding(.top, 8)
            }
            .padding()
        }
    }

    @ViewBuilder
    private func metaSection(_ entry: HistoryEntry) -> some View {
        HStack {
            Label(entry.providerID, systemImage: "server.rack")
            Spacer()
            if let tokens = entry.tokenCount {
                Label("\(tokens) tokens", systemImage: "number")
            }
            if let ms = entry.durationMs {
                Label("\(ms) ms", systemImage: "clock")
            }
            if entry.hadImage {
                Label("Image", systemImage: "photo")
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private func section<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }
}
