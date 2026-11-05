# Arch Extreme Gaming

An easy-to-run setup for Arch Linux gaming PCs. It installs KDE Plasma, graphics drivers, gaming tools, and optional virtualization.

Supports NVIDIA, AMD, Intel, and hybrid graphics, including the MSI Thin 15 B12UCX.

## Before you start

- Use an installed **64-bit Arch Linux** system with internet access.
- Run as a regular user with `sudo` access.
- Keep at least 10 GB of free disk space.
- Steam and 32-bit games need the `[multilib]` repository enabled in `/etc/pacman.conf`.
- If you use Secure Boot, make sure your NVIDIA modules are signed.

This tool does not install Arch Linux or change disk partitions.

## Install

```bash
git clone https://github.com/sopanha-lay/arch-extreme-gaming.git
cd arch-extreme-gaming
./install.sh --dry-run --full  # Preview first
./install.sh                   # Choose what to install
```

The installer shows your hardware and asks before making changes. It never reboots your computer.

Useful options:

```bash
./install.sh --full             # Install everything
./install.sh --modules 03,05,06 # Choose GPU, gaming, and Flatpak
./scripts/health-check.sh       # Check your setup
./scripts/update.sh             # Update packages and apps
```

## What gets installed

- KDE Plasma, SDDM, NetworkManager, Bluetooth, and PipeWire
- Zen kernel, while keeping the standard kernel as a fallback
- Detected GPU drivers and Vulkan tools
- Steam, Lutris, Wine, GameMode, MangoHud, and other available gaming tools
- Flatpak and Flathub
- Optional SSD maintenance and QEMU/KVM virtualization

Gaming performance depends on your hardware, drivers, and game settings. No risky performance tweaks are applied.

## Important

- Enable multilib yourself to install Steam and 32-bit drivers.
- The installer does not change bootloader entries. Check your bootloader before restarting after installing the Zen kernel.
- On hybrid laptops, integrated graphics are kept enabled. Use your desktop's per-app GPU option for NVIDIA.
- To undo the NVIDIA setting created by this project, run `./scripts/rollback.sh`.

## Troubleshooting

- **Steam or 32-bit drivers are skipped:** Enable `[multilib]`, then run `sudo pacman -Syu` and retry.
- **NVIDIA does not load:** Check Secure Boot signing and run `dkms status`.
- **Zen kernel is missing from the boot menu:** Update your bootloader configuration using its own instructions.

## Tests

```bash
bash tests/test-install.sh
```

Tests do not install packages. Try the setup in an Arch virtual machine before using it on your main computer.

## License

[MIT](./LICENSE)
