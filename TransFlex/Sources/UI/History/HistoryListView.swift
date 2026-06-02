import SwiftUI

struct HistoryListView: View {
    @ObservedObject var store: HistoryStore
    @Binding var entries: [HistoryEntry]
    @Binding var selectedEntryID: UUID?
    @State private var offset = 0
    @State private var isLoading = false
    private let pageSize = 50

    var body: some View {
        List(selection: $selectedEntryID) {
            ForEach(entries) { entry in
                HistoryRowView(entry: entry)
                    .tag(entry.id)
                    .onAppear {
                        if entry.id == entries.last?.id {
                            loadMore()
                        }
                    }
            }
        }
        .listStyle(.sidebar)
        .onAppear { loadInitial() }
    }

    private func loadInitial() {
        guard entries.isEmpty else { return }
        offset = 0
        do {
            entries = try store.fetchPage(offset: 0, limit: pageSize)
            offset = entries.count
        } catch {
            entries = []
        }
    }

    private func loadMore() {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let next = try store.fetchPage(offset: offset, limit: pageSize)
            guard !next.isEmpty else { return }
            entries.append(contentsOf: next)
            offset = entries.count
        } catch {}
    }
}

private struct HistoryRowView: View {
    let entry: HistoryEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(entry.inputText.flatMap { Self.truncate($0, length: 60) } ?? "Image translation")
                .lineLimit(1)
                .font(.body)
            Text(Self.truncate(entry.outputText, length: 60))
                .lineLimit(1)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(entry.createdAt, style: .date)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
    }

    private static func truncate(_ text: String, length: Int) -> String {
        guard text.count > length else { return text }
        return String(text.prefix(length)) + "..."
    }
}
