import SwiftUI

@MainActor
struct WelcomeProviderView: View {
    let onSaveSuccess: () -> Void
    let onSkip: () -> Void

    @State private var selectedProvider = "openai"
    @State private var apiKey = ""
    @State private var saveError: String?

    private let saver = ProviderKeySaver()
    private let providers: [WelcomeProviderOption] = [
        WelcomeProviderOption(id: "openai", name: "OpenAI", icon: "brain", placeholder: "sk-..."),
        WelcomeProviderOption(id: "anthropic", name: "Claude", icon: "bubble.left.and.bubble.right", placeholder: "sk-ant-..."),
        WelcomeProviderOption(id: "gemini", name: "Gemini", icon: "sparkles", placeholder: "AI..."),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Add an AI provider")
                    .font(.system(size: 17, weight: .semibold))
                Text("Pick one to start. Keys are stored in macOS Keychain — never sent anywhere except the provider.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Picker("Provider", selection: $selectedProvider) {
                ForEach(providers) { provider in
                    Label(provider.name, systemImage: provider.icon).tag(provider.id)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)

            SecureField(selectedOption.placeholder, text: $apiKey)
                .textFieldStyle(.roundedBorder)
                .onChange(of: apiKey) { _ in saveError = nil }

            if let saveError {
                Text(saveError)
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(spacing: 8) {
                Spacer()
                Button("Skip") { onSkip() }
                    .buttonStyle(.bordered)
                Button("Save & Continue") { saveAndContinue() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            Spacer()
        }
        .padding(.horizontal, 32)
        .padding(.top, 28)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var selectedOption: WelcomeProviderOption {
        providers.first { $0.id == selectedProvider } ?? providers[0]
    }

    private func saveAndContinue() {
        do {
            try saver.save(apiKey, for: selectedProvider)
            UserDefaults.standard.set(true, forKey: "hasCompletedFirstRun")
            onSaveSuccess()
        } catch ProviderKeySaver.SaveError.emptyKey {
            return
        } catch {
            saveError = (error as? LocalizedError)?.errorDescription
                ?? "Could not save API key."
        }
    }
}

private struct WelcomeProviderOption: Identifiable {
    let id: String
    let name: String
    let icon: String
    let placeholder: String
}
