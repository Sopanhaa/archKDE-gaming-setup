#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/lib/common.sh"
init_logging

passed=0
warnings=0
failures=0

pass() {
    log INFO "OK: $*"
    ((passed += 1))
}

warn() {
    log WARN "CHECK: $*"
    ((warnings += 1))
}

fail() {
    log ERROR "FAIL: $*"
    ((failures += 1))
}

module_loaded() {
    local module="$1"
    [[ -d "/sys/module/$module" ]]
}

section "System and kernel"
if [[ -f /etc/arch-release ]]; then
    pass "Arch Linux detected"
else
    fail "This is not an Arch Linux system."
fi
if command -v pacman >/dev/null 2>&1; then
    pass "pacman is available"
else
    fail "pacman is unavailable."
fi
if package_installed linux-zen; then
    pass "linux-zen is installed"
else
    warn "linux-zen is not installed"
fi
if package_installed linux; then
    pass "Standard linux kernel is present as a fallback"
else
    warn "The standard linux kernel is not installed; keep a fallback kernel"
fi

section "Graphics drivers"
GPU_INFO="$(detect_system_gpu_info)"
GPU_VENDORS="$(detect_gpu_vendors "$GPU_INFO")"
mapfile -t GPU_VENDOR_LIST <<<"$GPU_VENDORS"
if [[ "$GPU_VENDORS" == unknown ]]; then
    warn "No supported GPU vendor was detected"
else
    pass "Detected GPU vendor(s): $(gpu_vendor_label "${GPU_VENDOR_LIST[@]}")"
fi

HYBRID=0
if gpu_is_hybrid "$GPU_VENDORS"; then
    HYBRID=1
    pass "Hybrid graphics detected; integrated graphics should remain enabled"
fi

if gpu_has_vendor nvidia "$GPU_VENDORS"; then
    if module_loaded nvidia; then
        pass "NVIDIA kernel module is loaded"
    else
        warn "NVIDIA kernel module is not loaded (it may load only when needed)"
    fi
    if command -v nvidia-smi >/dev/null 2>&1; then
        pass "nvidia-smi is available"
    else
        warn "nvidia-smi is unavailable; check nvidia-utils"
    fi
    if package_installed nvidia-utils; then
        pass "NVIDIA userspace utilities are installed"
    else
        warn "nvidia-utils is not installed"
    fi
    if ((HYBRID)); then
        if command -v prime-run >/dev/null 2>&1; then
            pass "NVIDIA PRIME offloading helper (prime-run) is available"
        else
            warn "prime-run is unavailable; install nvidia-prime for per-app offloading"
        fi
    fi
fi

if gpu_has_vendor amd "$GPU_VENDORS"; then
    if module_loaded amdgpu; then
        pass "AMD amdgpu kernel module is loaded"
    else
        warn "AMD amdgpu kernel module is not loaded"
    fi
    if package_installed vulkan-radeon; then
        pass "AMD Vulkan driver is installed"
    else
        warn "vulkan-radeon is not installed"
    fi
fi

if gpu_has_vendor intel "$GPU_VENDORS"; then
    if module_loaded i915 || module_loaded xe; then
        pass "Intel graphics kernel module is loaded"
    else
        warn "Intel graphics kernel module is not loaded"
    fi
    if package_installed vulkan-intel; then
        pass "Intel Vulkan driver is installed"
    else
        warn "vulkan-intel is not installed"
    fi
fi

if secure_boot_enabled; then
    warn "Secure Boot is enabled; unsigned NVIDIA/kernel modules may not load"
else
    pass "Secure Boot is disabled or not detected (it was not changed)"
fi

section "Vulkan"
if command -v vulkaninfo >/dev/null 2>&1; then
    pass "Vulkan tools are installed"
    if vulkan_output="$(vulkaninfo --summary 2>&1)" && grep -qi 'deviceName' <<<"$vulkan_output"; then
        pass "Vulkan reported at least one device"
    else
        warn "vulkaninfo did not report a usable device"
    fi
else
    warn "vulkaninfo is unavailable; install vulkan-tools"
fi
icd_count="$(find /usr/share/vulkan/icd.d -maxdepth 1 -name '*.json' 2>/dev/null | wc -l)"
if ((icd_count > 0)); then
    pass "Vulkan ICD files found ($icd_count)"
else
    warn "No Vulkan ICD files were found in /usr/share/vulkan/icd.d"
fi

section "Gaming tools"
if package_installed steam || command -v steam >/dev/null 2>&1; then
    pass "Steam is installed"
else
    warn "Steam is not installed"
fi
if command -v gamemoderun >/dev/null 2>&1 && command -v gamemoded >/dev/null 2>&1; then
    pass "GameMode is installed"
    if systemctl --user is-active --quiet gamemoded 2>/dev/null; then
        pass "GameMode user daemon is running"
    else
        warn "GameMode user daemon is not running (it may start on demand)"
    fi
else
    warn "GameMode is not installed"
fi
if command -v mangohud >/dev/null 2>&1; then
    pass "MangoHud is installed"
else
    warn "MangoHud is not installed"
fi
if command -v lutris >/dev/null 2>&1; then
    pass "Lutris is installed"
else
    warn "Lutris is not installed"
fi
if command -v wine >/dev/null 2>&1; then
    pass "Wine is installed"
else
    warn "Wine is not installed"
fi
if multilib_enabled; then
    pass "[multilib] is enabled for 32-bit games"
else
    warn "[multilib] is disabled; Steam and 32-bit libraries may be unavailable"
fi

section "Desktop, services, and Flatpak"
services=(NetworkManager bluetooth sddm fstrim.timer)
if package_installed libvirt; then
    services+=(libvirtd)
fi
for service in "${services[@]}"; do
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

printf '\nHealth check: %d passed, %d warning(s), %d failure(s).\n' "$passed" "$warnings" "$failures"
printf 'Log: %s\n' "$LOG_FILE"
((failures == 0))
