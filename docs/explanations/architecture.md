# Architecture

## Architecture

TransFlex is a native macOS menu-bar app. `AppDelegate` is the bootstrap point: it sets accessory activation, seeds presets, registers OpenAI-compatible providers, opens the welcome flow, and wires the status menu, popup, hotkeys, settings, and history.

The codebase is split by responsibility:

- `App`: application bootstrap, menu-bar controller, app-level commands.
- `Core`: clipboard, hotkeys, Keychain, onboarding helpers, security helpers, settings policy.
- `Providers`: provider registry, credential metadata, request builders, streaming adapters, SSE parser, cost table.
- `Translation`: prompt building, translation input/result types, service orchestration.
- `Presets`: user-facing translation profiles and persistence.
- `History`: GRDB-backed translation history and export.
- `UI`: SwiftUI/AppKit windows for popup, settings, welcome, and history.

This layout is appropriate for the current app size. The main boundary to preserve is that providers emit stream events and should not know about UI, history, or clipboard side effects.

## Translation Flow

1. The popup view model receives text or image input.
2. `PromptBuilder` creates chat messages from the selected preset.
3. `TranslationService` resolves the provider and Keychain-loaded API key.
4. The provider adapter builds a request and streams `LLMEvent` values.
5. The popup updates UI state, records history, estimates cost, and copies the completed result.

Provider adapters share a small contract through `LLMProvider`, `LLMEvent`, request builders, `HeaderApplicator`, and `EventSource`.

## Security Model

Provider API keys are stored in Keychain. OpenAI-compatible header values are also kept in Keychain; `providers.json` stores metadata and header names only.

Provider errors and URLs pass through secret redaction before being logged or surfaced. Network transport is HTTPS-only except explicit localhost HTTP for OpenAI-compatible development endpoints. The app has no telemetry.

## Onboarding Flow

The dedicated welcome window appears on first launch. If the user closes it without configuring a provider, the popup can still present a compact provider setup sheet. That fallback is intentional and should be removed only if another provider-setup path replaces it.

## Generated Project

`project.yml` is the source of truth. `TransFlex.xcodeproj` is generated with XcodeGen and ignored by git, which keeps the repository reviewable and avoids Xcode project churn.

## Current Tradeoffs

- The UI layer is intentionally AppKit/SwiftUI mixed because non-activating panels, LSUIElement behavior, Settings routing, and global hotkeys need AppKit control points.
- `PresetEditor.swift` and `PopupView.swift` are the largest files. They are still cohesive, but future feature work should split them only when new behavior creates a clear subcomponent boundary.
- There is no distribution pipeline yet. Signing, notarization, and release packaging remain separate work.
