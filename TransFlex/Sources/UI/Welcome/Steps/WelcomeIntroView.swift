import SwiftUI

struct WelcomeIntroView: View {
    private let points: [(symbol: String, text: String)] = [
        ("keyboard", "One shortcut, in any app"),
        ("sparkles", "Your own AI provider: OpenAI, Anthropic or Gemini"),
        ("lock", "Keys stay in your Keychain"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            WelcomeHeading(title: "Welcome to \(AppIdentity.current.displayName)",
                           lead: "Translate text in any app without leaving it.")
            VStack(alignment: .leading, spacing: Spacing.m) {
                ForEach(points, id: \.text) { point in
                    Label {
                        Text(point.text)
                    } icon: {
                        Image(systemName: point.symbol)
                            .foregroundStyle(Color.accentText)
                            .frame(width: 20)
                    }
                }
            }
        }
    }
}
