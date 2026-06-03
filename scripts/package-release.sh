#!/usr/bin/env bash
set -euo pipefail

APP_PATH="${1:-DerivedData/Build/Products/Release/TransFlex.app}"
VERSION="${VERSION:-}"
SIGNING_LABEL="${SIGNING_LABEL:-unsigned}"
DIST_DIR="${DIST_DIR:-dist}"

fail() {
  echo "error: $*" >&2
  exit 1
}

if [[ -z "$VERSION" ]]; then
  fail "VERSION is required."
fi
if [[ ! "$SIGNING_LABEL" =~ ^[A-Za-z0-9._-]+$ ]]; then
  fail "SIGNING_LABEL may contain only letters, numbers, dot, underscore, and dash."
fi
if [[ ! -d "$APP_PATH" ]]; then
  fail "app bundle not found at '$APP_PATH'."
fi

mkdir -p "$DIST_DIR"

artifact="$DIST_DIR/TransFlex-${VERSION}-macos-universal-${SIGNING_LABEL}.zip"
checksum="$artifact.sha256"

rm -f "$artifact" "$checksum"

ditto -c -k --keepParent "$APP_PATH" "$artifact"
shasum -a 256 "$artifact" > "$checksum"

echo "==> Packaged: $artifact"
echo "==> Checksum: $checksum"

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  {
    echo "artifact=$artifact"
    echo "checksum=$checksum"
  } >> "$GITHUB_OUTPUT"
else
  printf 'ARTIFACT=%s\n' "$artifact"
  printf 'CHECKSUM=%s\n' "$checksum"
fi
