#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/lib/common.sh"

command -v lspci >/dev/null 2>&1 || die "lspci is required for GPU detection; install pciutils and rerun this module."
GPU_INFO="$(lspci -nn | grep -Ei 'VGA compatible controller|3D controller|Display controller' || true)"
GPU_VENDORS="$(detect_gpu_vendors "$GPU_INFO")"
log INFO "Detected display adapter vendor(s): ${GPU_VENDORS//$'\n'/, }"

packages=(mesa vulkan-tools)
nvidia_driver_selected=0
if multilib_enabled; then
    packages+=(lib32-mesa)
fi
if [[ "$GPU_VENDORS" == unknown ]]; then
    log WARN "No supported GPU vendor was detected; installing generic Mesa/Vulkan tools only."
fi

if grep -qx nvidia <<<"$GPU_VENDORS"; then
    if package_available nvidia-open-dkms; then
        packages+=(dkms linux-zen-headers nvidia-open-dkms nvidia-utils nvidia-settings nvidia-prime)
        nvidia_driver_selected=1
    elif package_available nvidia-dkms; then
        packages+=(dkms linux-zen-headers nvidia-dkms nvidia-utils nvidia-settings nvidia-prime)
        nvidia_driver_selected=1
    else
        log WARN "No supported NVIDIA DKMS package was found in enabled repositories."
    fi
    if ! multilib_enabled; then
        log WARN "Multilib is disabled; 32-bit NVIDIA libraries are unavailable. Enable [multilib] and refresh pacman databases to support 32-bit games."
    elif ((nvidia_driver_selected)); then
        packages+=(lib32-nvidia-utils)
    fi
fi

if grep -qx amd <<<"$GPU_VENDORS"; then
    packages+=(vulkan-radeon)
    if multilib_enabled; then
        packages+=(lib32-vulkan-radeon)
    else
        log WARN "Multilib is disabled; skipping 32-bit AMD Vulkan libraries."
    fi
fi

if grep -qx intel <<<"$GPU_VENDORS"; then
    packages+=(vulkan-intel)
    if multilib_enabled; then
        packages+=(lib32-vulkan-intel)
    else
        log WARN "Multilib is disabled; skipping 32-bit Intel Vulkan libraries."
    fi
fi

log INFO "Integrated graphics will remain enabled; no PRIME or GPU power settings are changed."
install_available_packages "${packages[@]}"
if ((nvidia_driver_selected)); then
    ensure_managed_config "$ROOT_DIR/config/nvidia-drm.conf" /etc/modprobe.d/arch-extreme-gaming-nvidia.conf
fi
