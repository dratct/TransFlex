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
