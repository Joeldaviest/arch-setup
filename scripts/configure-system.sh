#!/bin/bash

set -Eeuo pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)/scripts/lib/common.sh"
source "$SETUP_ROOT/scripts/lib/limine.sh"

note "Configuring locale"
sudo sed -i '/^#en_US.UTF-8 UTF-8/s/^#//' /etc/locale.gen
sudo locale-gen
[[ -f /etc/locale.conf ]] || printf 'LANG=en_US.UTF-8\n' | sudo tee /etc/locale.conf >/dev/null

note "Installing system configuration"
sudo install -Dm644 "$SETUP_ROOT/system/sddm.conf" /etc/sddm.conf.d/20-arch-setup.conf
sudo install -Dm644 "$SETUP_ROOT/system/sddm-theme/greeter-hyprland.lua" /usr/share/sddm/greeter-hyprland.lua
sudo rm -f /usr/share/sddm/greeter-hyprland.conf
sudo rm -rf /usr/share/sddm/themes/arch-setup
sudo cp -r "$SETUP_ROOT/system/sddm-theme/arch-setup" /usr/share/sddm/themes/arch-setup
sudo install -Dm644 "$SETUP_ROOT/assets/wallpapers/wallhaven-6d1v5q.jpg" /usr/share/sddm/themes/arch-setup/logo.jpg
sudo rm -f /usr/share/sddm/themes/arch-setup/logo.png
sudo rm -f /usr/local/bin/sddm-random-logo /usr/local/bin/sddm-greeter-start
sudo rm -f /etc/systemd/system/sddm.service.d/10-random-logo.conf
sudo rmdir /etc/systemd/system/sddm.service.d 2>/dev/null || true
sudo rm -rf /usr/share/backgrounds/arch-setup
sudo systemctl daemon-reload
sudo install -Dm644 "$SETUP_ROOT/system/arch-setup.desktop" /usr/share/wayland-sessions/arch-setup.desktop
sudo install -Dm644 "$SETUP_ROOT/system/docker-daemon.json" /etc/docker/daemon.json
sudo install -Dm644 "$SETUP_ROOT/system/docker-resolved.conf" /etc/systemd/resolved.conf.d/20-docker-dns.conf
sudo install -Dm644 "$SETUP_ROOT/system/avahi-resolved.conf" /etc/systemd/resolved.conf.d/30-avahi.conf
sudo install -Dm644 "$SETUP_ROOT/system/nvidia.conf" /etc/modprobe.d/arch-setup-nvidia.conf
sudo install -Dm644 "$SETUP_ROOT/system/xpadneo.conf" /etc/modules-load.d/xpadneo.conf
sudo install -Dm644 "$SETUP_ROOT/system/blacklist-xpad.conf" /etc/modprobe.d/blacklist-xpad.conf
sudo install -Dm644 "$SETUP_ROOT/system/iwd.conf" /etc/iwd/main.conf
sudo install -Dm644 "$SETUP_ROOT/system/20-wired.network" /etc/systemd/network/20-wired.network
sudo install -Dm644 "$SETUP_ROOT/system/zram-generator.conf" /etc/systemd/zram-generator.conf
sudo install -Dm644 "$SETUP_ROOT/system/limine-entry-tool.conf" /etc/limine-entry-tool.d/90-arch-setup-kernels.conf

# limine-entry-tool preserves the global section when it regenerates entries.
# Set the named default first, then let limine-update regenerate entries and run
# any configured signing or config-enrollment hooks. Update every supported
# candidate:
# UEFI Limine prefers a config beside its executable, while BIOS and older UEFI
# installations commonly use one of the /boot locations.
limine_configured=false
limine_source=$(mktemp)
limine_output=$(mktemp)
trap 'rm -f "$limine_source" "$limine_output"' EXIT
for limine_config in \
  /boot/EFI/limine/limine.conf \
  /boot/EFI/BOOT/limine.conf \
  /boot/limine/limine.conf \
  /boot/limine.conf; do
  sudo test -f "$limine_config" || continue
  sudo cat "$limine_config" | tee "$limine_source" >/dev/null
  zen_entry=$(find_limine_zen_entry "$limine_source")
  if [[ -z $zen_entry ]]; then
    note "Skipping $limine_config: no non-fallback linux-zen entry found"
    continue
  fi

  write_limine_zen_default "$limine_source" "$limine_output" "$zen_entry"
  if ! sudo cmp -s "$limine_output" "$limine_config"; then
    sudo test -e "$limine_config.arch-setup.bak" || sudo cp -a "$limine_config" "$limine_config.arch-setup.bak"
    limine_mode=$(sudo stat -c '%a' "$limine_config")
    limine_uid=$(sudo stat -c '%u' "$limine_config")
    limine_gid=$(sudo stat -c '%g' "$limine_config")
    sudo install -m "$limine_mode" -o "$limine_uid" -g "$limine_gid" "$limine_output" "$limine_config"
  fi
  note "Limine default kernel: $zen_entry ($limine_config)"
  limine_configured=true
done
rm -f "$limine_source" "$limine_output"
trap - EXIT

if [[ $limine_configured == false ]]; then
  note "No existing Limine configuration with a linux-zen entry was found; bootloader deployment remains unchanged"
fi

if command_exists limine-update; then
  note "Ordering Limine kernel entries with Zen first"
  sudo limine-update
fi

sudo usermod -aG docker,input "$USER"

note "Configuring firewall"
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 53317/udp comment 'LocalSend'
sudo ufw allow 53317/tcp comment 'LocalSend'
sudo ufw allow in proto udp from 172.16.0.0/12 to 172.17.0.1 port 53 comment 'Docker DNS'
sudo ufw allow in proto udp from 192.168.0.0/16 to 172.17.0.1 port 53 comment 'Docker DNS'
sudo ufw allow in proto tcp from 172.16.0.0/12 to 172.17.0.1 port 53 comment 'Docker DNS'
sudo ufw allow in proto tcp from 192.168.0.0/16 to 172.17.0.1 port 53 comment 'Docker DNS'
sudo ufw --force enable
sudo ufw-docker install
sudo ufw reload

note "Enabling services"
sudo systemctl enable systemd-networkd.service systemd-resolved.service iwd.service bluetooth.service cups.service cups-browsed.service avahi-daemon.service ufw.service docker.socket power-profiles-daemon.service sddm.service fwupd-refresh.timer paccache.timer
sudo systemctl start docker.socket
sudo systemctl disable systemd-networkd-wait-online.service 2>/dev/null || true
sudo systemctl disable NetworkManager.service 2>/dev/null || true
sudo ln -sfn /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf

# PPD 0.30 and newer can react to charger and battery-level changes. Keep the
# setup usable with an older package during upgrades by detecting the command.
if LC_ALL=C powerprofilesctl --help 2>&1 | grep -qF 'configure-battery-aware'; then
  note "Enabling battery-aware power profile changes"
  sudo powerprofilesctl configure-battery-aware --enable
else
  note "Battery-aware power profiles require power-profiles-daemon 0.30 or newer"
fi

# Package installation alone must not alter an existing filesystem or boot
# layout. Enable maintenance only when its required Btrfs state already exists.
if [[ $(findmnt -nro FSTYPE / 2>/dev/null) == btrfs ]]; then
  sudo systemctl enable btrfs-scrub@-.timer
  if [[ -f /etc/snapper/configs/root ]]; then
    sudo systemctl enable snapper-cleanup.timer
  else
    note "Btrfs root detected; Snapper activation is deferred until the root layout is configured"
  fi
fi

if ! grep -q 'mdns_minimal' /etc/nsswitch.conf; then
  sudo sed -i 's/^hosts:.*/hosts: mymachines mdns_minimal [NOTFOUND=return] resolve files myhostname dns/' /etc/nsswitch.conf
fi

if ! grep -q '^CreateRemotePrinters Yes' /etc/cups/cups-browsed.conf; then
  printf '%s\n' 'CreateRemotePrinters Yes' | sudo tee -a /etc/cups/cups-browsed.conf >/dev/null
fi

if grep -qi nvidia <<<"${HARDWARE_SUMMARY:-}"; then
  note "NVIDIA detected; installed driver configuration without changing initramfs"
fi
