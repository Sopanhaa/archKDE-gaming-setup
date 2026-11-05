#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/lib/common.sh"
init_logging

require_non_root
check_arch
managed_nvidia_config=/etc/modprobe.d/arch-extreme-gaming-nvidia.conf
if [[ ! -e "$managed_nvidia_config" ]]; then
    log INFO "No project-managed NVIDIA configuration is present."
    exit 0
fi

if ! cmp -s -- "$ROOT_DIR/config/nvidia-drm.conf" "$managed_nvidia_config"; then
    log WARN "The NVIDIA configuration differs from the project template; it will not be removed."
    exit 0
fi

printf 'This will remove only the unchanged project-managed file:\n  %s\n' "$managed_nvidia_config"
printf 'Installed packages, boot entries, and service states will not be changed.\n'
[[ -t 0 ]] || die "Rollback requires interactive confirmation."
read -r -p "Continue? [y/N] " answer
[[ "$answer" =~ ^[Yy]$ ]] || die "Rollback cancelled."
command -v sudo >/dev/null 2>&1 || die "sudo is required to remove the system configuration."
sudo -v

sudo_run rm -- "$managed_nvidia_config"
log INFO "Removed the unchanged project-managed NVIDIA configuration."
