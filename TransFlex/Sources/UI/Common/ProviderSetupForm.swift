import SwiftUI

/// A provider the first key can be entered for, in Welcome and the popup's
/// first-run sheet.
struct ProviderChoice: Identifiable, Equatable {
    let id: String
    let name: String
    /// The line under the name on its card.
    let detail: String
    let placeholder: String
    /// Where the provider hands out API keys.
    let keyURL: URL

    static let all: [ProviderChoice] = [
        ProviderChoice(id: "openai", name: "OpenAI", detail: "GPT models", placeholder: "sk-...",
                       keyURL: URL(string: "https://platform.openai.com/api-keys")!),
        ProviderChoice(id: "anthropic", name: "Anthropic", detail: "Claude models", placeholder: "sk-ant-...",
                       keyURL: URL(string: "https://platform.claude.com/settings/keys")!),
        ProviderChoice(id: "gemini", name: "Gemini", detail: "Google", placeholder: "AI...",
                       keyURL: URL(string: "https://aistudio.google.com/apikey")!),
    ]
}

/// The chosen provider and the key typed for it. Whoever owns the Continue or
/// Save button owns this, and calls `save()`.
@MainActor
final class ProviderSetupModel: ObservableObject {
    @Published var selected = ProviderChoice.all[0].id {
        // One field serves every card; a key typed for one provider must not
        // be saved under another.
        didSet { if selected != oldValue { key = ""; error = nil } }
    }
    @Published var key = "" {
        didSet { if key != oldValue { error = nil } }
    }
    @Published private(set) var error: String?

    private let saveKey: (_ key: String, _ providerID: String) throws -> Void
    private let onSaved: () -> Void

    init(save: @escaping (_ key: String, _ providerID: String) throws -> Void, onSaved: @escaping () -> Void) {
        self.saveKey = save
        self.onSaved = onSaved
    }

    /// Saves into the Keychain and marks the first run done.
    static func live() -> ProviderSetupModel {
        live(keychain: KeychainStore(), presetStore: AppDelegate.shared?.presetStore)
    }

    static func live(keychain: KeychainStore, presetStore: PresetStore?) -> ProviderSetupModel {
        let saver = ProviderKeySaver(keychain: keychain, presetStore: presetStore)
        return ProviderSetupModel(
            save: { key, providerID in try saver.save(key, for: providerID) },
            onSaved: { UserDefaults.standard.set(true, forKey: "hasCompletedFirstRun") }
        )
    }

    var choice: ProviderChoice {
        ProviderChoice.all.first { $0.id == selected } ?? ProviderChoice.all[0]
    }

    var canSave: Bool {
        !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// True when the key was saved; on failure the reason shows under the field.
    @discardableResult
    func save() -> Bool {
        guard canSave else { return false }
        do {
            try saveKey(key, selected)
            error = nil
            onSaved()
            return true
        } catch {
            self.error = (error as? LocalizedError)?.errorDescription ?? "Could not save API key."
            return false
        }
    }
}

/// Three provider cards, the key field and where to get a key
/// (docs/design/mockups.html › Welcome — provider step).
struct ProviderSetupForm: View {
    @ObservedObject var model: ProviderSetupModel

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.l) {
            HStack(spacing: Spacing.s) {
                ForEach(ProviderChoice.all) { choice in
                    card(choice)
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("\(model.choice.name) API key")
                    .font(.system(size: 13, weight: .medium))
                SecureField(model.choice.placeholder, text: $model.key)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("\(model.choice.name) API key")
                if let error = model.error {
                    Text(error)
                        .font(.system(size: 11))
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Link(destination: model.choice.keyURL) {
                    Label("Where do I get a key?", systemImage: "arrow.up.right")
                        .labelStyle(TrailingIconLabelStyle())
                }
                .font(.system(size: 12))
            }
        }
    }

    private func card(_ choice: ProviderChoice) -> some View {
        let isOn = choice.id == model.selected
        return Button {
            model.selected = choice.id
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                ProviderLogo(providerID: choice.id, name: choice.name)
                Text(choice.name)
                    .font(.system(size: 13, weight: .medium))
                Text(choice.detail)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: Radius.pane, style: .continuous)
                    .fill(Color(nsColor: .textBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Radius.pane, style: .continuous)
                    .strokeBorder(isOn ? Color.accentColor : Color(nsColor: .separatorColor),
                                  lineWidth: isOn ? 2 : 0.5)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(choice.name), \(choice.detail)")
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

/// "Where do I get a key? ↗": the arrow after the words.
private struct TrailingIconLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 3) {
            configuration.title
            configuration.icon
        }
    }
}
