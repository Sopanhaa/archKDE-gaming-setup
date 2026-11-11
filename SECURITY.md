# Security Policy

## Supported versions

The `main` branch and the latest tagged release receive security fixes. The
project is an installer for Arch Linux; it does not provide its own packages or
binaries.

## Reporting a vulnerability

Please report security issues privately through GitHub Security Advisories:

https://github.com/Sopanhaa/archKDE-play/security/advisories/new

Do not open a public issue for a vulnerability.

Include as much detail as possible:

- Affected version or commit
- Arch Linux version and kernel
- Steps to reproduce the problem
- Impact and any required privileges
- Relevant log output with usernames, serial numbers, and other private data
  removed
- Suggested fix, if you have one

Reports are handled on a best-effort basis. You will receive a response when the
report has been reviewed.

## Scope

Examples of in-scope issues:

- Command injection or unsafe quoting in installer scripts
- Privilege escalation through `sudo` operations
- Deletion or overwrite of user files outside the project's documented scope
- Rollback removing files that were changed after installation
- Secrets or private data committed to the repository
- Unsafe handling of package names, paths, or configuration files

Examples of issues that are usually out of scope:

- Vulnerabilities in Arch Linux packages, AUR packages, Flatpak applications, or
  upstream projects
- NVIDIA modules failing to load because Secure Boot signing was not configured
  (the installer warns about this)
- A missing bootloader entry for the Zen kernel (the installer does not edit boot
  entries by design)
- Problems caused by running the installer as root or by bypassing its
  confirmation prompts

## Safe harbor

Good-faith security research is welcome. Do not test against systems you do not
own or have permission to use, and do not access or modify other people's data.
