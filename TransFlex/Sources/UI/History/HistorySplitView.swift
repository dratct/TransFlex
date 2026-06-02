import SwiftUI

struct HistorySplitView: View {
    @ObservedObject var store: HistoryStore

    @State private var selectedEntryID: UUID?
    @State private var entries: [HistoryEntry] = []
    @State private var searchQuery = ""
    @State private var searchResults: [HistoryEntry]?
    @State private var showExportSheet = false
    @State private var showDeleteConfirm = false

    var body: some View {
        NavigationSplitView {
            listPane
        } detail: {
            HistoryDetailView(
                entry: currentEntry,
                onRetranslate: nil,
                onDelete: { id in deleteEntry(id) }
            )
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                ToolbarButton(title: "Export", systemImage: "square.and.arrow.up") {
                    showExportSheet = true
                }
                ToolbarButton(title: "Delete All", systemImage: "trash") {
                    showDeleteConfirm = true
                }
            }
        }
        .sheet(isPresented: $showExportSheet) {
            HistoryExportSheet(store: store, isPresented: $showExportSheet)
        }
        .alert("Delete All History?", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete All", role: .destructive) { deleteAll() }
        }
    }

    @ViewBuilder
    private var listPane: some View {
        VStack(spacing: 0) {
            HistorySearchField(query: $searchQuery)
                .padding(8)
            if let results = searchResults {
                List(results, selection: $selectedEntryID) { entry in
                    HistoryRowAdapter(entry: entry)
                        .tag(entry.id)
                }
                .listStyle(.sidebar)
            } else {
                HistoryListView(store: store, entries: $entries, selectedEntryID: $selectedEntryID)
            }
        }
        .onChange(of: searchQuery) { _ in
            performSearch(searchQuery)
        }
    }

    private var currentEntry: HistoryEntry? {
        if let results = searchResults {
            return results.first { $0.id == selectedEntryID }
        }
        return entries.first { $0.id == selectedEntryID }
    }

    private func performSearch(_ query: String) {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            searchResults = nil
            return
        }
        do {
            searchResults = try store.search(query: query)
        } catch {
            searchResults = nil
        }
    }

    private func deleteEntry(_ id: UUID) {
        do {
            try store.delete(id: id)
            searchResults?.removeAll { $0.id == id }
            entries.removeAll { $0.id == id }
            if selectedEntryID == id { selectedEntryID = nil }
        } catch {}
    }

    private func deleteAll() {
        do {
            try store.deleteAll()
            searchResults = nil
            entries = []
            selectedEntryID = nil
        } catch {}
    }
}

private struct HistoryRowAdapter: View {
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

private struct ToolbarButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
        }
    }
}
