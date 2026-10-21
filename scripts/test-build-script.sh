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

write_fake_toolchain() {
  local bin_dir="$1"
  local developer_dir="$2"
  local log="$3"

  mkdir -p "$bin_dir" "$developer_dir/Platforms/MacOSX.platform" "$developer_dir/Toolchains"

  cat > "$bin_dir/xcode-select" <<EOF
#!/usr/bin/env bash
set -euo pipefail

if [[ "\${1:-}" == "-p" ]]; then
  printf '%s\n' "$developer_dir"
  exit 0
fi

echo "unexpected xcode-select call: \$*" >&2
exit 99
EOF
  chmod +x "$bin_dir/xcode-select"

  cat > "$bin_dir/xcodebuild" <<EOF
#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' "xcodebuild \$*" >> "$log"
if [[ -f Config/DeveloperID.generated.xcconfig ]]; then
  sed 's/^/generated: /' Config/DeveloperID.generated.xcconfig >> "$log"
fi
exit 0
EOF
  chmod +x "$bin_dir/xcodebuild"
}

test_versioned_xcode_app_name_is_accepted() {
  local case_dir="$TEST_TMP/versioned-xcode"
  local developer_dir="$case_dir/Applications/Xcode_26.4.1.app/Contents/Developer"
  local log="$case_dir/xcodebuild.log"

  mkdir -p "$case_dir/bin"
  : > "$log"
  write_fake_toolchain "$case_dir/bin" "$developer_dir" "$log"

  local status
  set +e
  PATH="$case_dir/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
    scripts/build.sh --release --no-gen > "$case_dir/build.out" 2> "$case_dir/build.err"
  status=$?
  set -e

  if [[ "$status" -ne 0 ]]; then
    echo "==> build stdout" >&2
    cat "$case_dir/build.out" >&2
    echo "==> build stderr" >&2
    cat "$case_dir/build.err" >&2
    fail "expected build.sh to accept a versioned Xcode app path"
  fi

  if ! grep -Fq "xcodebuild -scheme TransFlex -configuration Release" "$log"; then
    echo "==> build stdout" >&2
    cat "$case_dir/build.out" >&2
    echo "==> build stderr" >&2
    cat "$case_dir/build.err" >&2
    echo "==> xcodebuild log" >&2
    cat "$log" >&2
    fail "expected build.sh to invoke xcodebuild for a versioned Xcode app path"
  fi
}

# Runs a copy of build.sh in its own root so a Config/Local.xcconfig on this machine cannot leak
# into the result. Sets case_root, case_log and run_status.
run_build_in_case() {
  local name="$1" with_local="$2"
  shift 2
  local case_dir="$TEST_TMP/$name"
  case_root="$case_dir/root"
  case_log="$case_dir/xcodebuild.log"

  mkdir -p "$case_root/scripts" "$case_root/Config" "$case_dir/bin"
  cp scripts/build.sh "$case_root/scripts/build.sh"
  if [[ "$with_local" == "with-local" ]]; then
    echo "DEVELOPMENT_TEAM = TEAM123" > "$case_root/Config/Local.xcconfig"
  fi
  : > "$case_log"
  write_fake_toolchain "$case_dir/bin" "$case_dir/Xcode.app/Contents/Developer" "$case_log"

  set +e
  env PATH="$case_dir/bin:/usr/bin:/bin:/usr/sbin:/sbin" "$@" \
    "$case_root/scripts/build.sh" --no-gen > "$case_dir/build.out" 2> "$case_dir/build.err"
  run_status=$?
  set -e
}

dump_case() {
  echo "==> build stderr" >&2
  cat "$(dirname "$case_log")/build.err" >&2
  echo "==> xcodebuild log" >&2
  cat "$case_log" >&2
}

test_auto_without_local_builds_adhoc() {
  run_build_in_case auto-adhoc without-local
  [[ "$run_status" -eq 0 ]] || { dump_case; fail "auto without Local.xcconfig should build"; }
  grep -Fq "CODE_SIGN_IDENTITY=-" "$case_log" || { dump_case; fail "auto without Local.xcconfig should sign ad-hoc"; }
}

test_auto_with_local_passes_no_signing_settings() {
  run_build_in_case auto-team with-local
  [[ "$run_status" -eq 0 ]] || { dump_case; fail "auto with Local.xcconfig should build"; }
  if grep -Fq "CODE_SIGN" "$case_log"; then
    dump_case
    fail "auto with Local.xcconfig must leave signing to the xcconfig"
  fi
}

test_adhoc_refuses_while_local_exists() {
  run_build_in_case adhoc-conflict with-local TRANSFLEX_SIGNING_MODE=adhoc
  [[ "$run_status" -ne 0 ]] || { dump_case; fail "adhoc with Local.xcconfig should fail"; }
  [[ ! -s "$case_log" ]] || { dump_case; fail "adhoc with Local.xcconfig must not run xcodebuild"; }
}

test_developer_id_requires_profile_name() {
  run_build_in_case devid-no-profile without-local TRANSFLEX_SIGNING_MODE=developer-id \
    DEVELOPER_ID_APPLICATION="Developer ID Application: Test (TEAM123)" APPLE_TEAM_ID=TEAM123
  [[ "$run_status" -ne 0 ]] || { dump_case; fail "developer-id without DEVELOPER_ID_PROFILE_NAME should fail"; }
  [[ ! -s "$case_log" ]] || { dump_case; fail "developer-id without a profile must not run xcodebuild"; }
}

test_developer_id_writes_target_xcconfig_and_removes_it() {
  run_build_in_case devid without-local TRANSFLEX_SIGNING_MODE=developer-id \
    DEVELOPER_ID_APPLICATION="Developer ID Application: Test (TEAM123)" APPLE_TEAM_ID=TEAM123 \
    DEVELOPER_ID_PROFILE_NAME="TransFlex Developer ID"
  [[ "$run_status" -eq 0 ]] || { dump_case; fail "developer-id should build"; }
  grep -Fq "generated: PROVISIONING_PROFILE_SPECIFIER = TransFlex Developer ID" "$case_log" ||
    { dump_case; fail "developer-id should hand the profile to the app target"; }
  grep -Fq "generated: CODE_SIGN_ENTITLEMENTS = TransFlex/TransFlex.signed.entitlements" "$case_log" ||
    { dump_case; fail "developer-id should use the signed entitlements"; }
  grep -Fq "generated: TRANSFLEX_KEYCHAIN_BACKEND = dataProtection" "$case_log" ||
    { dump_case; fail "developer-id should select the data protection keychain"; }
  if grep -Fq "PROVISIONING_PROFILE_SPECIFIER=" "$case_log"; then
    dump_case
    fail "the profile must not go on the command line, where package targets would get it"
  fi
  [[ ! -e "$case_root/Config/DeveloperID.generated.xcconfig" ]] ||
    fail "developer-id should remove the generated xcconfig"
}

test_versioned_xcode_app_name_is_accepted
test_auto_without_local_builds_adhoc
test_auto_with_local_passes_no_signing_settings
test_adhoc_refuses_while_local_exists
test_developer_id_requires_profile_name
test_developer_id_writes_target_xcconfig_and_removes_it

echo "==> Build script tests passed"
