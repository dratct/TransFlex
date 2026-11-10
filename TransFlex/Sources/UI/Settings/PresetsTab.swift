import SwiftUI

@MainActor
struct PresetsTab: View {
    @EnvironmentObject var presetStore: PresetStore
    let providersStore: ProvidersStore
    @State private var selectedPresetID: UUID?
    @State private var errorMessage: String?
    @State private var confirmingDelete = false

    var body: some View {
        HSplitView {
            presetList
                .frame(minWidth: 180, maxWidth: 220)

            editorPane
                .frame(minWidth: 340)
        }
        .onAppear {
            if selectedPreset == nil {
                selectedPresetID = presetStore.presets.first?.id
            }
        }
    }

    private var presetList: some View {
        VStack(spacing: 0) {
            List(selection: $selectedPresetID) {
                ForEach(presetStore.presets) { preset in
                    PresetListRow(preset: preset).tag(Optional(preset.id))
                }
            }
            .listStyle(.sidebar)

            Divider()

            HStack(spacing: Spacing.xs) {
                Button(action: addPreset) {
                    Image(systemName: "plus").frame(width: 20, height: 20)
                }
                .help("Add Preset")
                .accessibilityLabel("Add Preset")
                Button { confirmingDelete = true } label: {
                    Image(systemName: "minus").frame(width: 20, height: 20)
                }
                .disabled(selectedPreset == nil || !presetStore.canDelete)
                .help(presetStore.canDelete ? "Delete Preset" : "Keep at least one preset")
                .accessibilityLabel("Delete Preset")
                Spacer()
            }
            .buttonStyle(.borderless)
            .padding(Spacing.s)
            .confirmationDialog(
                "Delete ‘\(selectedPreset?.name ?? "")’?",
                isPresented: $confirmingDelete
            ) {
                Button("Delete", role: .destructive) { deleteSelected() }
            } message: {
                Text("Its shortcuts are removed too.")
            }

            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding([.horizontal, .bottom], Spacing.s)
            }
        }
    }

    @ViewBuilder
    private var editorPane: some View {
        if let preset = selectedPreset {
            PresetEditor(presetStore: presetStore, providersStore: providersStore, preset: preset)
                .id(preset.id)
        } else {
            EmptyState(symbol: "list.bullet.rectangle", title: "No preset selected",
                       message: "Pick a preset on the left, or add one with +.")
        }
    }

    private var selectedPreset: Preset? {
        presetStore.presets.first { $0.id == selectedPresetID }
    }

    private func addPreset() {
        let keychain = KeychainStore()
        let start = PresetStore.newPresetProvider(
            keyed: Set(DefaultPresets.keyedProviders.filter { keychain.exists("provider.\($0).apiKey") })
        )
        let newPreset = Preset(
            name: "New Preset",
            providerID: start.providerID,
            modelID: start.model,
            systemPrompt: "Translate the following text."
        )

        do {
            try presetStore.add(newPreset)
            selectedPresetID = newPreset.id
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteSelected() {
        guard let id = selectedPresetID else { return }
        do {
            try presetStore.delete(id: id)
            selectedPresetID = presetStore.presets.first?.id
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
