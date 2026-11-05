#!/usr/bin/env bash
# Xcode build phase: re-signs the helpers inside Sparkle.framework with the app's identity.
# Code Sign on Copy re-signs the framework only; its XPC services, Autoupdate and Updater.app
# stay ad-hoc, which notarization rejects. Signed inside-out, never with --deep.
set -euo pipefail

identity="${EXPANDED_CODE_SIGN_IDENTITY:-}"
if [[ "${CONFIGURATION:-}" != "Release" || -z "$identity" || "$identity" == "-" ]]; then
  echo "sign-sparkle: skipped (configuration ${CONFIGURATION:-unset}, identity '${identity}')"
  exit 0
fi

framework="$TARGET_BUILD_DIR/$FRAMEWORKS_FOLDER_PATH/Sparkle.framework"
if [[ ! -d "$framework" ]]; then
  echo "error: Sparkle.framework not found at '$framework'." >&2
  exit 1
fi
helpers="$framework/Versions/B"

sign() {
  codesign --force --options runtime --timestamp --sign "$identity" "$@"
}

sign "$helpers/XPCServices/Installer.xpc"
sign --preserve-metadata=entitlements "$helpers/XPCServices/Downloader.xpc"
sign "$helpers/Autoupdate"
sign "$helpers/Updater.app"
sign "$framework"
