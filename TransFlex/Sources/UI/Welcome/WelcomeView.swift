import SwiftUI

@MainActor
struct WelcomeView: View {
    let onClose: (Bool) -> Void

    @State private var step: WelcomeStep = .intro

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            Divider()
            footer
        }
        .frame(width: 620, height: 460)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "character.bubble.fill")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(Color.brandAccent)
                .symbolRenderingMode(.hierarchical)
            VStack(alignment: .leading, spacing: 2) {
                Text("TransFlex")
                    .font(.system(size: 15, weight: .semibold))
                Text(step.subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 24)
        .frame(height: 64)
        .background(.regularMaterial)
    }

    @ViewBuilder
    private var content: some View {
        ZStack {
            switch step {
            case .intro:
                WelcomeIntroView()
                    .transition(stepTransition)
            case .hotkey:
                WelcomeHotkeyView()
                    .transition(stepTransition)
            case .provider:
                WelcomeProviderView(
                    onSaveSuccess: { advance() },
                    onSkip: { advance() }
                )
                .transition(stepTransition)
            case .finish:
                WelcomeFinishView()
                    .transition(stepTransition)
            }
        }
        .animation(.easeOut(duration: 0.25), value: step)
    }

    private var stepTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        )
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Button("Back") { goBack() }
                .buttonStyle(.bordered)
                .opacity(step == .intro ? 0 : 1)
                .disabled(step == .intro)

            Spacer()

            stepDots

            Spacer()

            Button(step.primaryCTA) { advance() }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .opacity(step == .provider ? 0 : 1)
                .disabled(step == .provider)
        }
        .padding(.horizontal, 24)
        .frame(height: 64)
    }

    private var stepDots: some View {
        HStack(spacing: 6) {
            ForEach(WelcomeStep.allCases, id: \.rawValue) { dot in
                Capsule()
                    .fill(dot == step ? Color.brandAccent : Color.secondary.opacity(0.3))
                    .frame(width: dot == step ? 24 : 6, height: 6)
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: step)
            }
        }
    }

    private func advance() {
        if let next = step.next {
            step = next
        } else {
            onClose(true)
        }
    }

    private func goBack() {
        if let prev = step.previous {
            step = prev
        }
    }
}
