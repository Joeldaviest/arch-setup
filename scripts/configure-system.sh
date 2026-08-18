#!/bin/bash

set -Eeuo pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)/scripts/lib/common.sh"

note "Configuring locale"
sudo sed -i '/^#en_US.UTF-8 UTF-8/s/^#//' /etc/locale.gen
sudo locale-gen
[[ -f /etc/locale.conf ]] || printf 'LANG=en_US.UTF-8\n' | sudo tee /etc/locale.conf >/dev/null

note "Installing system configuration"
sudo install -Dm644 "$SETUP_ROOT/system/sddm.conf" /etc/sddm.conf.d/20-arch-setup.conf
sudo install -Dm644 "$SETUP_ROOT/system/sddm-theme/greeter-hyprland.lua" /usr/share/sddm/greeter-hyprland.lua
sudo rm -f /usr/share/sddm/greeter-hyprland.conf
sudo rm -rf /usr/share/sddm/themes/omarchy
sudo cp -r "$SETUP_ROOT/system/sddm-theme/omarchy" /usr/share/sddm/themes/omarchy
sudo install -Dm644 "$SETUP_ROOT/assets/wallpapers/wallhaven-6d1v5q.jpg" /usr/share/sddm/themes/omarchy/logo.jpg
sudo rm -f /usr/share/sddm/themes/omarchy/logo.png
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
sudo systemctl enable systemd-networkd.service systemd-resolved.service iwd.service bluetooth.service cups.service cups-browsed.service avahi-daemon.service ufw.service docker.socket power-profiles-daemon.service sddm.service fwupd-refresh.timer
sudo systemctl disable systemd-networkd-wait-online.service 2>/dev/null || true
sudo systemctl disable NetworkManager.service 2>/dev/null || true
sudo ln -sfn /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf

if ! grep -q 'mdns_minimal' /etc/nsswitch.conf; then
  sudo sed -i 's/^hosts:.*/hosts: mymachines mdns_minimal [NOTFOUND=return] resolve files myhostname dns/' /etc/nsswitch.conf
fi

if ! grep -q '^CreateRemotePrinters Yes' /etc/cups/cups-browsed.conf; then
  printf '%s\n' 'CreateRemotePrinters Yes' | sudo tee -a /etc/cups/cups-browsed.conf >/dev/null
fi

if grep -qi nvidia <<<"${HARDWARE_SUMMARY:-}"; then
  note "NVIDIA detected; installed driver configuration without changing initramfs"
fi
