# Contributing to Arch KDE Gaming Setup

Thanks for helping improve the project. This is a system installer, so small
mistakes can affect a user's machine. Please keep changes focused, tested, and
easy to review.

## Before you start

- Read the `README.md` and the module you want to change.
- Test on an Arch Linux virtual machine or a spare system.
- Do not test destructive changes on your main computer.
- Never add automatic `--noconfirm` flags or disk-partitioning commands.

## Development setup

```bash
git clone https://github.com/Sopanhaa/archKDE-play.git
cd archKDE-play
./install.sh --check
./install.sh --dry-run --full
```

The last two commands are read-only checks.

## Checks before opening a pull request

```bash
bash scripts/lint.sh
bash tests/test-install.sh
```

`scripts/lint.sh` runs `bash -n`, ShellCheck when available, and the test suite.
If you change installation behavior, also run the affected modules with
`--dry-run` on an Arch system.

## Code style

- Keep Bash simple and quote variables.
- Use `set -Eeuo pipefail`.
- Use the existing helpers such as `run`, `sudo_run`, `log`, `die`, and
  `install_available_packages` instead of duplicating logic.
- Respect `DRY_RUN`; every system-changing command should go through `run` or
  `sudo_run`.
- Keep modules idempotent and avoid overwriting existing user configuration.
- Explain risky operations in the log and in the README.
- Update tests and documentation when behavior changes.

## Adding or changing a module

- Follow the existing `modules/NN-name.sh` naming pattern.
- Source `lib/common.sh` from the module.
- Print clear progress messages with `log` and `section`.
- Support `--dry-run`.
- Do not remove packages, edit bootloader entries, or change disk layout.
- Add or update a test when the change is testable without installing packages.

## Pull requests

- Keep pull requests small and focused.
- Describe what changed, why it is needed, and how you tested it.
- Link the related issue when one exists.
- Mention any behavior that still needs testing on real hardware.
- Do not include logs with usernames, serial numbers, or other private data.

## Reporting bugs

Use the bug report template. Include:

- Arch Linux version and kernel
- GPU model and whether the system is hybrid
- The module that failed
- Relevant log lines with private data removed
- Output from `./scripts/health-check.sh`

## Security issues

Do not open a public issue for a security problem. Follow `SECURITY.md`.

## Code of Conduct

Participation is covered by `CODE_OF_CONDUCT.md`.
