import SwiftUI

@MainActor
struct OpenAICompatList: View {
    @ObservedObject var store: ProvidersStore
    @State private var editingInstance: OpenAICompatInstance?
    @State private var isAdding = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("OpenAI-Compatible Endpoints")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Button {
                    isAdding = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
            }

            if store.config.openAICompatInstances.isEmpty {
                Text("No custom endpoints configured.")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 12)
            } else {
                ForEach(store.config.openAICompatInstances, id: \.instanceId) { instance in
                    compatRow(instance)
                }
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
            }
        }
        .sheet(isPresented: $isAdding) {
            OpenAICompatEditor(store: store, editing: nil)
        }
        .sheet(item: $editingInstance) { instance in
            OpenAICompatEditor(store: store, editing: instance)
        }
    }

    private func compatRow(_ instance: OpenAICompatInstance) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "externaldrive.connected.to.line.below")
                .foregroundStyle(.secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(instance.displayName)
                    .font(.system(size: 12, weight: .medium))
                Text(instance.baseURL.host ?? instance.baseURL.absoluteString)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }

            Spacer()

            let hasKey = store.hasCompatAPIKey(for: instance.instanceId)
            Image(systemName: hasKey ? "checkmark.circle.fill" : "xmark.circle")
                .foregroundStyle(hasKey ? .green : .secondary)
                .font(.system(size: 12))

            Button {
                editingInstance = instance
            } label: {
                Image(systemName: "pencil")
                    .font(.system(size: 11))
            }
            .buttonStyle(.plain)

            Button(role: .destructive) {
                do {
                    try store.deleteCompatInstance(instance.instanceId)
                    errorMessage = nil
                } catch {
                    errorMessage = error.localizedDescription
                }
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 11))
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}
