#!/usr/bin/env bash
# PreToolUse(Edit|Write): TransFlex.xcodeproj is XcodeGen output, so a hand
# edit is lost on the next `xcodegen generate`.
set -euo pipefail
file=$(jq -r '.tool_input.file_path // empty')
root="${CLAUDE_PROJECT_DIR:-$(pwd)}"
case "$file" in
  "$root"/TransFlex.xcodeproj/*)
    echo "TransFlex.xcodeproj is generated: edit project.yml, then run xcodegen generate." >&2
    exit 2 ;;
esac
