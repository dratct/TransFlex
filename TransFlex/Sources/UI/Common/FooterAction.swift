import SwiftUI

/// A footer or notice button: title plus its shortcut as a `KeyHint`.
/// System button styles only, at the large control size, so macOS 26 and
/// later draw capsules and macOS 13–15 classic push buttons.
struct FooterAction: View {
    enum Prominence {
        /// The one filled button of a state.
        case primary
        case secondary
        /// Text only ("New").
        case plain
    }

    let title: String
    let keys: [String]
    var prominence: Prominence = .secondary
    let action: () -> Void

    init(_ title: String, keys: [String], prominence: Prominence = .secondary, action: @escaping () -> Void) {
        self.title = title
        self.keys = keys
        self.prominence = prominence
        self.action = action
    }

    var body: some View {
        styled(
            Button(action: action) {
                HStack(spacing: 6) {
                    Text(title)
                    KeyHint(keys: keys, onAccent: prominence == .primary)
                }
                .fixedSize()
            }
        )
        .controlSize(.large)
        .accessibilityLabel(title)
        .accessibilityHint(KeyHint.spokenLabel(for: keys))
    }

    @ViewBuilder
    private func styled(_ button: Button<some View>) -> some View {
        switch prominence {
        case .primary: button.buttonStyle(.borderedProminent)
        case .secondary: button.buttonStyle(.bordered)
        case .plain: button.buttonStyle(.borderless).foregroundStyle(.secondary)
        }
    }
}
