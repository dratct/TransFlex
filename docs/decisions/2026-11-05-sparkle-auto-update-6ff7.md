# Auto update with Sparkle 2, appcast on the GitHub Release

Status: accepted — 2026-11-05

## Context

TransFlex ships as a Developer ID signed, notarized zip on GitHub Releases
(`release.yml`, `scripts/package-release.sh`). Users had no way to learn about
a new version short of visiting the repository. The app is not sandboxed and
lives in the menu bar (`LSUIElement`).

## Decision

- Add the `Sparkle` package (`https://github.com/sparkle-project/Sparkle`,
  2.x; macOS 12+). It downloads, verifies the EdDSA signature, replaces the
  app and relaunches.
- The app checks on its own (`SUEnableAutomaticChecks` YES, Sparkle's default
  daily interval) and asks before installing (`SUAutomaticallyUpdate` NO).
- Stable releases only: the feed URL is
  `https://github.com/dratct/TransFlex/releases/latest/download/appcast.xml`.
  GitHub's `latest` skips prereleases and drafts, so alphas never reach users
  and no Sparkle channel is used.
- CI signs each archive with `generate_appcast` / `sign_update`, reading the
  private EdDSA key from a repository secret, and attaches `appcast.xml` to the
  Release. A Release without it breaks every update check, so CI fails
  instead of publishing one.
- All Sparkle calls live behind one updater type. The Debug build
  (`TransFlexDev`) runs without an updater; a future Mac App Store build, where
  self-updating is forbidden, drops Sparkle the same way.
- A background-found update shows as a dot on the menu bar icon and an
  "Update Available…" menu item (Sparkle gentle reminders), since a scheduled
  alert does not take focus from the active app. "Check for Updates…" is in
  the menu and on the About tab, next to an "Automatically check for updates"
  switch.
- The release build is not archived and exported, so CI re-signs Sparkle's
  helpers inside-out with the hardened runtime before signing the app.

## Consequences

- `CFBundleVersion` (the workflow run number) must keep increasing; Sparkle
  compares it, not the marketing version.
- Losing the private EdDSA key means shipped apps can no longer accept
  updates; the owner keeps a copy outside GitHub.

## Rejected

- Polling the GitHub API and linking to the Release page: users would still
  download and replace the app by hand.
- A home-made downloader and installer: replacing a running app, signature
  checks and recovery are what Sparkle already gets right.
- Committing `appcast.xml` to `main` or GitHub Pages: CI would have to push
  to a protected branch.
