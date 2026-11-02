import SwiftUI

/// The provider's own mark in a 28pt tile (DESIGN.md › Components). Endpoints
/// without a bundled mark show their initials.
struct ProviderLogo: View {
    let providerID: String
    let name: String

    private static let assets = [
        "openai": "ProviderOpenAI",
        "anthropic": "ProviderAnthropic",
        "gemini": "ProviderGemini",
    ]

    var body: some View {
        RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
            .fill(Color(nsColor: .quaternaryLabelColor).opacity(0.5))
            .frame(width: 28, height: 28)
            .overlay {
                if let asset = Self.assets[providerID] {
                    Image(asset)
                        .resizable()
                        .renderingMode(.template)
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 16, height: 16)
                        .foregroundStyle(.primary)
                } else {
                    Text(Self.initials(of: name))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityHidden(true)
    }

    /// "Local Ollama" → "LO", "openrouter" → "OP".
    static func initials(of name: String) -> String {
        let words = name.split(whereSeparator: { !$0.isLetter && !$0.isNumber })
        let letters = words.count >= 2 ? words.prefix(2).compactMap(\.first) : Array(words.first?.prefix(2) ?? "")
        return String(letters).uppercased()
    }
}
