#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/lib/common.sh"

usage() {
    cat <<'EOF'
Usage: ./scripts/rollback.sh [--dry-run]

Removes only configuration files that this project created and that are still
unchanged. Packages, package upgrades, boot entries, service states, and GPU
driver changes are never reverted.
EOF
}

for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=1 ;;
        --help|-h) usage; exit 0 ;;
        *) die "Unknown option: $arg (use --help)." ;;
    esac
done

init_logging
require_non_root
check_arch

section "Project-managed rollback"
printf 'This only removes configuration files created by this project whose\n'
printf 'contents are still unchanged. It does NOT remove packages, undo package\n'
printf 'upgrades, restore service states, change boot entries, or revert drivers.\n\n'

if [[ ! -f "$MANIFEST_FILE" ]]; then
    log INFO "No tracked project changes were found."
    exit 0
fi

declare -A remove_entries=()
declare -A backups=()
declare -a removable=()
declare -a kept=()
declare -a already_absent=()

while IFS='|' read -r kind target detail source; do
    [[ -n "${kind:-}" ]] || continue
    case "$kind" in
        created)
            if [[ ! -e "$target" ]]; then
                already_absent+=("$target")
                remove_entries["$target"]=1
            elif [[ -n "$detail" && "$(file_sha256 "$target")" == "$detail" ]]; then
                removable+=("$target")
                remove_entries["$target"]=1
            else
                kept+=("$target")
                log WARN "Keeping modified or user-owned file: $target"
            fi
            ;;
        backup)
            backups["$target"]="${detail:--}"
            ;;
    esac
done <"$MANIFEST_FILE"

if ((${#already_absent[@]})); then
    log INFO "Already absent (cleaning tracking only): ${already_absent[*]}"
fi
if ((${#kept[@]})); then
    log WARN "These tracked files were changed after installation and will be kept: ${kept[*]}"
fi
if ((${#backups[@]})); then
    log INFO "Backups created by this project are retained, not restored:"
    for target in "${!backups[@]}"; do
        printf '  %s -> %s\n' "$target" "${backups[$target]}"
    done
fi

if ((${#removable[@]} == 0)); then
    log INFO "No unchanged project-managed files need to be removed."
    exit 0
fi

printf '\nFiles that will be removed:\n'
for target in "${removable[@]}"; do
    printf '  %s\n' "$target"
done

if ((DRY_RUN)); then
    log WARN "Dry run enabled; no files will be removed."
else
    [[ -t 0 ]] || die "Rollback requires interactive confirmation."
    read -r -p "Remove these files? [y/N] " answer
    [[ "$answer" =~ ^[Yy]$ ]] || die "Rollback cancelled."
    command -v sudo >/dev/null 2>&1 || die "sudo is required to remove system configuration."
    sudo -v || die "sudo authentication failed."
fi

for target in "${removable[@]}"; do
    sudo_run rm -- "$target"
done

if ((!DRY_RUN)); then
    tmp_manifest="$(mktemp)"
    while IFS='|' read -r kind target detail source; do
        [[ -n "${kind:-}" ]] || continue
        if [[ "$kind" == "created" && "${remove_entries[$target]:-0}" == "1" ]]; then
            continue
        fi
        printf '%s|%s|%s|%s\n' "$kind" "$target" "$detail" "$source" >>"$tmp_manifest"
    done <"$MANIFEST_FILE"
    mv -- "$tmp_manifest" "$MANIFEST_FILE"
fi

log INFO "Rollback complete. Packages, package upgrades, boot entries, services, and drivers were not changed."
