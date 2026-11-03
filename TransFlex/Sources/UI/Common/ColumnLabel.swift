import SwiftUI

/// "ORIGINAL" / "TRANSLATION" over a popup column, with an optional muted note
/// ("· incomplete").
struct ColumnLabel: View {
    let title: String
    let color: Color
    var note: String?

    var body: some View {
        HStack(spacing: Spacing.xs) {
            Text(title.uppercased())
                .font(ReadingType.columnLabel)
                .tracking(ReadingType.columnLabelTracking)
                .foregroundStyle(color)
            if let note {
                Text("· \(note)")
                    .font(ReadingType.columnLabel)
                    .foregroundStyle(.tertiary)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(note.map { "\(title), \($0)" } ?? title)
        .accessibilityAddTraits(.isHeader)
    }
}
