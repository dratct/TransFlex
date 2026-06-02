import SwiftUI

@MainActor
struct GeneralTab: View {
    @State private var policy: PopupResetPolicy = PopupResetPolicyStore.load()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                heroHeader

                SettingsSection(
                    "Popup Behavior",
                    footer: "Controls when the popup discards the previous translation, attached image, and result on reopen."
                ) {
                    SettingsRow(
                        icon: "clock.arrow.circlepath",
                        iconTint: .brandAccent,
                        label: "Clear previous translation",
                        caption: "Reset popup state after the popup has been hidden for this long."
                    ) {
                        Picker("", selection: Binding(
                            get: { policy.rawMinutes },
                            set: { newRaw in
                                let next = PopupResetPolicy(rawMinutes: newRaw)
                                policy = next
                                PopupResetPolicyStore.save(next)
                            }
                        )) {
                            ForEach(PopupResetPolicy.presetOptions, id: \.rawMinutes) { option in
                                Text(option.displayName).tag(option.rawMinutes)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 160)
                    }
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 22)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var heroHeader: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.brandAccent.gradient)
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                )
            VStack(alignment: .leading, spacing: 2) {
                Text("General")
                    .font(.system(size: 16, weight: .semibold))
                Text("App-wide preferences")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
}
