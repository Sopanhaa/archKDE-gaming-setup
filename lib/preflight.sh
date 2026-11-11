#!/usr/bin/env bash
#
# Safe, non-destructive checks that run before any package is installed.
# Source this file after lib/common.sh.

PREFLIGHT_ERRORS=0
PREFLIGHT_WARNINGS=0

preflight_fail() {
    ui_fail "$*"
    PREFLIGHT_ERRORS=$((PREFLIGHT_ERRORS + 1))
}

preflight_warn() {
    ui_warn "$*"
    PREFLIGHT_WARNINGS=$((PREFLIGHT_WARNINGS + 1))
}

preflight_check_system() {
    if [[ -f /etc/arch-release ]]; then
        ui_ok "Arch Linux detected."
    else
        preflight_fail "This is not Arch Linux (/etc/arch-release is missing)."
    fi

    if command -v pacman >/dev/null 2>&1; then
        ui_ok "pacman is available."
    else
        preflight_fail "pacman was not found in PATH."
    fi

    if [[ "$(uname -m)" == x86_64 ]]; then
        ui_ok "64-bit x86_64 system detected."
    else
        preflight_fail "This setup requires x86_64; detected $(uname -m)."
    fi

    if ((EUID != 0)); then
        ui_ok "Running as a regular user."
    else
        preflight_fail "Do not run this installer as root; run it as your normal user."
    fi

    if command -v sudo >/dev/null 2>&1; then
        ui_ok "sudo is available."
        if ((EUID != 0)) && ! sudo -n true 2>/dev/null; then
            ui_note "sudo may ask for your password before installation starts."
        fi
    else
        preflight_fail "sudo is required but was not found."
    fi

    if command -v git >/dev/null 2>&1; then
        ui_ok "git is available."
    else
        preflight_warn "git is not installed; repository updates and developer workflows will need it."
    fi

    if [[ -d /run/archiso ]]; then
        preflight_warn "Arch live environment detected; changes may not persist after reboot."
    fi
}

preflight_check_network() {
    if internet_available; then
        ui_ok "Internet connectivity verified."
    else
        preflight_fail "No internet connection (or curl/wget/timeout is unavailable)."
    fi
}

preflight_check_storage() {
    local free_kib

    free_kib="$(df -Pk / 2>/dev/null | awk 'NR == 2 {print $4}')" || free_kib=""
    if [[ ! "$free_kib" =~ ^[0-9]+$ ]]; then
        preflight_warn "Could not determine free space on /."
        return 0
    fi

    if ((free_kib < 5 * 1024 * 1024)); then
        preflight_fail "Less than 5 GiB is free on /; package installation will likely fail."
    elif ((free_kib < 10 * 1024 * 1024)); then
        preflight_warn "Less than 10 GiB is free on /; consider freeing space first."
    else
        ui_ok "Enough free disk space ($(awk -v kib="$free_kib" 'BEGIN {printf "%.1f", kib / 1048576}') GiB on /)."
    fi
}

preflight_check_pacman() {
    if [[ ! -r /etc/pacman.conf ]]; then
        preflight_fail "/etc/pacman.conf is not readable."
        return 0
    fi

    if [[ -e /var/lib/pacman/db.lck ]]; then
        preflight_fail "pacman is locked (/var/lib/pacman/db.lck exists). Wait for other updates to finish."
    else
        ui_ok "pacman database is not locked."
    fi

    if package_database_ready; then
        ui_ok "pacman package databases are present."
    else
        preflight_warn "Package databases look empty; run 'sudo pacman -Syu' if package detection fails."
    fi

    if multilib_enabled; then
        ui_ok "[multilib] is enabled (32-bit games and drivers are supported)."
    else
        preflight_warn "[multilib] is disabled; Steam and 32-bit graphics libraries will be skipped."
    fi
}

preflight_check_graphics() {
    local info vendors

    info="$(detect_system_gpu_info)"
    vendors="$(detect_gpu_vendors "$info")"

    if command -v lspci >/dev/null 2>&1; then
        ui_ok "PCI detection tools are available."
    else
        preflight_warn "lspci is missing; GPU detection will use /sys instead."
    fi

    if [[ "$vendors" == unknown ]]; then
        preflight_warn "No supported GPU vendor was detected; Mesa/Vulkan tools will still be installed."
        return 0
    fi

    local -a vendor_list=()
    mapfile -t vendor_list <<<"$vendors"
    ui_ok "Detected GPU vendor(s): $(gpu_vendor_label "${vendor_list[@]}")."
    if gpu_is_hybrid "$vendors"; then
        ui_note "Hybrid graphics detected; both vendor drivers will be installed and the integrated GPU stays enabled."
    fi
}

preflight_check_boot() {
    local boot_status=""

    if command -v bootctl >/dev/null 2>&1; then
        boot_status="$(bootctl status --no-pager 2>/dev/null || true)"
    fi

    if grep -qi 'systemd-boot' <<<"$boot_status"; then
        ui_ok "systemd-boot detected."
    elif [[ -f /boot/grub/grub.cfg ]] || command -v grub-mkconfig >/dev/null 2>&1; then
        ui_ok "GRUB detected."
    elif command -v refind-install >/dev/null 2>&1; then
        ui_ok "rEFInd detected."
    else
        preflight_warn "Bootloader not identified; make sure it can find the linux-zen kernel after installation."
    fi

    if secure_boot_enabled; then
        preflight_warn "Secure Boot is enabled; NVIDIA modules may need to be signed before they will load."
    fi
}

run_preflight_checks() {
    PREFLIGHT_ERRORS=0
    PREFLIGHT_WARNINGS=0

    section "Preflight checks"
    preflight_check_system
    preflight_check_network
    preflight_check_storage
    preflight_check_pacman
    preflight_check_graphics
    preflight_check_boot

    printf '\n'
    if ((PREFLIGHT_ERRORS > 0)); then
        log ERROR "Preflight found $PREFLIGHT_ERRORS blocking problem(s) and $PREFLIGHT_WARNINGS warning(s)."
        log ERROR "Nothing has been changed. Fix the [FAIL] item(s) above, then run the installer again."
        return 1
    fi

    if ((PREFLIGHT_WARNINGS > 0)); then
        log WARN "Preflight completed with $PREFLIGHT_WARNINGS warning(s); installation can continue."
    else
        log INFO "All preflight checks passed."
    fi
    return 0
}
