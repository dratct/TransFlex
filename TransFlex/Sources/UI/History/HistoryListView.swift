import SwiftUI

/// The History sidebar list, grouped by day, newest first.
struct HistoryListView: View {
    let entries: [HistoryEntry]
    @Binding var selectedEntryID: UUID?
    /// Called when the last row appears, to load the next page.
    var onReachEnd: () -> Void = {}

    var body: some View {
        List(selection: $selectedEntryID) {
            ForEach(HistoryDays.sections(entries), id: \.title) { section in
                Section(section.title) {
                    ForEach(section.entries) { entry in
                        HistoryRowView(entry: entry)
                            .tag(entry.id)
                            .onAppear {
                                if entry.id == entries.last?.id { onReachEnd() }
                            }
                    }
                }
            }
        }
        .listStyle(.sidebar)
    }
}

private struct HistoryRowView: View {
    let entry: HistoryEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(entry.inputText ?? "Image translation")
                .lineLimit(1)
            Text("\(entry.modelID) · \(entry.createdAt.formatted(date: .omitted, time: .shortened))")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.vertical, 2)
    }
}
