# Arch KDE Gaming Setup

Arch KDE Gaming Setup helps you prepare an Arch Linux computer for gaming. It installs KDE Plasma, graphics drivers, gaming applications, and optional performance tools through a guided installer.

The installer is careful with your system. It keeps your current kernel as a fallback, asks before making changes, and does not format disks, edit boot entries, or reboot your computer.

## Requirements

- Arch Linux (64-bit)
- An internet connection
- `git` to clone the repository
- A regular user account with `sudo` access
- At least 10 GB of free disk space (5 GiB is the hard minimum)
- The `[multilib]` repository enabled for Steam and 32-bit games

If Secure Boot is enabled, NVIDIA and kernel modules must be signed before they
can load. This project does not sign modules or change Secure Boot settings. It
also does not edit bootloader entries; check your boot menu after installing the
Zen kernel.

## Installation

### Quick install

To clone, install every module, and confirm with a single `y`/`n` prompt:

```bash
git clone https://github.com/Sopanhaa/archKDE-play.git && cd archKDE-play && ./install.sh --full
```

The installer shows what it will do and asks `Proceed with installation? [y/N]`. Enter `y` to continue or press Enter to cancel; nothing is changed unless you confirm. Run this as your regular user, not as root.

Prefer to see the commands first? Use `./install.sh --dry-run --full`, which makes no changes and asks nothing.

### Step 1: Clone the repository

```bash
git clone https://github.com/Sopanhaa/archKDE-play.git
cd archKDE-play
```

### Step 2: Check the system

```bash
./install.sh --check
```

This runs the preflight checks only. It checks your Arch Linux system, internet connection, disk space, package database, multilib, graphics hardware, and bootloader. It makes no changes and writes no log or state files.

### Step 3: Preview installation

```bash
./install.sh --dry-run --full
```

A dry run prints the commands for every module without running them. It does not install packages, change services, or write logs or state files. Use it to see what will be installed.

### Step 4: Start installation

```bash
./install.sh
```

The installer shows a menu of modules. Choose all modules or only the ones you need. It displays the final plan and asks for confirmation before installing anything.

## Available Modules

1. **System update and base tools** – Updates Arch and installs basic tools such as `git`, `curl`, and `pciutils`.
2. **Zen kernel** – Installs `linux-zen` and keeps your current kernel as a fallback.
3. **GPU drivers and Vulkan** – Detects your graphics hardware and installs the matching drivers and Vulkan support.
4. **KDE Plasma desktop and services** – Installs Plasma, SDDM, NetworkManager, Bluetooth, and PipeWire.
5. **Gaming tools** – Installs Steam, Lutris, Wine, GameMode, MangoHud, and Heroic when available.
6. **Flatpak and Flathub** – Installs Flatpak and configures the Flathub application store.
7. **Safe performance setup** – Enables SSD trim and safe power profiles without risky tweaks.
8. **QEMU/KVM virtualization** – Installs QEMU/KVM and Virt-Manager for virtual machines.

`--full` and `--modules` cannot be used together.

## Usage

Interactive installation:

```bash
./install.sh
```

Full installation:

```bash
./install.sh --full
```

Install selected modules:

```bash
./install.sh --modules 03,05,06
```

Module ranges and short numbers also work:

```bash
./install.sh --modules 03-05
```

Dry-run mode:

```bash
./install.sh --dry-run --full
```

Check system health after installation:

```bash
./scripts/health-check.sh
```

Update packages, Flatpak applications, AUR packages, and this project:

```bash
./scripts/update.sh
```

Preview updates without changing anything:

```bash
./scripts/update.sh --dry-run
```

Skip third-party AUR updates:

```bash
./scripts/update.sh --skip-aur
```

AUR helpers run code from third-party packages. Use `--skip-aur` if you do not
want to update AUR packages.

Show the project version:

```bash
./install.sh --version
```

List module numbers and descriptions:

```bash
./install.sh --list-modules
```

Reduce progress output while still keeping warnings, errors, and the full log:

```bash
./install.sh --quiet --full
```

Disable coloured terminal output:

```bash
./install.sh --no-color --check
```

The helper scripts `drivers.sh`, `Zen-kernel.sh`, `services.sh`, `proton+tool.sh`, and `performance.sh` run a single module and pass their options to `install.sh`.

Normal installations and health checks write logs to `~/.local/state/archkde-play/logs/`. `--check` and `--dry-run` do not write logs. Existing installs that used the old project name keep their previous state directory.

## GPU Support

The GPU module detects your hardware automatically from PCI information.

- **NVIDIA** – Installs `nvidia-open-dkms` when available, or `nvidia-dkms` as a fallback, with NVIDIA utilities and 32-bit libraries when multilib is enabled.
- **AMD** – Installs Mesa, `vulkan-radeon`, and video decode support.
- **Intel** – Installs `vulkan-intel` and `intel-media-driver`.
- **Hybrid GPU laptops** – Installs drivers for every detected vendor and keeps the integrated GPU enabled. Use your desktop's per-application GPU option or launch a program with `prime-run`.

The installer does not force PRIME settings, change GPU power settings, or disable the integrated GPU.

## Project Structure

```text
archKDE-play/
├── install.sh
├── lib/
│   ├── common.sh
│   ├── modules.sh
│   └── preflight.sh
├── config/
├── modules/
├── scripts/
├── tests/
├── CONTRIBUTING.md
├── SECURITY.md
├── CODE_OF_CONDUCT.md
├── drivers.sh
├── performance.sh
├── proton+tool.sh
├── services.sh
├── update.sh
└── Zen-kernel.sh
```

## Troubleshooting

**Installation fails**

Read the last lines of the log in `~/.local/state/archkde-play/logs/` (or the old `arch-extreme-gaming` directory for existing installs), fix the reported problem, and rerun the suggested command, for example:

```bash
./install.sh --modules 03
```

Completed modules are safe to rerun. The installer does not roll back changes automatically.

**NVIDIA driver issues**

If Secure Boot is enabled, make sure your NVIDIA kernel modules are signed. Check the driver status with:

```bash
dkms status
```

On NVIDIA GPUs older than Turing, use `nvidia-dkms` instead of `nvidia-open-dkms`.

**Steam not working**

Enable `[multilib]`, refresh the package database, and rerun the gaming module:

```bash
sudo pacman -Syu
./install.sh --modules 05
```

**Vulkan issues**

Install the Vulkan tools and check that a device is detected:

```bash
sudo pacman -S vulkan-tools
vulkaninfo --summary
```

Make sure the Vulkan package for your GPU is installed: `vulkan-radeon`, `vulkan-intel`, or `nvidia-utils`.

**Packages are skipped as unavailable**

Refresh the package database and system packages, then retry:

```bash
sudo pacman -Syu
./install.sh --modules 01
```

**Missing multilib repository**

Open `/etc/pacman.conf`, uncomment the `[multilib]` section, then refresh the package database:

```bash
sudo pacman -Syu
```

**Undo project configuration**

Preview and remove only the configuration files created by this project:

```bash
./scripts/rollback.sh --dry-run
./scripts/rollback.sh
```

Rollback does not remove packages, undo upgrades, or revert driver changes.

## Development checks

Run these checks before opening a pull request:

```bash
bash scripts/lint.sh
bash tests/test-install.sh
```

You can also verify a full installer run without changing your system:

```bash
./install.sh --dry-run --full
```

## Contributing

See `CONTRIBUTING.md` for development setup, code style, and pull request
guidance. Report security problems privately using `SECURITY.md`. Participation
is covered by `CODE_OF_CONDUCT.md`.

## License

[MIT](./LICENSE)

