# Commands and Runtime Reference

## Commands

| Command | Purpose |
|---|---|
| `xcodegen generate` | Generate `TransFlex.xcodeproj` from `project.yml`. |
| `scripts/build.sh` | Generate and build Debug app. |
| `scripts/build.sh --no-gen` | Build using an already generated project. |
| `scripts/build.sh --release` | Build Release app. |
| `make test` | Run unit tests. |
| `make run` | Kill running app, build fast, open Debug app. |
| `make xcode` | Generate and open the Xcode project. |
| `make log` | Stream OSLog for `io.aiaz.transflex`. |
| `make clean` | Remove generated project and build artifacts. |
| `make welcome-reset` | Clear onboarding flags. |
| `make welcome-test` | Reset onboarding, build, and launch. |

## Generated Artifacts

These are intentionally ignored:

- `TransFlex.xcodeproj/`
- `DerivedData/`
- `.swiftpm/`
- `.build/`
- `Packages/`

## Runtime Storage

| Data | Location |
|---|---|
| Provider keys | macOS Keychain service `io.aiaz.transflex`. |
| OpenAI-compatible secrets | macOS Keychain service `io.aiaz.transflex`. |
| Provider metadata | Application Support `TransFlex/providers.json`. |
| Presets | Application Support `TransFlex/presets.json`. |
| History | Application Support `TransFlex/history.sqlite`. |
| Onboarding flags | UserDefaults for bundle `io.aiaz.transflex`. |

## Provider IDs

Built-in provider IDs:

- `openai`
- `anthropic`
- `gemini`

OpenAI-compatible providers use:

```text
openai-compatible:<instance-id>
```

## Build Settings

The app target is configured in `project.yml`:

- Bundle ID: `io.aiaz.transflex`
- Minimum macOS: `13.0`
- Swift version setting: `5.0`
- Code signing: ad-hoc local signing
- App sandbox: disabled
- Hardened runtime: disabled

## Troubleshooting

`xcodegen: command not found`

Install XcodeGen:

```bash
brew install xcodegen
```

`xcodebuild` uses Command Line Tools

Select full Xcode:

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

Generated project looks stale

Regenerate:

```bash
xcodegen generate
```

Onboarding does not show

Reset flags:

```bash
make welcome-reset
```
