#!/bin/bash

set -Eeuo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)

while IFS= read -r script; do
  bash -n "$script"
done < <(find "$root" -path "$root/.git" -prune -o -type f \( -name '*.sh' -o -perm -u+x \) -print)

duplicates=$(comm -12 \
  <(sed -E 's/[[:space:]]+#.*$//;/^[[:space:]]*(#|$)/d' "$root/packages/official.txt" | sort -u) \
  <(sed -E 's/[[:space:]]+#.*$//;/^[[:space:]]*(#|$)/d' "$root/packages/aur.txt" | sort -u))
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
  desktop-editor desktop-launcher desktop-osd desktop-power desktop-screenrecord
  desktop-screenshot desktop-wifi display-brightness keybindings keyboard-brightness
  monitor-scale terminal-cwd touchpad-toggle tui-launch waybar-toggle webapp-focus
  webapp-launch window-pop windows-close-all workspace-layout-toggle xdg-terminal-exec
  reminder reminder-set weather-status wallpaper-select
)
for helper in "${required_helpers[@]}"; do
  [[ -x $root/dotfiles/bin/.local/bin/$helper ]] || { echo "Missing helper: $helper" >&2; exit 1; }
done

jq empty "$root/dotfiles/waybar/.config/waybar/config.jsonc"
jq empty "$root/dotfiles/misc/.config/fastfetch/config.jsonc"

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
hardware_case 'VGA compatible controller: Intel Corporation Graphics' Generic vulkan-intel
hardware_case 'VGA compatible controller: NVIDIA Corporation RTX 4070' Generic nvidia-open-dkms
hardware_case 'VGA compatible controller: NVIDIA Corporation GTX 1080' Generic nvidia-580xx-dkms
hardware_case 'Ethernet controller [1f0a:6801] YT6801' Generic yt6801-dkms
hardware_case 'VGA compatible controller: AMD/ATI Radeon' Framework qmk-hid

if command -v shellcheck >/dev/null; then
  mapfile -t scripts < <(find "$root" -path "$root/.git" -prune -o -type f \( -name '*.sh' -o -perm -u+x \) -print)
  shellcheck -x -e SC1090,SC1091,SC2004,SC2015,SC2016,SC2034,SC2086,SC2119,SC2120,SC2155 "${scripts[@]}"
fi

echo 'Static checks passed'
