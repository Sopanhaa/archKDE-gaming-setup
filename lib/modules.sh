#!/usr/bin/env bash

# Single source of truth for installation modules. Keep this list in dependency
# order; the installer menu, validation, and tests all read from it.

MODULE_DIR="${ROOT_DIR}/modules"
MODULE_NUMBERS=(01 02 03 04 05 06 07 08)
MODULE_TITLES=(
    "System update and base tools"
    "Zen kernel (with standard kernel fallback)"
    "GPU drivers and Vulkan"
    "KDE Plasma desktop and services"
    "Gaming tools"
    "Flatpak and Flathub"
    "Safe performance setup"
    "QEMU/KVM virtualization"
)
MODULE_DESCRIPTIONS=(
    "Update Arch and install git, curl, wget, and PCI tools."
    "Install linux-zen without removing your current kernel."
    "Auto-detect NVIDIA, AMD, Intel, and hybrid laptop graphics."
    "Install Plasma, SDDM, NetworkManager, Bluetooth, and PipeWire."
    "Install Steam, Lutris, Wine, GameMode, MangoHud, and Heroic."
    "Configure Flatpak and the Flathub application store."
    "Enable SSD trim and safe power profiles only."
    "Install QEMU/KVM and Virt-Manager for virtual machines."
)
ALL_MODULES="${MODULE_NUMBERS[*]}"

module_title() {
    local number="$1"
    local i
    for i in "${!MODULE_NUMBERS[@]}"; do
        if [[ "${MODULE_NUMBERS[$i]}" == "$number" ]]; then
            printf '%s' "${MODULE_TITLES[$i]}"
            return 0
        fi
    done
    printf 'Module %s' "$number"
}

module_script() {
    local number="$1"
    local candidate
    for candidate in "$MODULE_DIR/${number}-"*.sh; do
        if [[ -f "$candidate" ]]; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done
    return 1
}

list_modules() {
    local i
    for i in "${!MODULE_NUMBERS[@]}"; do
        printf '%s  %s\n' "${MODULE_NUMBERS[$i]}" "${MODULE_TITLES[$i]}"
        printf '    %s\n' "${MODULE_DESCRIPTIONS[$i]}"
    done
}

# Normalise an interactive/CLI module selection into dependency order.
# Accepts "1 3 5", "01,03,05", ranges such as "03-05", and all/0.
parse_module_selection() {
    local input="${1:-}"
    local token start end number mask=0 result="" max
    local -a tokens=()

    max="${#MODULE_NUMBERS[@]}"
    input="${input//,/ }"
    input="${input//$'\t'/ }"
    read -r -a tokens <<<"$input"
    ((${#tokens[@]})) || return 1

    if ((${#tokens[@]} == 1)); then
        case "${tokens[0],,}" in
            all|full|everything|0)
                printf '%s' "$ALL_MODULES"
                return 0
                ;;
        esac
    fi

    for token in "${tokens[@]}"; do
        if [[ "$token" =~ ^([0-9]{1,2})-([0-9]{1,2})$ ]]; then
            start=$((10#${BASH_REMATCH[1]}))
            end=$((10#${BASH_REMATCH[2]}))
            ((start >= 1 && end <= max && start <= end)) || return 1
            for ((number = start; number <= end; number++)); do
                mask=$((mask | (1 << (number - 1))))
            done
        elif [[ "$token" =~ ^0?([0-9]{1,2})$ ]]; then
            number=$((10#${BASH_REMATCH[1]}))
            ((number >= 1 && number <= max)) || return 1
            mask=$((mask | (1 << (number - 1))))
        else
            return 1
        fi
    done

    ((mask)) || return 1
    for ((number = 1; number <= max; number++)); do
        if ((mask & (1 << (number - 1)))); then
            result+="${result:+ }${MODULE_NUMBERS[number - 1]}"
        fi
    done
    printf '%s' "$result"
}
