# Commands and Runtime Reference

## Commands

| Command | Purpose |
|---|---|
| `xcodegen generate` | Generate `TransFlex.xcodeproj` from `project.yml`. |
| `scripts/build.sh` | Generate and build Debug app (`TransFlexDev.app`). |
| `scripts/build.sh --no-gen` | Build using an already generated project. |
| `scripts/build.sh --release` | Build Release app. |
| `MARKETING_VERSION=0.2.0 CURRENT_PROJECT_VERSION=123 scripts/build.sh --release` | Build Release app with CI-style bundle versions. |
| `scripts/verify-release-app.sh --app DerivedData/Build/Products/Release/TransFlex.app` | Verify release app minimum macOS, bundle versions, and architectures. |
| `VERSION=0.2.0 SIGNING_LABEL=unsigned scripts/package-release.sh DerivedData/Build/Products/Release/TransFlex.app` | Create release zip and checksum under `dist/`. |
| `make test` | Run unit tests. |
| `make run` | Kill `TransFlexDev`, build fast, open Debug app. |
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
- `dist/`

## Release Artifacts

Release packages use this naming format:

```text
dist/TransFlex-<version>-macos-universal-unsigned.zip
dist/TransFlex-<version>-macos-universal-unsigned.zip.sha256
dist/TransFlex-<version>-macos-universal-signed-notarized.zip
dist/TransFlex-<version>-macos-universal-signed-notarized.zip.sha256
```

The unsigned artifact is the default alpha output. The signed-notarized artifact is produced only when the release workflow runs with `signed: true` and the Apple signing/notarization secrets are configured.

Verify the built app before packaging:

```bash
scripts/verify-release-app.sh \
  --app DerivedData/Build/Products/Release/TransFlex.app \
  --expected-min-macos 13.0 \
  --expected-marketing-version 0.2.0 \
  --expected-build-version 123
```

The executable must include both architectures:

```bash
lipo -info DerivedData/Build/Products/Release/TransFlex.app/Contents/MacOS/TransFlex
```

Expected output contains `x86_64` and `arm64`.

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

Release build output is verified to contain both `arm64` and `x86_64` executable slices.

## GitHub Actions

CI uses standard public GitHub-hosted macOS runners:

- `macos-26` for pull request, `main`, and release builds.
- `macos-26-intel` for the manually triggered Intel test probe.

The workflows avoid larger paid runner labels. Workflow artifacts use `retention-days: 7`; public release downloads are attached to GitHub Releases.

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
