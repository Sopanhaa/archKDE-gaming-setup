# Arch Extreme Gaming

An interactive, modular Arch Linux bootstrap for KDE Plasma gaming computers. It favors documented package defaults and changes that are reversible or easy to inspect. It does not partition or format disks, disable security mitigations, force a CPU governor, edit boot entries, or reboot.

## Supported hardware

- x86_64 Arch Linux installations, including fresh `archinstall` minimal installs
- NVIDIA, AMD, Intel, and Intel/NVIDIA hybrid graphics
- MSI Thin 15 B12UCX (Core i5-12450H, RTX 2050, Intel graphics) is a target configuration
- UEFI/BIOS systems with a compatible, already-installed bootloader

GPU drivers and 32-bit libraries are selected from enabled official repositories. NVIDIA DKMS drivers are preferred so the Zen kernel can build its module. If Secure Boot is enabled, your existing signing/enrollment setup must permit the NVIDIA module to load. The installer does not install an AUR helper or run one as root.

## Requirements

- An installed, bootable Arch Linux system; this does not install Arch or change partitions.
- x86_64 CPU, internet access, `sudo`, `pacman`, and a working shell. Connectivity is checked with `curl`, `wget`, or a bounded TCP fallback.
- A bootloader configured by the user. Review the kernel section below before relying on a newly installed kernel.
- About 10 GiB or more free on `/` is recommended; the installer reports available space.
- Enable the `[multilib]` repository in `/etc/pacman.conf` and refresh package databases to install Steam and 32-bit gaming libraries. The setup warns and skips unavailable multilib packages rather than editing pacman configuration.

Run from a TTY if no desktop environment is installed. The installer runs as a regular user and requests sudo access only for system changes.

## Install

```bash
git clone https://github.com/sopanha-lay/arch-extreme-gaming.git
cd arch-extreme-gaming
chmod +x install.sh
./install.sh
```

The default flow checks Arch Linux and internet access, prints a hardware summary, offers full/custom module selection, and asks for confirmation before changes. No automatic reboot occurs.

```bash
# Review the full plan without changing the system
./install.sh --dry-run --full

# Select modules; they always run in dependency order
./install.sh --modules 03,04,05

# Run all modules without the selection menu (still asks before changes)
./install.sh --full
```

`--dry-run` still requires Arch Linux and an internet connection so preflight behavior matches a real run. It skips sudo and package installation.

## Project layout

```text
install.sh                 preflight, hardware summary, menu, orchestration
config/packages.conf       official package groups
config/nvidia-drm.conf     project-managed NVIDIA DRM modesetting file
lib/common.sh              logging, package checks, GPU detection, safe helpers
modules/01-system.sh       official package update and base tools
modules/02-kernel.sh       Zen kernel, preserve standard-kernel fallback
modules/03-gpu.sh          GPU detection, drivers, Vulkan and optional multilib
modules/04-kde.sh          KDE, SDDM, NetworkManager, Bluetooth, PipeWire
modules/05-gaming.sh       Steam, Lutris, GameMode, MangoHud, ProtonUp-Qt, Heroic
modules/06-flatpak.sh      Flatpak, Flathub setup and remote verification
modules/07-performance.sh  SSD trim and dynamic power profiles when available
modules/08-virtualization.sh QEMU/KVM, Virt-Manager, libvirt
scripts/update.sh          confirmed system/app/AUR/repository updates
scripts/health-check.sh    service, kernel, Flatpak and Vulkan checks
scripts/rollback.sh        remove the unchanged project-managed NVIDIA config
tests/test-install.sh      Bash unit tests for shared helpers and safety behavior
```

The older top-level module names remain as compatibility wrappers. New work should use `modules/` and `scripts/`.

## Modules and behavior

1. **System:** Runs `pacman -Syu` interactively, then installs common tools and `pciutils`.
2. **Kernel:** Installs `linux-zen` and its headers. It keeps the standard `linux` kernel and installs it if missing. It detects common bootloader/Secure Boot conditions but never regenerates bootloader configuration or writes boot entries.
3. **GPU:** Uses `lspci` to identify display devices. Hybrid systems retain integrated graphics. Installs Mesa/Vulkan and the appropriate vendor driver; installs 32-bit packages only when multilib is active. It adds NVIDIA DRM modesetting only when the project config does not already exist. Existing configuration is never overwritten.
4. **KDE:** Installs a small Plasma desktop, SDDM with XWayland compatibility, NetworkManager, Bluetooth, and PipeWire packages; enables the relevant system services. Select the Plasma Wayland session at login.
5. **Gaming:** Installs available official packages for Steam, Lutris, MangoHud, GameMode, Wine, Gamescope, ProtonUp-Qt, and Flatpak. Heroic and ProtonUp-Qt use Flathub if no repository package is available. ProtonUp-Qt is used to download/manage Proton-GE releases; it does not select a Proton version for a game.
6. **Flatpak:** Adds the Flathub system remote only if missing and checks that the remote can be queried.
7. **Performance:** Enables `fstrim.timer` only when root storage is detected as solid-state. Uses `power-profiles-daemon` if available instead of pinning the CPU to a high-power governor. No speculative sysctl/kernel flags or zram configuration are applied.
8. **Virtualization:** Installs QEMU/KVM and Virt-Manager only when CPU virtualization extensions are detected, enables libvirt, and adds the current account to `libvirt` (effective after signing in again).

Package availability is checked against configured Arch repositories. Unavailable optional packages are reported and skipped. No AUR packages are required.

### Performance expectations

- `fstrim.timer` periodically tells SSDs which blocks are unused. This supports sustained storage behavior; it does not increase game frame rates.
- `power-profiles-daemon` exposes the system's supported balanced/performance power modes rather than forcing maximum clocks continuously. Actual results depend on firmware, cooling, and the selected desktop power profile.
- `linux-zen` is an alternative kernel intended to favor responsiveness. It is not a guaranteed FPS improvement, so keep the stock kernel available for comparison and recovery.
- GPU/Vulkan drivers and PRIME offload provide the correct rendering path for supported games. Performance depends on each game's graphics settings and GPU.

## NVIDIA hybrid graphics and bootloader notes

- The installer does not disable Intel graphics or change power-management settings for either GPU. When an NVIDIA driver is available, `nvidia-prime` provides the standard PRIME render-offload helper.
- NVIDIA DRM modesetting is enabled through a dedicated file under `/etc/modprobe.d/` only if that path does not already exist. Inspect `/etc/modprobe.d/arch-extreme-gaming-nvidia.conf` before removing it.
- The kernel package installs its initramfs through Arch's normal package hooks. Boot entry updates are bootloader-specific and deliberately left to you.
- For GRUB, review your setup and regenerate its configuration yourself after installation if needed (commonly `sudo grub-mkconfig -o /boot/grub/grub.cfg`).
- For systemd-boot, verify a valid loader entry or UKI exists for the kernel you intend to boot. Existing loader entries are not overwritten.
- With Secure Boot enabled, ensure the selected NVIDIA DKMS module is signed according to your established workflow.
- Do not remove the standard kernel until the Zen kernel successfully boots.

For PRIME render offload, use the desktop's per-application GPU launch option where available. Confirm driver status with `nvidia-smi` and Vulkan visibility with `vulkaninfo`; names/options vary by driver and desktop version.

## Configuration and maintenance

Edit package groups in `config/packages.conf` using valid Arch package names. Configuration is sourced as Bash, so only edit it with trusted content. Keep `[multilib]` configuration under your own control.

```bash
./scripts/health-check.sh
./scripts/update.sh
./scripts/rollback.sh
```

The updater asks before starting, uses interactive package-manager prompts, updates Flatpak applications, updates AUR packages only if `yay` or `paru` is already installed (as the normal user), and pulls project changes only when the Git worktree is clean. It uses fast-forward-only Git updates.

Rollback removes only the NVIDIA modesetting file when it still exactly matches the project template. It does not uninstall packages, revert service state, or modify boot settings, because those may be shared with other system configuration.

Installer output and commands are logged to:

```text
${XDG_STATE_HOME:-~/.local/state}/arch-extreme-gaming/logs/
```

## Testing

```bash
bash tests/test-install.sh
find . -type f -name '*.sh' -print0 | xargs -0 -n1 bash -n
```

ShellCheck can also be run when installed:

```bash
find . -type f -name '*.sh' -print0 | xargs -0 shellcheck
```

The test suite uses mocked commands for package and connectivity checks; it does not perform an Arch installation. Test on a disposable Arch machine or VM before using on hardware.

## Troubleshooting

- **Preflight rejects the system:** This tool requires Arch Linux, x86_64, pacman, and internet access to `archlinux.org`.
- **No GPU detected:** Install `pciutils` (`sudo pacman -S pciutils`) and check `lspci -nn`; rerun the GPU module.
- **Steam/32-bit driver packages skipped:** Enable `[multilib]` in `/etc/pacman.conf`, then run `sudo pacman -Syu` and rerun the relevant module.
- **NVIDIA module does not load:** Check Secure Boot signing, `dkms status`, installed Zen headers, and `journalctl -k`. The installer does not disable Secure Boot.
- **Zen kernel is not shown at boot:** Use the documentation for your bootloader to add/update its entry; the setup intentionally does not rewrite it.
- **No gaming package installed:** Check repository configuration and rerun `sudo pacman -Syu`; the installer reports unavailable packages.
- **libvirt access denied:** Sign out and back in after group membership is changed, then check `id -nG`.
- **Audio device unavailable:** Confirm PipeWire and WirePlumber are installed and running in the desktop user's session.

## License

MIT; see [LICENSE](./LICENSE).
