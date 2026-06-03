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

test_versioned_xcode_app_name_is_accepted

echo "==> Build script tests passed"
