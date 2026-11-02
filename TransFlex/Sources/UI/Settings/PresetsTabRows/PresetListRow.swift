import KeyboardShortcuts
import SwiftUI

/// A preset in the Presets sidebar: its name, then the model and the
/// Translate Selection shortcut when one is set.
@MainActor
struct PresetListRow: View {
    let preset: Preset

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(preset.name.isEmpty ? "Untitled Preset" : preset.name)
                .lineLimit(1)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.vertical, 2)
    }

    private var subtitle: String {
        let model = preset.modelID.isEmpty ? ProviderRegistry.shared.displayName(for: preset.providerID) : preset.modelID
        guard let shortcut = KeyboardShortcuts.getShortcut(for: .presetQuickPopup(preset.id)) else { return model }
        return "\(model) · \(shortcut.description)"
    }
}
