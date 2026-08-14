# Arch Setup

A personal, reproducible Arch Linux post-install setup for a Tokyo Night
Hyprland desktop. It is derived from a customized Omarchy installation but is
standalone: it does not use an Omarchy package repository, updater, menu,
branding, migration system, ISO, or bootloader configuration.

## Prerequisites

- Bootable x86-64 vanilla Arch Linux
- A non-root user in `wheel`, with `sudo` configured
- Working internet access
- A supported kernel (`linux`, `linux-lts`, `linux-zen`, or `linux-hardened`)

The setup deliberately does not change partitions, encryption, the bootloader,
mkinitcpio, Plymouth, Snapper, or hibernation.

## Usage

```bash
./setup.sh --check
./setup.sh --dry-run
./setup.sh
```

Repository tests can be run on a non-Arch development machine:

```bash
./tests/run.sh
```

A complete installation can be exercised in a disposable, headless Arch VM:

```bash
./tests/vm.sh
```

The VM test requires QEMU/KVM, `qemu-img`, OVMF firmware, `xorriso`, `curl`,
and OpenSSH. It downloads and verifies the latest official Arch cloud image,
runs setup, reboots, checks packages, services, wired networking, DNS, Docker,
dotfiles, and wallpapers, then runs setup again to test idempotency. The base
image is cached under `~/.cache/arch-setup-vm`; successful disposable runs are
removed. Failed runs and logs are preserved automatically. Use
`./tests/vm.sh --keep` to preserve a successful VM as well.

The setup installs the complete package set, detects applicable graphics and
hardware packages, backs up conflicting dotfiles, links the tracked dotfiles
with GNU Stow, configures services, and creates Chromium web applications.
Wallpapers are copied to `~/.config/wallpapers`, so the desktop does not depend
on the repository remaining in place. Each Hyprland session chooses a random
wallpaper and updates the `~/.config/wallpapers/current` symlink.

IWD manages Wi-Fi and its network configuration. systemd-networkd supplies
DHCP for wired interfaces matching `en*` or `eth*`; it does not claim Wi-Fi
interfaces. systemd-resolved provides DNS for both paths.

Conflicting files are backed up below:

```text
~/.local/state/arch-setup/backups/<timestamp>/
```

Machine-specific Hyprland settings live outside Git:

```text
~/.config/hypr/local/monitors.conf
~/.config/hypr/local/input.conf
~/.config/hypr/local/environment.conf
~/.config/hypr/local/autostart.conf
```

The tracked defaults work on a generic display. Use `nwg-displays` to generate
monitor rules or edit `local/monitors.conf` directly.

## Package policy

`packages/official.txt` is installed with pacman. `packages/multilib.txt`
contains official packages that require Arch's disabled-by-default multilib
repository; setup enables it before installation. `packages/aur.txt` is
installed with `yay`, bootstrapped from the AUR when necessary. Packages in
`packages/aur-preinstall.txt` are installed in an earlier AUR transaction when
they provide a dependency that yay would otherwise resolve to a conflicting
package. npm packages are listed separately. Hardware-only packages are
selected at runtime.

Arch is rolling release: this repository reproduces package selection and
configuration, not historic binary versions. `./setup.sh --check` verifies that
all listed package sources are currently available.

## Safety

Disk utilities are intentionally separate from setup. Destructive operations
require a whole-disk block device and typing its exact path for confirmation:

```bash
drive-write-iso image.iso /dev/sdX
drive-format-exfat /dev/sdX LABEL
drive-luks-password /dev/nvme0n1p2
```

Review the selected device with `lsblk` before confirming.
