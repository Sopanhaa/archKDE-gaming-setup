#!/usr/bin/env bash

ROOT_DIR="${ROOT_DIR:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
STATE_ROOT="${XDG_STATE_HOME:-${HOME}/.local/state}"
STATE_DIR="${STATE_ROOT}/archkde-play"
LEGACY_STATE_DIR="${STATE_ROOT}/arch-extreme-gaming"
# Keep using an existing legacy state directory so an in-progress install does
# not lose its logs or rollback manifest after the project rename.
if [[ ! -d "$STATE_DIR" && -d "$LEGACY_STATE_DIR" ]]; then
    STATE_DIR="$LEGACY_STATE_DIR"
fi
LOG_FILE="${LOG_FILE:-$STATE_DIR/logs/setup-$(date +%Y%m%d).log}"
MANIFEST_FILE="${MANIFEST_FILE:-$STATE_DIR/rollback/manifest.txt}"
BACKUP_DIR="${BACKUP_DIR:-$STATE_DIR/backups}"
DRY_RUN="${DRY_RUN:-0}"
LOG_TEE="${LOG_TEE:-0}"
SETUP_QUIET="${SETUP_QUIET:-0}"

# Colour is only used on a real terminal. install.sh sets SETUP_FORCE_COLOR
# before it redirects output through tee so interactive output stays readable.
if [[ -z "${NO_COLOR:-}" && "${TERM:-dumb}" != "dumb" ]] &&
    { [[ -t 1 ]] || [[ "${SETUP_FORCE_COLOR:-0}" == "1" ]]; }; then
    C_RESET=$'\033[0m'
    C_BOLD=$'\033[1m'
    C_DIM=$'\033[2m'
    C_RED=$'\033[31m'
    C_GREEN=$'\033[32m'
    C_YELLOW=$'\033[33m'
    C_BLUE=$'\033[34m'
    C_CYAN=$'\033[36m'
else
    C_RESET=""
    C_BOLD=""
    C_DIM=""
    C_RED=""
    C_GREEN=""
    C_YELLOW=""
    C_BLUE=""
    C_CYAN=""
fi

log() {
    local level="$1"
    shift
    local message quiet=0
    printf -v message '%s [%s] %s' "$(date '+%Y-%m-%d %H:%M:%S')" "$level" "$*"
    if ((SETUP_QUIET)) && [[ "$level" == INFO ]]; then
        quiet=1
    fi
    ((quiet)) || printf '%s\n' "$message"
    if ((!LOG_TEE)) || ((quiet)); then
        if [[ -d "$(dirname -- "$LOG_FILE")" ]] || mkdir -p -- "$(dirname -- "$LOG_FILE")"; then
            printf '%s\n' "$message" >>"$LOG_FILE"
        else
            printf 'Unable to write log file: %s\n' "$LOG_FILE" >&2
            return 1
        fi
    fi
}

die() {
    log ERROR "$*"
    exit 1
}

section() {
    ((SETUP_QUIET)) && return 0
    printf '\n%s==> %s%s\n' "$C_BOLD$C_BLUE" "$*" "$C_RESET"
}

ui_ok() {
    ((SETUP_QUIET)) && return 0
    printf '  %s[ OK ]%s %s\n' "$C_GREEN" "$C_RESET" "$*"
}

ui_warn() {
    printf '  %s[WARN]%s %s\n' "$C_YELLOW" "$C_RESET" "$*"
}

ui_fail() {
    printf '  %s[FAIL]%s %s\n' "$C_RED" "$C_RESET" "$*"
}

ui_note() {
    ((SETUP_QUIET)) && return 0
    printf '  %s[INFO]%s %s\n' "$C_CYAN" "$C_RESET" "$*"
}

format_duration() {
    local seconds="${1:-0}"
    if ((seconds < 60)); then
        printf '%ss' "$seconds"
    else
        printf '%dm %ss' "$((seconds / 60))" "$((seconds % 60))"
    fi
}

require_non_root() {
    ((EUID != 0)) || die "Run this command as a regular user, not root."
}

path_within_state() {
    local path="$1"
    local state_real path_real
    state_real="$(realpath -m -- "$STATE_DIR" 2>/dev/null)" || return 1
    path_real="$(realpath -m -- "$path" 2>/dev/null)" || return 1
    [[ "$path_real" == "$state_real" || "$path_real" == "$state_real"/* ]]
}

rollback_target_allowed() {
    local target="${1:-}"
    local canonical
    canonical="$(realpath -m -- "$target" 2>/dev/null)" || return 1
    [[ "$canonical" == "$target" ]] || return 1
    [[ "$target" == /etc/modprobe.d/arch-extreme-gaming-* ||
        "$target" == /etc/modprobe.d/archkde-play-* ]]
}

init_logging() {
    local log_dir
    log_dir="$(dirname -- "$LOG_FILE")"
    mkdir -p -- "$STATE_DIR"
    chmod 700 -- "$STATE_DIR" 2>/dev/null || true
    mkdir -p -- "$log_dir"
    if path_within_state "$log_dir"; then
        chmod 700 -- "$log_dir" 2>/dev/null || true
    fi
    touch "$LOG_FILE"
    if path_within_state "$LOG_FILE"; then
        chmod 600 -- "$LOG_FILE" 2>/dev/null || true
    fi
}

run() {
    local quoted
    printf -v quoted '%q ' "$@"
    quoted="${quoted% }"
    if ((DRY_RUN)); then
        printf '%s[DRY-RUN]%s %s\n' "$C_DIM" "$C_RESET" "$quoted"
        return 0
    fi
    printf '%s+ %s%s\n' "$C_DIM" "$quoted" "$C_RESET"
    "$@"
}

sudo_run() {
    run sudo "$@"
}

check_arch() {
    [[ -f /etc/arch-release ]] || die "This installer supports Arch Linux only."
    command -v pacman >/dev/null 2>&1 || die "pacman was not found."
    [[ "$(uname -m)" == x86_64 ]] || die "This gaming setup currently supports x86_64 systems only."
}

check_internet() {
    if ! internet_available; then
        die "Internet connectivity check failed; connect to the internet and ensure curl, wget, or timeout is available."
    fi
    log INFO "Internet connectivity verified."
}

secure_boot_enabled() {
    local boot_status=""
    if command -v mokutil >/dev/null 2>&1 &&
        mokutil --sb-state 2>/dev/null | grep -qi enabled; then
        return 0
    fi
    if command -v bootctl >/dev/null 2>&1; then
        boot_status="$(bootctl status --no-pager 2>/dev/null || true)"
    fi
    grep -Eqi 'Secure Boot:[[:space:]]*enabled' <<<"$boot_status"
}

internet_available() {
    if command -v curl >/dev/null 2>&1; then
        if curl -fsS --max-time 8 https://archlinux.org/ -o /dev/null; then
            return 0
        fi
    fi
    if command -v wget >/dev/null 2>&1; then
        if wget -q --spider --timeout=8 https://archlinux.org/; then
            return 0
        fi
    fi
    if command -v timeout >/dev/null 2>&1; then
        if timeout 8 bash -c 'exec 3<>/dev/tcp/archlinux.org/443' >/dev/null 2>&1; then
            return 0
        fi
    fi
    return 1
}

# Return the raw display-controller information from lspci. If lspci is not
# installed (or returns nothing), fall back to sysfs so GPU detection still
# works on minimal systems.
detect_system_gpu_info() {
    local info=""
    local device class vendor_id

    if command -v lspci >/dev/null 2>&1; then
        info="$(lspci -nn 2>/dev/null |
            grep -Ei 'VGA compatible controller|3D controller|Display controller' || true)"
    fi

    if [[ -n "$info" ]]; then
        printf '%s\n' "$info"
        return 0
    fi

    for device in /sys/bus/pci/devices/*; do
        [[ -r "$device/class" && -r "$device/vendor" ]] || continue
        class="$(<"$device/class")"
        class="${class,,}"
        case "$class" in
            0x0300*|0x0302*|0x0380*)
                vendor_id="$(<"$device/vendor")"
                printf '%s: display controller\n' "${vendor_id#0x}"
                ;;
        esac
    done
}

# Accepts lspci-style text and prints unique vendor names in detection order:
# "nvidia", "amd", "intel", multiple values, or "unknown".
detect_gpu_vendors() {
    local info="${1:-}"
    local line lower vendor
    local -a found=()
    local -A seen=()

    while IFS= read -r line; do
        [[ -n "${line//[[:space:]]/}" ]] || continue
        lower="${line,,}"
        if [[ "$lower" =~ (nvidia|10de:) ]]; then
            vendor=nvidia
        elif [[ "$lower" =~ (amd|advanced[[:space:]]micro[[:space:]]devices|1002:) ]]; then
            vendor=amd
        elif [[ "$lower" =~ (intel|8086:) ]]; then
            vendor=intel
        else
            continue
        fi
        [[ -n "${seen[$vendor]:-}" ]] && continue
        seen[$vendor]=1
        found+=("$vendor")
    done <<<"$info"

    if ((${#found[@]})); then
        printf '%s\n' "${found[@]}"
    else
        printf 'unknown\n'
    fi
}

gpu_vendor_label() {
    local vendor result=""
    for vendor in "$@"; do
        case "$vendor" in
            nvidia) result+="${result:+, }NVIDIA" ;;
            amd) result+="${result:+, }AMD" ;;
            intel) result+="${result:+, }Intel" ;;
            unknown) result+="${result:+, }Unknown" ;;
        esac
    done
    printf '%s' "${result:-Unknown}"
}

gpu_has_vendor() {
    local wanted="${1:-}"
    shift || true
    local vendors="${*:-}"
    local normalized="${vendors//$'\n'/ }"
    [[ " $normalized " == *" $wanted "* ]]
}

gpu_is_hybrid() {
    local vendors="${1:-}"
    local vendor count=0

    for vendor in nvidia amd intel; do
        if gpu_has_vendor "$vendor" "$vendors"; then
            count=$((count + 1))
        fi
    done
    ((count > 1))
}

show_hardware_summary() {
    local cpu ram gpu gpu_vendors gpu_label disk storage free_kib hybrid_note=""
    local -a gpu_vendor_list=()
    cpu="$(awk -F: '/model name/ {gsub(/^[ \t]+/, "", $2); print $2; exit}' /proc/cpuinfo 2>/dev/null || true)"
    ram="$(awk '/MemTotal/ {printf "%.1f GiB", $2 / 1048576}' /proc/meminfo 2>/dev/null || printf unknown)"
    gpu="$(detect_system_gpu_info)"
    gpu_vendors="$(detect_gpu_vendors "$gpu")"
    mapfile -t gpu_vendor_list <<<"$gpu_vendors"
    gpu_label="$(gpu_vendor_label "${gpu_vendor_list[@]}")"
    if gpu_is_hybrid "$gpu_vendors"; then
        hybrid_note=" (hybrid graphics detected)"
    fi
    [[ -n "$gpu" ]] || gpu="Not detected (lspci unavailable or no display controller found)"
    disk="$(findmnt -no SOURCE / 2>/dev/null || printf unknown)"
    storage="Not detected"
    if command -v lsblk >/dev/null 2>&1 && [[ "$disk" != unknown ]]; then
        storage="$(lsblk -s -npo NAME,TYPE,SIZE,ROTA,MODEL "$disk" 2>/dev/null |
            awk '$2 == "disk" {
                model=$5
                for (i=6; i<=NF; i++) model=model " " $i
                kind=($4 == 0 ? "non-rotational" : "rotational")
                printf "%s %s (%s, %s)", $1, model, $3, kind
            }' || true)"
        [[ -n "$storage" ]] || storage="Not detected"
    fi
    free_kib="$(df -Pk / 2>/dev/null | awk 'NR == 2 {print $4}' || true)"

    printf '\nHardware summary\n'
    printf '  CPU: %s\n' "${cpu:-unknown}"
    printf '  Memory: %s\n' "$ram"
    printf '  Detected GPU vendor(s): %s%s\n' "$gpu_label" "$hybrid_note"
    printf '  Display adapter(s):\n%s\n' "$gpu"
    printf '  Root filesystem: %s\n' "$disk"
    printf '  Physical storage: %s\n' "$storage"
    if [[ "$free_kib" =~ ^[0-9]+$ ]]; then
        printf '  Free space on /: %.1f GiB\n' "$(awk -v kib="$free_kib" 'BEGIN {print kib / 1048576}')"
        if ((free_kib < 10485760)); then
            log WARN "Less than 10 GiB is free on /; package installation may fail."
        fi
    else
        log WARN "Could not determine free disk space."
    fi
}

package_available() {
    local package="$1"
    ((DRY_RUN)) && return 0
    command -v pacman >/dev/null 2>&1 || return 1
    pacman -Si -- "$package" >/dev/null 2>&1
}

# One pacman call for the common case where every package is available.
packages_available_batch() {
    (($#)) || return 0
    ((DRY_RUN)) && return 0
    command -v pacman >/dev/null 2>&1 || return 1
    pacman -Si -- "$@" >/dev/null 2>&1
}

package_database_ready() {
    compgen -G "/var/lib/pacman/sync/*.db" >/dev/null 2>&1
}

validate_package_name() {
    [[ "$1" =~ ^[a-zA-Z0-9@._+-]+$ ]]
}

package_installed() {
    local package="$1"
    command -v pacman >/dev/null 2>&1 || return 1
    pacman -Q "$package" >/dev/null 2>&1
}

install_available_packages() {
    local package
    local -a valid=()
    local -a available=()
    local -a missing=()
    local -a invalid=()
    for package in "$@"; do
        if validate_package_name "$package"; then
            valid+=("$package")
        else
            invalid+=("$package")
        fi
    done
    if ((${#valid[@]})) && packages_available_batch "${valid[@]}"; then
        available=("${valid[@]}")
    else
        for package in "${valid[@]}"; do
            if package_available "$package"; then
                available+=("$package")
            else
                missing+=("$package")
            fi
        done
    fi
    if ((${#invalid[@]})); then
        log WARN "Invalid package names (skipped): ${invalid[*]}"
    fi
    if ((${#missing[@]})); then
        log WARN "Unavailable packages (skipped): ${missing[*]}"
        log WARN "If these packages should exist, refresh the package database with: sudo pacman -Syu"
    fi
    if ((${#available[@]})); then
        log INFO "Installing ${#available[@]} package(s): ${available[*]}"
        sudo_run pacman -S --needed -- "${available[@]}"
        if ((!DRY_RUN)); then
            local -a not_installed=()
            for package in "${available[@]}"; do
                package_installed "$package" || not_installed+=("$package")
            done
            if ((${#not_installed[@]})); then
                log WARN "Requested packages that are still missing: ${not_installed[*]}"
            else
                log INFO "All requested packages are installed."
            fi
        fi
    else
        log WARN "No requested packages are available; nothing was installed."
    fi
}

multilib_enabled() {
    [[ -r /etc/pacman.conf ]] || return 1
    awk '
        /^\[multilib\][[:space:]]*$/ { in_multilib=1; next }
        /^\[[^]]+\][[:space:]]*$/ { in_multilib=0 }
        in_multilib && /^[[:space:]]*Include[[:space:]]*=/ { found=1 }
        END { exit !found }
    ' /etc/pacman.conf
}

record_change() {
    local kind="$1"
    local target="$2"
    local detail="${3:--}"
    local source="${4:--}"
    local manifest_dir
    ((DRY_RUN)) && return 0
    manifest_dir="$(dirname -- "$MANIFEST_FILE")"
    mkdir -p -- "$manifest_dir"
    if path_within_state "$manifest_dir"; then
        chmod 700 -- "$manifest_dir" 2>/dev/null || true
    fi
    printf '%s|%s|%s|%s\n' "$kind" "$target" "$detail" "$source" >>"$MANIFEST_FILE"
    if path_within_state "$MANIFEST_FILE"; then
        chmod 600 -- "$MANIFEST_FILE" 2>/dev/null || true
    fi
}

file_sha256() {
    sha256sum -- "$1" 2>/dev/null | awk '{print $1}'
}

tracked_change_count() {
    if [[ -f "$MANIFEST_FILE" ]]; then
        awk -F'|' '$1 == "created" { count++ } END { print count + 0 }' "$MANIFEST_FILE"
    else
        printf '0\n'
    fi
}

backup_file() {
    local target="$1"
    local label="${2:-$(basename -- "$target")}"
    local stamp backup
    stamp="$(date +%Y%m%d-%H%M%S)"
    backup="$BACKUP_DIR/$stamp/$label"
    if ((DRY_RUN)); then
        run sudo cp -a -- "$target" "$backup"
        log INFO "Dry run: would back up $target to $backup"
        return 0
    fi
    mkdir -p -- "$BACKUP_DIR/$stamp"
    if path_within_state "$BACKUP_DIR"; then
        chmod 700 -- "$BACKUP_DIR" "$BACKUP_DIR/$stamp" 2>/dev/null || true
    fi
    # -n avoids an unexpected password prompt in non-interactive runs; the
    # installer authenticates sudo before any module starts, so this succeeds
    # there without prompting.
    if ! sudo -n cp -a -- "$target" "$backup" 2>/dev/null; then
        log WARN "Could not back up $target; it will be left untouched."
        return 1
    fi
    sudo chown "$(id -u):$(id -g)" -- "$backup" 2>/dev/null || true
    if path_within_state "$backup"; then
        sudo chmod 600 -- "$backup" 2>/dev/null || true
    fi
    record_change "backup" "$target" "$backup" "-"
    log INFO "Backed up $target to $backup"
}

ensure_managed_config() {
    local source_file="$1"
    local target_file="$2"
    local digest
    if [[ -e "$target_file" ]]; then
        if cmp -s -- "$source_file" "$target_file"; then
            log INFO "Managed configuration already matches: $target_file"
        else
            log WARN "Existing configuration differs; it will not be overwritten: $target_file"
            backup_file "$target_file" "$(basename -- "$target_file")" ||
                log WARN "A backup could not be created; the existing file is still untouched."
        fi
        return 0
    fi
    if ((DRY_RUN)); then
        run sudo install -D -m 0644 "$source_file" "$target_file"
        log INFO "Dry run: would install managed configuration: $target_file"
        return 0
    fi
    sudo_run install -D -m 0644 "$source_file" "$target_file"
    digest="$(file_sha256 "$target_file")"
    record_change "created" "$target_file" "$digest" "$source_file"
    log INFO "Installed managed configuration: $target_file"
}
