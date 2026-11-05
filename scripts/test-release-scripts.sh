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
  local appcast="$case_dir/appcast.xml"
  local notes="$case_dir/release-notes.md"
  local log="$case_dir/gh.log"

  touch "$artifact" "$checksum" "$appcast"
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
    APPCAST="$appcast" \
    DRAFT_RELEASE="$draft_release" \
    PRERELEASE_RELEASE="$prerelease_release" \
    scripts/publish-release.sh > "$case_dir/publish.out"

  printf '%s\n' "$log"
}

test_release_create_path() {
  local log
  log="$(run_publish_case create false)"

  assert_file_contains "$log" "release view v0.2.0"
  assert_file_contains "$log" "release create v0.2.0 $TEST_TMP/create/TransFlex-0.2.0-macos-universal-unsigned.zip $TEST_TMP/create/TransFlex-0.2.0-macos-universal-unsigned.zip.sha256 $TEST_TMP/create/appcast.xml --verify-tag --title TransFlex 0.2.0 --notes-file $TEST_TMP/create/release-notes.md --draft --prerelease"
  assert_file_not_contains "$log" "release upload"
  assert_file_not_contains "$log" "release edit"
}

test_release_update_path() {
  local log
  log="$(run_publish_case update true)"

  assert_file_contains "$log" "release view v0.2.0"
  assert_file_contains "$log" "release upload v0.2.0 $TEST_TMP/update/TransFlex-0.2.0-macos-universal-unsigned.zip $TEST_TMP/update/TransFlex-0.2.0-macos-universal-unsigned.zip.sha256 $TEST_TMP/update/appcast.xml --clobber"
  assert_file_contains "$log" "release edit v0.2.0 --title TransFlex 0.2.0 --notes-file $TEST_TMP/update/release-notes.md --draft --prerelease"
  assert_file_not_contains "$log" "release create"
}

test_regular_release_create_path() {
  local log
  log="$(run_publish_case stable-create false false false)"

  assert_file_contains "$log" "release view v0.2.0"
  assert_file_contains "$log" "release create v0.2.0 $TEST_TMP/stable-create/TransFlex-0.2.0-macos-universal-unsigned.zip $TEST_TMP/stable-create/TransFlex-0.2.0-macos-universal-unsigned.zip.sha256 $TEST_TMP/stable-create/appcast.xml --verify-tag --title TransFlex 0.2.0 --notes-file $TEST_TMP/stable-create/release-notes.md"
  assert_file_not_contains "$log" "--draft"
  assert_file_not_contains "$log" "--prerelease"
  assert_file_not_contains "$log" "release upload"
  assert_file_not_contains "$log" "release edit"
}

test_regular_release_update_path() {
  local log
  log="$(run_publish_case stable-update true false false)"

  assert_file_contains "$log" "release view v0.2.0"
  assert_file_contains "$log" "release upload v0.2.0 $TEST_TMP/stable-update/TransFlex-0.2.0-macos-universal-unsigned.zip $TEST_TMP/stable-update/TransFlex-0.2.0-macos-universal-unsigned.zip.sha256 $TEST_TMP/stable-update/appcast.xml --clobber"
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
    -c "Add :SUFeedURL string https://github.com/dratct/TransFlex/releases/latest/download/appcast.xml" \
    -c "Add :SUPublicEDKey string AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=" \
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

write_get_task_allow_entitlements() {
  cat > "$1" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>com.apple.security.get-task-allow</key><true/>
</dict></plist>
PLIST
}

test_verify_rejects_signed_app_with_get_task_allow() {
  local case_dir="$TEST_TMP/verify-signed-get-task-allow"
  mkdir -p "$case_dir"
  write_get_task_allow_entitlements "$case_dir/app.entitlements"
  make_fixture_app "$case_dir/TransFlex.app" dataProtection "$case_dir/app.entitlements"
  run_verify "$case_dir/TransFlex.app" --signed-team TEAM123
  [[ "$verify_status" -ne 0 ]] || fail "signed app requesting get-task-allow should be rejected"
  assert_file_contains "$verify_err" "get-task-allow"
}

# CI builds an ad-hoc Release app, which xcodebuild gives get-task-allow; it is never notarized.
test_verify_accepts_unsigned_app_with_get_task_allow() {
  local case_dir="$TEST_TMP/verify-unsigned-get-task-allow"
  mkdir -p "$case_dir"
  write_get_task_allow_entitlements "$case_dir/app.entitlements"
  make_fixture_app "$case_dir/TransFlex.app" file "$case_dir/app.entitlements"
  run_verify "$case_dir/TransFlex.app"
  [[ "$verify_status" -eq 0 ]] || { cat "$verify_err" >&2; fail "unsigned app with get-task-allow should verify"; }
}

test_verify_rejects_empty_feed_url() {
  local app="$TEST_TMP/verify-no-feed/TransFlex.app"
  make_fixture_app "$app" file
  /usr/libexec/PlistBuddy -c "Set :SUFeedURL ''" "$app/Contents/Info.plist"
  codesign -f -s - "$app" 2>/dev/null
  run_verify "$app"
  [[ "$verify_status" -ne 0 ]] || fail "a release without an update feed should be rejected"
  assert_file_contains "$verify_err" "SUFeedURL"
}

test_verify_rejects_placeholder_public_key() {
  local app="$TEST_TMP/verify-key-placeholder/TransFlex.app"
  make_fixture_app "$app" file
  /usr/libexec/PlistBuddy -c "Set :SUPublicEDKey SPARKLE_PUBLIC_KEY_PENDING" "$app/Contents/Info.plist"
  codesign -f -s - "$app" 2>/dev/null
  run_verify "$app"
  [[ "$verify_status" -ne 0 ]] || fail "a release without the real Sparkle public key should be rejected"
  assert_file_contains "$verify_err" "SUPublicEDKey"
}

test_verify_rejects_a_key_of_the_wrong_length() {
  local app="$TEST_TMP/verify-key-length/TransFlex.app"
  make_fixture_app "$app" file
  /usr/libexec/PlistBuddy -c "Set :SUPublicEDKey AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA" "$app/Contents/Info.plist"
  codesign -f -s - "$app" 2>/dev/null
  run_verify "$app"
  [[ "$verify_status" -ne 0 ]] || fail "a public key that is not 32 bytes of base64 should be rejected"
  assert_file_contains "$verify_err" "SUPublicEDKey"
}

test_verify_rejects_signed_app_missing_a_sparkle_helper() {
  local app="$TEST_TMP/verify-sparkle-missing/TransFlex.app"
  make_fixture_app "$app" dataProtection
  mkdir -p "$app/Contents/Frameworks/Sparkle.framework/Versions/A"
  run_verify "$app" --signed-team TEAM123
  [[ "$verify_status" -ne 0 ]] || fail "a signed app whose Sparkle helpers are missing should be rejected"
  assert_file_contains "$verify_err" "is missing"
}

# Xcode re-signs Sparkle.framework on copy but leaves its helpers ad-hoc; notarization rejects them.
test_verify_rejects_signed_app_with_adhoc_sparkle_helper() {
  local app="$TEST_TMP/verify-sparkle-adhoc/TransFlex.app"
  local helper="$app/Contents/Frameworks/Sparkle.framework/Versions/B/Autoupdate"
  make_fixture_app "$app" dataProtection
  # Added after the app is signed: codesign refuses to seal a half-built framework.
  mkdir -p "$(dirname "$helper")"
  cp /usr/bin/true "$helper"
  codesign -f -s - "$helper" 2>/dev/null
  run_verify "$app" --signed-team TEAM123
  [[ "$verify_status" -ne 0 ]] || fail "a signed app with an ad-hoc Sparkle helper should be rejected"
  assert_file_contains "$verify_err" "Sparkle helper"
}

test_publish_requires_appcast() {
  local case_dir="$TEST_TMP/publish-no-appcast"
  mkdir -p "$case_dir/bin"
  write_fake_gh "$case_dir/bin"
  touch "$case_dir/a.zip" "$case_dir/a.zip.sha256"
  printf 'notes\n' > "$case_dir/notes.md"
  local status
  set +e
  GH_LOG="$case_dir/gh.log" PATH="$case_dir/bin:$PATH" TAG=v0.2.0 VERSION=0.2.0 \
    RELEASE_NOTES="$case_dir/notes.md" ARTIFACT="$case_dir/a.zip" CHECKSUM="$case_dir/a.zip.sha256" \
    scripts/publish-release.sh > /dev/null 2> "$case_dir/err"
  status=$?
  set -e
  [[ "$status" -ne 0 ]] || fail "a release without appcast.xml must not be published"
  assert_file_contains "$case_dir/err" "APPCAST"
  [[ ! -s "$case_dir/gh.log" ]] || fail "publish must stop before calling gh when the appcast is missing"
}

FAKE_ED_KEY="ZmFrZS1wcml2YXRlLWtleS1mb3ItdGVzdHMtb25seQ=="

# A generate_appcast stand-in: logs its arguments, insists on the key on stdin, and writes an
# appcast for the archive in the folder it is given. GENERATE_APPCAST_UNSIGNED drops the signature.
write_fake_generate_appcast() {
  local bin_dir="$1"
  mkdir -p "$bin_dir"
  cat > "$bin_dir/generate_appcast" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" > "$GENERATE_APPCAST_LOG"
key="$(cat)"
[[ "$key" == "$EXPECTED_ED_KEY" ]] || { echo "fake generate_appcast: wrong key on stdin" >&2; exit 3; }
prefix="" output="" folder=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --download-url-prefix) prefix="$2"; shift 2 ;;
    -o) output="$2"; shift 2 ;;
    --ed-key-file|--maximum-versions) shift 2 ;;
    --*) shift ;;
    *) folder="$1"; shift ;;
  esac
done
zip="$(cd "$folder" && ls *.zip)"
notes="${zip%.zip}.md"
[[ -f "$folder/$notes" ]] || { echo "fake generate_appcast: no release notes beside the archive" >&2; exit 4; }
signature=' sparkle:edSignature="c2lnbmF0dXJl"'
[[ -z "${GENERATE_APPCAST_UNSIGNED:-}" ]] || signature=""
cat > "$output" <<XML
<rss><channel><item><sparkle:version>${FAKE_BUILD:-42}</sparkle:version>
<enclosure url="${prefix}${zip}"${signature} length="1"/></item></channel></rss>
XML
EOF
  chmod +x "$bin_dir/generate_appcast"
}

# Sets appcast_status, appcast_dir (holding out, err, args.log and dist/).
run_make_appcast() {
  local name="$1"
  shift
  appcast_dir="$TEST_TMP/$name"
  mkdir -p "$appcast_dir/dist"
  write_fake_generate_appcast "$appcast_dir/bin"
  touch "$appcast_dir/dist/TransFlex-0.5.0-macos-universal-signed-notarized.zip"
  printf '## Changes\n' > "$appcast_dir/notes.md"
  set +e
  env SPARKLE_BIN="$appcast_dir/bin" GENERATE_APPCAST_LOG="$appcast_dir/args.log" \
    EXPECTED_ED_KEY="$FAKE_ED_KEY" SPARKLE_ED_PRIVATE_KEY="$FAKE_ED_KEY" \
    ARTIFACT="$appcast_dir/dist/TransFlex-0.5.0-macos-universal-signed-notarized.zip" \
    RELEASE_NOTES="$appcast_dir/notes.md" TAG=v0.5.0 BUILD_VERSION=42 DIST_DIR="$appcast_dir/dist" \
    GITHUB_OUTPUT="$appcast_dir/github_output" "$@" \
    scripts/make-appcast.sh > "$appcast_dir/out" 2> "$appcast_dir/err"
  appcast_status=$?
  set -e
}

test_make_appcast_points_at_the_tag_and_hides_the_key() {
  run_make_appcast appcast-ok
  [[ "$appcast_status" -eq 0 ]] || { cat "$appcast_dir/err" >&2; fail "make-appcast.sh should succeed"; }
  assert_file_contains "$appcast_dir/args.log" "--ed-key-file -"
  assert_file_contains "$appcast_dir/args.log" "--download-url-prefix https://github.com/dratct/TransFlex/releases/download/v0.5.0/"
  assert_file_contains "$appcast_dir/args.log" "--embed-release-notes"
  assert_file_contains "$appcast_dir/dist/appcast.xml" 'url="https://github.com/dratct/TransFlex/releases/download/v0.5.0/TransFlex-0.5.0-macos-universal-signed-notarized.zip"'
  assert_file_contains "$appcast_dir/github_output" "appcast=$appcast_dir/dist/appcast.xml"
  assert_file_not_contains "$appcast_dir/out" "$FAKE_ED_KEY"
  assert_file_not_contains "$appcast_dir/err" "$FAKE_ED_KEY"
  assert_file_not_contains "$appcast_dir/args.log" "$FAKE_ED_KEY"
}

test_make_appcast_requires_the_key() {
  run_make_appcast appcast-no-key SPARKLE_ED_PRIVATE_KEY=
  [[ "$appcast_status" -ne 0 ]] || fail "make-appcast.sh must fail without SPARKLE_ED_PRIVATE_KEY"
  assert_file_contains "$appcast_dir/err" "SPARKLE_ED_PRIVATE_KEY"
}

test_make_appcast_rejects_an_unsigned_appcast() {
  run_make_appcast appcast-unsigned GENERATE_APPCAST_UNSIGNED=1
  [[ "$appcast_status" -ne 0 ]] || fail "an appcast without an EdDSA signature must be rejected"
  assert_file_contains "$appcast_dir/err" "edSignature"
}

test_make_appcast_rejects_a_wrong_build_version() {
  run_make_appcast appcast-wrong-build FAKE_BUILD=41
  [[ "$appcast_status" -ne 0 ]] || fail "an appcast whose sparkle:version is not the build number must be rejected"
  assert_file_contains "$appcast_dir/err" "sparkle:version"
}

test_release_create_path
test_publish_requires_appcast
test_make_appcast_points_at_the_tag_and_hides_the_key
test_make_appcast_requires_the_key
test_make_appcast_rejects_an_unsigned_appcast
test_make_appcast_rejects_a_wrong_build_version
test_release_update_path
test_verify_rejects_empty_feed_url
test_verify_rejects_placeholder_public_key
test_verify_rejects_signed_app_with_adhoc_sparkle_helper
test_verify_rejects_a_key_of_the_wrong_length
test_verify_rejects_signed_app_missing_a_sparkle_helper
test_regular_release_create_path
test_regular_release_update_path
test_invalid_prerelease_versions_are_rejected
test_package_checksum_uses_downloadable_asset_name
test_verify_accepts_unsigned_app_on_file_keychain
test_verify_rejects_unsigned_app_on_data_protection_keychain
test_verify_rejects_unsigned_app_with_access_group
test_verify_rejects_signed_app_without_profile
test_verify_rejects_signed_app_with_get_task_allow
test_verify_accepts_unsigned_app_with_get_task_allow

echo "==> Release script tests passed"
