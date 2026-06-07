# Release TransFlex

This document is the operating process for TransFlex releases. The current
release system is tag-driven: a `v*` tag triggers the GitHub Actions `Release`
workflow, which builds the app, verifies the bundle, packages a zip plus SHA-256
checksum, and creates or updates the GitHub Release.

Use this process for every public alpha release. Do not move or reuse release
tags after publication; publish a new tag instead.

## Release Policy

TransFlex is in active alpha. The default public artifact is an unsigned
unnotarized universal macOS app. Signed and notarized artifacts are supported by
the workflow, but only when Apple Developer ID and notary secrets are configured.

Release tags must be semantic versions with a leading `v`:

```text
v0.2.0
v0.2.0-alpha.1
```

Use these release types:

| Release type | Example tag | GitHub Release state | Use when |
|---|---|---|---|
| No app release | none | none | Changes are docs, CI, or tooling only. |
| Alpha prerelease | `v0.2.0-alpha.1` | prerelease | You want testers to validate a build before a regular alpha. |
| Public alpha | `v0.2.0` | regular release | The build is ready for normal alpha users. |
| Signed/notarized rebuild | existing tag | manual workflow result | Apple signing secrets are available and the same tag needs a trusted artifact. |

## Release Gates

Every app release must pass these gates:

1. Scope is frozen and merged to `main`.
2. Working tree is clean.
3. Release proposal has been reviewed.
4. CI is green for the commit being tagged.
5. Local test and release build pass, or the release owner explicitly accepts
   using GitHub Actions as the build authority.
6. GitHub Release assets and notes are reviewed after the workflow finishes.

Do not release directly from uncommitted local changes. The release manager
skill must report a dirty working tree, but uncommitted changes are not included
in the release tag.

## Plan The Release

Use the project-local `transflex-release-manager` skill in Codex CLI or Claude
Code before tagging. Ask the agent to prepare a release proposal from the repo
root, for example:

```text
Use the transflex-release-manager skill to prepare the next TransFlex release proposal.
```

The skill is installed for both agent surfaces:

```text
.codex/skills/transflex-release-manager/SKILL.md
.claude/skills/transflex-release-manager/SKILL.md
```

The skill must inspect the latest SemVer tag, commits, changed files, diff,
release workflow, packaging scripts, and current platform docs when needed. It
returns an advisory proposal only; it does not create tags, push, or publish
releases.

The proposal should include:

- Suggested bump: `none`, `patch`, `minor`, or `major`.
- Suggested version and tag.
- Changed files and commits since the previous tag.
- Draft release notes.
- Exact tag commands to run after approval.

Version bump rules:

| Change type | Suggested bump |
|---|---|
| No commits since the latest release tag | `none` |
| Docs, workflow, or tooling-only changes | `none` |
| UI polish, branding, bug fixes, tests, or maintenance | `patch` |
| `feat:` conventional commits | `minor` |
| `BREAKING CHANGE` or `type!:` before `1.0.0` | `minor` |
| `BREAKING CHANGE` or `type!:` at or after `1.0.0` | `major` |

If the agent's recommendation is too conservative or too aggressive, record the
reason in the release notes and use the version/tag approved by the release
owner.

## Standard Alpha Flow

Start from `main` after the change set has been merged:

```bash
git switch main
git pull --ff-only
git status --short
```

The status output must be empty before tagging.

Generate and review the AI-assisted proposal using the
`transflex-release-manager` skill. Keep any reusable release notes in the
GitHub Release draft or a local `dist/release-notes-draft.md` file if needed.

Run the local verification gate:

```bash
make test
make release
scripts/verify-release-app.sh \
  --app DerivedData/Build/Products/Release/TransFlex.app \
  --expected-min-macos 13.0
```

Confirm the latest CI run on `main` is green. Then create and push the approved
tag:

```bash
git tag v0.2.0
git push origin v0.2.0
```

For prereleases, use a semantic prerelease suffix:

```bash
git tag v0.2.0-alpha.1
git push origin v0.2.0-alpha.1
```

Tag pushes publish immediately. A stable tag such as `v0.2.0` creates a regular
GitHub Release. A prerelease tag such as `v0.2.0-alpha.1` creates a prerelease.

The `Release` GitHub Actions workflow checks out the tag, runs tests, builds
`DerivedData/Build/Products/Release/TransFlex.app`, verifies macOS minimum
`13.0`, verifies `arm64` and `x86_64`, packages the app, writes a checksum,
uploads a 7-day workflow artifact, and creates or updates the GitHub Release.

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

Use the `Release` workflow in GitHub Actions when rebuilding an existing tag or
when you want a draft release for review before publication.

Inputs:

| Input | Value |
|---|---|
| `version` | Semantic version without leading `v`, such as `0.2.0` or `0.2.0-alpha.1`. |
| `draft` | Use `true` to review a draft, or `false` to publish immediately. |
| `prerelease` | Use `false` for stable tags such as `0.1.0`; use `true` for versions such as `0.1.0-alpha.1`. |
| `signed` | Use `false` for unsigned alpha artifacts; use `true` only after signing secrets are configured. |

Manual dispatch requires the matching remote tag to exist. For
`version=0.2.0`, the workflow checks for `refs/tags/v0.2.0`. If the GitHub
Release already exists, it re-uploads the zip and checksum with clobber
semantics and updates the release notes, title, draft state, and prerelease
state.

Use manual dispatch carefully. Rebuilding the same tag can replace release
assets, so confirm the workflow run belongs to the intended tag before
publishing or updating a release.

## Review And Publish

After the workflow finishes, review the GitHub Release before announcing it:

1. Confirm the release tag matches the approved proposal.
2. Confirm the asset name includes `macos-universal-unsigned` or
   `macos-universal-signed-notarized`.
3. Confirm the `.sha256` asset is present.
4. Confirm release notes state macOS 13 Ventura or later.
5. Confirm release notes state Intel and Apple Silicon support.
6. Confirm release notes correctly state whether the artifact is unsigned or
   signed and notarized.
7. Download the zip and checksum from the GitHub Release.
8. Verify the checksum:

```bash
shasum -a 256 -c TransFlex-0.2.0-macos-universal-unsigned.zip.sha256
```

For unsigned alpha builds, expect Gatekeeper to warn testers because the app is
not notarized. For signed/notarized builds, also verify:

```bash
unzip TransFlex-0.2.0-macos-universal-signed-notarized.zip
codesign --verify --deep --strict --verbose=2 TransFlex.app
xcrun stapler validate TransFlex.app
spctl --assess --type execute --verbose TransFlex.app
```

If the release was created as a draft, publish it only after these checks pass.

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

When the secrets are configured, run the `Release` workflow with `signed=true`.
The workflow imports the certificate into a temporary keychain, builds with
Developer ID signing and hardened runtime, verifies the signature, submits the
app to Apple notarization, staples the ticket, verifies Gatekeeper assessment,
and uploads:

```text
TransFlex-0.2.0-macos-universal-signed-notarized.zip
TransFlex-0.2.0-macos-universal-signed-notarized.zip.sha256
```

Do not print decoded certificate or API key material in logs. The workflow
cleanup step removes temporary signing files and the temporary keychain.

## Hotfix Flow

Use a hotfix when the latest public alpha has a focused regression that should
ship before the next planned release.

1. Branch from `main` if the fix is already safe there, or from the latest
   release tag when `main` contains unrelated risky work.
2. Apply only the fix, tests, and necessary release notes.
3. Run `make test`.
4. Merge the hotfix to `main`.
5. Use the `transflex-release-manager` skill to confirm the patch bump and
   draft focused hotfix notes.
6. Tag the next patch version, such as `v0.2.1`.
7. After release, ensure the fix is present on `main`.

Do not reuse the broken release tag for a hotfix.

## Rollback Or Bad Release

Do not move a published tag. Prefer one of these recovery paths:

| Situation | Response |
|---|---|
| Release notes are wrong, binary is correct | Edit the GitHub Release notes only. |
| Artifact upload failed before announcement | Rerun manual dispatch for the same tag and keep the release as draft until verified. |
| Published artifact is bad | Mark the release notes with a warning, publish a fixed patch tag, and announce the replacement. |
| Secret exposure or malicious artifact | Remove affected assets, revoke exposed credentials, publish an incident note, and ship a clean replacement tag. |

If the bad release is marked as `Latest`, update the GitHub Release state after
the replacement is available so users land on the safe build.

## Release Owner Checklist

Use this checklist as the final release runbook:

```text
[ ] main is up to date
[ ] working tree is clean
[ ] transflex-release-manager proposal reviewed
[ ] release notes reviewed
[ ] make test passed
[ ] make release passed
[ ] scripts/verify-release-app.sh passed
[ ] CI is green on the tagged commit
[ ] tag pushed
[ ] Release workflow completed
[ ] zip asset uploaded
[ ] sha256 asset uploaded
[ ] release notes compatibility section is correct
[ ] downloaded checksum verifies
[ ] signed/notarized checks passed, if applicable
[ ] release announcement posted, if applicable
```

## Source Of Truth

For release mechanics, prefer the repo's automation over memory:

- `.github/workflows/release.yml` defines tag triggers, manual dispatch inputs,
  signing behavior, notarization, packaging, artifact upload, and GitHub Release
  publication.
- `.codex/skills/transflex-release-manager/SKILL.md` and
  `.claude/skills/transflex-release-manager/SKILL.md` define the AI-assisted
  release proposal workflow.
- `scripts/resolve-release-version.sh` defines accepted release version formats.
- `scripts/build.sh` defines build and signing modes.
- `scripts/verify-release-app.sh` defines bundle verification.
- `scripts/package-release.sh` defines artifact names and checksums.
- `scripts/publish-release.sh` defines create/update behavior for GitHub
  Releases.
