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

assert_failure() {
    local description="$1"
    shift
    tests_run=$((tests_run + 1))
    if "$@" >/dev/null 2>&1; then
        printf 'not ok - %s\n' "$description"
        tests_failed=$((tests_failed + 1))
    else
        printf 'ok - %s\n' "$description"
    fi
}

contains_text() {
    [[ "$1" == *"$2"* ]]
}

equals_text() {
    [[ "$1" == "$2" ]]
}

all_modules_have_scripts() {
    local number
    for number in $(all_module_numbers); do
        compgen -G "$ROOT_DIR/modules/${number}-*.sh" >/dev/null || return 1
    done
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

<<<<<<< HEAD
assert "detects NVIDIA and Intel hybrid graphics" contains_text "$(detect_gpu_vendors $'01:00.0 VGA compatible controller: NVIDIA Corporation (10de:25a9)\n00:02.0 VGA compatible controller: Intel Corporation (8086:46a6)')" "nvidia intel"
assert "detects AMD graphics" contains_text "$(detect_gpu_vendors '03:00.0 VGA compatible controller: Advanced Micro Devices, Inc. [AMD/ATI] (1002:73ff)')" "amd"
assert "detects all supported vendors" contains_text "$(detect_gpu_vendors $'NVIDIA (10de:2504)\nAMD (1002:73ff)\nIntel (8086:46a6)')" "nvidia amd intel"
=======
assert "detects NVIDIA and Intel hybrid graphics" equals_text "$(detect_gpu_vendors $'01:00.0 VGA compatible controller: NVIDIA Corporation (10de:25a9)\n00:02.0 VGA compatible controller: Intel Corporation (8086:46a6)')" $'nvidia\nintel'
>>>>>>> 6e9c759 (fix: improve hybrid GPU detection and driver handling)
assert "reports unknown for unsupported display hardware" contains_text "$(detect_gpu_vendors 'Virtual display adapter')" "unknown"
assert "recognizes hybrid graphics" gpu_is_hybrid "nvidia intel"
assert "finds a vendor in a hybrid vendor list" gpu_has_vendor nvidia "intel nvidia"
assert "does not label a single GPU as hybrid" test "$(gpu_is_hybrid 'nvidia' && printf yes || printf no)" = "no"
assert "formats GPU vendor labels" test "$(gpu_vendor_label nvidia intel)" = "NVIDIA, Intel"
assert "parses comma-separated module numbers in dependency order" test "$(parse_module_selection '5,1,3')" = "01 03 05"
assert "parses space-separated module numbers" test "$(parse_module_selection '03 05 06')" = "03 05 06"
assert "expands module ranges" test "$(parse_module_selection '03-05')" = "03 04 05"
assert "accepts the all keyword" test "$(parse_module_selection 'all')" = "01 02 03 04 05 06 07 08"

if parse_module_selection "09" >/dev/null 2>&1; then
    printf 'not ok - rejects out-of-range module numbers\n'
    tests_failed=$((tests_failed + 1))
else
    printf 'ok - rejects out-of-range module numbers\n'
    tests_run=$((tests_run + 1))
fi

if parse_module_selection "03,gpu" >/dev/null 2>&1; then
    printf 'not ok - rejects non-numeric module selections\n'
    tests_failed=$((tests_failed + 1))
else
    printf 'ok - rejects non-numeric module selections\n'
    tests_run=$((tests_run + 1))
fi

assert "package configuration contains valid package identifiers" valid_package_names

assert "lists every module in dependency order" equals_text "$(all_module_numbers)" "01 02 03 04 05 06 07 08"
assert "normalizes and deduplicates module selection" equals_text "$(normalize_module_selection '05,03,03,01')" "05 03 01"
assert "orders module selection by dependency order" equals_text "$(order_module_selection '05 03 01')" "01 03 05"
assert "accepts space-separated module selections" equals_text "$(normalize_module_selection '03 05')" "03 05"
assert_failure "rejects unknown module numbers" normalize_module_selection '09'
assert_failure "rejects empty module selections" normalize_module_selection ''
assert "every registered module has a script" all_modules_have_scripts

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

sudo() {
    if [[ "${1:-}" == "-n" ]]; then
        shift
    fi
    "$@"
}
printf 'managed\n' >"$tmp_dir/source"
cp "$tmp_dir/source" "$tmp_dir/target"
assert "managed configuration is idempotent when unchanged" ensure_managed_config "$tmp_dir/source" "$tmp_dir/target"
printf 'user configuration\n' >"$tmp_dir/target"
ensure_managed_config "$tmp_dir/source" "$tmp_dir/target" >/dev/null
assert "existing conflicting configuration is left unchanged" grep -qx 'user configuration' "$tmp_dir/target"

MANIFEST_FILE="$tmp_dir/rollback/manifest.txt"
BACKUP_DIR="$tmp_dir/backups"
printf 'managed\n' >"$tmp_dir/new-source"
ensure_managed_config "$tmp_dir/new-source" "$tmp_dir/new-target" >/dev/null
assert "new managed configuration is installed" test -f "$tmp_dir/new-target"
assert "created configuration is tracked for rollback" grep -q "^created|$tmp_dir/new-target|" "$MANIFEST_FILE"

printf 'user configuration\n' >"$tmp_dir/existing-target"
ensure_managed_config "$tmp_dir/new-source" "$tmp_dir/existing-target" >/dev/null
backup_exists() {
    grep -qx 'user configuration' "$tmp_dir/existing-target" &&
        find "$BACKUP_DIR" -type f -name existing-target | grep -q .
}
assert "conflicting configuration is backed up without overwrite" backup_exists

DRY_RUN=1
ensure_managed_config "$tmp_dir/new-source" "$tmp_dir/dry-target" >/dev/null
assert "dry-run does not install managed configuration" test ! -e "$tmp_dir/dry-target"
DRY_RUN=0

printf '\n%d tests, %d failures\n' "$tests_run" "$tests_failed"
((tests_failed == 0))
