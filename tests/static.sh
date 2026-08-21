#!/bin/bash

set -Eeuo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)

while IFS= read -r script; do
  bash -n "$script"
done < <(find "$root" -path "$root/.git" -prune -o -type f \( -name '*.sh' -o -perm -u+x \) -print)

duplicates=$(cat \
  <(sed -E 's/[[:space:]]+#.*$//;/^[[:space:]]*(#|$)/d' "$root/packages/official.txt") \
  <(sed -E 's/[[:space:]]+#.*$//;/^[[:space:]]*(#|$)/d' "$root/packages/multilib.txt") \
  <(sed -E 's/[[:space:]]+#.*$//;/^[[:space:]]*(#|$)/d' "$root/packages/aur-preinstall.txt") \
  <(sed -E 's/[[:space:]]+#.*$//;/^[[:space:]]*(#|$)/d' "$root/packages/aur.txt") | sort | uniq -d)
[[ -z $duplicates ]] || { echo "Duplicate classification: $duplicates" >&2; exit 1; }

if grep -RInE 'pkgs\.omarchy|mirror\.omarchy|\[omarchy\]' "$root" --exclude=README.md --exclude=static.sh; then
  echo 'Custom Omarchy repository reference found' >&2
  exit 1
fi

if grep -RInE '(^|[ /])omarchy-|OMARCHY_|\.config/omarchy|\.local/share/omarchy' "$root/dotfiles"; then
  echo 'Runtime Omarchy dependency found' >&2
  exit 1
fi

required_helpers=(
  audio-input-mute audio-output-switch desktop-audio desktop-bluetooth desktop-browser
  desktop-editor desktop-firmware desktop-launcher desktop-osd desktop-power desktop-screenrecord
  desktop-screenshot desktop-wifi display-brightness keybindings keyboard-brightness
  monitor-scale terminal-cwd touchpad-toggle tui-launch
  power-profile-cycle storage-status
  webapp-launch window-pop windows-close-all windows-vm workspace-group-toggle xdg-terminal-exec
  reminder reminder-set weather-status wallpaper-select wallpaper-start
)
for helper in "${required_helpers[@]}"; do
  [[ -x $root/dotfiles/bin/.local/bin/$helper ]] || { echo "Missing helper: $helper" >&2; exit 1; }
done

for test_script in run.sh static.sh behavior.sh vm.sh vm-guest.sh; do
  [[ -x $root/tests/$test_script ]] || { echo "Test script is not executable: $test_script" >&2; exit 1; }
done

cloud_reboot_line=$(grep -nF "reboot_guest 'SSH returned after the cloud-image update reboot'" "$root/tests/vm.sh" | cut -d: -f1)
vm_ssh_rule_line=$(grep -nF "sudo ufw allow 22/tcp comment 'VM test SSH'" "$root/tests/vm.sh" | cut -d: -f1)
setup_line=$(grep -nF "TERM=xterm-256color ./setup.sh' 2>&1" "$root/tests/vm.sh" | head -1 | cut -d: -f1)
[[ -n $cloud_reboot_line && -n $vm_ssh_rule_line && -n $setup_line && \
   $cloud_reboot_line -lt $vm_ssh_rule_line && $vm_ssh_rule_line -lt $setup_line ]] || {
  echo 'VM setup must run after the cloud-image reboot and VM-only SSH firewall rule' >&2
  exit 1
}

waybar_config="$root/dotfiles/waybar/.config/waybar/config.jsonc"
jq empty "$waybar_config"
jq -e '
  ."modules-left" == ["hyprland/workspaces"] and
  ."modules-center" == ["clock", "custom/weather"] and
  ."modules-right" == ["mpris", "pulseaudio", "privacy", "custom/screenrecording",
    "cpu", "memory", "custom/storage", "idle_inhibitor", "custom/notification",
    "network", "bluetooth", "battery", "power-profiles-daemon", "tray"] and
  (.privacy.modules == [{"type": "audio-in", "tooltip": true, "tooltip-icon-size": 24}]) and
  (."custom/notification".exec == "swaync-client -swb") and
  (."custom/notification"["on-click"] == "swaync-client -t -sw") and
  (."custom/notification"["on-click-right"] == "swaync-client -d -sw") and
  (["cpu", "memory", "custom/storage"] | all(. as $module |
    ($ARGS.named.config[$module]["on-click"] | contains("btop")))) and
  (.clock.format == "{:L%I:%M %p}") and
  (.clock | has("format-alt") | not) and
  (.clock["tooltip-format"] | contains("%A, %d %B %Y") and contains("{calendar}")) and
  (.mpris.format == "{player_icon} {status_icon}") and
  (.mpris["tooltip-format"] == "{player_icon} {player} ({status})\nTitle: {title}\nArtist: {artist}") and
  (."power-profiles-daemon".format == "{icon}") and
  (."power-profiles-daemon".tooltip == false) and
  (."power-profiles-daemon"["on-click"] == "power-profile-cycle") and
  (.battery["on-click"] == "power-profile-cycle") and
  (.tray.spacing == 10) and
  (.idle_inhibitor.timeout == 120)
' --argjson config "$(jq . "$waybar_config")" "$waybar_config" >/dev/null
swaync_config="$root/dotfiles/swaync/.config/swaync/config.json"
jq -e '
  .widgets == ["title", "dnd", "notifications"] and
  .["notification-grouping"] == true and
  .["timeout-critical"] == 0 and
  .["control-center-width"] == 400 and
  .["notification-window-width"] == 420
' "$swaync_config" >/dev/null

grep -qxF 'swaync' "$root/packages/official.txt"
if grep -qxF 'mako' "$root/packages/official.txt"; then
  echo 'Mako must not remain in the active package manifest' >&2
  exit 1
fi
grep -qxF 'mako' "$root/packages/obsolete.txt"
grep -qF 'uwsm-app -- swaync' "$root/dotfiles/hypr/.config/hypr/autostart.lua"
if grep -qF 'uwsm-app -- mako' "$root/dotfiles/hypr/.config/hypr/autostart.lua"; then
  echo 'Mako must not remain in Hyprland autostart' >&2
  exit 1
fi
grep -qF 'scale = 1.0' "$root/dotfiles/hypr/.config/hypr/hyprland.lua"
jq empty "$root/dotfiles/misc/.config/fastfetch/config.jsonc"

grep -qF 'Name=en* eth*' "$root/system/20-wired.network"
grep -qF 'DHCP=yes' "$root/system/20-wired.network"
grep -qF 'RequiredForOnline=no' "$root/system/20-wired.network"
[[ $(grep -cF 'RouteMetric=100' "$root/system/20-wired.network") == 3 ]]
grep -qF 'systemd-networkd.service' "$root/scripts/configure-system.sh"
grep -qF 'disable systemd-networkd-wait-online.service' "$root/scripts/configure-system.sh"
grep -qF 'fwupd-refresh.timer' "$root/scripts/configure-system.sh"
if grep -qE 'Name=.*(wl\*|wlan)' "$root/system/20-wired.network"; then
  echo 'systemd-networkd configuration must not claim Wi-Fi interfaces managed by IWD' >&2
  exit 1
fi

for protocol in udp tcp; do
  grep -qF "proto $protocol from 172.16.0.0/12 to 172.17.0.1 port 53" "$root/scripts/configure-system.sh"
  grep -qF "proto $protocol from 192.168.0.0/16 to 172.17.0.1 port 53" "$root/scripts/configure-system.sh"
done

hardware_case() (
  source "$root/scripts/lib/common.sh"
  source "$root/scripts/lib/packages.sh"
  source "$root/scripts/lib/hardware.sh"
  ARCH_SETUP_TEST_PCI=$1
  ARCH_SETUP_TEST_DMI_VENDOR=${2:-Generic}
  classify_hardware
  [[ " ${HARDWARE_PACKAGES[*]} " == *" $3 "* || " ${HARDWARE_AUR_PACKAGES[*]} " == *" $3 "* ]]
)
hardware_case 'VGA compatible controller: AMD/ATI Radeon RX' Generic vulkan-radeon
hardware_case 'Ethernet controller: Virtio network device' Generic linux-headers
hardware_case 'Ethernet controller: Virtio network device' Generic vulkan-swrast
hardware_case 'Ethernet controller: Virtio network device' Generic lib32-vulkan-swrast
hardware_case 'VGA compatible controller: Intel Corporation Graphics' Generic vulkan-intel
hardware_case 'VGA compatible controller: NVIDIA Corporation RTX 4070' Generic nvidia-open-dkms
hardware_case 'VGA compatible controller: NVIDIA Corporation GTX 1080' Generic nvidia-580xx-dkms
hardware_case 'Ethernet controller [1f0a:6801] YT6801' Generic yt6801-dkms
hardware_case 'VGA compatible controller: AMD/ATI Radeon' Framework qmk-hid

grep -qF 'hl.exec_cmd("uwsm-app -- wallpaper-start")' "$root/dotfiles/hypr/.config/hypr/autostart.lua"
if grep -RqsF "$root/assets/wallpapers" "$root/dotfiles"; then
  echo 'Runtime wallpaper configuration depends on the repository path' >&2
  exit 1
fi

wallpaper_menu="$root/dotfiles/elephant/.config/elephant/menus/wallpaper.lua"
wallpaper_picker="$root/dotfiles/bin/.local/bin/wallpaper-select"
walker_config="$root/dotfiles/walker/.config/walker/config.toml"
walker_preview="$root/dotfiles/walker/.config/walker/themes/tokyo-night/preview.xml"
[[ -f $wallpaper_menu ]] || { echo 'Elephant wallpaper menu is missing' >&2; exit 1; }
[[ -f $walker_preview ]] || { echo 'Walker preview layout is missing' >&2; exit 1; }
grep -qF 'PreviewType = "file"' "$wallpaper_menu"
grep -qF 'Preview = path' "$wallpaper_menu"
grep -qF 'select = "lua:SetWallpaper"' "$wallpaper_menu"
grep -qF "desktop-launcher -m 'menus:wallpaper'" "$wallpaper_picker"
grep -qF 'WALKER_WIDTH=1100' "$wallpaper_picker"
grep -qF '"menus:wallpaper" = [' "$walker_config"
grep -qF 'systemctl --user restart elephant.service' "$root/scripts/configure-user.sh"
if grep -qF -- '--dmenu' "$wallpaper_picker"; then
  echo 'Wallpaper picker still uses preview-less Walker dmenu mode' >&2
  exit 1
fi
if command -v xmllint >/dev/null; then
  xmllint --noout "$walker_preview"
fi
if command -v luac >/dev/null; then
  luac -p "$wallpaper_menu"
fi

legacy_config='.config/arch''-setup'
if grep -RqsF "$legacy_config" "$root" --exclude-dir=.git; then
  echo 'Legacy namespaced config directory found' >&2
  exit 1
fi

grep -qxF freerdp "$root/packages/official.txt"
grep -qxF usbutils "$root/packages/official.txt"

windows_vm="$root/dotfiles/bin/.local/bin/windows-vm"
for port_bind in '127.0.0.1:8006:8006' '127.0.0.1:3389:3389/tcp' '127.0.0.1:3389:3389/udp'; do
  grep -qF "$port_bind" "$windows_vm" || { echo "windows-vm must bind $port_bind to loopback" >&2; exit 1; }
done

if command -v shellcheck >/dev/null; then
  mapfile -t scripts < <(find "$root" -path "$root/.git" -prune -o -type f \( -name '*.sh' -o -perm -u+x \) -print)
  shellcheck -x -e SC1090,SC1091,SC2004,SC2015,SC2016,SC2032,SC2034,SC2086,SC2119,SC2120,SC2155 "${scripts[@]}"
fi

echo 'Static checks passed'
