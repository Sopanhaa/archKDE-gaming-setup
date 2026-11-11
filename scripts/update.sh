#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/lib/common.sh"

DRY_RUN=0

usage() {
    cat <<'EOF'
Usage: ./scripts/update.sh [--dry-run]

Options:
  --dry-run       Print planned commands without changing the system.
  --help          Show this help.

Without --dry-run, this updates official packages, Flatpak applications,
optional AUR packages, and the project repository (fast-forward only).
EOF
}

while (($#)); do
    case "$1" in
        --dry-run) DRY_RUN=1 ;;
        --help|-h) usage; exit 0 ;;
        *) die "Unknown option: $1 (use --help)." ;;
    esac
    shift
done

init_logging
export LOG_TEE=1
export LOG_FILE
exec > >(tee -a "$LOG_FILE") 2>&1

require_non_root
check_arch
check_internet

if ((DRY_RUN)); then
    log WARN "Dry run enabled; no system changes will be made."
else
    [[ -t 0 ]] || die "Updates require interactive confirmation; run this script in a terminal."
    printf 'This will update system packages, Flatpak applications, optional AUR packages, and the project repository.\n'
    printf 'Package managers will ask for any required confirmations; no automatic yes flags are used.\n'
    read -r -p "Continue? [y/N] " answer
    [[ "$answer" =~ ^[Yy]$ ]] || die "Update cancelled."
    command -v sudo >/dev/null 2>&1 || die "sudo is required for system package updates."
    sudo -v
fi

log INFO "Updating official Arch packages."
sudo_run pacman -Syu

if command -v flatpak >/dev/null 2>&1; then
    log INFO "Updating Flatpak applications."
    run flatpak update
else
    log INFO "Flatpak is not installed; skipping Flatpak updates."
fi

if command -v yay >/dev/null 2>&1; then
    log INFO "Updating AUR packages with yay (as the current user)."
    run yay -Sua
elif command -v paru >/dev/null 2>&1; then
    log INFO "Updating AUR packages with paru (as the current user)."
    run paru -Sua
else
    log INFO "No supported AUR helper found; skipping AUR updates."
fi

if git -C "$ROOT_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    if [[ -n "$(git -C "$ROOT_DIR" status --porcelain)" ]]; then
        log WARN "Project repository has local changes; skipping Git update to avoid overwriting work."
    else
        log INFO "Updating project repository with fast-forward-only Git."
        run git -C "$ROOT_DIR" pull --ff-only
    fi
else
    log WARN "Project directory is not a Git checkout; skipping repository update."
fi

log INFO "Updates complete. Review package-manager output for any errors."
