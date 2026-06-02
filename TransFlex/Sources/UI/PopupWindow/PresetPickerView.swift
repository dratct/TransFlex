import SwiftUI

@MainActor
struct PresetPickerView: View {
    @ObservedObject var viewModel: PopupViewModel

    var body: some View {
        Menu {
            ForEach(viewModel.presets) { preset in
                Button {
                    viewModel.switchPreset(preset.id)
                } label: {
                    HStack {
                        Text(preset.name)
                        if viewModel.selectedPresetID == preset.id {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }

            Divider()

            Button("Manage Presets...") {
                AppCommands.openSettings(tab: .presets)
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "globe")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text(viewModel.selectedPreset?.name ?? "Select Preset")
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                    .foregroundStyle(.primary)
                // macOS-standard popup indicator (same as NSPopUpButton); reads
                // unambiguously as "this is a picker, click to open".
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule(style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.55))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(Color(nsColor: .separatorColor).opacity(0.5), lineWidth: 0.5)
            )
            .contentShape(Capsule())
        }
        // `.menuStyle(.borderlessButton)` on macOS strips a custom HStack label
        // down to title-only — it dropped our globe + chevron + capsule. Use
        // `.button` style with `.plain` button style instead so the label is
        // rendered exactly as written.
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
    }
}
