# A local Debug build keeps its keys in a keychain file of its own

Status: accepted — 2026-11-11

## Context

A Debug build signed by a self-signed certificate (no Team ID) stored provider
keys in the login keychain. macOS ties each item an app saves to the code hash
(cdhash) of the build that saved it, so every rebuild asked for the login
password before the app could read its keys. Team signing with the data
protection keychain (2026-10-20-keychain-data-protection-21b6) avoids this, but
needs an Apple developer account signed in on the machine, which some
development machines do not have.

Measured on macOS 27.2 with the app running in the desktop session:

- Items the app saves in a keychain created by `security create-keychain` also
  carry `partition_id cdhash:<build>`. An earlier test from a command-line tool
  over ssh showed no partition; it did not hold for the app.
- `security set-generic-password-partition-list -S cdhash:<new> -k <password>`
  hands every item to a new build; the new build then reads them without a
  prompt.
- A keychain's lock state belongs to a login session: `security
  unlock-keychain` run over ssh does not unlock it for the app on screen.

## Decision

- Opt-in per machine, Debug only: `Config/Local.xcconfig` sets
  `TRANSFLEX_KEYCHAIN_PATH` and `TRANSFLEX_KEYCHAIN_PASSWORD_FILE`;
  `make dev-keychain` creates the keychain and a random password in
  `Config/Local.keychain-password` (git-ignored, mode 600). The keychain never
  joins the user's search list and never times out.
- `KeychainBackend.fileAt` scopes every query to that keychain. When it is
  locked, the app unlocks it with the password file; a missing or wrong file
  throws, and nothing falls back to the login keychain.
- `make open-debug`, which every build target ends with, sets every Debug
  item's partition to the build about to open.
- Release clears both settings in `Config/Signing.xcconfig`, and
  `scripts/verify-release-app.sh` rejects an app that carries either Info.plist
  key.

## Consequences

- A rebuild through `make` reads its keys with no dialog, and a reboot asks for
  nothing. Building from Xcode directly skips the hand-over, so the first read
  asks for the keychain's own password (not the login password).
- The keychain password sits in a plain file and shows in `ps` for a moment
  while a build hands over its items. It protects only the Debug build's keys.
- Keys saved earlier in the login keychain stay there; the Debug build no
  longer reads them, so it needs its keys entered once.
- The code uses the deprecated `SecKeychain*` file-keychain API. It is public
  API and runs only in builds that opt in.

## Rejected

- Unlocking from `make`: a shell over ssh unlocks only its own session.
- Signing in an Apple developer account on every development machine for team
  signing: not wanted on shared or virtual machines.
- "Always Allow" on each prompt: it adds one more code hash per build and still
  prompts after the next rebuild.
