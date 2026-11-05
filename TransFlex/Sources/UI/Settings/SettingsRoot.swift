import SwiftUI

enum SettingsTab: Hashable, CaseIterable {
    case general, providers, presets, about
}

@MainActor
final class SettingsTabState: ObservableObject {
    @Published var selected: SettingsTab = .general
}

@MainActor
struct SettingsRoot: View {
    @StateObject private var providersStore = ProvidersStore()
    @EnvironmentObject var presetStore: PresetStore
    @ObservedObject var tabState: SettingsTabState
    let updater: AppUpdater?
    // The segmented Picker writes its binding while SwiftUI updates the view, which must not
    // publish an ObservableObject; `tabState` only carries the tab requested by `show(tab:)`.
    @State private var selected: SettingsTab

    init(tabState: SettingsTabState, updater: AppUpdater? = nil) {
        self.tabState = tabState
        self.updater = updater
        self._selected = State(initialValue: tabState.selected)
    }

    var body: some View {
        // A segmented Picker instead of `TabView`: AppKit centers the
        // NSTabView tab bar at half-point offsets, which blurs its labels on
        // non-Retina displays. SwiftUI rounds this layout to whole pixels.
        VStack(spacing: 0) {
            Picker("Settings", selection: $selected) {
                Text("General").tag(SettingsTab.general)
                Text("Providers").tag(SettingsTab.providers)
                Text("Presets").tag(SettingsTab.presets)
                Text("About").tag(SettingsTab.about)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
            .padding(.vertical, 10)

            Divider()

            Group {
                switch selected {
                case .general: GeneralTab()
                case .providers: ProvidersTab(store: providersStore)
                case .presets: PresetsTab(providersStore: providersStore).environmentObject(presetStore)
                case .about: AboutTab(updater: updater)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 620, minHeight: 480)
        .onAppear {
            providersStore.registerAllWithRegistry()
        }
        .onReceive(tabState.$selected) { selected = $0 }
    }
}
