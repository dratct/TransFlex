import SwiftUI

@MainActor
struct FirstRunWizardView: View {
    @ObservedObject var viewModel: PopupViewModel
    @State private var apiKey = ""
    @State private var selectedProvider = "openai"
    @State private var saveError: String?
    @Environment(\.dismiss) private var dismiss
    private let saver = ProviderKeySaver()

    private let providers = [
        ProviderOption(id: "openai", name: "OpenAI", icon: "brain", placeholder: "sk-..."),
        ProviderOption(id: "anthropic", name: "Claude", icon: "bubble.left.and.bubble.right", placeholder: "sk-ant-..."),
        ProviderOption(id: "gemini", name: "Gemini", icon: "sparkles", placeholder: "AI..."),
    ]

    var body: some View {
        VStack(spacing: 18) {
            VStack(spacing: 8) {
                Text("Configure a Provider")
                    .font(.system(size: 15, weight: .semibold))

                Text("Enter an API key to start translating.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Provider")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)

                Picker("Provider", selection: $selectedProvider) {
                    ForEach(providers) { provider in
                        Label(provider.name, systemImage: provider.icon)
                            .tag(provider.id)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
            }

            SecureField(selectedProviderOption.placeholder, text: $apiKey)
                .textFieldStyle(.roundedBorder)
                .onChange(of: apiKey) { _ in saveError = nil }

            if let saveError {
                Text(saveError)
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(spacing: 12) {
                Button("Skip") { 
                    UserDefaults.standard.set(true, forKey: "hasCompletedFirstRun")
                    dismiss() 
                }
                    .font(.system(size: 12))

                Button("Save & Start") {
                    saveKey()
                }
                .font(.system(size: 12))
                .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(28)
        .frame(width: 420)
    }

    private var selectedProviderOption: ProviderOption {
        providers.first { $0.id == selectedProvider } ?? providers[0]
    }

    private func saveKey() {
        do {
            try saver.save(apiKey, for: selectedProvider)
            UserDefaults.standard.set(true, forKey: "hasCompletedFirstRun")
            dismiss()
        } catch ProviderKeySaver.SaveError.emptyKey {
            return
        } catch {
            saveError = (error as? LocalizedError)?.errorDescription
                ?? "Could not save API key."
        }
    }
}

private struct ProviderOption: Identifiable {
    let id: String
    let name: String
    let icon: String
    let placeholder: String
}
