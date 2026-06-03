# TransFlex

Native macOS quick-translation app: global hotkey `Option+Q` opens a floating popup, streams translation from the selected LLM provider, and keeps provider keys in macOS Keychain.

> **Status:** active alpha. Core popup, providers, presets, settings, image translation, onboarding, and history are implemented. Unsigned alpha releases are the default; signed/notarized release mode is wired for GitHub Actions when Apple Developer ID and notary secrets are configured.

## Requirements

- macOS 13 Ventura or later at runtime
- Release artifacts are universal macOS apps for Intel and Apple Silicon
- Xcode 15+ with Command Line Tools (tested with Xcode 26.5)
- [`xcodegen`](https://github.com/yonaskolb/XcodeGen) via `brew install xcodegen`
- Optional: [`xcbeautify`](https://github.com/cpisciotta/xcbeautify) for cleaner build logs

## Quick Start

```bash
brew install xcodegen
xcodegen generate
make test
scripts/build.sh
open DerivedData/Build/Products/Debug/TransFlex.app
```

TransFlex is a menu-bar app (`LSUIElement=YES`) with no Dock icon. Click the menu-bar icon or press `Option+Q` to open the popup. Use **Quit TransFlex** or `Command+Q` from the status menu to exit.

## Build

```bash
scripts/build.sh           # Debug build, regenerates TransFlex.xcodeproj
scripts/build.sh --release # Release build
scripts/build.sh --no-gen  # Skip XcodeGen when project is already current
```

The build script regenerates `TransFlex.xcodeproj` from `project.yml`, builds with ad-hoc signing by default, and outputs `DerivedData/Build/Products/Debug/TransFlex.app`. Release builds output `DerivedData/Build/Products/Release/TransFlex.app`.

Release version values can be injected for CI-built bundles:

```bash
MARKETING_VERSION=0.2.0 CURRENT_PROJECT_VERSION=123 scripts/build.sh --release
```

## Release

Public alpha releases are created by GitHub Actions from existing tags such as `v0.2.0` or `v0.2.0-alpha.1`. The phase 1 artifact is named like `TransFlex-0.2.0-macos-universal-unsigned.zip`, includes a `.sha256` checksum, requires macOS 13 Ventura or later, and runs on Intel and Apple Silicon.

Unsigned alpha artifacts are not notarized, so Gatekeeper can block them on tester machines. Signed and notarized releases require Apple Developer ID credentials configured as GitHub Secrets; see [docs/how-to/release.md](docs/how-to/release.md).

## Test

```bash
make test

xcodebuild -scheme TransFlex \
  -derivedDataPath DerivedData \
  -destination 'platform=macOS' \
  CODE_SIGN_IDENTITY=- \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=YES \
  test
```

If a sandboxed automation cannot write Xcode or SwiftPM caches under `~/Library` or `~/.cache`, rerun the same command outside the sandbox.

## Useful Make Targets

```bash
make run          # kill running app, build-fast, open Debug app
make build        # full build, then open Debug app
make release      # Release build only
make welcome-test # reset onboarding flags, build, open app
make clean        # remove generated Xcode/build artifacts
```

## Project Layout

```text
project.yml                 # XcodeGen spec; edit this, not .xcodeproj
TransFlex/
  Info.plist
  TransFlex.entitlements
  Sources/
    App/                    # AppDelegate, menu bar, app commands
    Core/                   # Keychain, hotkey, settings policy, security helpers
    History/                # GRDB-backed translation history
    Presets/                # Preset models and JSON persistence
    Providers/              # OpenAI, Anthropic, Gemini, OpenAI-compatible adapters
    Translation/            # Prompt/input/result orchestration
    UI/                     # SwiftUI/AppKit windows, popup, settings, welcome, history
TransFlexTests/             # Unit tests
docs/                       # Diataxis-lite project docs
scripts/build.sh            # XcodeGen + xcodebuild wrapper
```

## Dependencies

Dependencies are declared in `project.yml` and resolved by SwiftPM when XcodeGen generates the project.

| Package | Version in `project.yml` | Purpose |
|---|---:|---|
| [GRDB](https://github.com/groue/GRDB.swift) | `from: 7.10.0` | SQLite history |
| [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) | `from: 2.4.0` | Global hotkeys |

`TransFlex.xcodeproj` and its generated `Package.resolved` are build artifacts and are not committed.

## Documentation

Docs follow a Diataxis-lite split:

- [Tutorials](docs/tutorials/): guided first success.
- [How-to](docs/how-to/): task recipes.
- [Explanations](docs/explanations/): architecture, security model, and tradeoffs.
- [Reference](docs/reference/): commands, file layout, provider IDs, runtime storage, troubleshooting.

Start with [docs/index.md](docs/index.md). Code conventions live in [docs/reference/code-standards.md](docs/reference/code-standards.md), and macOS-specific pitfalls live in [docs/reference/macos-platform-gotchas.md](docs/reference/macos-platform-gotchas.md).

## Security

- API keys are stored in Keychain only.
- Network transport is HTTPS-only except explicit localhost HTTP for OpenAI-compatible local servers.
- `NSAllowsArbitraryLoads` remains `false`.
- Provider errors and URLs are redacted before leaving provider boundaries.
- No telemetry, analytics, or usage pings.

See [SECURITY.md](SECURITY.md) for reporting guidance.

## Contributing

Contributions are welcome while the project is still alpha. Please read [CONTRIBUTING.md](CONTRIBUTING.md), run `make test`, and keep docs in the Diataxis-lite structure.

## License

TransFlex is released under the [MIT License](LICENSE). Provider icon and trademark notices are listed in [NOTICE.md](NOTICE.md).

## Troubleshooting

**`xcodegen: command not found`**: install with `brew install xcodegen`.

**Build fails because Xcode is not selected**: run `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`.

**App appears in the Dock**: confirm `LSUIElement=YES` in `Info.plist` and `.accessory` activation policy in `AppDelegate`.

**Hotkey did not change after editing the default**: `KeyboardShortcuts` persists user overrides. Delete the stored shortcut with `defaults delete io.aiaz.transflex KeyboardShortcuts_openPopup`, then relaunch.
