#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/lib/common.sh"
source "$ROOT_DIR/config/packages.conf"

tests_run=0
tests_failed=0
DRY_RUN=0
tmp_dir="$(mktemp -d)"
LOG_FILE="$tmp_dir/test.log"
trap 'rm -rf -- "$tmp_dir"' EXIT

assert() {
    local description="$1"
    shift
    tests_run=$((tests_run + 1))
    if "$@"; then
        printf 'ok - %s\n' "$description"
    else
        printf 'not ok - %s\n' "$description"
        tests_failed=$((tests_failed + 1))
    fi
}

contains_text() {
    [[ "$1" == *"$2"* ]]
}

valid_package_names() {
    local name
    local -a packages=(
        "${SYSTEM_PACKAGES[@]}"
        "${KDE_PACKAGES[@]}"
        "${GAMING_PACKAGES[@]}"
        "${FLATPAK_PACKAGES[@]}"
        "${VIRTUALIZATION_PACKAGES[@]}"
    )
    for name in "${packages[@]}"; do
        [[ "$name" =~ ^[a-zA-Z0-9@._+-]+$ ]] || return 1
    done
}

assert "detects NVIDIA and Intel hybrid graphics" contains_text "$(detect_gpu_vendors $'01:00.0 VGA compatible controller: NVIDIA Corporation (10de:25a9)\n00:02.0 VGA compatible controller: Intel Corporation (8086:46a6)')" "nvidia intel"
assert "reports unknown for unsupported display hardware" contains_text "$(detect_gpu_vendors 'Virtual display adapter')" "unknown"
assert "package configuration contains valid package identifiers" valid_package_names

pacman() {
    [[ "$*" == "-Si known-package" ]]
}
assert "recognizes package availability" package_available known-package
if package_available missing-package; then
    printf 'not ok - rejects unavailable package\n'
    tests_failed=$((tests_failed + 1))
else
    printf 'ok - rejects unavailable package\n'
    tests_run=$((tests_run + 1))
fi

DRY_RUN=1
run touch "$tmp_dir/dry-run-marker"
assert "dry-run command returns successfully without execution" test ! -e "$tmp_dir/dry-run-marker"
DRY_RUN=0

if run false >/dev/null 2>&1; then
    printf 'not ok - propagates command failure\n'
    tests_failed=$((tests_failed + 1))
else
    printf 'ok - propagates command failure\n'
    tests_run=$((tests_run + 1))
fi

curl() { return 7; }
if internet_available >/dev/null 2>&1; then
    printf 'not ok - detects missing internet\n'
    tests_failed=$((tests_failed + 1))
else
    printf 'ok - detects missing internet\n'
    tests_run=$((tests_run + 1))
fi

if (die "expected test failure") >/dev/null 2>&1; then
    printf 'not ok - fatal errors return a failing status\n'
    tests_failed=$((tests_failed + 1))
else
    printf 'ok - fatal errors return a failing status\n'
    tests_run=$((tests_run + 1))
fi

printf 'managed\n' >"$tmp_dir/source"
cp "$tmp_dir/source" "$tmp_dir/target"
assert "managed configuration is idempotent when unchanged" ensure_managed_config "$tmp_dir/source" "$tmp_dir/target"
printf 'user configuration\n' >"$tmp_dir/target"
ensure_managed_config "$tmp_dir/source" "$tmp_dir/target" >/dev/null
assert "existing conflicting configuration is left unchanged" grep -qx 'user configuration' "$tmp_dir/target"

printf '\n%d tests, %d failures\n' "$tests_run" "$tests_failed"
((tests_failed == 0))
