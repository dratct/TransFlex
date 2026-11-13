# TransFlex — agent notes

A macOS menu-bar translator (SwiftUI + AppKit, Swift 6). Terms and product
rules: `CONTEXT.md`. Everything else: `docs/index.md`.

## Commands

- `make test` — all unit tests. `make test ONLY="HistoryStoreTests PopupViewModelQuickModeTests"`
  runs just those classes. The output is long: pipe it through
  `rg "error:|Executed .* tests|TEST (SUCCEEDED|FAILED)|BUILD FAILED"`.
- `make build-fast` — kill, build, relaunch TransFlexDev. `make build` also
  regenerates the Xcode project. `make build-fresh` resets it to first launch.
- `scripts/test-release-scripts.sh` — after touching `scripts/` or the release workflow.
- `make help` lists the rest.

## Traps

- `TransFlex.xcodeproj` is XcodeGen output and is not committed. Change
  `project.yml`; run `xcodegen generate` after adding a Swift file by any
  means other than the Write tool (a hook covers Write).
- `make open-debug` does not restart an app that is already running, so it
  keeps showing the old build. Use `make build-fast`, or `make kill-debug` first.
- Running the Debug binary by hand leaves `default.profraw` in the working
  directory. Delete it; never commit it.
- `TransFlexDev --screenshots <dir>` renders every screen and state to PNG
  from sample data. It shows layout, not behaviour.
- `Config/Local.*` is per-machine signing and keychain setup. Never read or
  print `Config/Local.keychain-password`, and never read a keychain value.
- Tests that format numbers must pin a locale: a decimal-comma system locale
  turns `$0.0004` into `$0,0004`.

## Checking the UI

Unit tests and screenshots do not prove a popup, Settings, History or
shortcut flow. Drive the running app with `cua-driver`, following
`.claude/skills/ui-e2e/SKILL.md`, and leave the app as you found it.

## Dev build and Release build

TransFlexDev is built by this Mac's Xcode; the released TransFlex by the
workflow's runner. A change that calls an API newer than macOS 13, adds
`#if` or `#available`, or touches build settings, entitlements or a runner
is checked in both, following `.claude/skills/build-parity/SKILL.md`. Never
gate app code on `#if compiler(...)`: an older Xcode drops it silently.

## Docs to keep in step

- A changed screen or state: `docs/design/DESIGN.md` and `docs/design/mockups.html`.
- A hard-to-reverse choice: a new record in `docs/decisions/`.
- A new term or product rule: `CONTEXT.md`.
