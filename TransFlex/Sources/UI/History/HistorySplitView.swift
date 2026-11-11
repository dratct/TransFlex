import KeyboardShortcuts
import SwiftUI

struct HistorySplitView: View {
    @ObservedObject var store: HistoryStore
    @ObservedObject var presets: PresetStore
    /// The window the export save panel attaches to.
    var hostWindow: () -> NSWindow? = { NSApp.keyWindow }

    @State private var selectedEntryID: UUID?
    @State private var entries: [HistoryEntry] = []
    @State private var hasLoaded = false
    @State private var searchQuery = ""
    @State private var searchResults: [HistoryEntry]?
    @State private var showExportSheet = false
    @State private var pendingExport: ExportFormat?
    @State private var exportError: String?
    @State private var showDeleteConfirm = false
    @State private var todayLabel: String?
    @State private var searchFocusRequest = 0
    @FocusState private var listFocused: Bool

    private let pageSize = 50
    private let searchPageSize = 100

    var body: some View {
        content
            .frame(minWidth: 560, minHeight: 340)
            // The day's total is read-only, so it sits under the title rather
            // than in a toolbar item, which macOS draws as a button capsule.
            .navigationSubtitle(todayLabel ?? "")
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
            .sheet(isPresented: $showExportSheet, onDismiss: startPendingExport) {
                HistoryExportSheet(isPresented: $showExportSheet) { pendingExport = $0 }
            }
            .alert(
                "Couldn’t export history",
                isPresented: Binding(get: { exportError != nil }, set: { if !$0 { exportError = nil } })
            ) {
                Button("OK") {}
            } message: {
                Text(exportError ?? "")
            }
            .confirmationDialog("Delete all history?", isPresented: $showDeleteConfirm) {
                Button("Delete All", role: .destructive) { deleteAll() }
            } message: {
                Text("Every saved translation is removed. This can’t be undone.")
            }
            .onAppear(perform: loadFirstPage)
            .onReceive(NotificationCenter.default.publisher(for: .historyDidChange, object: store)) { _ in
                reloadAfterInsert()
            }
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
                    HistorySearchField(
                        query: $searchQuery,
                        focusRequest: searchFocusRequest,
                        onMoveDown: { listFocused = true }
                    )
                    .padding(Spacing.s)
                    HistoryListView(
                        entries: searchResults ?? entries,
                        selectedEntryID: $selectedEntryID,
                        presetName: presetName,
                        onReachEnd: { searchResults == nil ? loadMore() : loadMoreResults() }
                    )
                    .focused($listFocused)
                }
                .background {
                    Button("Find") { searchFocusRequest += 1 }
                        .keyboardShortcut("f")
                        .opacity(0)
                        .accessibilityHidden(true)
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
            HistoryDetailView(
                entry: currentEntry,
                presetModelID: currentEntry.flatMap { entry in presets.presets.first { $0.id == entry.presetID }?.modelID },
                onDelete: deleteEntry
            )
                .id(currentEntry?.id)
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

    private func presetName(_ id: UUID) -> String? {
        presets.presets.first { $0.id == id }?.name
    }

    private func loadFirstPage() {
        entries = (try? store.fetchPage(offset: 0, limit: pageSize)) ?? []
        hasLoaded = true
        selectedEntryID = entries.first?.id
        // ↑/↓ browse at once; otherwise the first key view is a detail button.
        listFocused = true
        refreshToday()
    }

    /// Puts a new entry at the top of the list, and of the results when it matches the
    /// search being typed, without losing the selection or how far the list was scrolled.
    private func reloadAfterInsert() {
        entries = (try? store.fetchPage(offset: 0, limit: max(pageSize, entries.count + 1))) ?? entries
        hasLoaded = true
        if let shown = searchResults {
            searchResults = (try? store.search(query: searchQuery, limit: max(searchPageSize, shown.count + 1))) ?? shown
        }
        if selectedEntryID == nil { selectedEntryID = (searchResults ?? entries).first?.id }
        refreshToday()
    }

    private func refreshToday() {
        let today = try? store.todayCost(now: Date(), calendar: .current)
        todayLabel = today.flatMap { HistoryText.today(total: $0.total, unpriced: $0.unpriced) }
    }

    private func loadMore() {
        guard let next = try? store.fetchPage(offset: entries.count, limit: pageSize), !next.isEmpty else { return }
        entries.append(contentsOf: next)
    }

    private func performSearch(_ query: String) {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            searchResults = nil
            selectedEntryID = entries.first?.id
            return
        }
        searchResults = (try? store.search(query: query, limit: searchPageSize)) ?? []
        selectedEntryID = searchResults?.first?.id
    }

    private func loadMoreResults() {
        guard let shown = searchResults,
              let next = try? store.search(query: searchQuery, offset: shown.count, limit: searchPageSize),
              !next.isEmpty else { return }
        searchResults?.append(contentsOf: next)
    }

    /// Runs after the format sheet has gone, so the save panel opens on the History window
    /// with no other sheet in the way.
    private func startPendingExport() {
        guard let format = pendingExport else { return }
        pendingExport = nil
        do {
            let all = try store.allEntries()
            guard let window = hostWindow() else {
                exportError = "The History window wasn’t found. Try Export… again."
                return
            }
            HistoryExporter.export(entries: all, as: format, from: window) { error in
                exportError = error.localizedDescription
            }
        } catch {
            exportError = error.localizedDescription
        }
    }

    private func deleteEntry(_ id: UUID) {
        let shown = searchResults ?? entries
        let next = shown.firstIndex { $0.id == id }.flatMap { index in
            shown.indices.contains(index + 1) ? shown[index + 1].id : (index > 0 ? shown[index - 1].id : nil)
        }
        do {
            try store.delete(id: id)
            searchResults?.removeAll { $0.id == id }
            entries.removeAll { $0.id == id }
            if selectedEntryID == id { selectedEntryID = next }
            refreshToday()
        } catch {}
    }

    private func deleteAll() {
        do {
            try store.deleteAll()
            searchQuery = ""
            searchResults = nil
            entries = []
            selectedEntryID = nil
            todayLabel = nil
        } catch {}
    }
}
