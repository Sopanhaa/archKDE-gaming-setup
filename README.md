# Arch KDE Gaming Setup

Sets up an Arch Linux computer for gaming: KDE Plasma, graphics drivers, Steam and friends, and optional performance tweaks.

Safe by design — it keeps your current kernel, asks before changing anything, and never formats disks, edits boot entries, or reboots your PC.

## Requirements

- Arch Linux (64-bit) with internet access
- A regular user account with `sudo` (do not run as root)
- 10 GB free disk space (5 GiB minimum)
- `[multilib]` enabled for Steam — see [Troubleshooting](#troubleshooting)
- Secure Boot users must sign NVIDIA/kernel modules themselves; this project does not

## Install

One command:

```bash
git clone https://github.com/Sopanhaa/archKDE-play.git && cd archKDE-play && ./install.sh --full
```

It prints the plan and asks `Proceed with installation? [y/N]` — enter `y` to continue, anything else cancels. To look first, use `./install.sh --dry-run --full` (preview) or `./install.sh` (pick modules).

## Modules

| # | Module | Installs |
|---|--------|----------|
| 01 | System update | Arch updates plus `git`, `curl`, `pciutils` |
| 02 | Zen kernel | `linux-zen`, keeping your current kernel as fallback |
| 03 | GPU drivers | Matching drivers and Vulkan for your detected GPU |
| 04 | KDE Plasma | Plasma, SDDM, NetworkManager, Bluetooth, PipeWire |
| 05 | Gaming tools | Steam, Lutris, Wine, GameMode, MangoHud, Heroic |
| 06 | Flatpak | Flatpak with the Flathub store |
| 07 | Performance | SSD trim and safe power profiles, no risky tweaks |
| 08 | Virtualization | QEMU/KVM and Virt-Manager |

Install all modules with `--full`, or pick some:

```bash
./install.sh --modules 03,05,06    # specific modules
./install.sh --modules 03-05       # a range
```

`--full` and `--modules` cannot be combined.

## Common commands

| Task | Command |
|------|---------|
| Check the system (no changes) | `./install.sh --check` |
| Preview everything (no changes) | `./install.sh --dry-run --full` |
| Install all modules | `./install.sh --full` |
| Check system health | `./scripts/health-check.sh` |
| Update system and this project | `./scripts/update.sh` |
| Preview updates | `./scripts/update.sh --dry-run` |
| Skip third-party AUR updates | `./scripts/update.sh --skip-aur` |
| Undo project config files | `./scripts/rollback.sh` |

AUR helpers run third-party code — use `--skip-aur` if you prefer to avoid that.

## GPU support

GPUs are detected automatically: **NVIDIA** gets `nvidia-open-dkms` (or `nvidia-dkms`), **AMD** gets Mesa and `vulkan-radeon`, **Intel** gets `vulkan-intel`, and **hybrid laptops** get drivers for every vendor (`prime-run` works). The installer never forces PRIME, changes GPU power settings, or disables the integrated GPU.

## Troubleshooting

| Problem | Fix |
|---------|-----|
| Install fails | Read `~/.local/state/archkde-play/logs/`, fix the issue, rerun e.g. `./install.sh --modules 03`. Completed modules are safe to rerun. |
| NVIDIA driver issues | Sign modules if Secure Boot is on, check with `dkms status`. Pre-Turing GPUs need `nvidia-dkms`, not `nvidia-open-dkms`. |
| Steam not working | Enable `[multilib]` in `/etc/pacman.conf`, run `sudo pacman -Syu`, then `./install.sh --modules 05`. |
| Vulkan issues | `sudo pacman -S vulkan-tools && vulkaninfo --summary`. Ensure `vulkan-radeon`, `vulkan-intel`, or `nvidia-utils` is installed. |
| Packages skipped | Refresh first: `sudo pacman -Syu`, then rerun the module. |

`./scripts/rollback.sh --dry-run` previews removing config files this project created. Rollback does not remove packages or undo driver changes.

## Contributing

See `CONTRIBUTING.md` (setup, style, PRs), `SECURITY.md` (private reports), and `CODE_OF_CONDUCT.md`.

## License

[MIT](./LICENSE)
