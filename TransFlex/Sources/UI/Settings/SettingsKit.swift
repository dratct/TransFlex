import SwiftUI

/// `SettingsRow` (DESIGN.md › Components): a label with an optional one-line
/// explanation leading, one control trailing. Rows live in a
/// `Form { Section { … } }.formStyle(.grouped)`, which draws the `content`
/// box and the hairlines between rows.
struct SettingsRow<Control: View>: View {
    let label: String
    var caption: String?
    @ViewBuilder var control: () -> Control

    init(_ label: String, caption: String? = nil, @ViewBuilder control: @escaping () -> Control) {
        self.label = label
        self.caption = caption
        self.control = control
    }

    var body: some View {
        LabeledContent {
            control()
        } label: {
            SettingsLabel(label, caption: caption)
        }
    }
}

/// Title plus an optional `faint` explanation, for rows whose control brings
/// its own label slot (Toggle, Picker).
struct SettingsLabel: View {
    let title: String
    var caption: String?

    init(_ title: String, caption: String? = nil) {
        self.title = title
        self.caption = caption
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
            if let caption {
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// Every Settings tab: a grouped form with the window's own scroll view.
struct SettingsForm<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        Form(content: content)
            .formStyle(.grouped)
    }
}
