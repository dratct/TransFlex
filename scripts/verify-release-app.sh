#!/usr/bin/env bash
set -euo pipefail

APP_PATH=""
EXPECTED_MIN_MACOS="13.0"
EXPECTED_MARKETING_VERSION=""
EXPECTED_BUILD_VERSION=""
EXPECTED_ARCHS="arm64 x86_64"

usage() {
  cat >&2 <<'EOF'
Usage:
  scripts/verify-release-app.sh --app PATH [options]

Options:
  --expected-min-macos VERSION
  --expected-marketing-version VERSION
  --expected-build-version VERSION
  --expected-archs "arm64 x86_64"
EOF
}

fail() {
  echo "error: $*" >&2
  exit 1
}

require_value() {
  if [[ $# -lt 2 || "$2" == -* ]]; then
    usage
    fail "missing value for '$1'."
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --app)
      require_value "$@"
      APP_PATH="${2:-}"
      shift 2
      ;;
    --expected-min-macos)
      require_value "$@"
      EXPECTED_MIN_MACOS="${2:-}"
      shift 2
      ;;
    --expected-marketing-version)
      require_value "$@"
      EXPECTED_MARKETING_VERSION="${2:-}"
      shift 2
      ;;
    --expected-build-version)
      require_value "$@"
      EXPECTED_BUILD_VERSION="${2:-}"
      shift 2
      ;;
    --expected-archs)
      require_value "$@"
      EXPECTED_ARCHS="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage
      fail "unknown argument '$1'."
      ;;
  esac
done

if [[ -z "$APP_PATH" ]]; then
  usage
  fail "--app is required."
fi

if [[ ! -d "$APP_PATH" ]]; then
  fail "app bundle not found at '$APP_PATH'."
fi

INFO_PLIST="$APP_PATH/Contents/Info.plist"
EXECUTABLE="$APP_PATH/Contents/MacOS/TransFlex"

if [[ ! -f "$INFO_PLIST" ]]; then
  fail "Info.plist not found at '$INFO_PLIST'."
fi
if [[ ! -x "$EXECUTABLE" ]]; then
  fail "executable not found or not executable at '$EXECUTABLE'."
fi

plist_value() {
  /usr/libexec/PlistBuddy -c "Print :$1" "$INFO_PLIST"
}

min_macos="$(plist_value LSMinimumSystemVersion)"
marketing_version="$(plist_value CFBundleShortVersionString)"
build_version="$(plist_value CFBundleVersion)"

if [[ "$min_macos" != "$EXPECTED_MIN_MACOS" ]]; then
  fail "LSMinimumSystemVersion expected '$EXPECTED_MIN_MACOS' but found '$min_macos'."
fi
if [[ -z "$marketing_version" ]]; then
  fail "CFBundleShortVersionString is empty."
fi
if [[ -z "$build_version" ]]; then
  fail "CFBundleVersion is empty."
fi
if [[ -n "$EXPECTED_MARKETING_VERSION" && "$marketing_version" != "$EXPECTED_MARKETING_VERSION" ]]; then
  fail "CFBundleShortVersionString expected '$EXPECTED_MARKETING_VERSION' but found '$marketing_version'."
fi
if [[ -n "$EXPECTED_BUILD_VERSION" && "$build_version" != "$EXPECTED_BUILD_VERSION" ]]; then
  fail "CFBundleVersion expected '$EXPECTED_BUILD_VERSION' but found '$build_version'."
fi

actual_archs="$(lipo -archs "$EXECUTABLE")"
for expected_arch in $EXPECTED_ARCHS; do
  found_arch=false
  for actual_arch in $actual_archs; do
    if [[ "$actual_arch" == "$expected_arch" ]]; then
      found_arch=true
      break
    fi
  done
  if [[ "$found_arch" != true ]]; then
    fail "expected architecture '$expected_arch' in '$EXECUTABLE'; actual architectures: $actual_archs"
  fi
done

echo "==> Verified release app: $APP_PATH"
echo "    LSMinimumSystemVersion=$min_macos"
echo "    CFBundleShortVersionString=$marketing_version"
echo "    CFBundleVersion=$build_version"
echo "    architectures=$EXPECTED_ARCHS"
