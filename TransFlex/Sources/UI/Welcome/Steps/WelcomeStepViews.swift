import KeyboardShortcuts
import SwiftUI

struct WelcomeProviderView: View {
    @ObservedObject var model: ProviderSetupModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            WelcomeHeading(title: "Connect an AI provider",
                           lead: "\(AppIdentity.current.displayName) uses your own key. It stays in your Keychain.")
            ProviderSetupForm(model: model)
        }
    }
}

struct WelcomeShortcutView: View {
    @Binding var keys: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            WelcomeHeading(title: "Choose your shortcut",
                           lead: "Press it in any app to open \(AppIdentity.current.displayName).")
            Keycaps(keys: keys)
            HStack(spacing: Spacing.s) {
                Text("Change it:")
                    .foregroundStyle(.secondary)
                KeyboardShortcuts.Recorder(for: .openPopup) { keys = $0.map(ShortcutKeys.symbols(for:)) ?? [] }
                    .shortcutValidation(ShortcutConflicts.validator(for: .openPopup) { AppDelegate.shared?.presetStore.presets ?? [] })
            }
            .padding(.top, Spacing.xl)
        }
    }
}

struct WelcomeDoneView: View {
    let keys: [String]
    let keySkipped: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            let heading = WelcomeStep.doneHeading(keySkipped: keySkipped)
            WelcomeHeading(title: heading.title, lead: heading.lead)
            Keycaps(keys: keys)
            Label {
                Text("Look for the icon in the menu bar.")
            } icon: {
                Image("MenuBarIcon")
                    .resizable()
                    .renderingMode(.template)
                    .scaledToFit()
                    .frame(width: 14, height: 14)
            }
            .foregroundStyle(.secondary)
            .padding(.top, Spacing.xl)
        }
    }
}
