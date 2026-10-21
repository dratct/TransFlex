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

test_package_checksum_uses_downloadable_asset_name() {
  local case_dir="$TEST_TMP/package-checksum"
  local app="$case_dir/Fake.app"
  local artifact_name="TransFlex-0.2.0-macos-universal-unsigned.zip"
  local checksum_name="$artifact_name.sha256"

  mkdir -p "$app/Contents/MacOS"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$app/Contents/MacOS/TransFlex"
  chmod +x "$app/Contents/MacOS/TransFlex"

  (
    cd "$case_dir"
    VERSION="0.2.0" \
      SIGNING_LABEL="unsigned" \
      "$ROOT_DIR/scripts/package-release.sh" "Fake.app" > package.out
  )

  assert_file_contains "$case_dir/dist/$checksum_name" "$artifact_name"
  assert_file_not_contains "$case_dir/dist/$checksum_name" "dist/$artifact_name"

  mkdir -p "$case_dir/download"
  cp "$case_dir/dist/$artifact_name" "$case_dir/dist/$checksum_name" "$case_dir/download/"

  (
    cd "$case_dir/download"
    shasum -a 256 -c "$checksum_name" >/dev/null
  )
}

# An ad-hoc signed bundle shaped like TransFlex.app; /usr/bin/true stands in for the binary.
make_fixture_app() {
  local app="$1" backend="$2" entitlements="${3:-}"

  mkdir -p "$app/Contents/MacOS"
  cp /usr/bin/true "$app/Contents/MacOS/TransFlex"
  local plist="$app/Contents/Info.plist"
  /usr/libexec/PlistBuddy \
    -c "Add :CFBundleIdentifier string io.aiaz.transflex" \
    -c "Add :CFBundleExecutable string TransFlex" \
    -c "Add :LSMinimumSystemVersion string 13.0" \
    -c "Add :CFBundleShortVersionString string 0.2.0" \
    -c "Add :CFBundleVersion string 7" \
    -c "Add :TransFlexKeychainBackend string $backend" \
    "$plist" >/dev/null
  if [[ -n "$entitlements" ]]; then
    codesign -f -s - --entitlements "$entitlements" "$app" 2>/dev/null
  else
    codesign -f -s - "$app" 2>/dev/null
  fi
}

# Runs verify-release-app.sh on the fixture; sets verify_status and verify_err.
run_verify() {
  local app="$1"
  shift
  verify_err="$(dirname "$app")/verify.err"
  set +e
  scripts/verify-release-app.sh --app "$app" --expected-archs x86_64 "$@" > /dev/null 2> "$verify_err"
  verify_status=$?
  set -e
}

test_verify_accepts_unsigned_app_on_file_keychain() {
  local app="$TEST_TMP/verify-unsigned/TransFlex.app"
  make_fixture_app "$app" file
  run_verify "$app"
  [[ "$verify_status" -eq 0 ]] || { cat "$verify_err" >&2; fail "unsigned app on the file keychain should verify"; }
}

test_verify_rejects_unsigned_app_on_data_protection_keychain() {
  local app="$TEST_TMP/verify-unsigned-dp/TransFlex.app"
  make_fixture_app "$app" dataProtection
  run_verify "$app"
  [[ "$verify_status" -ne 0 ]] || fail "unsigned app on the data protection keychain should be rejected"
  assert_file_contains "$verify_err" "must use TransFlexKeychainBackend 'file'"
}

test_verify_rejects_unsigned_app_with_access_group() {
  local case_dir="$TEST_TMP/verify-unsigned-group"
  mkdir -p "$case_dir"
  cat > "$case_dir/app.entitlements" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>keychain-access-groups</key><array><string>TEAM123.io.aiaz.transflex</string></array>
</dict></plist>
PLIST
  make_fixture_app "$case_dir/TransFlex.app" file "$case_dir/app.entitlements"
  run_verify "$case_dir/TransFlex.app"
  [[ "$verify_status" -ne 0 ]] || fail "unsigned app claiming a keychain access group should be rejected"
  assert_file_contains "$verify_err" "must not claim keychain-access-groups"
}

test_verify_rejects_signed_app_without_profile() {
  local app="$TEST_TMP/verify-signed-no-profile/TransFlex.app"
  make_fixture_app "$app" dataProtection
  run_verify "$app" --signed-team TEAM123
  [[ "$verify_status" -ne 0 ]] || fail "signed app without an embedded profile should be rejected"
  assert_file_contains "$verify_err" "no embedded.provisionprofile"
}

test_release_create_path
test_release_update_path
test_regular_release_create_path
test_regular_release_update_path
test_invalid_prerelease_versions_are_rejected
test_package_checksum_uses_downloadable_asset_name
test_verify_accepts_unsigned_app_on_file_keychain
test_verify_rejects_unsigned_app_on_data_protection_keychain
test_verify_rejects_unsigned_app_with_access_group
test_verify_rejects_signed_app_without_profile

echo "==> Release script tests passed"
