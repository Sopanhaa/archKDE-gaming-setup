#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/lib/common.sh"
source "$ROOT_DIR/config/packages.conf"

install_available_packages "${FLATPAK_PACKAGES[@]}"
if ((DRY_RUN)); then
    run sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    run flatpak remotes
    exit 0
fi

sudo_run flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
flatpak remotes
flatpak remote-info flathub org.freedesktop.Platform >/dev/null
log INFO "Flathub is configured system-wide; existing Flatpak applications were not reinstalled."
