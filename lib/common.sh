#!/usr/bin/env bash

ROOT_DIR="${ROOT_DIR:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
STATE_DIR="${XDG_STATE_HOME:-${HOME}/.local/state}/arch-extreme-gaming"
LOG_FILE="${LOG_FILE:-$STATE_DIR/logs/setup-$(date +%Y%m%d).log}"
DRY_RUN="${DRY_RUN:-0}"
LOG_TEE="${LOG_TEE:-0}"

log() {
    local level="$1"
    shift
    local message
    printf -v message '%s [%s] %s' "$(date '+%Y-%m-%d %H:%M:%S')" "$level" "$*"
    printf '%s\n' "$message"
    if ((!LOG_TEE)); then
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

require_non_root() {
    ((EUID != 0)) || die "Run this command as a regular user, not root."
}

init_logging() {
    mkdir -p -- "$(dirname -- "$LOG_FILE")"
    touch "$LOG_FILE"
}

run() {
    printf '+'
    printf ' %q' "$@"
    printf '\n'
    if ((DRY_RUN)); then
        return 0
    fi
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

internet_available() {
    if command -v curl >/dev/null 2>&1; then
        curl -fsS --max-time 8 https://archlinux.org/ -o /dev/null
    elif command -v wget >/dev/null 2>&1; then
        wget -q --spider --timeout=8 https://archlinux.org/
    elif command -v timeout >/dev/null 2>&1; then
        timeout 8 bash -c 'exec 3<>/dev/tcp/archlinux.org/443' >/dev/null 2>&1
    else
        return 127
    fi
}

detect_gpu_vendors() {
    local info="${1:-}"
    local line lower existing
    local -a found=()
    local vendor already

    while IFS= read -r line; do
        lower="${line,,}"
        if [[ "$lower" =~ nvidia|10de: ]]; then
            vendor=nvidia
        elif [[ "$lower" =~ amd|advanced.micro.devices|1002: ]]; then
            vendor=amd
        elif [[ "$lower" =~ intel|8086: ]]; then
            vendor=intel
        else
            continue
        fi
        already=0
        for existing in "${found[@]}"; do
            [[ "$existing" == "$vendor" ]] && already=1
        done
        ((already)) || found+=("$vendor")
    done <<<"$info"

    if ((${#found[@]})); then
        printf '%s\n' "${found[*]}"
    else
        printf 'unknown\n'
    fi
}

show_hardware_summary() {
    local cpu ram gpu disk storage free_kib
    cpu="$(awk -F: '/model name/ {gsub(/^[ \t]+/, "", $2); print $2; exit}' /proc/cpuinfo 2>/dev/null || true)"
    ram="$(awk '/MemTotal/ {printf "%.1f GiB", $2 / 1048576}' /proc/meminfo 2>/dev/null || printf unknown)"
    if command -v lspci >/dev/null 2>&1; then
        gpu="$(lspci -nn | grep -Ei 'VGA compatible controller|3D controller|Display controller' || true)"
    else
        gpu=""
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
    free_kib="$(df -Pk / | awk 'NR == 2 {print $4}')"

    printf '\nHardware summary\n'
    printf '  CPU: %s\n' "${cpu:-unknown}"
    printf '  Memory: %s\n' "$ram"
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
    pacman -Si "$package" >/dev/null 2>&1
}

install_available_packages() {
    local package
    local -a available=()
    local -a missing=()
    for package in "$@"; do
        if package_available "$package"; then
            available+=("$package")
        else
            missing+=("$package")
        fi
    done
    if ((${#missing[@]})); then
        log WARN "Unavailable packages (skipped): ${missing[*]}"
    fi
    if ((${#available[@]})); then
        sudo_run pacman -S --needed "${available[@]}"
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

ensure_managed_config() {
    local source_file="$1"
    local target_file="$2"
    if [[ -e "$target_file" ]]; then
        if cmp -s -- "$source_file" "$target_file"; then
            log INFO "Managed configuration already matches: $target_file"
        else
            log WARN "Leaving existing configuration untouched: $target_file"
        fi
        return 0
    fi
    sudo_run install -D -m 0644 "$source_file" "$target_file"
}
