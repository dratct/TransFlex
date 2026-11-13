#!/usr/bin/env bash
# Compares the Dev app built on this Mac with a Release app built by CI, and
# lists the code that compiles differently between builds. Exits 1 when the
# two were built with different macOS SDKs, when a probe string is in one
# binary and not the other, or when app code is gated on the toolchain version.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

DEV_APP="DerivedData/Build/Products/Debug/TransFlexDev.app"
RELEASE_APP=""
PROBES=()

usage() {
  cat >&2 <<'EOF'
Usage:
  scripts/check-build-parity.sh --release PATH [--dev PATH] [--probe STRING]...

Options:
  --release PATH   Release app built by CI (a release zip or a workflow artifact, unpacked)
  --dev PATH       Dev app built here (default DerivedData/Build/Products/Debug/TransFlexDev.app)
  --probe STRING   text that must be in both binaries or in neither, such as the
                   selector of an API newer than the deployment target; repeatable
EOF
}

fail() {
  echo "error: $*" >&2
  exit 2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dev|--release|--probe)
      [[ $# -ge 2 ]] || { usage; fail "missing value for '$1'."; }
      case "$1" in
        --dev) DEV_APP="$2" ;;
        --release) RELEASE_APP="$2" ;;
        --probe) PROBES+=("$2") ;;
      esac
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

[[ -n "$RELEASE_APP" ]] || { usage; fail "--release is required."; }
for app in "$DEV_APP" "$RELEASE_APP"; do
  [[ -f "$app/Contents/Info.plist" ]] || fail "no app bundle at '$app'."
done

plist_value() {
  /usr/libexec/PlistBuddy -c "Print :$2" "$1/Contents/Info.plist" 2>/dev/null || echo "-"
}

executable() {
  echo "$1/Contents/MacOS/$(plist_value "$1" CFBundleExecutable)"
}

# The SDK each slice was linked against, as the binary records it.
linked_sdks() {
  otool -l -arch all "$(executable "$1")" | awk '$1 == "sdk" { print $2 }' | sort -u | paste -sd, -
}

entitlement_keys() {
  codesign -d --entitlements - --xml "$1" 2>/dev/null \
    | plutil -convert json -o - - 2>/dev/null \
    | tr ',{' '\n\n' | sed -n 's/^ *"\([^"]*\)" *:.*/\1/p' | sort -u | paste -sd' ' -
}

# A Debug build keeps its code in <name>.debug.dylib beside a stub executable.
probe_count() {
  cat "$1"/Contents/MacOS/* | strings -a | grep -cF -- "$2" || true
}

differences=0

row() {
  local label="$1" dev="$2" release="$3" mark=""
  [[ "$dev" == "$release" ]] || mark="  <- differs"
  printf '%-26s %-34s %-34s%s\n' "$label" "$dev" "$release" "$mark"
}

echo "==> Toolchain"
echo "Dev:     $DEV_APP"
echo "Release: $RELEASE_APP"
printf '%-26s %-34s %-34s\n' "" "Dev" "Release"
for key in DTXcode DTXcodeBuild DTSDKName DTPlatformVersion LSMinimumSystemVersion; do
  row "$key" "$(plist_value "$DEV_APP" "$key")" "$(plist_value "$RELEASE_APP" "$key")"
done
row "linked SDK" "$(linked_sdks "$DEV_APP")" "$(linked_sdks "$RELEASE_APP")"
row "architectures" "$(lipo -archs "$(executable "$DEV_APP")")" "$(lipo -archs "$(executable "$RELEASE_APP")")"

dev_sdk="$(plist_value "$DEV_APP" DTSDKName)"
release_sdk="$(plist_value "$RELEASE_APP" DTSDKName)"
if [[ "${dev_sdk%%.*}" != "${release_sdk%%.*}" ]]; then
  echo "DIFFERENT: Dev is built with $dev_sdk, Release with $release_sdk. What you saw in Dev says nothing about this Release."
  differences=$((differences + 1))
fi

echo
echo "==> Entitlements (Dev and Release differ by design; read the list)"
echo "Dev:     $(entitlement_keys "$DEV_APP")"
echo "Release: $(entitlement_keys "$RELEASE_APP")"

if [[ ${#PROBES[@]} -gt 0 ]]; then
  echo
  echo "==> Probes (is the text in the binary?)"
  for probe in "${PROBES[@]}"; do
    dev_has=no
    release_has=no
    [[ "$(probe_count "$DEV_APP" "$probe")" -eq 0 ]] || dev_has=yes
    [[ "$(probe_count "$RELEASE_APP" "$probe")" -eq 0 ]] || release_has=yes
    row "$probe" "$dev_has" "$release_has"
    if [[ "$dev_has" != "$release_has" ]]; then
      echo "DIFFERENT: '$probe' is compiled into only one of the two."
      differences=$((differences + 1))
    fi
  done
fi

echo
echo "==> Code that compiles differently between builds (TransFlex/Sources)"
grep -rnE '#if +(DEBUG|!DEBUG|canImport|compiler|swift|targetEnvironment|arch)' TransFlex/Sources --include='*.swift' || echo "(none)"
toolchain_gates="$(grep -rnE '#if .*(compiler|swift) *\(' TransFlex/Sources --include='*.swift' || true)"
if [[ -n "$toolchain_gates" ]]; then
  echo "DIFFERENT: app code gated on the toolchain version is left out by an older Xcode without an error:"
  echo "$toolchain_gates"
  differences=$((differences + 1))
fi

echo
echo "==> Run-time checks for a macOS version (each branch needs a look on that macOS)"
grep -rnE '#available|#unavailable|@available\(macOS' TransFlex/Sources --include='*.swift' || echo "(none)"

echo
if [[ "$differences" -gt 0 ]]; then
  echo "==> $differences difference(s) between the Dev and Release builds."
  exit 1
fi
echo "==> Dev and Release builds match on SDK, probes and toolchain gates."
