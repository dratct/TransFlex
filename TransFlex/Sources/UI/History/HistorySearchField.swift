import SwiftUI

struct HistorySearchField: View {
    @Binding var query: String
    @State private var debounceTask: Task<Void, Never>?

    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search history...", text: $query)
                .textFieldStyle(.plain)
                .onSubmit { submitSearch() }
                .onChange(of: query) { _ in
                    debounceTask?.cancel()
                    debounceTask = Task {
                        try? await Task.sleep(nanoseconds: 200_000_000)
                        guard !Task.isCancelled else { return }
                        submitSearch()
                    }
                }
            if !query.isEmpty {
                Button {
                    query = ""
                    submitSearch()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
        }
        .padding(6)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func submitSearch() {
        // Parent view observes query binding and reacts
    }
}
