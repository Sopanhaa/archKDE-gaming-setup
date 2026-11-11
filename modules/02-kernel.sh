#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/lib/common.sh"

packages=(linux-zen linux-zen-headers)
if ((DRY_RUN)); then
    packages+=(linux linux-headers)
    log INFO "Dry run will retain/install the standard kernel as a fallback."
elif ! pacman -Q linux >/dev/null 2>&1; then
    packages+=(linux linux-headers)
    log WARN "The standard linux kernel is not installed; installing it as a fallback."
else
    log INFO "The standard linux kernel is present and will be kept as a fallback."
fi

log WARN "Boot entries and bootloader configuration will not be edited."
boot_status=""
if command -v bootctl >/dev/null 2>&1; then
    boot_status="$(bootctl status --no-pager 2>/dev/null || true)"
fi
if grep -qi 'systemd-boot' <<<"$boot_status"; then
    log INFO "systemd-boot detected; verify or create a suitable entry/UKI for linux-zen yourself."
elif command -v grub-mkconfig >/dev/null 2>&1 && [[ -f /boot/grub/grub.cfg ]]; then
    log INFO "GRUB detected; its configuration was left unchanged. Review it and regenerate it yourself if needed."
elif command -v refind-install >/dev/null 2>&1; then
    log INFO "rEFInd detected; verify it can boot linux-zen yourself."
else
    log WARN "Bootloader not identified; verify that it discovers the linux-zen kernel."
fi

if secure_boot_enabled; then
    log WARN "Secure Boot is enabled; unsigned kernel modules may not load unless your signing setup supports them."
fi

install_available_packages "${packages[@]}"
