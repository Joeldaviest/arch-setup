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

To pull repository changes onto an already-set-up machine and re-apply them:

```bash
./upgrade.sh
```

It fetches and fast-forwards the current branch (refusing on local changes or
a diverged branch), then re-runs `setup.sh`, which is safe to repeat.

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
with GNU Stow, and configures services. Floorp is installed and configured as
the default handler for HTTP, HTTPS, and `mailto:` links. Navidrome has a
conventional desktop entry and `SUPER+SHIFT+M` binding that open it in a normal
Floorp tab.

Wallpapers are copied to `~/.config/wallpapers`, so the desktop does not depend
on the repository remaining in place. Each Hyprland session chooses a random
wallpaper, updates the `~/.config/wallpapers/current` symlink, and asks the
session's `awww` daemon to display it with a short fade transition.

IWD manages Wi-Fi and its network configuration. systemd-networkd supplies
DHCP for wired interfaces matching `en*` or `eth*`; it does not claim Wi-Fi
interfaces. systemd-resolved provides DNS for both paths.

Conflicting files are backed up below:

```text
~/.local/state/arch-setup/backups/<timestamp>/
```

Machine-specific Hyprland settings live outside Git:

```text
~/.config/hypr/local/monitors.lua
~/.config/hypr/local/input.lua
~/.config/hypr/local/environment.lua
~/.config/hypr/local/autostart.lua
```

The tracked defaults work on a generic display. Use `nwg-displays` to generate
monitor rules or edit `local/monitors.lua` directly (e.g. `hl.monitor({ output
= "eDP-1", position = "0x0" })`).

Firmware updates use `fwupd`; `fwupd-refresh.timer` keeps LVFS metadata current
in the background. Run `desktop-firmware check` to list pending updates or
`desktop-firmware update` to apply them, or pick Firmware from the power menu
(`SUPER+SHIFT+E`).

The waybar weather module (`weather-status`) auto-detects location by IP via
wttr.in. The bar shows only the current temperature; hover for conditions and
a short forecast, left-click for the detailed forecast, or right-click to pick
an exact location. The picker searches Open-Meteo's worldwide geocoder, keeps
recent choices, and can restore automatic IP detection. It stores precise
coordinates under `~/.config/weather-status/`, so unusual ISP routing does not
affect a selected location. Successful responses are cached for 15 minutes and
remain available when a refresh temporarily fails.

## Windows VM

`windows-vm` runs Windows in a Docker container (`dockurr/windows`, KVM-accelerated
QEMU) and connects to it fullscreen over RDP. Setup only installs this command; it does
not create a VM. Run it yourself, from any directory:

```bash
windows-vm install   # configure RAM/CPU/disk/credentials, then download and boot Windows 10 LTSC
windows-vm launch     # start the VM if needed and connect (add -k/--keep-alive to leave it running)
windows-vm stop
windows-vm status
windows-vm remove     # tear down the VM and its data (keeps ~/Windows)
```

A "Windows" launcher is also added to the app menu. RDP and the setup web viewer
(`http://127.0.0.1:8006`) are bound to loopback only. `~/Windows` is shared into the VM as
a drive; the Windows version is fixed to `10-ltsc` and can be changed afterwards by
editing `~/.config/windows-vm/vm.env` and re-running `windows-vm render`.

There is no GPU passthrough, so this setup is not suitable for gaming or video editing.

USB devices can be passed through while the VM is stopped:

```bash
windows-vm usb add       # pick a device with lsusb
windows-vm usb list
windows-vm usb remove
```

Attaching a USB mass-storage device before Windows Setup has finished can cause the
installer to fail, or format that drive as the VM's system disk. `usb add` refuses to run
until the VM has booted successfully once; pass `--force` to override.

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
