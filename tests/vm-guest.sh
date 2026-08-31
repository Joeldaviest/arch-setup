#!/bin/bash

set -Eeuo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)

fail() {
  printf 'Guest assertion failed: %s\n' "$*" >&2
  exit 1
}

read_manifest() {
  sed -E 's/[[:space:]]+#.*$//' "$1" | sed -E '/^[[:space:]]*(#|$)/d'
}

[[ -f /etc/arch-release ]] || fail 'guest is not Arch Linux'

for manifest in official multilib aur-preinstall aur; do
  while IFS= read -r package; do
    pacman -Q "$package" >/dev/null 2>&1 || fail "package is not installed: $package"
  done < <(read_manifest "$root/packages/$manifest.txt")
done

while IFS= read -r package; do
  if pacman -Q "$package" >/dev/null 2>&1; then
    fail "obsolete managed package is still installed: $package"
  fi
done < <(read_manifest "$root/packages/obsolete.txt")

pci=$(lspci -nn)
if ! grep -qiE '(VGA|Display).*(AMD|Intel|NVIDIA)|(AMD|Intel|NVIDIA).*(VGA|Display)' <<<"$pci"; then
  pacman -Q vulkan-swrast >/dev/null 2>&1 || fail 'software Vulkan provider is missing for the virtual GPU'
  pacman -Q lib32-vulkan-swrast >/dev/null 2>&1 || fail '32-bit software Vulkan provider is missing for the virtual GPU'
  if pacman -Q nvidia-utils >/dev/null 2>&1; then
    fail 'NVIDIA Vulkan provider was selected for a non-NVIDIA virtual GPU'
  fi
fi

kernel_release=$(uname -r)
[[ -e /usr/lib/modules/$kernel_release/build ]] || fail "kernel headers are missing for $kernel_release"
find "/usr/lib/modules/$kernel_release" -type f -name 'hid-xpadneo.ko*' -print -quit | grep -q . || \
  fail "xpadneo DKMS module was not built for $kernel_release"

enabled_services=(
  systemd-networkd.service systemd-resolved.service iwd.service bluetooth.service
  cups.service cups-browsed.service avahi-daemon.service ufw.service docker.socket
  power-profiles-daemon.service scx-lavd-balanced.service sddm.service
)
for service in "${enabled_services[@]}"; do
  systemctl is-enabled --quiet "$service" || fail "service is not enabled: $service"
done

systemctl is-active --quiet systemd-networkd.service || fail 'systemd-networkd is not active'
systemctl is-active --quiet systemd-resolved.service || fail 'systemd-resolved is not active'
if systemctl is-enabled --quiet systemd-networkd-wait-online.service; then
  fail 'systemd-networkd wait-online service should not delay desktop boot'
fi

[[ -f /etc/systemd/network/20-wired.network ]] || fail 'wired networkd configuration is missing'
grep -qF 'Name=en* eth*' /etc/systemd/network/20-wired.network || fail 'wired interface match is incorrect'
grep -qF 'DHCP=yes' /etc/systemd/network/20-wired.network || fail 'wired DHCP is not enabled'

wired_interface=$(ip -o link show | awk -F': ' '$2 ~ /^(en|eth)/ {print $2; exit}')
[[ -n $wired_interface ]] || fail 'no wired interface was found'
networkctl status "$wired_interface" | grep -q 'State:.*routable' || fail "$wired_interface is not routable"
ip -4 route show default | grep -q "dev $wired_interface" || fail 'wired interface does not provide the IPv4 default route'

[[ -L /etc/resolv.conf ]] || fail '/etc/resolv.conf is not a symlink'
[[ $(readlink -f /etc/resolv.conf) == /run/systemd/resolve/stub-resolv.conf ]] || fail '/etc/resolv.conf does not use systemd-resolved'
getent hosts archlinux.org >/dev/null || fail 'host DNS resolution failed'

sudo ufw status | grep -q '^Status: active' || fail 'UFW is not active'
sudo docker run --rm alpine:latest nslookup archlinux.org >/dev/null || fail 'Docker DNS resolution failed'

[[ -f /usr/share/wayland-sessions/arch-setup.desktop ]] || fail 'Hyprland session entry is missing'
[[ -L $HOME/.zshrc ]] || fail '.zshrc is not managed by Stow'
[[ -L $HOME/.config/hypr/hyprland.lua ]] || fail 'Hyprland configuration is not managed by Stow'

wallpaper_dir="$HOME/.config/wallpapers"
[[ -d $wallpaper_dir ]] || fail 'local wallpaper directory is missing'
[[ -L $wallpaper_dir/current ]] || fail 'active background is not a symlink'
background=$(readlink -f "$wallpaper_dir/current")
[[ $background == "$wallpaper_dir/"* && -f $background ]] || fail 'active background does not point to a local wallpaper'

if systemctl --failed --no-legend --plain | grep -q .; then
  systemctl --failed --no-legend --plain >&2
  fail 'systemd has failed units'
fi

echo 'Guest assertions passed'
