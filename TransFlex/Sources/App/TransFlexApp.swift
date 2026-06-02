import SwiftUI

@main
struct TransFlexApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // App requires at least one Scene. We intentionally do not use the
        // SwiftUI `Settings { }` scene here because its `showSettingsWindow:`
        // action does not route from a `.nonactivatingPanel` context. Settings
        // is shown via `AppDelegate.settingsWindowController` instead.
        Settings { EmptyView() }
    }
}
