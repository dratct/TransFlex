import SwiftUI

/// Shown in the output area when a selection shortcut needs the Accessibility
/// grant. Switches to a confirmation once the grant is detected.
struct AccessibilityPermissionCard: View {
    let granted: Bool

    /// The name System Settings lists, so the card and the pane read the same.
    private var appName: String { AccessibilityPermission.listedAppName }
    private var paneName: String { AccessibilityPermission.settingsPaneName }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(granted ? Color.green.gradient : Color.brandAccent.gradient)
                    .frame(width: 36, height: 36)
                    .overlay(
                        Image(systemName: granted ? "checkmark" : "hand.raised.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                    )
                VStack(alignment: .leading, spacing: 2) {
                    Text(granted ? "Permission granted" : "One permission needed")
                        .font(.system(size: 15, weight: .semibold))
                    Text(granted
                         ? "Select text and press the shortcut again."
                         : "\(appName) needs \(paneName) to copy your selection and paste the translation.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if !granted {
                VStack(alignment: .leading, spacing: 8) {
                    step(1, "Click **Open System Settings** below.")
                    step(2, "Under \(paneName), turn on **\(AccessibilityPermission.listedAppName)**.")
                    step(3, "This window comes back to confirm once access is on.")
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.65))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color(nsColor: .separatorColor).opacity(0.45), lineWidth: 1)
                )
            }
        }
        .padding(.top, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(.easeInOut(duration: 0.2), value: granted)
    }

    private func step(_ number: Int, _ text: LocalizedStringKey) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("\(number)")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 18, height: 18)
                .background(Circle().fill(Color.brandAccent))
            Text(text)
                .font(.system(size: 12))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
