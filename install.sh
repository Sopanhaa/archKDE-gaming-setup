#!/usr/bin/env bash
set -Eeuo pipefail

# Decide about colour before lib/common.sh is sourced, because the installer
# sends all output through tee (which would otherwise hide the terminal).
for arg in "$@"; do
    if [[ "$arg" == "--no-color" ]]; then
        export NO_COLOR=1
    fi
done
if [[ -t 1 && -z "${NO_COLOR:-}" && "${TERM:-dumb}" != "dumb" ]]; then
    export SETUP_FORCE_COLOR=1
fi

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$ROOT_DIR/lib/common.sh"
source "$ROOT_DIR/lib/preflight.sh"

DRY_RUN=0
SELECTION=""
FULL_INSTALL=0
CHECK_ONLY=0
CURRENT_MODULE=""
CURRENT_MODULE_LABEL=""
MODULES_COMPLETED=()

ALL_MODULES="01 02 03 04 05 06 07 08"
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

usage() {
    cat <<'EOF'
Usage: ./install.sh [options]

Options:
  --dry-run       Preview every action without changing the system.
  --full          Install all modules without showing the menu.
  --modules LIST  Install selected modules (e.g. 03,05,06 or 3-5).
  --check         Run preflight checks only and exit.
  --no-color      Disable coloured terminal output.
  --help, -h      Show this help.

Interactive use:
  Run ./install.sh and enter module numbers such as:
    03 05 06        specific modules
    03-06           a range
    all or 0        every module
    q               quit

No option ever formats disks, edits bootloader entries, or reboots.
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
        --modules=*) SELECTION="${1#*=}" ;;
        --check|--preflight) CHECK_ONLY=1 ;;
        --no-color) export NO_COLOR=1 ;;
        --help|-h) usage; exit 0 ;;
        *) die "Unknown option: $1 (use --help)." ;;
    esac
    shift
done

if ((FULL_INSTALL)) && [[ -n "$SELECTION" ]]; then
    die "Use either --full or --modules, not both."
fi

init_logging
export LOG_FILE
export LOG_TEE=1
exec > >(tee -a "$LOG_FILE") 2>&1

on_error() {
    local status="$1"
    local line="$2"
    local command="$3"
    trap - ERR

    printf '\n'
    log ERROR "Setup stopped unexpectedly (exit status $status, line $line)."
    log ERROR "Failed command: $command"
    if [[ -n "$CURRENT_MODULE" ]]; then
        log ERROR "While running module $CURRENT_MODULE: $CURRENT_MODULE_LABEL"
    fi
    log ERROR "No changes were rolled back automatically."
    log ERROR "Read the full log here: $LOG_FILE"
    log ERROR "Fix the problem above, then rerun the same command. Completed modules are safe to rerun."
    exit "$status"
}

on_interrupt() {
    local signal="$1"
    trap - INT TERM
    printf '\n'
    log WARN "Installation interrupted ($signal). No automatic rollback was performed."
    log WARN "Review the log before rerunning: $LOG_FILE"
    exit 130
}

trap 'status=$?; on_error "$status" "$LINENO" "$BASH_COMMAND"' ERR
trap 'on_interrupt INT' INT
trap 'on_interrupt TERM' TERM

if [[ -n "$SELECTION" ]]; then
    requested_selection="$SELECTION"
    if ! SELECTION="$(parse_module_selection "$requested_selection")"; then
        die "Invalid module selection: '$requested_selection'. Use numbers from 01 to 08, a range like 03-05, or all."
    fi
fi

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

show_module_menu() {
    local i
    section "Choose installation modules"
    printf '  0) All modules (recommended for a new gaming setup)\n\n'
    for i in "${!MODULE_NUMBERS[@]}"; do
        printf '  %s) %s\n' "${MODULE_NUMBERS[$i]}" "${MODULE_TITLES[$i]}"
        printf '      %s\n' "${MODULE_DESCRIPTIONS[$i]}"
    done
    printf '\n  q) Quit without changing anything\n'
    printf '\nEnter numbers separated by spaces or commas (for example: 03 05 06),\n'
    printf 'a range such as 03-06, or "all".\n'
}

show_selection() {
    local number
    section "Installation plan"
    for number in $SELECTED_MODULES; do
        printf '  %s  %s\n' "$number" "$(module_title "$number")"
    done
    printf '\nModules run in the order shown; select 01 as well if you want a full system update first.\n'
}

interactive_select() {
    local answer normalized
    show_module_menu

    while true; do
        printf '\nSelect modules: '
        if ! IFS= read -r answer; then
            printf '\n'
            return 1
        fi
        answer="${answer#"${answer%%[![:space:]]*}"}"
        answer="${answer%"${answer##*[![:space:]]}"}"

        case "${answer,,}" in
            "") ui_warn "Please enter a selection, or q to quit."; continue ;;
            q|quit|exit) return 1 ;;
            h|help|\?) show_module_menu; continue ;;
        esac

        if normalized="$(parse_module_selection "$answer")"; then
            SELECTED_MODULES="$normalized"
            return 0
        fi
        ui_warn "That selection was not understood. Use 01-08, a range like 03-05, or all."
    done
}

choose_modules() {
    if [[ -n "$SELECTION" ]]; then
        if ! SELECTED_MODULES="$(parse_module_selection "$SELECTION")"; then
            die "Invalid module selection: '$SELECTION'. Use numbers from 01 to 08, a range like 03-05, or all."
        fi
        return 0
    fi

    if ((FULL_INSTALL)); then
        SELECTED_MODULES="$ALL_MODULES"
        return 0
    fi

    if [[ ! -t 0 ]]; then
        die "Interactive input is unavailable. Use --full, --modules LIST, or --check."
    fi
    interactive_select
}

section "Arch Extreme Gaming setup"
log INFO "Log file: $LOG_FILE"

if ! run_preflight_checks; then
    exit 1
fi
show_hardware_summary

if ((CHECK_ONLY)); then
    section "Check complete"
    log INFO "Preflight checks finished. No packages or configuration files were changed."
    exit 0
fi

if ! choose_modules; then
    log INFO "Installation cancelled. Nothing was changed."
    exit 0
fi

show_selection
read -r -a selected_module_numbers <<<"$SELECTED_MODULES"
module_count="${#selected_module_numbers[@]}"

if ((DRY_RUN)); then
    log WARN "Dry run enabled; commands are printed but no system changes will be made."
else
    printf '\nThe installer will use sudo to install packages and enable services.\n'
    printf 'It never formats disks, edits bootloader entries, or reboots automatically.\n'
    read -r -p "Proceed with installation? [y/N] " answer || answer=""
    if [[ ! "$answer" =~ ^[Yy]$ ]]; then
        log INFO "Installation cancelled. Nothing was changed."
        exit 0
    fi
    command -v sudo >/dev/null 2>&1 || die "sudo is required for system changes."
    log INFO "Requesting sudo access..."
    sudo -v || die "sudo authentication failed; nothing was changed."
fi

module_index=0
for number in "${selected_module_numbers[@]}"; do
    module_index=$((module_index + 1))
    CURRENT_MODULE="$number"
    CURRENT_MODULE_LABEL="$(module_title "$number")"

    module_file=""
    for candidate in "$ROOT_DIR/modules/${number}-"*.sh; do
        if [[ -f "$candidate" ]]; then
            module_file="$candidate"
            break
        fi
    done
    [[ -n "$module_file" ]] || die "Module $number is missing from $ROOT_DIR/modules."

    section "Module $module_index of $module_count: $CURRENT_MODULE_LABEL"
    log INFO "Starting module $number ($module_index/$module_count)."
    module_start=$SECONDS

    if DRY_RUN="$DRY_RUN" SETUP_MODULE_NUMBER="$number" \
        SETUP_MODULE_INDEX="$module_index" SETUP_MODULE_TOTAL="$module_count" \
        bash "$module_file"; then
        elapsed=$((SECONDS - module_start))
        MODULES_COMPLETED+=("$number")
        log INFO "Module $number finished successfully in $(format_duration "$elapsed")."
    else
        status=$?
        log ERROR "Module $number ($CURRENT_MODULE_LABEL) failed with exit status $status."
        log ERROR "No changes were rolled back automatically. Review the log: $LOG_FILE"
        log ERROR "Fix the reported problem, then rerun this module with: ./install.sh --modules $number"
        exit "$status"
    fi
done

CURRENT_MODULE=""
CURRENT_MODULE_LABEL=""

section "Setup complete"
printf '  Modules completed: %s\n' "${MODULES_COMPLETED[*]}"
if ((DRY_RUN)); then
    printf '  Mode: dry run (nothing was changed)\n'
else
    printf '  Mode: installation\n'
fi
printf '  Log file: %s\n' "$LOG_FILE"
if ((!DRY_RUN)); then
    printf '  Tracked configuration changes: %s\n' "$(tracked_change_count)"
    printf '  Review rollback with: ./scripts/rollback.sh --dry-run\n'
fi
printf '\nNext steps:\n'
printf '  - Reboot when convenient so the new kernel and GPU drivers load.\n'
printf '  - Sign out and back in if this setup added you to the libvirt group.\n'
printf '  - Run ./scripts/health-check.sh to verify the installation.\n'
printf '  - Check your bootloader menu before rebooting to use linux-zen.\n'
printf '\nThis installer did not reboot your computer or modify boot entries.\n'
