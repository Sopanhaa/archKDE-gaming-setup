#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/lib/common.sh"

GPU_INFO="$(detect_system_gpu_info)"
GPU_VENDORS="$(detect_gpu_vendors "$GPU_INFO")"
GPU_LABEL="$(gpu_vendor_label $GPU_VENDORS)"
HYBRID=0

if gpu_is_hybrid "$GPU_VENDORS"; then
    HYBRID=1
fi

log INFO "Detected display adapter vendor(s): $GPU_LABEL"
if [[ -n "$GPU_INFO" ]]; then
    while IFS= read -r adapter; do
        [[ -n "$adapter" ]] && log INFO "Adapter: $adapter"
    done <<<"$GPU_INFO"
fi

if [[ "$GPU_VENDORS" == unknown ]]; then
    log WARN "No supported GPU vendor was detected; installing generic Mesa and Vulkan tools only."
elif ((HYBRID)); then
    log INFO "Hybrid graphics detected. The integrated GPU remains enabled for the desktop; use your desktop's per-application GPU option for the discrete GPU."
fi

packages=(mesa mesa-utils vulkan-tools)

if multilib_enabled; then
    packages+=(lib32-mesa)
else
    log WARN "Multilib is disabled; 32-bit Mesa and Vulkan libraries will be skipped. Enable [multilib] for Steam and 32-bit games."
fi

nvidia_driver_selected=0
if gpu_has_vendor nvidia "$GPU_VENDORS"; then
    header_packages=()
    for kernel in linux linux-zen linux-lts; do
        if package_installed "$kernel"; then
            header_packages+=("${kernel}-headers")
        fi
    done
    if ((${#header_packages[@]} == 0)); then
        header_packages=(linux-headers)
    fi

    nvidia_module_package=""
    if package_installed nvidia-open-dkms; then
        nvidia_module_package=nvidia-open-dkms
        log INFO "Keeping the already-installed open NVIDIA driver (nvidia-open-dkms)."
    elif package_installed nvidia-dkms; then
        nvidia_module_package=nvidia-dkms
        log INFO "Keeping the already-installed NVIDIA driver (nvidia-dkms)."
    elif package_installed nvidia; then
        nvidia_module_package=nvidia
        log INFO "Keeping the already-installed NVIDIA driver (nvidia); it will not be replaced automatically."
    elif package_available nvidia-open-dkms; then
        nvidia_module_package=nvidia-open-dkms
        log INFO "Selected the open NVIDIA kernel module (nvidia-open-dkms)."
        log INFO "If your NVIDIA GPU is older than Turing (for example GTX 10-series), use nvidia-dkms instead."
    elif package_available nvidia-dkms; then
        nvidia_module_package=nvidia-dkms
        log INFO "Selected the standard NVIDIA kernel module (nvidia-dkms)."
    else
        log WARN "No supported NVIDIA DKMS package was found in the enabled repositories."
    fi

    if [[ -n "$nvidia_module_package" ]]; then
        nvidia_driver_selected=1
        if [[ "$nvidia_module_package" == "nvidia" ]]; then
            packages+=("$nvidia_module_package" nvidia-utils nvidia-settings)
        else
            packages+=(dkms "${header_packages[@]}" "$nvidia_module_package" nvidia-utils nvidia-settings)
        fi
    fi

    if ((nvidia_driver_selected)) && ((HYBRID)); then
        packages+=(nvidia-prime)
    fi

    if ((nvidia_driver_selected)); then
        if multilib_enabled; then
            packages+=(lib32-nvidia-utils)
        else
            log WARN "Multilib is disabled; skipping 32-bit NVIDIA libraries."
        fi
    fi
fi

if gpu_has_vendor amd "$GPU_VENDORS"; then
    packages+=(vulkan-radeon libva-mesa-driver)
    if multilib_enabled; then
        packages+=(lib32-vulkan-radeon)
    else
        log WARN "Multilib is disabled; skipping 32-bit AMD Vulkan libraries."
    fi
fi

if gpu_has_vendor intel "$GPU_VENDORS"; then
    packages+=(vulkan-intel intel-media-driver)
    if multilib_enabled; then
        packages+=(lib32-vulkan-intel)
    else
        log WARN "Multilib is disabled; skipping 32-bit Intel Vulkan libraries."
    fi
fi

log INFO "Integrated graphics will remain enabled; no PRIME or GPU power settings are changed automatically."
install_available_packages "${packages[@]}"

if ((nvidia_driver_selected)); then
    ensure_managed_config "$ROOT_DIR/config/nvidia-drm.conf" /etc/modprobe.d/arch-extreme-gaming-nvidia.conf
    log INFO "NVIDIA DRM modesetting is configured through the project-managed modprobe file."
fi

log INFO "GPU setup finished. Reboot before testing games or running vulkaninfo."
