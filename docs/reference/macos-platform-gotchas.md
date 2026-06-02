# macOS Platform Gotchas

## LSUIElement Apps

TransFlex runs as an accessory/menu-bar app. It has no Dock icon and does not rely on the normal app menu bar for every command path.

Settings and popup commands should route through app-owned controllers rather than assuming the default SwiftUI Settings scene responder path is available.

## Non-Activating Panels

The translator popup is a non-activating `NSPanel`. It must become key so the text editor receives keyboard input, but it should not behave like a normal main window.

Dismissal should be driven through explicit controller/policy code, not only `resignKey`, because same-process sheets and child windows can also change key state.

## System Dialogs

Keychain prompts, Touch ID/password prompts, and sandboxed open/save panel helper processes can become frontmost while the popup should remain visible. Keep allowlist behavior centralized in `PopupDismissPolicy`.

## Keyboard Shortcuts

Global shortcuts use KeyboardShortcuts. User overrides are persisted by that library, so changing a default shortcut in code does not overwrite existing user preferences.

To clear the default popup shortcut:

```bash
defaults delete io.aiaz.transflex KeyboardShortcuts_openPopup
```

## Keychain

Use `KeychainStore.exists(_:)` when probing for configuration. Reading a protected item can trigger an authentication prompt.

## XcodeGen

`project.yml` owns project structure. Regenerate after adding source folders, packages, targets, or build settings:

```bash
xcodegen generate
```
