import SwiftUI

/// The popup's sheet when no key is set yet: the same provider form as
/// Welcome's provider step.
@MainActor
struct FirstRunWizardView: View {
    static let width: CGFloat = 460

    @StateObject private var model: ProviderSetupModel
    @Environment(\.dismiss) private var dismiss

    init(model: ProviderSetupModel? = nil) {
        _model = StateObject(wrappedValue: model ?? .live())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Connect an AI provider")
                    .font(.system(size: 15, weight: .semibold))
                Text("Enter an API key to start translating.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            ProviderSetupForm(model: model)

            HStack(spacing: 12) {
                Spacer()
                Button("Skip for now") {
                    UserDefaults.standard.set(true, forKey: "hasCompletedFirstRun")
                    dismiss()
                }
                Button("Save & Start") {
                    if model.save() { dismiss() }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(!model.canSave)
            }
        }
        .padding(28)
        .frame(width: Self.width)
    }
}
