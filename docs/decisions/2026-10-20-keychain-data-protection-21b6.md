# Keychain: data protection keychain for team-signed builds

Status: proposed — 2026-10-20

## Context

`KeychainStore` writes through `SecItem` without `kSecUseDataProtectionKeychain`,
so every secret lands in the file-based login keychain. Each item there carries
its own ACL, and the ACL records the designated requirement of the app that
created it. Ad-hoc signed builds have a cdhash designated requirement, which
changes on every build: after each rebuild or update macOS asks for the login
password again, once per item, even after "Always Allow".
`kSecAttrAccessible` has no effect on that keychain.

The data protection keychain has no per-app ACL; access comes from keychain
access groups in the code signature, which a provisioning profile must
authorise. Ad-hoc builds cannot write to it: `SecItemAdd` and `SecItemDelete`
return `-34018` (`errSecMissingEntitlement`). CI tests, unsigned alpha releases
and contributors without an Apple team build ad-hoc.

## Decision

- Builds signed with a team (Debug with the developer's team, Release with
  Developer ID) store secrets in the data protection keychain, in the access
  group `$(AppIdentifierPrefix)$(PRODUCT_BUNDLE_IDENTIFIER)`, embedded with a
  provisioning profile.
- Ad-hoc builds keep the file-based login keychain.
- The backend is fixed at build time and written into `Info.plist`; the app
  never switches backend at runtime. A team-signed build that gets `-34018`
  reports the error instead of falling back to the file-based keychain.
- The local team comes from a git-ignored `Config/Local.xcconfig`, included by
  the app target's `Config/Signing.xcconfig` so Swift package targets keep
  their own settings; without it the build is ad-hoc. Builds, tests and
  `scripts/build.sh` follow the same file, and never request provisioning.
- Certificates, profiles and device registration come from a separate,
  once-per-machine `make provision` (`xcodebuild -allowProvisioningUpdates`).
  A developer's own Mac uses the Apple Account signed in to Xcode; a machine
  that must not hold an Apple Account, such as an agent's build VM, uses a
  short-lived App Store Connect team API key with the Developer role, revoked
  after use.
- Release builds get the Developer ID profile from a repository secret,
  installed by the release workflow; the profile and the signed entitlements
  reach the app target through a generated xcconfig, not the command line.
- Existing items are not migrated. Users enter their keys again; old items stay
  in the login keychain until removed by hand.

## Consequences

- Team-signed builds stop asking for the login password; ad-hoc builds keep
  asking after every rebuild.
- Changing the signing team changes the access group, so keys saved under the
  previous team are no longer visible and must be entered again.
- Release needs a paid Apple Developer Program membership and a Developer ID
  provisioning profile in the release pipeline; unsigned alpha releases keep
  the file-based keychain.
- Two backends live in `KeychainStore`; CI exercises only the file-based one.
  A machine with `Config/Local.xcconfig` signs its tests with the team too, so
  the keychain holding its signing identity must be unlocked, which over SSH
  is a manual step.
