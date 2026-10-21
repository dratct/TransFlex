# Development Workflows

## Build the App

```bash
scripts/build.sh
```

Use `--release` for a Release build and `--no-gen` when `TransFlex.xcodeproj` is already current.

```bash
scripts/build.sh --release
scripts/build.sh --no-gen
```

## Sign Local Builds with Your Team

Ad-hoc builds keep API keys in the login keychain, and macOS asks for the login password after every rebuild. Signing with an Apple Developer team moves the keys to the data protection keychain and stops the prompts.

1. Copy the example and set your team ID:

   ```bash
   cp Config/Local.xcconfig.example Config/Local.xcconfig
   ```

2. Provision this Mac once. With an Apple Account signed in to Xcode (Settings → Accounts):

   ```bash
   make provision
   ```

   On a machine without an Xcode account, pass an App Store Connect team API key (role Developer) instead, and revoke the key afterwards:

   ```bash
   make provision ASC_KEY_PATH=/path/AuthKey_ABC123.p8 ASC_KEY_ID=ABC123 ASC_ISSUER_ID=<issuer-uuid>
   ```

3. Build and test as usual; `scripts/build.sh`, `make build` and `make test` sign with the team while `Config/Local.xcconfig` exists. Enter your API keys again in Settings once, because the new keychain starts empty.

Later builds reuse the cached profile and need no account or key. Over SSH the login keychain is locked, so codesign fails with "User interaction is not allowed" until you unlock the keychain that holds the signing identity (`security unlock-keychain <keychain>`) in the same session.

## Run Tests

```bash
make test
```

If Xcode or SwiftPM cache writes fail in a sandbox, rerun the same command in a normal terminal.

## Launch During Development

```bash
make run
```

This kills a running `TransFlexDev` instance, builds without regenerating the project, and opens `DerivedData/Build/Products/Debug/TransFlexDev.app`.

## Open the Project in Xcode

```bash
make xcode
```

This regenerates `TransFlex.xcodeproj` and opens it.

## Configure Cloud Provider Keys

1. Open TransFlex.
2. Open Settings from the menu-bar menu or popup gear.
3. Select Providers.
4. Paste an API key for OpenAI, Anthropic, or Gemini.

Keys are stored in Keychain. The providers JSON file stores non-secret metadata only.

## Add an OpenAI-Compatible Endpoint

1. Open Settings.
2. Select Providers.
3. Add an OpenAI-compatible endpoint.
4. Enter a name, base URL, default model, optional key, and optional non-auth extra headers.

HTTP is accepted only for localhost-style endpoints. Remote endpoints must use HTTPS.

## Add or Edit a Preset

1. Open Settings.
2. Select Presets.
3. Add a preset or edit an existing preset.
4. Choose provider, model, prompt, temperature, vision support, and optional extra request body.

Preset hotkeys use `Option+1` through `Option+9` for the first nine presets.

## Reset Onboarding

```bash
make welcome-reset
make welcome-test
```

`welcome-test` clears Debug onboarding flags, builds, and opens `TransFlexDev.app` so the welcome flow appears again.

## Stream Logs

```bash
make log
```

This streams OSLog entries for subsystem `io.aiaz.transflex`.
