#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/lib/common.sh"
init_logging

passed=0
warnings=0

pass() {
    log INFO "OK: $*"
    ((passed += 1))
}

warn() {
    log WARN "CHECK: $*"
    ((warnings += 1))
}

[[ -f /etc/arch-release ]] && pass "Arch Linux detected" || warn "This is not an Arch Linux system."
command -v pacman >/dev/null 2>&1 && pass "pacman is available" || warn "pacman is unavailable."
command -v lspci >/dev/null 2>&1 && pass "PCI detection tools are available" || warn "Install pciutils for GPU detection."

if pacman -Q linux-zen >/dev/null 2>&1; then
    pass "linux-zen is installed"
else
    warn "linux-zen is not installed"
fi

for service in NetworkManager bluetooth sddm fstrim.timer libvirtd; do
    if systemctl is-enabled --quiet "$service" 2>/dev/null; then
        pass "$service is enabled"
    else
        warn "$service is not enabled"
    fi
done

if command -v flatpak >/dev/null 2>&1; then
    pass "Flatpak is installed"
    if flatpak remotes 2>/dev/null | grep -q '^flathub'; then
        pass "Flathub remote is configured"
    else
        warn "Flathub remote is not configured"
    fi
else
    warn "Flatpak is not installed"
fi

if command -v vulkaninfo >/dev/null 2>&1; then
    pass "Vulkan tools are installed"
else
    warn "Vulkan tools are unavailable"
fi

printf '\nHealth check: %d passed, %d warning(s).\n' "$passed" "$warnings"
((warnings == 0))
