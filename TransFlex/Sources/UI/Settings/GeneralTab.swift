import KeyboardShortcuts
import SwiftUI

@MainActor
struct GeneralTab: View {
    @State private var policy: PopupResetPolicy = PopupResetPolicyStore.load()
    @StateObject private var launchManager = LaunchAtLoginManager.shared

    var body: some View {
        SettingsForm {
            Section("Popup") {
                Picker(selection: Binding(
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
                } label: {
                    SettingsLabel(
                        "Keep last translation",
                        caption: "When you reopen the popup within this time, your text and result are still there."
                    )
                }

                SettingsRow("Open shortcut", caption: "Shows the popup from any app.") {
                    KeyboardShortcuts.Recorder(for: .openPopup)
                }
            }

            Section("Startup") {
                Toggle(isOn: Binding(
                    get: { launchManager.isEnabled },
                    set: { launchManager.setEnabled($0) }
                )) {
                    SettingsLabel("Open at login")
                }
                .toggleStyle(.switch)

                if launchManager.needsApproval {
                    SettingsRow(
                        "Needs approval",
                        caption: "Allow \(AppIdentity.current.displayName) in Login Items to finish turning this on."
                    ) {
                        Button("Open Login Items…") { launchManager.openApprovalSettings() }
                    }
                }
            }
        }
        .onAppear { launchManager.refreshStatus() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            launchManager.refreshStatus()
        }
    }
}
