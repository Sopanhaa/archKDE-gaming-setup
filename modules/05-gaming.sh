#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/lib/common.sh"
source "$ROOT_DIR/config/packages.conf"

packages=("${GAMING_PACKAGES[@]}")
if multilib_enabled; then
    packages+=(lib32-mangohud lib32-gamemode)
else
    log WARN "Multilib is disabled; 32-bit gaming libraries were skipped. Steam may be unavailable until multilib is enabled."
fi
install_available_packages "${packages[@]}"

if command -v flatpak >/dev/null 2>&1; then
    sudo_run flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
else
    log WARN "Flatpak is unavailable; Heroic and ProtonUp-Qt Flatpak fallbacks will be skipped."
fi

if package_available heroic-games-launcher; then
    install_available_packages heroic-games-launcher
elif command -v flatpak >/dev/null 2>&1 && flatpak remotes 2>/dev/null | grep -q '^flathub'; then
    run flatpak install --user --or-update flathub com.heroicgameslauncher.hgl
else
    log WARN "Heroic was not installed; run the Flatpak module and install com.heroicgameslauncher.hgl from Flathub."
fi

if package_available protonup-qt; then
    log INFO "ProtonUp-Qt is available for managing Proton-GE versions."
elif command -v flatpak >/dev/null 2>&1; then
    run flatpak install --user --or-update flathub net.davidotek.pupgui2
else
    log WARN "ProtonUp-Qt is not available in enabled repositories."
fi
