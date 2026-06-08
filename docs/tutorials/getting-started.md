# Getting Started

This tutorial gets TransFlex running locally and performs the first translation.

## 1. Install Prerequisites

TransFlex requires macOS 13+, Xcode with Command Line Tools, and XcodeGen.

```bash
brew install xcodegen
xcodebuild -version
xcodegen version
```

If `xcodebuild` points to Command Line Tools instead of full Xcode, select Xcode:

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

## 2. Generate the Xcode Project

```bash
xcodegen generate
```

The generated `TransFlex.xcodeproj` is ignored by git. Edit `project.yml` when adding source folders, packages, targets, or build settings.

## 3. Run Tests

```bash
make test
```

This runs the `TransFlex` scheme against the macOS destination with ad-hoc signing.

## 4. Build and Launch

```bash
scripts/build.sh
open DerivedData/Build/Products/Debug/TransFlexDev.app
```

The Debug app is `TransFlex Dev` (`TransFlexDev.app`) so it stays separate from the Release app. It is a menu-bar utility with no Dock icon. Use the menu-bar item or press `Option+Q` to open the translation popup.

## 5. Configure a Provider

On first launch, the welcome window guides you through hotkey and provider setup. Provider keys are saved in Keychain.

Supported built-in providers:

- OpenAI
- Anthropic
- Gemini

You can also add OpenAI-compatible endpoints from Settings, such as local Ollama, vLLM, LM Studio, or third-party gateways.

## 6. Translate

1. Press `Option+Q`.
2. Type or paste text.
3. Choose a preset if needed.
4. Press `Command+Return`.

The result streams into the popup and is copied to the clipboard when complete.
