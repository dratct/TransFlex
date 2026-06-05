import SwiftUI

enum SettingsTab: Hashable, CaseIterable {
    case general, providers, presets, hotkeys, about
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

    var body: some View {
        TabView(selection: $tabState.selected) {
            GeneralTab()
                .tabItem { Label("General", systemImage: "gearshape") }
                .tag(SettingsTab.general)

            ProvidersTab(store: providersStore)
                .tabItem { Label("Providers", systemImage: "server.rack") }
                .tag(SettingsTab.providers)

            PresetsTab(providersStore: providersStore)
                .tabItem { Label("Presets", systemImage: "text.badge.star") }
                .tag(SettingsTab.presets)
                .environmentObject(presetStore)

            HotkeysTab()
                .tabItem { Label("Hotkeys", systemImage: "keyboard") }
                .tag(SettingsTab.hotkeys)

            AboutTab()
                .tabItem { Label("About", systemImage: "info.circle") }
                .tag(SettingsTab.about)
        }
        .padding(.top, 10)
        .frame(minWidth: 620, minHeight: 480)
        .onAppear {
            providersStore.registerAllWithRegistry()
        }
    }
}
