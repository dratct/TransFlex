#!/usr/bin/env bash
set -euo pipefail

fail() {
  echo "error: $*" >&2
  exit 1
}

SEMVER_PATTERN='^(0|[1-9][0-9]*)[.](0|[1-9][0-9]*)[.](0|[1-9][0-9]*)(-[0-9A-Za-z-]+([.][0-9A-Za-z-]+)*)?$'

event_name="${GITHUB_EVENT_NAME:-}"
ref_type="${GITHUB_REF_TYPE:-}"
ref_name="${GITHUB_REF_NAME:-}"
input_version="${INPUT_VERSION:-}"
build_number="${GITHUB_RUN_NUMBER:-}"

if [[ -z "$build_number" ]]; then
  fail "GITHUB_RUN_NUMBER is required."
fi
if [[ ! "$build_number" =~ ^[0-9]+$ ]]; then
  fail "GITHUB_RUN_NUMBER must be numeric."
fi

case "$event_name" in
  push)
    if [[ "$ref_type" != "tag" ]]; then
      fail "push releases must run from a tag."
    fi
    if [[ ! "$ref_name" =~ ^v(.+)$ ]]; then
      fail "release tags must start with 'v'."
    fi
    tag="$ref_name"
    version="${ref_name#v}"
    ;;
  workflow_dispatch)
    if [[ -z "$input_version" ]]; then
      fail "INPUT_VERSION is required for manual releases."
    fi
    version="$input_version"
    tag="v$version"
    ;;
  *)
    fail "unsupported release event '$event_name'."
    ;;
esac

if [[ ! "$version" =~ $SEMVER_PATTERN ]]; then
  fail "version '$version' must look like 0.2.0 or 0.2.0-alpha.1."
fi

if [[ "$tag" != "v$version" ]]; then
  fail "tag '$tag' does not match version '$version'."
fi

if ! git check-ref-format "refs/tags/$tag"; then
  fail "tag '$tag' is not a valid Git tag name."
fi

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  {
    echo "tag=$tag"
    echo "version=$version"
    echo "build_number=$build_number"
  } >> "$GITHUB_OUTPUT"
else
  printf 'TAG=%s\n' "$tag"
  printf 'VERSION=%s\n' "$version"
  printf 'BUILD_NUMBER=%s\n' "$build_number"
fi
