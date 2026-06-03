# Release TransFlex

This recipe creates GitHub Releases for TransFlex alpha builds.

## Unsigned Alpha Release

Create and push a release tag:

```bash
git tag v0.2.0
git push origin v0.2.0
```

For prereleases, use a semantic prerelease suffix:

```bash
git tag v0.2.0-alpha.1
git push origin v0.2.0-alpha.1
```

The `Release` GitHub Actions workflow builds `DerivedData/Build/Products/Release/TransFlex.app`, verifies macOS minimum `13.0`, verifies `arm64` and `x86_64`, packages the app, writes a checksum, uploads a 7-day workflow artifact, and creates or updates a GitHub Release. Stable tags such as `v0.1.0` publish a regular release; prerelease tags such as `v0.1.0-alpha.1` publish a prerelease.

Unsigned alpha asset names:

```text
TransFlex-0.2.0-macos-universal-unsigned.zip
TransFlex-0.2.0-macos-universal-unsigned.zip.sha256
```

Release notes must state:

- Requires macOS 13 Ventura or later.
- Universal app for Intel and Apple Silicon.
- The alpha artifact is unsigned and not notarized.

## Manual Dispatch

Use the `Release` workflow in GitHub Actions when rebuilding an existing tag.

Inputs:

| Input | Value |
|---|---|
| `version` | Semantic version without leading `v`, such as `0.2.0` or `0.2.0-alpha.1`. |
| `draft` | Use `false` to publish immediately, or `true` when reviewing a draft. |
| `prerelease` | Use `false` for stable tags such as `0.1.0`; use `true` for versions such as `0.1.0-alpha.1`. |
| `signed` | Keep `false` for unsigned alpha artifacts. |

Manual dispatch requires the matching remote tag to exist. For `version=0.2.0`, the workflow checks for `refs/tags/v0.2.0`; if the GitHub Release already exists, it re-uploads the zip and checksum with clobber semantics and updates the release notes/title/state.

## Review And Publish

Before publishing the draft GitHub Release:

1. Confirm the asset name includes `macos-universal-unsigned`.
2. Confirm the `.sha256` asset is present.
3. Confirm release notes state macOS 13 Ventura or later.
4. Confirm release notes state Intel and Apple Silicon support.
5. Confirm release notes state unsigned and not notarized for phase 1 artifacts.

## Signed And Notarized Release

Signed releases require these GitHub Secrets:

| Secret | Purpose |
|---|---|
| `APPLE_DEVELOPER_ID_APPLICATION_CERT_BASE64` | Base64 encoded `.p12` Developer ID Application certificate. |
| `APPLE_DEVELOPER_ID_APPLICATION_CERT_PASSWORD` | Password for the `.p12`. |
| `APPLE_TEAM_ID` | Apple Developer Team ID. |
| `APPLE_NOTARY_KEY_ID` | App Store Connect API key ID. |
| `APPLE_NOTARY_ISSUER_ID` | App Store Connect issuer ID. |
| `APPLE_NOTARY_KEY_BASE64` | Base64 encoded `.p8` API key. |

When the secrets are configured, run the `Release` workflow with `signed=true`. The workflow imports the certificate into a temporary keychain, builds with Developer ID signing and hardened runtime, verifies the signature, submits the app to Apple notarization, staples the ticket, verifies Gatekeeper assessment, and uploads:

```text
TransFlex-0.2.0-macos-universal-signed-notarized.zip
TransFlex-0.2.0-macos-universal-signed-notarized.zip.sha256
```

Do not print decoded certificate or API key material in logs. The workflow cleanup step removes temporary signing files and the temporary keychain.
