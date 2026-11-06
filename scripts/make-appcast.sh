#!/usr/bin/env bash
# Builds appcast.xml for one release archive with Sparkle's generate_appcast.
#
# Installed apps read it from https://github.com/dratct/TransFlex/releases/latest/download/appcast.xml,
# so it lists only this release, points at this tag's asset and carries its EdDSA signature.
# The private key comes from SPARKLE_ED_PRIVATE_KEY and reaches generate_appcast on stdin only.
set -euo pipefail

ARTIFACT="${ARTIFACT:-}"
RELEASE_NOTES="${RELEASE_NOTES:-}"
TAG="${TAG:-}"
BUILD_VERSION="${BUILD_VERSION:-}"
DIST_DIR="${DIST_DIR:-dist}"
SPARKLE_BIN="${SPARKLE_BIN:-DerivedData/SourcePackages/artifacts/sparkle/Sparkle/bin}"
DOWNLOAD_BASE="https://github.com/dratct/TransFlex/releases/download"

fail() {
  echo "error: $*" >&2
  exit 1
}

[[ -n "${SPARKLE_ED_PRIVATE_KEY:-}" ]] || fail "SPARKLE_ED_PRIVATE_KEY is required to sign the update."
[[ -f "$ARTIFACT" ]] || fail "ARTIFACT not found at '$ARTIFACT'."
[[ -f "$RELEASE_NOTES" ]] || fail "RELEASE_NOTES not found at '$RELEASE_NOTES'."
[[ -n "$TAG" ]] || fail "TAG is required."
[[ "$BUILD_VERSION" =~ ^[0-9]+$ ]] || fail "BUILD_VERSION must be the numeric CFBundleVersion."
[[ -x "$SPARKLE_BIN/generate_appcast" ]] || fail "generate_appcast not found in '$SPARKLE_BIN'."

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

archive_name="$(basename "$ARTIFACT")"
cp "$ARTIFACT" "$work/$archive_name"
# generate_appcast takes release notes from a file named like the archive.
cp "$RELEASE_NOTES" "$work/${archive_name%.zip}.md"

mkdir -p "$DIST_DIR"
appcast="$(cd "$DIST_DIR" && pwd)/appcast.xml"

tool_log="$work/generate_appcast.log"
printf '%s' "$SPARKLE_ED_PRIVATE_KEY" | "$SPARKLE_BIN/generate_appcast" \
  --ed-key-file - \
  --download-url-prefix "$DOWNLOAD_BASE/$TAG/" \
  --embed-release-notes \
  --maximum-versions 1 \
  -o "$appcast" \
  "$work" > "$tool_log" 2>&1 || { cat "$tool_log" >&2; fail "generate_appcast failed."; }
cat "$tool_log"

# generate_appcast only warns when the key does not match the app's SUPublicEDKey.
if grep -Fq "does not match key" "$tool_log"; then
  fail "SPARKLE_ED_PRIVATE_KEY is not the key of SUPublicEDKey in the app; installed apps would refuse the update."
fi

grep -Fq "url=\"$DOWNLOAD_BASE/$TAG/$archive_name\"" "$appcast" ||
  fail "appcast.xml does not point at $DOWNLOAD_BASE/$TAG/$archive_name."
grep -Fq "sparkle:edSignature=" "$appcast" ||
  fail "appcast.xml has no sparkle:edSignature; installed apps would refuse the update."
grep -Fq "<sparkle:version>$BUILD_VERSION</sparkle:version>" "$appcast" ||
  fail "appcast.xml sparkle:version is not the build number $BUILD_VERSION."

echo "==> Appcast: $appcast"
if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  echo "appcast=$appcast" >> "$GITHUB_OUTPUT"
fi
