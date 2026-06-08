#!/usr/bin/env bash
# TransFlex build wrapper around xcodebuild.
# Regenerates the Xcode project from project.yml (XcodeGen), then builds.
#
# Usage:
#   scripts/build.sh              # Debug build
#   CONFIG=Release scripts/build.sh
#   scripts/build.sh --release
#   scripts/build.sh --no-gen     # Skip xcodegen step (project already current)
#
# Release version overrides:
#   MARKETING_VERSION=0.2.0 CURRENT_PROJECT_VERSION=123 scripts/build.sh --release
#
# Signing modes:
#   TRANSFLEX_SIGNING_MODE=adhoc        # default local/CI unsigned alpha build
#   TRANSFLEX_SIGNING_MODE=developer-id # requires DEVELOPER_ID_APPLICATION and APPLE_TEAM_ID

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

CONFIG="${CONFIG:-Debug}"
SCHEME="${SCHEME:-TransFlex}"
GENERATE=true
SIGNING_MODE="${TRANSFLEX_SIGNING_MODE:-adhoc}"

for arg in "$@"; do
  case "$arg" in
    --no-gen) GENERATE=false ;;
    --release) CONFIG=Release ;;
    *) echo "warn: unknown flag '$arg' (ignored)" >&2 ;;
  esac
done

DEVELOPER_DIR_ACTIVE="$(xcode-select -p 2>/dev/null || true)"
if [[ -z "$DEVELOPER_DIR_ACTIVE" ||
      ! -d "$DEVELOPER_DIR_ACTIVE/Platforms/MacOSX.platform" ||
      ! -d "$DEVELOPER_DIR_ACTIVE/Toolchains" ]]; then
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

VERSION_SETTINGS=()
if [[ -n "${MARKETING_VERSION:-}" ]]; then
  VERSION_SETTINGS+=(MARKETING_VERSION="$MARKETING_VERSION")
fi
if [[ -n "${CURRENT_PROJECT_VERSION:-}" ]]; then
  VERSION_SETTINGS+=(CURRENT_PROJECT_VERSION="$CURRENT_PROJECT_VERSION")
fi

case "$SIGNING_MODE" in
  adhoc)
    SIGNING_SETTINGS=(
      CODE_SIGN_IDENTITY=-
      CODE_SIGNING_REQUIRED=NO
      CODE_SIGNING_ALLOWED=YES
    )
    ;;
  developer-id)
    if [[ -z "${DEVELOPER_ID_APPLICATION:-}" ]]; then
      echo "error: DEVELOPER_ID_APPLICATION is required when TRANSFLEX_SIGNING_MODE=developer-id." >&2
      exit 1
    fi
    if [[ -z "${APPLE_TEAM_ID:-}" ]]; then
      echo "error: APPLE_TEAM_ID is required when TRANSFLEX_SIGNING_MODE=developer-id." >&2
      exit 1
    fi
    SIGNING_SETTINGS=(
      CODE_SIGN_STYLE=Manual
      CODE_SIGN_IDENTITY="$DEVELOPER_ID_APPLICATION"
      CODE_SIGNING_REQUIRED=YES
      CODE_SIGNING_ALLOWED=YES
      DEVELOPMENT_TEAM="$APPLE_TEAM_ID"
      ENABLE_HARDENED_RUNTIME=YES
      OTHER_CODE_SIGN_FLAGS=--timestamp
    )
    ;;
  *)
    echo "error: TRANSFLEX_SIGNING_MODE must be 'adhoc' or 'developer-id'." >&2
    exit 1
    ;;
esac

echo "==> xcodebuild ($CONFIG)"
echo "==> signing mode: $SIGNING_MODE"
if [[ -n "${MARKETING_VERSION:-}" ]]; then
  echo "==> marketing version: $MARKETING_VERSION"
fi
if [[ -n "${CURRENT_PROJECT_VERSION:-}" ]]; then
  echo "==> build version: $CURRENT_PROJECT_VERSION"
fi

BUILD_CMD=(
  xcodebuild
  -scheme "$SCHEME"
  -configuration "$CONFIG"
  -derivedDataPath DerivedData
  -destination 'platform=macOS'
)
if (( ${#VERSION_SETTINGS[@]} > 0 )); then
  BUILD_CMD+=("${VERSION_SETTINGS[@]}")
fi
BUILD_CMD+=("${SIGNING_SETTINGS[@]}" build)

if command -v xcbeautify >/dev/null 2>&1; then
  "${BUILD_CMD[@]}" | xcbeautify
else
  "${BUILD_CMD[@]}"
fi

APP_NAME="$SCHEME"
if [[ "$SCHEME" == "TransFlex" && "$CONFIG" == "Debug" ]]; then
  APP_NAME="TransFlexDev"
fi

APP_PATH="$ROOT_DIR/DerivedData/Build/Products/$CONFIG/$APP_NAME.app"
if [ -d "$APP_PATH" ]; then
  echo "==> Built: $APP_PATH"
fi
