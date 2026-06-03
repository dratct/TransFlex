#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

TEST_TMP="$(mktemp -d)"
trap 'rm -rf "$TEST_TMP"' EXIT

fail() {
  echo "error: $*" >&2
  exit 1
}

assert_file_contains() {
  local file="$1"
  local expected="$2"

  if ! grep -Fq -- "$expected" "$file"; then
    echo "==> $file" >&2
    cat "$file" >&2
    fail "expected '$file' to contain: $expected"
  fi
}

assert_file_not_contains() {
  local file="$1"
  local unexpected="$2"

  if grep -Fq -- "$unexpected" "$file"; then
    echo "==> $file" >&2
    cat "$file" >&2
    fail "expected '$file' not to contain: $unexpected"
  fi
}

write_fake_gh() {
  local bin_dir="$1"

  cat > "$bin_dir/gh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' "$*" >> "$GH_LOG"

if [[ "${1:-}" == "release" && "${2:-}" == "view" ]]; then
  if [[ "${GH_FAKE_RELEASE_EXISTS:-false}" == "true" ]]; then
    exit 0
  fi
  exit 1
fi

if [[ "${1:-}" == "release" && "${2:-}" =~ ^(create|edit|upload)$ ]]; then
  exit 0
fi

echo "unexpected gh call: $*" >&2
exit 99
EOF
  chmod +x "$bin_dir/gh"
}

run_publish_case() {
  local case_name="$1"
  local release_exists="$2"
  local draft_release="${3:-true}"
  local prerelease_release="${4:-true}"
  local case_dir="$TEST_TMP/$case_name"

  mkdir -p "$case_dir/bin"
  write_fake_gh "$case_dir/bin"

  local artifact="$case_dir/TransFlex-0.2.0-macos-universal-unsigned.zip"
  local checksum="$artifact.sha256"
  local notes="$case_dir/release-notes.md"
  local log="$case_dir/gh.log"

  touch "$artifact" "$checksum"
  printf 'release notes\n' > "$notes"
  : > "$log"

  GH_LOG="$log" \
    GH_FAKE_RELEASE_EXISTS="$release_exists" \
    PATH="$case_dir/bin:$PATH" \
    TAG="v0.2.0" \
    VERSION="0.2.0" \
    RELEASE_NOTES="$notes" \
    ARTIFACT="$artifact" \
    CHECKSUM="$checksum" \
    DRAFT_RELEASE="$draft_release" \
    PRERELEASE_RELEASE="$prerelease_release" \
    scripts/publish-release.sh > "$case_dir/publish.out"

  printf '%s\n' "$log"
}

test_release_create_path() {
  local log
  log="$(run_publish_case create false)"

  assert_file_contains "$log" "release view v0.2.0"
  assert_file_contains "$log" "release create v0.2.0 $TEST_TMP/create/TransFlex-0.2.0-macos-universal-unsigned.zip $TEST_TMP/create/TransFlex-0.2.0-macos-universal-unsigned.zip.sha256 --verify-tag --title TransFlex 0.2.0 --notes-file $TEST_TMP/create/release-notes.md --draft --prerelease"
  assert_file_not_contains "$log" "release upload"
  assert_file_not_contains "$log" "release edit"
}

test_release_update_path() {
  local log
  log="$(run_publish_case update true)"

  assert_file_contains "$log" "release view v0.2.0"
  assert_file_contains "$log" "release upload v0.2.0 $TEST_TMP/update/TransFlex-0.2.0-macos-universal-unsigned.zip $TEST_TMP/update/TransFlex-0.2.0-macos-universal-unsigned.zip.sha256 --clobber"
  assert_file_contains "$log" "release edit v0.2.0 --title TransFlex 0.2.0 --notes-file $TEST_TMP/update/release-notes.md --draft --prerelease"
  assert_file_not_contains "$log" "release create"
}

test_regular_release_create_path() {
  local log
  log="$(run_publish_case stable-create false false false)"

  assert_file_contains "$log" "release view v0.2.0"
  assert_file_contains "$log" "release create v0.2.0 $TEST_TMP/stable-create/TransFlex-0.2.0-macos-universal-unsigned.zip $TEST_TMP/stable-create/TransFlex-0.2.0-macos-universal-unsigned.zip.sha256 --verify-tag --title TransFlex 0.2.0 --notes-file $TEST_TMP/stable-create/release-notes.md"
  assert_file_not_contains "$log" "--draft"
  assert_file_not_contains "$log" "--prerelease"
  assert_file_not_contains "$log" "release upload"
  assert_file_not_contains "$log" "release edit"
}

test_regular_release_update_path() {
  local log
  log="$(run_publish_case stable-update true false false)"

  assert_file_contains "$log" "release view v0.2.0"
  assert_file_contains "$log" "release upload v0.2.0 $TEST_TMP/stable-update/TransFlex-0.2.0-macos-universal-unsigned.zip $TEST_TMP/stable-update/TransFlex-0.2.0-macos-universal-unsigned.zip.sha256 --clobber"
  assert_file_contains "$log" "release edit v0.2.0 --title TransFlex 0.2.0 --notes-file $TEST_TMP/stable-update/release-notes.md --draft=false --prerelease=false"
  assert_file_not_contains "$log" "release create"
}

test_invalid_prerelease_versions_are_rejected() {
  local version output status

  for version in "0.2.0-alpha." "0.2.0-alpha..1"; do
    set +e
    output="$(
      GITHUB_EVENT_NAME="workflow_dispatch" \
        INPUT_VERSION="$version" \
        GITHUB_RUN_NUMBER="456" \
        scripts/resolve-release-version.sh 2>&1
    )"
    status=$?
    set -e

    if [[ "$status" -eq 0 ]]; then
      echo "$output" >&2
      fail "expected invalid version '$version' to be rejected"
    fi
  done
}

test_release_create_path
test_release_update_path
test_regular_release_create_path
test_regular_release_update_path
test_invalid_prerelease_versions_are_rejected

echo "==> Release script tests passed"
