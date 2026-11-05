#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/lib/common.sh"
source "$ROOT_DIR/config/packages.conf"

log INFO "Updating official packages and installing base tools."
sudo_run pacman -Syu
install_available_packages "${SYSTEM_PACKAGES[@]}"
