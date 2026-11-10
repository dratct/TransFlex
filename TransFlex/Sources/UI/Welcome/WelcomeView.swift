import KeyboardShortcuts
import SwiftUI

/// Welcome: the brand panel on the left stays put; the step on the right
/// changes (docs/design/mockups.html › Welcome and menu bar).
@MainActor
struct WelcomeView: View {
    static let size = NSSize(width: 800, height: 500)

    let onClose: (Bool) -> Void

    @State private var step: WelcomeStep
    @State private var shortcutKeys: [String]
    @StateObject private var provider: ProviderSetupModel

    init(
        initialStep: WelcomeStep = .intro,
        shortcutKeys: [String]? = nil,
        provider: ProviderSetupModel? = nil,
        onClose: @escaping (Bool) -> Void
    ) {
        _step = State(initialValue: initialStep)
        _shortcutKeys = State(initialValue: shortcutKeys
            ?? KeyboardShortcuts.getShortcut(for: .openPopup).map(ShortcutKeys.symbols(for:)) ?? [])
        _provider = StateObject(wrappedValue: provider ?? .live())
        self.onClose = onClose
    }

    var body: some View {
        HStack(spacing: 0) {
            WelcomeArt()
                .frame(width: 290)
            VStack(alignment: .leading, spacing: 0) {
                Text(step.stepLabel)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.tertiary)
                stepContent
                    .padding(.top, 6)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                footer
            }
            .padding(EdgeInsets(top: 28, leading: 32, bottom: 20, trailing: 32))
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .frame(width: Self.size.width, height: Self.size.height)
    }

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case .intro:
            WelcomeIntroView()
        case .provider:
            WelcomeProviderView(model: provider)
        case .shortcut:
            WelcomeShortcutView(keys: $shortcutKeys)
        case .done:
            WelcomeDoneView(keys: shortcutKeys)
        }
    }

    private var footer: some View {
        HStack(spacing: Spacing.s) {
            WelcomeProgress(step: step)
            Spacer()
            if step.showsBack {
                Button("Back") { if let previous = step.previous { step = previous } }
                    .buttonStyle(WelcomeTextButtonStyle())
            }
            if step.showsSkip {
                Button("Skip for now") { advance() }
                    .buttonStyle(WelcomeTextButtonStyle())
            }
            Button(step.primaryTitle) { primaryAction() }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
                .disabled(step == .provider && !provider.canSave)
        }
    }

    private func primaryAction() {
        // The provider step goes on only once the key is in the Keychain;
        // a failure stays on the step with its reason under the field.
        if step == .provider, !provider.save() { return }
        advance()
    }

    private func advance() {
        if let next = step.next {
            step = next
        } else {
            onClose(true)
        }
    }
}

/// The step's title and the line under it.
struct WelcomeHeading: View {
    let title: String
    let lead: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 20, weight: .semibold))
            Text(lead)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.bottom, 18)
    }
}

/// One bar per step, filled up to the current one.
private struct WelcomeProgress: View {
    let step: WelcomeStep

    var body: some View {
        HStack(spacing: 6) {
            ForEach(WelcomeStep.allCases, id: \.rawValue) { each in
                RoundedRectangle(cornerRadius: 2)
                    .fill(each.rawValue <= step.rawValue ? Color.accentColor : Color(nsColor: .quaternaryLabelColor))
                    .frame(width: 22, height: 4)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(step.stepLabel)
    }
}

/// Back and Skip for now: words, no fill, so the one filled button is the way on.
private struct WelcomeTextButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .lineLimit(1)
            .fixedSize()
            .foregroundStyle(.secondary)
            .padding(.horizontal, Spacing.s)
            .padding(.vertical, 5)
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

/// The brand panel: what the app does, in one line and one picture.
private struct WelcomeArt: View {
    var body: some View {
        ZStack(alignment: .topLeading) {
            // White text reads 7.7:1 on `brandDeep` but 2.7:1 on `brand`, so
            // the panel stays deep down past the text and lightens only
            // behind the picture.
            LinearGradient(stops: [.init(color: .brandDeep, location: 0),
                                   .init(color: .brandDeep, location: 0.45),
                                   .init(color: .brand, location: 1)],
                           startPoint: .top, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 0) {
                Image("AppLogo")
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 52, height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(.white.opacity(0.25), lineWidth: 0.5)
                    )
                    .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
                Text("Translate anything you select.")
                    .font(.system(size: 22, weight: .semibold))
                    .padding(.top, 18)
                    .padding(.bottom, 6)
                Text("Press a shortcut in any app. The translation appears right there.")
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(.white)
            .padding(28)
            popupPicture
                .padding(.leading, 28)
                .padding(.trailing, -40)
                .frame(maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, 30)
        }
        .clipped()
        .accessibilityElement(children: .combine)
    }

    /// A drawing of the popup, not a real one: fixed colours on purpose.
    private var popupPicture: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Natural EN ↔ VI")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color(white: 0.11))
            bar(width: 0.85, color: Color(white: 0.9))
            bar(width: 0.95, color: Color.brand.opacity(0.35))
            bar(width: 0.6, color: Color.brand.opacity(0.35))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: Radius.pane, style: .continuous).fill(.white.opacity(0.95)))
        .shadow(color: .black.opacity(0.25), radius: 20, y: 20)
        .accessibilityHidden(true)
    }

    private func bar(width: CGFloat, color: Color) -> some View {
        GeometryReader { geo in
            RoundedRectangle(cornerRadius: 4).fill(color).frame(width: geo.size.width * width)
        }
        .frame(height: 8)
    }
}
