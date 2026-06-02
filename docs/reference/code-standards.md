# Code Standards

## Boundaries

- Keep provider adapters free of UI, clipboard, and history side effects.
- Keep Keychain access in `Core/Keychain` or provider secret stores.
- Keep prompt construction in `Translation/PromptBuilder`.
- Keep generated Xcode state out of git; edit `project.yml` instead.

## Comments

Use comments for:

- Security contracts.
- macOS/AppKit behavior that is hard to infer from code.
- Persistence invariants.
- Protocol or data-format constraints.

Avoid comments for:

- Changelog notes.
- Explanations of why a previous implementation was changed.
- Restating code flow.
- Design preference narration that has no maintenance impact.

## Swift Style

- Prefer small value types and focused helpers over broad manager objects.
- Keep async streams cancellable and propagate `CancellationError` correctly.
- Use `@MainActor` for UI state and AppKit controllers.
- Redact provider errors before logging or showing them.
- Prefer dependency injection in tests for `URLSession`, Keychain service names, stores, and clocks.

## Tests

Add focused tests for:

- Provider request bodies and stream parsing.
- SSE edge cases and retry behavior.
- Keychain and provider metadata migration.
- Prompt building and translation orchestration.
- Popup policies that encode macOS process/window edge cases.

Run:

```bash
make test
```
