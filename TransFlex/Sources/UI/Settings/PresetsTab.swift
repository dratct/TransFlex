import SwiftUI

@MainActor
struct PresetsTab: View {
    @EnvironmentObject var presetStore: PresetStore
    let providersStore: ProvidersStore
    @State private var selectedPresetID: UUID?
    @State private var errorMessage: String?

    var body: some View {
        HSplitView {
            presetList
                .frame(minWidth: 180, maxWidth: 220)

            editorPane
                .frame(minWidth: 340)
        }
    }

    private var presetList: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(presetStore.presets) { preset in
                        PresetListRow(preset: preset, isSelected: preset.id == selectedPresetID)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedPresetID = preset.id
                            }
                    }
                }
                .padding(.vertical, 6)
            }

            Divider()

            HStack {
                Button {
                    addPreset()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)

                Spacer()

                Button {
                    deleteSelected()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .disabled(selectedPreset == nil)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)

            if let error = errorMessage {
                Text(error)
                    .font(.system(size: 10))
                    .foregroundStyle(.red)
                    .padding(.horizontal, 8)
                    .padding(.bottom, 4)
            }
        }
    }

    @ViewBuilder
    private var editorPane: some View {
        if let preset = selectedPreset {
            PresetEditor(presetStore: presetStore, providersStore: providersStore, preset: preset)
                .id(preset.id)
        } else {
            VStack {
                Text("Select a preset to edit")
                    .font(.system(size: 13))
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var selectedPreset: Preset? {
        presetStore.presets.first { $0.id == selectedPresetID }
    }

    private func addPreset() {
        let newPreset = Preset(
            name: "New Preset",
            providerID: "openai",
            modelID: "gpt-4o-mini",
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
