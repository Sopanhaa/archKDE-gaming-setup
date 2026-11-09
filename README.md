# Arch Extreme Gaming

An interactive, beginner-friendly setup for Arch Linux gaming PCs. It installs KDE Plasma, graphics drivers, gaming tools, and optional virtualization while keeping existing kernels and configuration safe.

Supports NVIDIA, AMD, Intel, and hybrid graphics, including laptops such as the MSI Thin 15 B12UCX.

## Before you start

- Use an installed **64-bit Arch Linux** system with internet access.
- Run as a regular user with `sudo` access.
- Keep at least 10 GB of free disk space.
- Steam and 32-bit games need the `[multilib]` repository enabled in `/etc/pacman.conf`.
- If you use Secure Boot, make sure your NVIDIA modules are signed.

This tool does not install Arch Linux, format disks, edit bootloader entries, or reboot your computer.

## Install

```bash
git clone https://github.com/sopanha-lay/arch-extreme-gaming.git
cd arch-extreme-gaming
./install.sh --check          # Run safety checks only
./install.sh --dry-run --full # Preview everything
./install.sh                  # Interactive module selection
```

### Interactive selection

Running `./install.sh` without arguments shows numbered modules:

```text
0) All modules (recommended for a new gaming setup)

01) System update and base tools
02) Zen kernel (with standard kernel fallback)
03) GPU drivers and Vulkan
04) KDE Plasma desktop and services
05) Gaming tools
06) Flatpak and Flathub
07) Safe performance setup
08) QEMU/KVM virtualization

q) Quit without changing anything
```

Enter any of these:

```text
03 05 06    # specific modules
03,05,06    # commas also work
03-06       # a range
all         # everything
0           # everything
q           # quit
```

Invalid input is explained and you are asked again. Before anything is installed, the installer shows the final plan and asks for confirmation. The default answer is **No**.

### Command-line options

```bash
./install.sh --full             # Install everything, no menu
./install.sh --modules 03,05,06 # Choose GPU, gaming, and Flatpak
./install.sh --check            # Preflight checks only
./install.sh --dry-run          # Print commands without running them
./install.sh --no-color         # Plain output for logs or screen readers
./scripts/health-check.sh       # Check your setup
./scripts/update.sh             # Update packages and apps
```

## Safety checks before installation

The installer runs these checks first:

- Arch Linux, `pacman`, and 64-bit `x86_64`
- Regular user (not root) and available `sudo`
- Internet connectivity
- At least 5 GiB free on `/` (warns below 10 GiB)
- pacman database lock and package database availability
- Whether `[multilib]` is enabled
- GPU detection and hybrid graphics
- Bootloader detection and Secure Boot warning

Blocking problems stop the installer **before** any change is made. Warnings let you continue with clear notes.

## Automatic GPU detection

The GPU module reads PCI information from `lspci`, with a `/sys` fallback when `lspci` is missing, then installs the matching drivers:

- **NVIDIA:** `nvidia-open-dkms` when available (or `nvidia-dkms`), plus `nvidia-utils`, kernel headers, and 32-bit libraries when multilib is enabled
- **AMD:** `mesa`, `vulkan-radeon`, and video decode support
- **Intel:** `vulkan-intel` and `intel-media-driver`
- **Hybrid laptops:** both vendor drivers are installed; the integrated GPU stays enabled and `nvidia-prime` is added for per-application GPU selection

The module does not force PRIME settings, change GPU power policy, or disable the integrated GPU.

On hybrid NVIDIA laptops, use the per-application option in your desktop or launch a program with `prime-run`:

```bash
prime-run <program>
```

For Steam games, set the launch option to `prime-run %command%`.

## What gets installed

- KDE Plasma, SDDM, NetworkManager, Bluetooth, and PipeWire
- Zen kernel, while keeping the standard kernel as a fallback
- Detected GPU drivers and Vulkan tools
- Steam, Lutris, Wine, GameMode, MangoHud, and other available gaming tools
- Flatpak and Flathub
- Optional SSD maintenance and QEMU/KVM virtualization

Gaming performance depends on your hardware, drivers, and game settings. No risky performance tweaks are applied.

## Progress, errors, and logs

Each module prints a numbered progress heading, the packages it plans to install, and a completion time. If something fails, the installer:

- Shows the failing module, command, and line number
- Explains that no automatic rollback was performed
- Prints the full log location
- Tells you how to rerun just that module

Logs are stored in:

```text
~/.local/state/arch-extreme-gaming/logs/setup-YYYYMMDD.log
```

At the end, the installer prints a summary of completed modules, the log path, and the next steps.

## Health checks

Run the health check after installation or whenever a game misbehaves:

```bash
./scripts/health-check.sh
```

It checks the kernel and fallback kernel, detected GPU drivers and loaded modules, NVIDIA PRIME (`prime-run`) on hybrid laptops, Vulkan tools and ICD files, Steam, GameMode, MangoHud, Lutris, Wine, multilib, services, and Flatpak/Flathub. Blocking failures return a non-zero exit status; optional warnings do not.

## Safety

The installer is intentionally conservative:

- It never formats disks, creates partitions, or changes filesystems.
- It never edits bootloader entries or firmware settings.
- It never disables Secure Boot.
- It never reboots automatically.
- It does not remove existing GPU drivers automatically; pacman asks before replacing conflicting packages.
- It keeps the standard kernel as a fallback.
- It does not overwrite an existing configuration file. If a project-managed file would conflict, the existing file is left in place and a backup is recorded.
- It asks for confirmation before installing packages or changing services.
- `--dry-run` works for every module and only prints the commands.

## Rollback

```bash
./scripts/rollback.sh --dry-run   # Preview tracked removals
./scripts/rollback.sh             # Remove unchanged project files
```

Rollback only removes configuration files that this project created, recorded in its manifest, and that are still unchanged. It does **not** remove packages, undo package upgrades or downgrades, restore previous service states, revert GPU driver changes, or modify boot entries. Backups made when an existing conflicting configuration is found are kept in `~/.local/state/arch-extreme-gaming/backups/`.

## Important

- Enable multilib yourself to install Steam and 32-bit drivers.
- The installer does not change bootloader entries. Check your bootloader before restarting after installing the Zen kernel.
- On hybrid laptops, integrated graphics are kept enabled. Use your desktop's per-app GPU option for NVIDIA.
- To review or remove only the project-managed configuration, run `./scripts/rollback.sh --dry-run` first, then `./scripts/rollback.sh`. See [Rollback](#rollback) for what it cannot undo.

## Troubleshooting

- **Steam or 32-bit drivers are skipped:** Enable `[multilib]`, then run `sudo pacman -Syu` and retry.
- **NVIDIA does not load:** Check Secure Boot signing and run `dkms status`.
- **NVIDIA GPU is older than Turing:** Use `nvidia-dkms` instead of `nvidia-open-dkms`.
- **Vulkan reports no device:** Install `vulkan-tools`, then run `vulkaninfo --summary`. Check that `vulkan-radeon`, `vulkan-intel`, or `nvidia-utils` is installed for your GPU.
- **GameMode daemon is not running:** This is normal; `gamemoded` can start on demand. Use `gamemoderun %command%` as a Steam launch option.
- **Health check warnings:** Only `[FAIL]` items are blocking. `[WARN]` items are optional tools or services that may not be needed on every system.
- **Zen kernel is missing from the boot menu:** Update your bootloader configuration using its own instructions.
- **Installation stopped:** Read the last lines of the log, fix the reported problem, then rerun the suggested `./install.sh --modules NN` command.
- **Need to undo project configuration:** Run `./scripts/rollback.sh --dry-run` first. Rollback does not undo package changes.

## Tests

```bash
bash tests/test-install.sh
```

Tests do not install packages. Try the setup in an Arch virtual machine before using it on your main computer.

## License

[MIT](./LICENSE)
