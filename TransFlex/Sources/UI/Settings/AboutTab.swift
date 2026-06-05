import SwiftUI

enum AboutInfo {
    static let appName = "TransFlex"
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
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                heroHeader

                SettingsSection("Project") {
                    SettingsRow(
                        icon: "chevron.left.forwardslash.chevron.right",
                        iconTint: .blue,
                        label: "GitHub Repository",
                        caption: AboutInfo.repositoryDisplayName
                    ) {
                        externalLinkButton("Open", systemImage: "arrow.up.right", url: AboutInfo.repositoryURL)
                    }

                    SettingsRowDivider()

                    SettingsRow(
                        icon: "doc.text",
                        iconTint: .green,
                        label: "License",
                        caption: AboutInfo.licenseName
                    ) {
                        externalLinkButton("View", systemImage: "doc.text.magnifyingglass", url: AboutInfo.licenseURL)
                    }
                }

                SettingsSection(
                    "Support",
                    footer: "Contributions help keep TransFlex polished and useful."
                ) {
                    SettingsRow(
                        icon: "heart.fill",
                        iconTint: .pink,
                        label: "Donate",
                        caption: AboutInfo.donateDisplayName
                    ) {
                        externalLinkButton("PayPal", systemImage: "arrow.up.right", url: AboutInfo.donateURL)
                    }
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 22)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var heroHeader: some View {
        HStack(spacing: 14) {
            Image("AppLogo")
                .resizable()
                .interpolation(.high)
                .frame(width: 58, height: 58)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .shadow(color: Color.brandAccent.opacity(0.18), radius: 10, y: 4)

            VStack(alignment: .leading, spacing: 3) {
                Text(AboutInfo.appName)
                    .font(.system(size: 18, weight: .semibold))
                Text(versionText)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Text("AI translation companion")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }

            Spacer()
        }
    }

    private var versionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        return AboutInfo.versionText(version: version, build: build)
    }

    private func externalLinkButton(_ title: String, systemImage: String, url: URL) -> some View {
        Link(destination: url) {
            Label(title, systemImage: systemImage)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }
}
