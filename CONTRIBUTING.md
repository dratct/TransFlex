# Contributing

Thanks for helping improve TransFlex. The project is an alpha macOS app, so small, well-tested changes are preferred over broad rewrites.

## Local Setup

```bash
brew install xcodegen
xcodegen generate
make test
```

Use `scripts/build.sh` for a Debug app and `make run` when you want to build and launch the app.

## Pull Request Checklist

- Keep `project.yml` as the source of truth; do not commit `TransFlex.xcodeproj`.
- Run `make test` before opening a PR.
- Add or update focused tests for provider parsing, persistence, security, and translation orchestration changes.
- Update docs when behavior, commands, settings, or architecture changes.
- Keep comments focused on invariants, platform gotchas, and security contracts. Do not add changelog-style comments explaining why a past edit was made.

## Documentation Style

Docs use a Diataxis-lite split:

- Tutorial: guided first success.
- How-to: task recipes.
- Explanation: architecture and tradeoffs.
- Reference: exact commands, paths, IDs, and troubleshooting.

Prefer the smallest page that fits the reader's question.
