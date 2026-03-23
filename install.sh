#!/usr/bin/env bash
set -euo pipefail

LOG="install.log"
exec > >(tee -a "$LOG") 2>&1

echo "Arch Gaming Setup"

if [[ "$EUID" -eq 0 ]]; then
  echo "Run as normal user, not root!"
  exit 1
fi

sudo pacman -Syu --noconfirm git base-devel wget curl

# Run all modules in order
for script in modules/*.sh; do
  echo "Running $script"
  bash "$script"
done

echo "INSTALL COMPLETE"
echo "Reboot now"
