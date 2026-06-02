import SwiftUI

/// Shared primitives for Settings tabs.
/// Mimics macOS Ventura/Sonoma System Settings: section header above a rounded
/// card, rows separated by hairline dividers, leading colored-square icons.

@MainActor
struct SettingsSection<Content: View>: View {
    let title: String?
    let footer: String?
    @ViewBuilder var content: () -> Content

    init(_ title: String? = nil, footer: String? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.footer = footer
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let title {
                Text(title.uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .tracking(0.6)
                    .padding(.leading, 4)
            }

            VStack(spacing: 0) {
                content()
            }
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )

            if let footer {
                Text(footer)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 4)
                    .padding(.top, 2)
            }
        }
    }
}

@MainActor
struct SettingsRow<Trailing: View>: View {
    let icon: String
    let iconTint: Color
    let label: String
    let caption: String?
    @ViewBuilder var trailing: () -> Trailing

    init(
        icon: String,
        iconTint: Color = .brandAccent,
        label: String,
        caption: String? = nil,
        @ViewBuilder trailing: @escaping () -> Trailing
    ) {
        self.icon = icon
        self.iconTint = iconTint
        self.label = label
        self.caption = caption
        self.trailing = trailing
    }

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(iconTint.gradient)
                .frame(width: 22, height: 22)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 12))
                if let caption {
                    Text(caption)
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer(minLength: 12)

            trailing()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

@MainActor
struct SettingsRowDivider: View {
    var body: some View {
        Divider()
            .opacity(0.5)
            .padding(.leading, 48)
    }
}
