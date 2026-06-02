import SwiftUI

/// Shortcut hint with one key cap per glyph.
struct KeyHintBadge: View {
    enum Tone { case primary, secondary }

    let keys: [String]
    var tone: Tone = .secondary

    var body: some View {
        HStack(spacing: 3) {
            ForEach(Array(keys.enumerated()), id: \.offset) { _, key in
                Text(key)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(foregroundColor)
                    .frame(minWidth: 16, minHeight: 16)
                    .padding(.horizontal, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                            .fill(backgroundColor)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                            .stroke(borderColor, lineWidth: 0.5)
                    )
            }
        }
        .fixedSize()
    }

    private var foregroundColor: Color {
        switch tone {
        case .primary: return .white
        case .secondary: return .primary.opacity(0.92)
        }
    }

    private var backgroundColor: Color {
        switch tone {
        case .primary: return .black.opacity(0.32)
        case .secondary: return .black.opacity(0.18)
        }
    }

    private var borderColor: Color {
        switch tone {
        case .primary: return .white.opacity(0.22)
        case .secondary: return .primary.opacity(0.18)
        }
    }
}
