import SwiftUI

struct StreamingTextView: View {
    let text: String
    let isStreaming: Bool

    var body: some View {
        Text(displayText)
            .font(.system(size: 14))
            .lineSpacing(2)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var displayText: AttributedString {
        var result = AttributedString(text)
        if isStreaming, !text.isEmpty {
            var cursor = AttributedString(" \u{258D}")
            cursor.foregroundColor = .secondary
            result.append(cursor)
        }
        return result
    }
}
