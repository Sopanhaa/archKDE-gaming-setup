#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/lib/common.sh"
source "$ROOT_DIR/config/packages.conf"

if ! grep -Eqw 'vmx|svm' /proc/cpuinfo; then
    log WARN "CPU virtualization extensions (Intel VT-x/AMD-V) were not detected; skipping KVM setup."
    exit 0
fi

install_available_packages "${VIRTUALIZATION_PACKAGES[@]}"
sudo_run systemctl enable --now libvirtd.service
if ((DRY_RUN)) || getent group libvirt >/dev/null 2>&1; then
    if ((DRY_RUN)); then
        sudo_run usermod -aG libvirt "$USER"
    elif ! id -nG "$USER" | tr ' ' '\n' | grep -qx libvirt; then
        sudo_run usermod -aG libvirt "$USER"
        log INFO "Added $USER to libvirt; sign out and back in for the new group membership."
    else
        log INFO "$USER is already a member of libvirt."
    fi
else
    log WARN "The libvirt group was not found after package installation; check the libvirt package setup."
fi
