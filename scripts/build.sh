#!/usr/bin/env bash
# TransFlex build wrapper around xcodebuild.
# Regenerates the Xcode project from project.yml (XcodeGen), then builds.
#
# Usage:
#   scripts/build.sh              # Debug build
#   CONFIG=Release scripts/build.sh
#   scripts/build.sh --no-gen     # Skip xcodegen step (project already current)

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

CONFIG="${CONFIG:-Debug}"
SCHEME="${SCHEME:-TransFlex}"
GENERATE=true

for arg in "$@"; do
  case "$arg" in
    --no-gen) GENERATE=false ;;
    --release) CONFIG=Release ;;
    *) echo "warn: unknown flag '$arg' (ignored)" >&2 ;;
  esac
done

DEVELOPER_DIR_ACTIVE="$(xcode-select -p 2>/dev/null || true)"
if [[ "$DEVELOPER_DIR_ACTIVE" != *"Xcode.app"* ]]; then
  cat >&2 <<EOF
error: xcode-select is pointing at Command Line Tools, not full Xcode.
       active: ${DEVELOPER_DIR_ACTIVE:-<none>}

       xcodebuild requires the full Xcode app. Fix with:
         sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
         sudo xcodebuild -license accept   # if first run

       If Xcode isn't installed yet, install it from the App Store
       (running 'xcode-select --install' only installs CLT and will not help).
EOF
  exit 1
fi

if $GENERATE; then
  if ! command -v xcodegen >/dev/null 2>&1; then
    echo "error: xcodegen not found. Install via 'brew install xcodegen'." >&2
    exit 1
  fi
  echo "==> xcodegen generate"
  xcodegen generate
fi

echo "==> xcodebuild ($CONFIG)"
BUILD_CMD=(
  xcodebuild
  -scheme "$SCHEME"
  -configuration "$CONFIG"
  -derivedDataPath DerivedData
  -destination 'platform=macOS'
  CODE_SIGN_IDENTITY=-
  CODE_SIGNING_REQUIRED=NO
  CODE_SIGNING_ALLOWED=YES
  build
)

if command -v xcbeautify >/dev/null 2>&1; then
  "${BUILD_CMD[@]}" | xcbeautify
else
  "${BUILD_CMD[@]}"
fi

APP_PATH="$ROOT_DIR/DerivedData/Build/Products/$CONFIG/$SCHEME.app"
if [ -d "$APP_PATH" ]; then
  echo "==> Built: $APP_PATH"
fi
