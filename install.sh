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
source "$ROOT_DIR/lib/modules.sh"

DRY_RUN=0
SELECTION=""
SELECTION_SET=0
FULL_INSTALL=0
CHECK_ONLY=0
CURRENT_MODULE=""
CURRENT_MODULE_LABEL=""
MODULES_COMPLETED=()

usage() {
    cat <<'EOF'
Usage: ./install.sh [options]

Options:
  --dry-run       Preview every action without changing the system.
  --full          Install all modules without showing the menu.
  --modules LIST  Install selected modules (e.g. 03,05,06 or 3-5).
  --check         Run preflight checks only and exit.
  --list-modules  Show module numbers, titles, and descriptions.
  --version       Show the project version.
  --quiet         Show warnings and errors only (everything is still logged).
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

project_version() {
    local version=""
    if command -v git >/dev/null 2>&1 &&
        git -C "$ROOT_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        version="$(git -C "$ROOT_DIR" describe --tags --always --dirty 2>/dev/null || true)"
    fi
    printf '%s\n' "${version:-dev}"
}

while (($#)); do
    case "$1" in
        --dry-run) DRY_RUN=1 ;;
        --full) FULL_INSTALL=1 ;;
        --modules)
            (($# >= 2)) || die "--modules requires a comma-separated module list."
            SELECTION="$2"
            SELECTION_SET=1
            shift
            ;;
        --modules=*)
            SELECTION="${1#*=}"
            SELECTION_SET=1
            ;;
        --check|--preflight) CHECK_ONLY=1 ;;
        --list-modules) list_modules; exit 0 ;;
        --version) printf 'archKDE-play %s\n' "$(project_version)"; exit 0 ;;
        --quiet) SETUP_QUIET=1; export SETUP_QUIET ;;
        --no-color) export NO_COLOR=1 ;;
        --help|-h) usage; exit 0 ;;
        *) die "Unknown option: $1 (use --help)." ;;
    esac
    shift
done

if ((FULL_INSTALL && SELECTION_SET)); then
    die "Use either --full or --modules, not both."
fi
if ((SELECTION_SET)) && [[ -z "${SELECTION//[[:space:]]/}" ]]; then
    die "--modules requires at least one module number."
fi

# Check this before creating any log or state files, so running with sudo does
# not leave root-owned files behind.
if ((EUID == 0)); then
    printf 'Run this installer as a regular user, not root.\n' >&2
    exit 1
fi

if ((DRY_RUN || CHECK_ONLY)); then
    export LOG_FILE="/dev/null"
    export LOG_TEE=0
else
    init_logging
    export LOG_FILE
    export LOG_TEE=1
    exec > >(tee -a "$LOG_FILE") 2>&1
fi

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
    if ((DRY_RUN || CHECK_ONLY)); then
        log ERROR "Logging is disabled in dry-run/check mode."
    else
        log ERROR "Read the full log here: $LOG_FILE"
    fi
    log ERROR "Review project-managed changes with: ./scripts/rollback.sh --dry-run"
    log ERROR "Fix the problem above, then rerun the same command. Completed modules are safe to rerun."
    exit "$status"
}

on_interrupt() {
    local signal="$1"
    trap - INT TERM
    printf '\n'
    log WARN "Installation interrupted ($signal). No automatic rollback was performed."
    if ((DRY_RUN || CHECK_ONLY)); then
        log WARN "Logging is disabled in dry-run/check mode."
    else
        log WARN "Review the log before rerunning: $LOG_FILE"
    fi
    exit 130
}

trap 'on_error "$?" "$LINENO" "$BASH_COMMAND"' ERR
trap 'on_interrupt INT' INT
trap 'on_interrupt TERM' TERM

if ((SELECTION_SET)); then
    requested_selection="$SELECTION"
    if ! SELECTION="$(parse_module_selection "$requested_selection")"; then
        die "Invalid module selection: '$requested_selection'. Use numbers from 01 to 08, a range like 03-05, or all."
    fi
fi

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
    if ((SELECTION_SET)); then
        SELECTED_MODULES="$SELECTION"
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

section "Arch KDE Gaming Setup"
if ((DRY_RUN || CHECK_ONLY)); then
    log WARN "Log file: not written (dry-run/check mode)."
else
    log INFO "Log file: $LOG_FILE"
fi

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

# Fail before changing anything if a configured module has no script.
declare -A module_paths=()
for number in "${selected_module_numbers[@]}"; do
    module_file="$(module_script "$number")" || true
    [[ -n "$module_file" ]] || die "Module $number is missing from $ROOT_DIR/modules."
    module_paths["$number"]="$module_file"
done

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

    section "Module $module_index of $module_count: $CURRENT_MODULE_LABEL"
    log INFO "Starting module $number ($module_index/$module_count)."
    module_start=$SECONDS

    if DRY_RUN="$DRY_RUN" SETUP_MODULE_NUMBER="$number" \
        SETUP_MODULE_INDEX="$module_index" SETUP_MODULE_TOTAL="$module_count" \
        bash "${module_paths[$number]}"; then
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
printf '  Modules completed: %s\n' "${MODULES_COMPLETED[*]-}"
if ((DRY_RUN)); then
    printf '  Mode: dry run (nothing was changed)\n'
else
    printf '  Mode: installation\n'
fi
if ((DRY_RUN)); then
    printf '  Log file: not written (dry run)\n'
else
    printf '  Log file: %s\n' "$LOG_FILE"
fi
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
