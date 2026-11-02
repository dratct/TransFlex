import KeyboardShortcuts
import SwiftUI

struct HistorySplitView: View {
    @ObservedObject var store: HistoryStore

    @State private var selectedEntryID: UUID?
    @State private var entries: [HistoryEntry] = []
    @State private var hasLoaded = false
    @State private var searchQuery = ""
    @State private var searchResults: [HistoryEntry]?
    @State private var showExportSheet = false
    @State private var showDeleteConfirm = false

    private let pageSize = 50

    var body: some View {
        content
            .frame(minWidth: 560, minHeight: 340)
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    // Searching never changes these: they act on the whole history.
                    Button("Export…") { showExportSheet = true }
                        .disabled(!hasHistory)
                    if hasHistory {
                        Button("Delete All…") { showDeleteConfirm = true }
                    }
                }
            }
            .sheet(isPresented: $showExportSheet) {
                HistoryExportSheet(store: store, isPresented: $showExportSheet)
            }
            .confirmationDialog("Delete all history?", isPresented: $showDeleteConfirm) {
                Button("Delete All", role: .destructive) { deleteAll() }
            } message: {
                Text("Every saved translation is removed. This can’t be undone.")
            }
            .onAppear(perform: loadFirstPage)
    }

    @ViewBuilder
    private var content: some View {
        if hasLoaded && !hasHistory {
            // No sidebar and no search when there is nothing to search.
            EmptyState(
                symbol: "clock.arrow.circlepath",
                title: "No translations yet",
                message: emptyMessage
            )
        } else {
            NavigationSplitView {
                VStack(spacing: 0) {
                    HistorySearchField(query: $searchQuery)
                        .padding(Spacing.s)
                    HistoryListView(
                        entries: searchResults ?? entries,
                        selectedEntryID: $selectedEntryID,
                        onReachEnd: { if searchResults == nil { loadMore() } }
                    )
                }
                .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 360)
                .onChange(of: searchQuery) { performSearch($0) }
            } detail: {
                detail
            }
        }
    }

    @ViewBuilder
    private var detail: some View {
        if let results = searchResults, results.isEmpty {
            EmptyState(
                symbol: "magnifyingglass",
                title: "No results for “\(searchQuery.trimmingCharacters(in: .whitespaces))”",
                message: "Search looks in both the text and its translation."
            )
        } else {
            HistoryDetailView(entry: currentEntry, onDelete: deleteEntry)
        }
    }

    private var hasHistory: Bool { !entries.isEmpty }

    private var emptyMessage: String {
        let base = "Everything you translate shows up here, newest first."
        guard let shortcut = KeyboardShortcuts.getShortcut(for: .openPopup) else { return base }
        return base + " Press \(shortcut.description) to start."
    }

    private var currentEntry: HistoryEntry? {
        (searchResults ?? entries).first { $0.id == selectedEntryID }
    }

    private func loadFirstPage() {
        entries = (try? store.fetchPage(offset: 0, limit: pageSize)) ?? []
        hasLoaded = true
    }

    private func loadMore() {
        guard let next = try? store.fetchPage(offset: entries.count, limit: pageSize), !next.isEmpty else { return }
        entries.append(contentsOf: next)
    }

    private func performSearch(_ query: String) {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            searchResults = nil
            return
        }
        searchResults = (try? store.search(query: query)) ?? []
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
            searchQuery = ""
            searchResults = nil
            entries = []
            selectedEntryID = nil
        } catch {}
    }
}
