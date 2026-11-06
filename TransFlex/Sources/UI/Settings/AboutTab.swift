import SwiftUI

enum AboutInfo {
    static var appName: String { AppIdentity.current.displayName }
    static let repositoryURL = URL(string: "https://github.com/dratct/transflex")!
    static let licenseURL = URL(string: "https://github.com/dratct/transflex/blob/main/LICENSE")!
    static let donateURL = URL(string: "https://paypal.me/truongtc1109")!
    static let licenseName = "MIT License"
    static let repositoryDisplayName = "github.com/dratct/transflex"
    static let donateDisplayName = "paypal.me/truongtc1109"

    static func versionText(version: String?, build: String?) -> String {
        guard let version, !version.isEmpty else {
            return "Version unavailable"
        }
        return "Version \(version)"
    }
}

@MainActor
struct AboutTab: View {
    var updater: AppUpdater?

    static func showsUpdates(updater: AppUpdater?) -> Bool {
        updater != nil
    }

    var body: some View {
        SettingsForm {
            Section {
                VStack(spacing: Spacing.s) {
                    // The brand appears on the app icon only (DESIGN.md › Colors).
                    Image("AppLogo")
                        .resizable()
                        .interpolation(.high)
                        .frame(width: 64, height: 64)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.window, style: .continuous))
                        .accessibilityHidden(true)
                    Text(AboutInfo.appName)
                        .font(.title3.weight(.semibold))
                    Text("Translate anything on your Mac with the AI you choose.")
                        .foregroundStyle(.secondary)
                    Text("\(versionText) · \(AboutInfo.licenseName)")
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.m)
            }

            if Self.showsUpdates(updater: updater), let updater {
                UpdatesSection(updater: updater)
            }

            Section {
                SettingsRow("Source code", caption: AboutInfo.repositoryDisplayName) {
                    Link("Open GitHub", destination: AboutInfo.repositoryURL)
                }
                SettingsRow("License", caption: AboutInfo.licenseName) {
                    Link("View License", destination: AboutInfo.licenseURL)
                }
                SettingsRow("Support the project", caption: AboutInfo.donateDisplayName) {
                    Link("Donate", destination: AboutInfo.donateURL)
                }
            }
        }
    }

    private var versionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        return AboutInfo.versionText(version: version, build: build)
    }
}

@MainActor
private struct UpdatesSection: View {
    @ObservedObject var updater: AppUpdater

    var body: some View {
        Section {
            Toggle(isOn: Binding(
                get: { updater.automaticallyChecksForUpdates },
                set: { updater.automaticallyChecksForUpdates = $0 }
            )) {
                SettingsLabel("Automatically check for updates")
            }
            .toggleStyle(.switch)
            SettingsRow(UpdateMenu.title(updateFound: updater.updateFound)) {
                Button("Check Now") { updater.checkForUpdates() }
                    .disabled(!updater.canCheckForUpdates)
            }
        }
    }
}
