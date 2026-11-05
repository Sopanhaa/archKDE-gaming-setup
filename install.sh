#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$ROOT_DIR/lib/common.sh"

DRY_RUN=0
SELECTION=""
FULL_INSTALL=0

usage() {
    cat <<'EOF'
Usage: ./install.sh [--dry-run] [--full | --modules LIST]

Options:
  --dry-run       Print planned actions without changing the system.
  --full          Run all setup modules without showing the selection menu.
  --modules LIST  Run selected module numbers in dependency order (e.g. 01,04,06).
  --help          Show this help.
EOF
}

while (($#)); do
    case "$1" in
        --dry-run) DRY_RUN=1 ;;
        --full) FULL_INSTALL=1 ;;
        --modules)
            (($# >= 2)) || die "--modules requires a comma-separated module list."
            SELECTION="$2"
            shift
            ;;
        --help|-h) usage; exit 0 ;;
        *) die "Unknown option: $1 (use --help)." ;;
    esac
    shift
done

init_logging
export LOG_TEE=1
exec > >(tee -a "$LOG_FILE") 2>&1
trap 'status=$?; log ERROR "Installation failed at line $LINENO (exit $status). See $LOG_FILE."; exit "$status"' ERR

require_non_root
check_arch
check_internet
show_hardware_summary

MODULES=(
    "01:system:Base system updates and tools"
    "02:kernel:Zen kernel and fallback kernel"
    "03:gpu:GPU drivers and Vulkan"
    "04:kde:KDE Plasma, display manager, network, audio"
    "05:gaming:Gaming tools"
    "06:flatpak:Flatpak and Flathub"
    "07:performance:Conservative performance setup"
    "08:virtualization:QEMU/KVM and Virt-Manager"
)

select_modules() {
    if [[ -n "$SELECTION" ]]; then
        local normalized number
        local -a requested=()
        normalized="$(printf '%s' "$SELECTION" | tr ',' ' ')"
        SELECTED_MODULES=""
        read -r -a requested <<<"$normalized"
        for number in "${requested[@]}"; do
            [[ "$number" =~ ^0[1-8]$ ]] || die "Invalid module number: $number."
            if [[ " $SELECTED_MODULES " == *" $number "* ]]; then
                continue
            fi
            SELECTED_MODULES+="${SELECTED_MODULES:+ }$number"
        done
        [[ -n "$SELECTED_MODULES" ]] || die "No module numbers were provided."
        return
    fi

    if ((FULL_INSTALL)); then
        SELECTED_MODULES="01 02 03 04 05 06 07 08"
        return
    fi

    [[ -t 0 ]] || die "Interactive input is unavailable; use --full or --modules LIST."
    printf '\nInstallation modules:\n'
    printf '  0) Full installation\n'
    for item in "${MODULES[@]}"; do
        IFS=: read -r number _ description <<<"$item"
        printf '  %s) %s\n' "$number" "$description"
    done
    printf '  q) Quit\n\n'
    read -r -p "Select full install, custom, or quit [0/c/q]: " choice
    case "$choice" in
        0) SELECTED_MODULES="01 02 03 04 05 06 07 08" ;;
        c|C)
            read -r -p "Enter module numbers separated by commas (e.g. 03,05,06): " entered
            SELECTION="$entered"
            select_modules
            ;;
        q|Q) exit 0 ;;
        *) die "Invalid selection." ;;
    esac
}

select_modules

ordered_modules=""
for item in "${MODULES[@]}"; do
    IFS=: read -r number _ _ <<<"$item"
    if [[ " $SELECTED_MODULES " == *" $number "* ]]; then
        ordered_modules+="${ordered_modules:+ }$number"
    fi
done
SELECTED_MODULES="$ordered_modules"
read -r -a selected_module_numbers <<<"$SELECTED_MODULES"

printf '\nSelected modules: %s\n' "${SELECTED_MODULES// /, }"
if ((DRY_RUN)); then
    log WARN "Dry run enabled; no system changes will be made."
else
    printf '\nThis may install packages, enable services, and add project-managed configuration.\n'
    printf 'It will not format disks, edit boot entries, or reboot the system.\n'
    read -r -p "Continue? [y/N] " answer
    [[ "$answer" =~ ^[Yy]$ ]] || die "Installation cancelled."
    command -v sudo >/dev/null 2>&1 || die "sudo is required for system changes."
    sudo -v
fi

for number in "${selected_module_numbers[@]}"; do
    module_file="$(find "$ROOT_DIR/modules" -maxdepth 1 -type f -name "${number}-*.sh" -print -quit)"
    [[ -n "$module_file" ]] || die "Module $number is missing."
    log INFO "Running $(basename "$module_file")"
    DRY_RUN="$DRY_RUN" bash "$module_file"
done

printf '\nInstallation summary\n'
printf '  Modules completed: %s\n' "${SELECTED_MODULES// /, }"
if ((DRY_RUN)); then
    printf '  Dry run: yes\n'
else
    printf '  Dry run: no\n'
fi
printf '  Log: %s\n' "$LOG_FILE"
printf '  Reboot only if desired; this installer never reboots automatically.\n'
