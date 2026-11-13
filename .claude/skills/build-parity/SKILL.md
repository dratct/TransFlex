---
name: build-parity
description: >-
  Check that a change behaves the same in the Dev app built on this Mac and in
  the Release app CI builds and ships: compare their Xcode, SDK, entitlements
  and compiled-in code, then look at the CI-built Release app itself. Use
  before calling done any change that calls an API newer than macOS 13, adds
  `#if`, `#available` or a build setting, touches `project.yml`, `Config/`,
  entitlements, `scripts/build.sh` or a workflow's runner, and whenever
  something works in TransFlexDev but not in the released TransFlex (or the
  other way round).
---

# Dev build against Release build

The two apps differ in more than the configuration. Dev is `TransFlexDev`,
Debug, built by the Xcode on this Mac, ad-hoc or team signed, on the file
keychain. Release is `TransFlex`, built by the workflow's runner, Developer
ID signed, on the data protection keychain. A change seen working in one
proves nothing about the other until both were built from it and compared.

## 1. Get a Release app that CI built

A Release build made on this Mac uses this Mac's Xcode, so it hides the
difference this check exists for. Use one of:

```bash
S=<scratchpad>/parity && mkdir -p "$S"
# The branch's own build: the Screenshots workflow (runs on a PR that touches
# TransFlex/Sources/UI or App, or by hand) keeps the Release app for 3 days.
gh run list --workflow Screenshots --branch "$(git branch --show-current)" --limit 1
gh run download <run id> -n TransFlex-screenshot-build -D "$S"
# Or the latest shipped release, to see what users run today.
gh release download -p 'TransFlex-macos.zip' -D "$S"
ditto -x -k "$S"/*.zip "$S/app" && xattr -cr "$S/app/TransFlex.app"
```

No run for the branch yet: push the branch and start one with
`gh workflow run Screenshots --ref <branch>`, or say the check waits for CI.

## 2. Compare

```bash
# Builds only. `make build` would also relaunch the app and, without
# Config/Local.xcconfig (a fresh worktree), reset its privacy grants.
scripts/build.sh
scripts/check-build-parity.sh --release "$S/app/TransFlex.app" \
  --probe <text> [--probe <text>]...
```

Give one `--probe` per thing the change relies on being compiled in: the
selector of a newer API (`setPreferredImageVisibility:`), a symbol name, a
log message. The script exits 1 when:

- the two apps were built with different macOS SDKs;
- a probe is in one binary and not in the other;
- app code is gated on the toolchain (`#if compiler(...)`, `#if swift(...)`).
  An older Xcode drops that code without an error. Ask for a newer API at
  run time instead (`responds(to:)`, `#available`).

It also prints every `#if DEBUG`, `canImport` and `#available` in the app,
and both apps' entitlements. Read the lines the change touches: each is a
branch one of the two builds never runs.

## 3. Look at the Release app

A binary that contains the code still has to behave. Run the CI-built app on
this Mac and check the changed screen with the `ui-e2e` skill's cua-driver
calls, using process name `TransFlex` instead of `TransFlexDev`.

- It is the real app: bundle id `io.aiaz.transflex`, the same preferences
  and history as an installed TransFlex. Quit the installed one first, tell
  the owner, change no setting, and quit the CI-built one when done.
- A workflow build is version 0.1.0, so it opens Sparkle's Software Update
  window offering the latest release, and Welcome on a Mac that never ran
  TransFlex. Never press Install Update: it would replace the app under
  test. Leave both windows alone and end with `pkill -x TransFlex`.
- The status item has no window: find it in a full-size
  `get_desktop_state` capture and click it by pixel.
- An unsigned CI build has no Accessibility grant and keeps keys on the file
  keychain, so selection shortcuts and provider calls may not work. Menus,
  windows and layout do.
- Whatever cannot be checked this way, name it in the reply as unchecked.

## 4. Report

Paste the script's `DIFFERENT:` lines (or its last line when there are
none), which Release app was used (run id or release tag), and what was
looked at in it.
