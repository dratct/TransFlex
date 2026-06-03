#!/usr/bin/env bash
set -euo pipefail

TAG="${TAG:-}"
VERSION="${VERSION:-}"
RELEASE_NOTES="${RELEASE_NOTES:-}"
ARTIFACT="${ARTIFACT:-}"
CHECKSUM="${CHECKSUM:-}"
DRAFT_RELEASE="${DRAFT_RELEASE:-true}"
PRERELEASE_RELEASE="${PRERELEASE_RELEASE:-true}"

fail() {
  echo "error: $*" >&2
  exit 1
}

require_file() {
  local name="$1"
  local path="$2"

  if [[ -z "$path" ]]; then
    fail "$name is required."
  fi
  if [[ ! -f "$path" ]]; then
    fail "$name not found at '$path'."
  fi
}

bool_flag() {
  local name="$1"
  local value="$2"

  case "$value" in
    true) printf '%s\n' "--$name" ;;
    false) ;;
    *) fail "$name must be 'true' or 'false'." ;;
  esac
}

bool_edit_flag() {
  local name="$1"
  local value="$2"

  case "$value" in
    true) printf '%s\n' "--$name" ;;
    false) printf '%s\n' "--$name=false" ;;
    *) fail "$name must be 'true' or 'false'." ;;
  esac
}

if [[ -z "$TAG" ]]; then
  fail "TAG is required."
fi
if [[ -z "$VERSION" ]]; then
  fail "VERSION is required."
fi
require_file "RELEASE_NOTES" "$RELEASE_NOTES"
require_file "ARTIFACT" "$ARTIFACT"
require_file "CHECKSUM" "$CHECKSUM"

create_flags=(
  --verify-tag
  --title "TransFlex $VERSION"
  --notes-file "$RELEASE_NOTES"
)
edit_flags=(
  --title "TransFlex $VERSION"
  --notes-file "$RELEASE_NOTES"
)

draft_create_flag="$(bool_flag draft "$DRAFT_RELEASE")"
prerelease_create_flag="$(bool_flag prerelease "$PRERELEASE_RELEASE")"
draft_edit_flag="$(bool_edit_flag draft "$DRAFT_RELEASE")"
prerelease_edit_flag="$(bool_edit_flag prerelease "$PRERELEASE_RELEASE")"

if [[ -n "$draft_create_flag" ]]; then
  create_flags+=("$draft_create_flag")
fi
if [[ -n "$prerelease_create_flag" ]]; then
  create_flags+=("$prerelease_create_flag")
fi
edit_flags+=("$draft_edit_flag" "$prerelease_edit_flag")

if gh release view "$TAG" >/dev/null 2>&1; then
  echo "==> Updating existing GitHub Release: $TAG"
  gh release upload "$TAG" "$ARTIFACT" "$CHECKSUM" --clobber
  gh release edit "$TAG" "${edit_flags[@]}"
else
  echo "==> Creating GitHub Release: $TAG"
  gh release create "$TAG" "$ARTIFACT" "$CHECKSUM" "${create_flags[@]}"
fi
