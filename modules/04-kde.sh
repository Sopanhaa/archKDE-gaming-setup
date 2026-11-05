#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/lib/common.sh"
source "$ROOT_DIR/config/packages.conf"

install_available_packages "${KDE_PACKAGES[@]}"
sudo_run systemctl enable NetworkManager.service bluetooth.service sddm.service
log INFO "PipeWire user services start with the user's session; no system-wide audio service is enabled."
