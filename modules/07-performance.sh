#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/lib/common.sh"

if lsblk -ndo ROTA "$(findmnt -no SOURCE /)" 2>/dev/null | grep -qx 0; then
    sudo_run systemctl enable --now fstrim.timer
    log INFO "Enabled weekly SSD discard through fstrim.timer."
else
    log INFO "Root storage was not identified as solid-state; fstrim.timer was not changed."
fi

if package_available power-profiles-daemon; then
    install_available_packages power-profiles-daemon
    sudo_run systemctl enable --now power-profiles-daemon.service
    log INFO "Enabled dynamic power profiles; no fixed performance governor was forced."
else
    log WARN "power-profiles-daemon is unavailable; leaving CPU power policy unchanged."
fi

log INFO "No speculative sysctl, security-mitigation, or kernel-parameter tweaks were applied."
log INFO "Zram was not enabled automatically; on a 16 GiB system it should be chosen based on workload."
