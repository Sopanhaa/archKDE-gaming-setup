#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/lib/common.sh"
init_logging
export LOG_TEE=1
exec > >(tee -a "$LOG_FILE") 2>&1

require_non_root
check_arch
check_internet
[[ -t 0 ]] || die "Updates require interactive confirmation; run this script in a terminal."
printf 'This will update system packages, Flatpak applications, optional AUR packages, and the project repository.\n'
printf 'Package managers will ask for any required confirmations; no automatic yes flags are used.\n'
read -r -p "Continue? [y/N] " answer
[[ "$answer" =~ ^[Yy]$ ]] || die "Update cancelled."
command -v sudo >/dev/null 2>&1 || die "sudo is required for system package updates."
sudo -v

log INFO "Updating official Arch packages."
sudo pacman -Syu

if command -v flatpak >/dev/null 2>&1; then
    log INFO "Updating Flatpak applications."
    flatpak update
fi

if command -v yay >/dev/null 2>&1; then
    log INFO "Updating AUR packages with yay (as the current user)."
    yay -Sua
elif command -v paru >/dev/null 2>&1; then
    log INFO "Updating AUR packages with paru (as the current user)."
    paru -Sua
else
    log INFO "No supported AUR helper found; skipping AUR updates."
fi

if git -C "$ROOT_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    if [[ -z "$(git -C "$ROOT_DIR" status --porcelain)" ]]; then
        log INFO "Updating project repository with fast-forward-only Git."
        git -C "$ROOT_DIR" pull --ff-only
    else
        log WARN "Project repository has local changes; skipping Git update to avoid overwriting work."
    fi
else
    log WARN "Project directory is not a Git checkout; skipping repository update."
fi

log INFO "Updates complete. Review package-manager output for any errors."
