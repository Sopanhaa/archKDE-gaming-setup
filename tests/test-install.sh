#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

# Keep every test artifact in a temporary directory. These variables must be
# set before lib/common.sh is sourced, because it computes the default paths
# at source time.
tmp_dir="$(mktemp -d)"
export XDG_STATE_HOME="$tmp_dir/state"
export LOG_FILE="$tmp_dir/test.log"
export MANIFEST_FILE="$tmp_dir/rollback/manifest.txt"
export BACKUP_DIR="$tmp_dir/backups"
trap 'rm -rf -- "$tmp_dir"' EXIT

source "$ROOT_DIR/lib/common.sh"
source "$ROOT_DIR/lib/modules.sh"
source "$ROOT_DIR/config/packages.conf"

tests_run=0
tests_failed=0
DRY_RUN=0

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
    for number in "${MODULE_NUMBERS[@]}"; do
        module_script "$number" >/dev/null || return 1
    done
}

registry_is_consistent() {
    ((${#MODULE_NUMBERS[@]} == ${#MODULE_TITLES[@]})) &&
        ((${#MODULE_NUMBERS[@]} == ${#MODULE_DESCRIPTIONS[@]}))
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

install_help_works() {
    bash "$ROOT_DIR/install.sh" --help 2>&1 | grep -q '^Usage:'
}

install_rejects_conflicting_flags() {
    ! bash "$ROOT_DIR/install.sh" --full --modules 03 >/dev/null 2>&1
}

assert "detects NVIDIA and Intel hybrid graphics" equals_text "$(detect_gpu_vendors $'01:00.0 VGA compatible controller: NVIDIA Corporation (10de:25a9)\n00:02.0 VGA compatible controller: Intel Corporation (8086:46a6)')" $'nvidia\nintel'
assert "detects AMD graphics" equals_text "$(detect_gpu_vendors '03:00.0 VGA compatible controller: Advanced Micro Devices, Inc. [AMD/ATI] (1002:73ff)')" "amd"
assert "detects all supported vendors" equals_text "$(detect_gpu_vendors $'NVIDIA (10de:2504)\nAMD (1002:73ff)\nIntel (8086:46a6)')" $'nvidia\namd\nintel'
assert "reports unknown for unsupported display hardware" contains_text "$(detect_gpu_vendors 'Virtual display adapter')" "unknown"
assert "recognizes hybrid graphics" gpu_is_hybrid "nvidia intel"
assert "finds a vendor in a hybrid vendor list" gpu_has_vendor nvidia "intel nvidia"
assert "does not label a single GPU as hybrid" test "$(gpu_is_hybrid 'nvidia' && printf yes || printf no)" = "no"
assert "formats GPU vendor labels" test "$(gpu_vendor_label nvidia intel)" = "NVIDIA, Intel"

assert "parses comma-separated module numbers in dependency order" test "$(parse_module_selection '5,1,3')" = "01 03 05"
assert "parses space-separated module numbers" test "$(parse_module_selection '03 05 06')" = "03 05 06"
assert "expands module ranges" test "$(parse_module_selection '03-05')" = "03 04 05"
assert "accepts the all keyword" test "$(parse_module_selection 'all')" = "01 02 03 04 05 06 07 08"
assert_failure "rejects out-of-range module numbers" parse_module_selection "09"
assert_failure "rejects non-numeric module selections" parse_module_selection "03,gpu"
assert_failure "rejects empty module selections" parse_module_selection ""

assert "package configuration contains valid package identifiers" valid_package_names
assert "every registered module has a script" all_modules_have_scripts
assert "module registry arrays are consistent" registry_is_consistent
assert "module registry titles are available" test "$(module_title 03)" = "GPU drivers and Vulkan"
assert "module registry resolves script paths" test -n "$(module_script 03)"
assert "installer help works" install_help_works
assert "installer rejects conflicting --full and --modules" install_rejects_conflicting_flags

installer_version_works() {
    local output
    output="$(bash "$ROOT_DIR/install.sh" --version 2>&1)"
    [[ "$output" =~ ^archKDE-play[[:space:]]+[^[:space:]]+$ ]]
}

installer_lists_modules() {
    local output
    output="$(bash "$ROOT_DIR/install.sh" --list-modules 2>&1)"
    [[ "$output" == *"01  System update and base tools"* &&
        "$output" == *"08  QEMU/KVM virtualization"* ]]
}

quiet_hides_info_but_keeps_warnings() {
    local output
    output="$(SETUP_QUIET=1; log INFO "quiet-info-marker"; log WARN "quiet-warn-marker")"
    [[ "$output" != *"quiet-info-marker"* && "$output" == *"quiet-warn-marker"* ]]
}

assert "installer reports its version" installer_version_works
assert "installer lists all modules" installer_lists_modules
assert "quiet mode hides informational output" quiet_hides_info_but_keeps_warnings
assert "rollback allowlist accepts managed modprobe configuration" rollback_target_allowed /etc/modprobe.d/arch-extreme-gaming-nvidia.conf
assert_failure "rollback allowlist rejects arbitrary files" rollback_target_allowed /etc/passwd
assert_failure "rollback allowlist rejects path traversal" rollback_target_allowed /etc/modprobe.d/archkde-play-../../passwd

dry_run_creates_no_state() {
    local state="$tmp_dir/dry-state"
    XDG_STATE_HOME="$state" LOG_FILE="$state/log" \
        bash "$ROOT_DIR/install.sh" --dry-run --full --no-color >/dev/null 2>&1 || true
    [[ ! -e "$state" ]]
}
assert "dry-run does not create state files" dry_run_creates_no_state

pacman() {
    case "$*" in
        "-Si -- known-package") return 0 ;;
        "-Si -- known-package second-known") return 0 ;;
        *) return 1 ;;
    esac
}
assert "recognizes package availability" package_available known-package
assert "recognizes a batch of available packages" packages_available_batch known-package second-known
assert_failure "rejects unavailable packages in a batch" packages_available_batch known-package missing-package
assert_failure "rejects unavailable packages" package_available missing-package

DRY_RUN=1
run touch "$tmp_dir/dry-run-marker"
assert "dry-run command returns successfully without execution" test ! -e "$tmp_dir/dry-run-marker"
DRY_RUN=0

assert_failure "propagates command failure" run false

curl() { return 7; }
wget_status=0
wget() { return "$wget_status"; }
timeout() { return 9; }
assert "falls back to wget when curl fails" internet_available
wget_status=8
assert_failure "detects missing internet" internet_available

die_fails() {
    (die "expected test failure")
}
assert_failure "fatal errors return a failing status" die_fails

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
