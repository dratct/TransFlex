import SwiftUI

@MainActor
struct GeneralTab: View {
    @State private var policy: PopupResetPolicy = PopupResetPolicyStore.load()
    @StateObject private var launchManager = LaunchAtLoginManager.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                heroHeader

                SettingsSection(
                    "Startup Options",
                    footer: "Automatically starts the application when you log into your Mac."
                ) {
                    SettingsRow(
                        icon: "play.square.stack",
                        iconTint: .brandAccent,
                        label: "Start at login",
                        caption: "Launch TransFlex when you start your session."
                    ) {
                        Toggle("", isOn: Binding(
                            get: { launchManager.isEnabled },
                            set: { launchManager.setEnabled($0) }
                        ))
                        .toggleStyle(.switch)
                        .labelsHidden()
                    }

                    if launchManager.needsApproval {
                        SettingsRowDivider()
                        approvalRequiredRow
                    }
                }

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
        .onAppear {
            launchManager.refreshStatus()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            launchManager.refreshStatus()
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

    private var approvalRequiredRow: some View {
        SettingsRow(
            icon: "exclamationmark.triangle.fill",
            iconTint: .orange,
            label: "Needs approval",
            caption: "Allow TransFlex in Login Items to finish enabling startup."
        ) {
            Button {
                launchManager.openApprovalSettings()
            } label: {
                Label("Open Login Items", systemImage: "arrow.up.forward.app")
            }
            .controlSize(.small)
        }
    }
}
