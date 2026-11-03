import SwiftUI

/// Brief confirmation centred above the popup footer. Only "Copied" today.
struct Toast: View {
    let message: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark")
                .font(.system(size: 11, weight: .semibold))
            Text(message)
                .font(.system(size: 12, weight: .medium))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, Spacing.m)
        .padding(.vertical, 6)
        .background(Capsule().fill(Color.black.opacity(0.78)))
        .accessibilityElement(children: .combine)
    }
}
