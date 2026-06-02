# Security Policy

TransFlex stores provider credentials in macOS Keychain and does not include telemetry or usage tracking.

## Reporting a Vulnerability

Please avoid posting API keys, tokens, crash dumps, request bodies, or screenshots with credentials in public issues. Use the repository's private security advisory flow when it is enabled. If that is not available yet, contact the maintainer privately before sharing sensitive details.

Helpful reports include:

- TransFlex version or commit.
- macOS and Xcode versions.
- A minimal reproduction.
- Whether the issue exposes provider keys, prompt/input text, translation output, local files, or history data.

## Security-Sensitive Areas

- Keychain access in `TransFlex/Sources/Core/Keychain`.
- Provider credential and header storage in `TransFlex/Sources/Providers`.
- Secret redaction in `TransFlex/Sources/Core/Security`.
- History persistence in `TransFlex/Sources/History`.
- Image attachment and file picker flows in `TransFlex/Sources/UI/PopupWindow/Image`.
