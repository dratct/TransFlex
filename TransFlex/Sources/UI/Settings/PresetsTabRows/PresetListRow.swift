import SwiftUI

@MainActor
struct PresetListRow: View {
    let preset: Preset
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(preset.name)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)

                Text(providerSubtitle)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private var providerSubtitle: String {
        let id = preset.providerID
        if id.hasPrefix("openai-compatible:") {
            let instanceId = String(id.dropFirst("openai-compatible:".count))
            if let displayName = ProviderRegistry.shared.compatInstance(instanceId)?.displayName,
               !displayName.isEmpty {
                return displayName
            }
            return "Custom Endpoint"
        }
        return id
    }
}
