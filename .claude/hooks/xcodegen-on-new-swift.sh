#!/usr/bin/env bash
# PostToolUse(Write): a new .swift file is invisible to xcodebuild until the
# project is regenerated, so `make test` would silently skip new tests.
set -euo pipefail
file=$(jq -r '.tool_input.file_path // empty')
root="${CLAUDE_PROJECT_DIR:-$(pwd)}"
case "$file" in
  "$root"/TransFlex/*.swift|"$root"/TransFlexTests/*.swift) ;;
  *) exit 0 ;;
esac
cd "$root"
xcodegen generate --quiet
