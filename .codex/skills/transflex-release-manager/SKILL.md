---
name: transflex-release-manager
description: >-
  Manage TransFlex releases as an AI agent workflow. Use when preparing,
  reviewing, or validating a TransFlex release in Codex CLI or Claude Code:
  release proposals, version bump decisions, release notes, tag approval
  commands, GitHub Release checks, hotfix/rollback decisions, signed/notarized
  release review, and release-process drift detection.
---

# TransFlex Release Manager

Use this skill to act as the release manager for TransFlex. This is an agent
workflow, not a wrapper around an AI release script. You may run local commands
to gather evidence, but your release judgment must come from inspecting the repo,
the current diff, release docs, workflow files, and current external docs when
the answer depends on changing platform behavior.

## Core Rules

- Keep this release workflow neutral for open-source use. Do not hard-code
  natural language, locale, personal tone, or maintainer coordination
  preferences in this skill.
- Do not create tags, push tags, publish releases, edit GitHub Releases, or run
  destructive git commands unless the release operator explicitly approves that
  exact action.
- Do not use `make release-plan-ai` or any script that calls an AI API as the
  release authority. If such a script exists, treat it as legacy or advisory.
- Do not release from uncommitted local changes. Dirty worktrees are useful for
  review, but only committed code can be tagged.
- Always use `git diff --color=never --no-ext-diff` and the same flags for
  diff-producing commands such as `git show` and `git log -p`.
- Research current docs before making claims about GitHub Actions runners,
  GitHub Releases, macOS signing/notarization, Apple notary tooling, OpenAI
  models/APIs, or any other time-sensitive release dependency.
- Keep generated release notes grounded in commits, changed files, and diff
  evidence. Do not invent shipped features.
- Preserve local changes. If the worktree is dirty, identify which changes are
  relevant and avoid reverting unrelated files.

## Evidence To Gather

Start every release review from the repo root and inspect:

```bash
git status --short
git branch --show-current
git tag --list 'v*' --sort=-v:refname
git log --color=never --no-ext-diff --oneline --decorate -n 20
```

Then inspect the release sources of truth that exist in this repo:

```bash
sed -n '1,260p' docs/how-to/release.md
sed -n '1,320p' .github/workflows/release.yml
sed -n '1,220p' scripts/build.sh
sed -n '1,220p' scripts/resolve-release-version.sh
sed -n '1,220p' scripts/package-release.sh
sed -n '1,220p' scripts/publish-release.sh
sed -n '1,260p' scripts/verify-release-app.sh
```

For changes since the latest release tag, inspect commits, files, and diff:

```bash
git diff --color=never --no-ext-diff --name-only <tag>..HEAD
git log --color=never --no-ext-diff --format='%h %s' <tag>..HEAD
git diff --color=never --no-ext-diff --find-renames <tag>..HEAD
```

If the worktree itself is under review, also inspect:

```bash
git diff --color=never --no-ext-diff --stat
git diff --color=never --no-ext-diff
```

## Version Decision

Use the latest SemVer tag merged into `HEAD` as the baseline unless the release
operator explicitly chooses another tag.

Recommend:

- `none` when there are no app changes, or changes are docs, CI, workflow, or
  tooling only.
- `patch` for bug fixes, UI polish, branding updates, tests, refactors, and
  maintenance that affects the app but does not add a new user-facing feature.
- `minor` for `feat:` commits or meaningful new app capability before `1.0.0`.
- `minor` for breaking changes before `1.0.0`.
- `major` for breaking changes at or after `1.0.0`.

When commit messages are not conventional, infer from the diff and explain the
inference. If evidence is mixed, present the conservative recommendation and the
alternative.

## Release Review Output

Return concise Markdown with these sections:

1. `Recommendation`
   - Suggested bump, version, and tag.
   - Whether this should be a prerelease, regular alpha, hotfix, or no release.
2. `Evidence`
   - Latest tag, current branch, worktree state, commit range, changed files
     summary, and notable risk areas.
3. `Release Notes Draft`
   - Highlights grounded in commits/diff.
   - Compatibility notes: macOS 13 Ventura or later, universal Intel/Apple
     Silicon support, and unsigned vs signed/notarized status.
4. `Required Gates`
   - Commands/checks to run before tagging.
   - CI or GitHub Release checks that cannot be verified locally.
5. `Approval Commands`
   - Exact tag commands only after making clear they require release operator
     approval.
   - Never imply the release has already been created.

## Release Artifact Writing

When drafting release notes, approval comments, workflow comments, or GitHub
Release text:

- Write for a public open-source audience, not for a specific maintainer.
- Match the structure and terminology of existing project release artifacts
  when they are available.
- Keep claims factual, evidence-backed, and scoped to committed changes.
- Separate shipped changes from verification status, unresolved risks, and
  required operator actions.
- Avoid personal voice, private coordination preferences, and conversational
  filler in release artifacts.

## Verification Gates

Before recommending a tag as ready, require:

```bash
make test
make release
scripts/verify-release-app.sh \
  --app DerivedData/Build/Products/Release/TransFlex.app \
  --expected-min-macos 13.0
```

If these cannot run locally, state why and treat GitHub Actions as the build
authority only if the release operator explicitly accepts that.

When checking CI with GitHub CLI, resolve the release commit to its full
40-character SHA first. Do not rely on a short hash with `gh run list --commit`;
it can return an empty result even when the branch run exists.

```bash
release_sha="$(git rev-parse HEAD)"
gh run list \
  --commit "$release_sha" \
  --limit 5 \
  --json databaseId,headSha,status,conclusion,workflowName,createdAt,url
```

If the commit filter returns no runs, cross-check the latest branch run and only
accept it when `headSha` exactly matches the full release SHA:

```bash
branch="$(git branch --show-current)"
gh run list \
  --branch "$branch" \
  --limit 10 \
  --json databaseId,headSha,status,conclusion,workflowName,createdAt,url
```

For release assets, require:

```bash
shasum -a 256 -c TransFlex-<version>-macos-universal-<label>.zip.sha256
```

For signed/notarized artifacts, also require:

```bash
codesign --verify --deep --strict --verbose=2 TransFlex.app
xcrun stapler validate TransFlex.app
spctl --assess --type execute --verbose TransFlex.app
```

## Hotfix And Rollback

- Never move or reuse a published release tag.
- For a bad binary, recommend a new patch tag and a warning in the bad release
  notes.
- For wrong notes with a correct binary, edit only the GitHub Release notes.
- For failed upload before announcement, rerun the release workflow for the same
  existing tag and keep the release draft until verified.
- For credential exposure or malicious artifact risk, remove affected assets,
  revoke exposed credentials, document the incident, and publish a clean
  replacement tag.

## Drift Detection

If docs, scripts, workflow files, README, and this skill disagree:

1. Name the mismatch.
2. Identify the most authoritative source for the specific behavior.
3. Ask whether to update the stale source, or update it directly if the release
   task clearly includes maintaining release workflow documentation.
