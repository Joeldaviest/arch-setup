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

required_helpers=(
  audio-input-mute audio-output-switch desktop-audio desktop-bluetooth desktop-browser
  desktop-editor desktop-firmware desktop-launcher desktop-osd desktop-power desktop-screenrecord
  desktop-screenshot desktop-wifi display-brightness keybindings keyboard-brightness
  monitor-scale terminal-cwd tmux-new-session touchpad-toggle tui-launch
  power-profile-cycle storage-status
  window-pop windows-close-all windows-vm workspace-group-toggle xdg-terminal-exec
  reminder reminder-set weather-location weather-status wallpaper-select wallpaper-start
)
for helper in "${required_helpers[@]}"; do
  [[ -x $root/dotfiles/bin/.local/bin/$helper ]] || { echo "Missing helper: $helper" >&2; exit 1; }
done

desktop_launcher="$root/dotfiles/bin/.local/bin/desktop-launcher"
grep -qF 'setsid uwsm-app -- walker --gapplication-service' "$desktop_launcher"
if grep -qF 'GSK_RENDERER=' "$desktop_launcher"; then
  echo 'Walker is forced to use a specific GTK renderer' >&2
  exit 1
fi
grep -qF 'max_results = 50' "$root/dotfiles/walker/.config/walker/config.toml"

for legacy_helper in webapp-launch gmail-handler; do
  [[ ! -e $root/dotfiles/bin/.local/bin/$legacy_helper ]] || { echo "Legacy helper remains: $legacy_helper" >&2; exit 1; }
done

for scheme in http https mailto; do
  grep -qF "xdg-mime default firefox.desktop x-scheme-handler/$scheme" "$root/scripts/configure-user.sh" || {
    echo "Firefox is not the default $scheme handler" >&2
    exit 1
  }
done
grep -qF 'xdg-settings set default-web-browser firefox.desktop' "$root/scripts/configure-user.sh" || {
  echo 'Firefox is not configured as the default web browser' >&2
  exit 1
}

grep -qxF firefox "$root/packages/official.txt" || {
  echo 'Firefox is missing from the official package manifest' >&2
  exit 1
}
if grep -qxF floorp-bin "$root/packages/aur.txt"; then
  echo 'Floorp remains in the active AUR package manifest' >&2
  exit 1
fi
grep -qxF floorp-bin "$root/packages/obsolete.txt"
grep -qxF chromium "$root/packages/obsolete.txt"
if grep -qxF claude-code "$root/packages/aur.txt"; then
  echo 'Claude Code remains in the active AUR package manifest' >&2
  exit 1
fi
grep -qxF claude-code "$root/packages/obsolete.txt"
grep -qF 'curl -fsSL https://claude.ai/install.sh | bash' "$root/scripts/lib/packages.sh" || {
  echo "Anthropic's native Claude Code installer is missing" >&2
  exit 1
}
grep -qF 'install_claude_code' "$root/setup.sh" || {
  echo 'Claude Code native installation is not part of setup' >&2
  exit 1
}

if grep -qF 'webapp-launch' "$root/dotfiles/hypr/.config/hypr/bindings.lua"; then
  echo "Legacy web-app keybinding remains" >&2
  exit 1
fi

grep -qF 'firefox --new-tab http://127.0.0.1:4533/' "$root/scripts/configure-user.sh" || {
  echo "Normal Firefox Navidrome launcher is missing" >&2
  exit 1
}
grep -qF 'firefox-navidrome.desktop' "$root/scripts/configure-user.sh" || {
  echo 'Firefox Navidrome desktop entry is missing' >&2
  exit 1
}
grep -qF 'uwsm-app -- firefox --new-tab http://127.0.0.1:4533/' "$root/dotfiles/hypr/.config/hypr/bindings.lua" || {
  echo "Firefox Navidrome keybinding is missing" >&2
  exit 1
}
grep -qF 'exec uwsm-app -- firefox' "$root/dotfiles/bin/.local/bin/desktop-browser"
grep -qF 'args+=(--private-window)' "$root/dotfiles/bin/.local/bin/desktop-browser"
grep -qF 'class = "^[fF]irefox"' "$root/dotfiles/hypr/.config/hypr/apps/browser.lua"
grep -qF 'tag = "+firefox-browser"' "$root/dotfiles/hypr/.config/hypr/apps/browser.lua"
grep -qF 'class = "^[fF]irefox"' "$root/dotfiles/hypr/.config/hypr/hyprland.lua"
grep -qF 'class = "^[fF]irefox" }, workspace = "2 silent", group = "set"' "$root/dotfiles/hypr/.config/hypr/hyprland.lua"
grep -qF 'class = "^(codium|VSCodium)$" }, workspace = "3 silent", group = "set"' "$root/dotfiles/hypr/.config/hypr/hyprland.lua"
if grep -qE 'match = \{ workspace = "(2|3)" \}' "$root/dotfiles/hypr/.config/hypr/windows.lua"; then
  echo 'Grouped application rules still depend on the window initial workspace' >&2
  exit 1
fi
assignment_line=$(grep -nF 'class = "^[fF]irefox" }, workspace = "2 silent", group = "set"' "$root/dotfiles/hypr/.config/hypr/hyprland.lua" | cut -d: -f1)
windows_load_line=$(grep -nF 'require("./windows.lua")' "$root/dotfiles/hypr/.config/hypr/hyprland.lua" | cut -d: -f1)
[[ -n $assignment_line && -n $windows_load_line && $assignment_line -lt $windows_load_line ]]
apps_load_line=$(grep -nF 'require("./apps/*.lua")' "$root/dotfiles/hypr/.config/hypr/windows.lua" | cut -d: -f1)
floating_consumer_line=$(grep -nF 'match = { tag = "floating-window" }' "$root/dotfiles/hypr/.config/hypr/windows.lua" | cut -d: -f1)
[[ -n $apps_load_line && -n $floating_consumer_line && $apps_load_line -lt $floating_consumer_line ]]
if grep -qF 'match = { tag = "floating-window" }' "$root/dotfiles/hypr/.config/hypr/apps/system.lua"; then
  echo 'Floating-window tag is still consumed before all application rules load' >&2
  exit 1
fi

if rg -n -i 'floorp|chromium' "$root/scripts/configure-user.sh" "$root/dotfiles/bin/.local/bin/desktop-browser" \
    "$root/dotfiles/hypr/.config/hypr/apps/browser.lua" "$root/dotfiles/hypr/.config/hypr/bindings.lua" \
    "$root/dotfiles/hypr/.config/hypr/hyprland.lua"; then
  echo 'An obsolete browser remains in active runtime configuration' >&2
  exit 1
fi

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
waybar_style="$root/dotfiles/waybar/.config/waybar/style.css"
jq empty "$waybar_config"
jq -e '
  ."modules-left" == ["hyprland/workspaces"] and
  ."modules-center" == ["clock", "custom/weather"] and
  ."modules-right" == ["custom/music", "pulseaudio", "privacy", "custom/screenrecording",
    "cpu", "memory", "custom/storage", "idle_inhibitor", "custom/notification",
    "network", "bluetooth", "battery", "power-profiles-daemon", "tray"] and
  (.privacy.modules == [{"type": "audio-in", "tooltip": true, "tooltip-icon-size": 24}]) and
  (."custom/notification".exec == "swaync-client -swb") and
  (."custom/notification"["on-click"] == "swaync-client -t -sw") and
  (."custom/notification"["on-click-right"] == "swaync-client -d -sw") and
  (."custom/screenrecording".signal == 9) and
  (."custom/screenrecording" | has("interval") | not) and
  (.network.interval == 5) and
  (.cpu.interval == 10) and
  (.memory.interval == 10) and
  (."custom/storage".interval == 120) and
  (["cpu", "memory", "custom/storage"] | all(. as $module |
    ($ARGS.named.config[$module]["on-click"] | contains("btop")))) and
  (.clock.locale == "C") and
  (.clock.format == "{:%I:%M %p}") and
  (.clock | has("format-alt") | not) and
  (.clock["tooltip-format"] | contains("{:%A, %d %B %Y}") and contains("{calendar}")) and
  (."custom/weather".exec == "weather-status --json") and
  (."custom/weather".interval == 900) and
  (."custom/weather".signal == 8) and
  (."custom/weather"["on-click"] | contains("weather-status --detail") and contains("read -rsn1")) and
  (."custom/weather"["on-click-right"] == "weather-location") and
  (."custom/music".exec | contains("waybar-module-music --marquee") and
    contains("--artist-width 16") and contains("--title-width 24")) and
  (."custom/music"["return-type"] == "json") and
  (."custom/music"["on-click"] == "playerctl play-pause") and
  (."custom/music"["on-click-middle"] == "playerctl next") and
  (."custom/music"["on-click-right"] == "playerctl previous") and
  (."power-profiles-daemon".format == "{icon}") and
  (."power-profiles-daemon".tooltip == false) and
  (."power-profiles-daemon"["on-click"] == "power-profile-cycle") and
  (.battery["on-click"] == "power-profile-cycle") and
  (.tray.spacing == 10) and
  (.idle_inhibitor.timeout == 120) and
  (.idle_inhibitor["tooltip-format-activated"] | contains("dimming") and contains("suspend"))
' --argjson config "$(jq . "$waybar_config")" "$waybar_config" >/dev/null
grep -qF 'window#waybar {' "$waybar_style"
grep -A2 -F 'window#waybar {' "$waybar_style" | grep -qF 'background-color: @background;'
grep -qF '#workspaces button.urgent {' "$waybar_style"
grep -A5 -F '#workspaces button.urgent {' "$waybar_style" | grep -qF 'background-color: #f7768e;'
grep -A5 -F '#workspaces button.urgent {' "$waybar_style" | grep -qF 'color: @foreground;'
grep -qF 'tooltip {' "$waybar_style"
grep -A3 -F 'tooltip {' "$waybar_style" | grep -qF 'background-color: @background;'
grep -qF 'tooltip label {' "$waybar_style"
grep -A2 -F 'tooltip label {' "$waybar_style" | grep -qF 'background-color: @background;'
grep -qF 'focus_on_activate = false' "$root/dotfiles/hypr/.config/hypr/looknfeel.lua"
grep -qF 'passes = 2' "$root/dotfiles/hypr/.config/hypr/looknfeel.lua"
grep -qF 'pkill -RTMIN+9 -x waybar' "$root/dotfiles/bin/.local/bin/desktop-screenrecord"
swaync_config="$root/dotfiles/swaync/.config/swaync/config.json"
jq -e '
  .widgets == ["title", "dnd", "notifications"] and
  .["notification-grouping"] == true and
  .["timeout-critical"] == 0 and
  .["control-center-width"] == 400 and
  .["notification-window-width"] == 420
' "$swaync_config" >/dev/null

grep -qxF 'swaync' "$root/packages/official.txt"
grep -qxF 'awww' "$root/packages/official.txt"
for package in linux-zen linux-zen-headers linux-lts linux-lts-headers linux-firmware \
  mkinitcpio limine btrfs-progs snapper snap-pac pacman-contrib; do
  grep -qxF "$package" "$root/packages/official.txt" || {
    echo "Missing recovery package: $package" >&2
    exit 1
  }
done
for package in elephant-bin elephant-desktopapplications-bin elephant-websearch-bin \
  elephant-providerlist-bin elephant-files-bin elephant-symbols-bin elephant-calc-bin \
  elephant-clipboard-bin elephant-menus-bin; do
  grep -qxF "$package" "$root/packages/aur-preinstall.txt" || {
    echo "Missing configured Elephant provider: $package" >&2
    exit 1
  }
done
if grep -qxF elephant-all-bin "$root/packages/aur-preinstall.txt"; then
  echo 'The broad Elephant provider metapackage remains active' >&2
  exit 1
fi
grep -qxF elephant-all-bin "$root/packages/obsolete.txt"
grep -qxF elephant-protonpass-bin "$root/packages/obsolete.txt"
if grep -qxF 'mako' "$root/packages/official.txt"; then
  echo 'Mako must not remain in the active package manifest' >&2
  exit 1
fi
if grep -qxF 'swaybg' "$root/packages/official.txt"; then
  echo 'swaybg must not remain in the active package manifest' >&2
  exit 1
fi
grep -qxF 'mako' "$root/packages/obsolete.txt"
grep -qxF 'swaybg' "$root/packages/obsolete.txt"
grep -qxF 'mise' "$root/packages/obsolete.txt"
if grep -qxF 'mise' "$root/packages/official.txt" || grep -RqsE '\bmise\b' "$root/dotfiles/zsh"; then
  echo 'Mise remains active in the managed setup' >&2
  exit 1
fi
grep -qF 'uwsm-app -- swaync' "$root/dotfiles/hypr/.config/hypr/autostart.lua"
if grep -qF 'uwsm-app -- mako' "$root/dotfiles/hypr/.config/hypr/autostart.lua"; then
  echo 'Mako must not remain in Hyprland autostart' >&2
  exit 1
fi
grep -qF 'scale = 1.0' "$root/dotfiles/hypr/.config/hypr/hyprland.lua"
jq empty "$root/dotfiles/misc/.config/fastfetch/config.jsonc"

hypridle_config="$root/dotfiles/hypr/.config/hypr/hypridle.conf"
grep -qF 'timeout = 600' "$hypridle_config"
grep -qF 'on-timeout = display-brightness idle-dim; keyboard-brightness off' "$hypridle_config"
grep -qF 'timeout = 900' "$hypridle_config"
grep -qF 'on-timeout = desktop-power lock-only' "$hypridle_config"
grep -qF 'timeout = 930' "$hypridle_config"
grep -qF 'timeout = 2100' "$hypridle_config"
grep -qF 'on-timeout = desktop-power idle-suspend' "$hypridle_config"
grep -qF 'on_unlock_cmd = desktop-power wake' "$hypridle_config"
grep -qF -- '--what=idle' "$root/dotfiles/bin/.local/bin/desktop-screenrecord"
grep -qF 'pgrep -x hypridle' "$root/scripts/configure-dotfiles.sh"
grep -qF 'setsid uwsm-app -- hypridle' "$root/scripts/configure-dotfiles.sh"

hyprlock_config="$root/dotfiles/hypr/.config/hypr/hyprlock.conf"
grep -qF 'immediate_render = true' "$hyprlock_config"
grep -qF 'fractional_scaling = 2' "$hyprlock_config"
grep -qF 'hide_cursor = true' "$hyprlock_config"
grep -qF 'brightness = 0.45' "$hyprlock_config"
grep -qF 'size = 420, 64' "$hyprlock_config"
grep -qF 'check_color = $check_color' "$hyprlock_config"
grep -qF 'fail_color = $fail_color' "$hyprlock_config"
grep -qF 'capslock_color = $capslock_color' "$hyprlock_config"
if grep -qE '^[[:space:]]*(label|image|shape)[[:space:]]*\{' "$hyprlock_config"; then
  echo 'Hyprlock must remain free of clock, user, and informational widgets' >&2
  exit 1
fi

grep -qF 'Name=en* eth*' "$root/system/20-wired.network"
grep -qF 'DHCP=yes' "$root/system/20-wired.network"
grep -qF 'RequiredForOnline=no' "$root/system/20-wired.network"
[[ $(grep -cF 'RouteMetric=100' "$root/system/20-wired.network") == 3 ]]
grep -qF 'systemd-networkd.service' "$root/scripts/configure-system.sh"
grep -qF 'disable systemd-networkd-wait-online.service' "$root/scripts/configure-system.sh"
grep -qF 'fwupd-refresh.timer' "$root/scripts/configure-system.sh"
grep -qF "powerprofilesctl configure-battery-aware --enable" "$root/scripts/configure-system.sh"
grep -qxF 'BOOT_ORDER="linux-zen, linux-lts, *, *fallback, Snapshots"' "$root/system/limine-entry-tool.conf"
grep -qF '/etc/limine-entry-tool.d/90-arch-setup-kernels.conf' "$root/scripts/configure-system.sh"
grep -qF 'sudo limine-update' "$root/scripts/configure-system.sh"

limine_fixture=$(mktemp)
limine_result=$(mktemp)
trap 'rm -f "$limine_fixture" "$limine_result"' EXIT
printf '%s\n' \
  'timeout: 5' \
  'default_entry: 1' \
  'remember_last_entry: yes' \
  '/+Arch Linux' \
  '//linux-lts' \
  'protocol: linux' \
  'path: boot():/vmlinuz-linux-lts' \
  '//linux-zen' \
  'protocol: linux' \
  'path: boot():/vmlinuz-linux-zen' \
  '//linux-zen-fallback' \
  'protocol: linux' \
  'path: boot():/vmlinuz-linux-zen' >"$limine_fixture"
source "$root/scripts/lib/limine.sh"
zen_entry=$(find_limine_zen_entry "$limine_fixture")
[[ $zen_entry == 'Arch Linux/linux-zen' ]]
write_limine_zen_default "$limine_fixture" "$limine_result" "$zen_entry"
grep -qxF 'default_entry: Arch Linux/linux-zen' "$limine_result"
grep -qxF 'remember_last_entry: no' "$limine_result"
[[ $(grep -ciE '^[[:space:]]*default_entry[[:space:]]*:' "$limine_result") == 1 ]]
[[ $(grep -ciE '^[[:space:]]*remember_last_entry[[:space:]]*:' "$limine_result") == 1 ]]
rm -f "$limine_fixture" "$limine_result"
trap - EXIT
if grep -qE 'Name=.*(wl\*|wlan)' "$root/system/20-wired.network"; then
  echo 'systemd-networkd configuration must not claim Wi-Fi interfaces managed by IWD' >&2
  exit 1
fi

sddm_theme="$root/system/sddm-theme/arch-setup/Main.qml"
grep -qF 'userModel.lastUser' "$sddm_theme"
grep -qF 'userModel.count > 0' "$sddm_theme"
grep -qF 'Qt.UserRole + 1' "$sddm_theme"
if grep -qF 'property string currentUser: userModel.lastUser' "$sddm_theme"; then
  echo 'SDDM theme still requires a previously remembered user' >&2
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

cpu_microcode=$(ARCH_SETUP_TEST_CPU_VENDOR=GenuineIntel bash -c '
  source "$1/scripts/lib/common.sh"
  source "$1/scripts/lib/packages.sh"
  source "$1/scripts/lib/hardware.sh"
  ARCH_SETUP_TEST_CPU_VENDOR=$2
  ARCH_SETUP_TEST_PCI="Ethernet controller: Virtio network device"
  classify_hardware
  printf "%s\n" "${HARDWARE_PACKAGES[@]}"
' _ "$root" GenuineIntel)
grep -qxF intel-ucode <<<"$cpu_microcode"

dual_kernel_headers=$(bash -c '
  source "$1/scripts/lib/common.sh"
  source "$1/scripts/lib/packages.sh"
  source "$1/scripts/lib/hardware.sh"
  command_exists() { [[ $1 == pacman ]]; }
  pacman() { [[ $1 == -Q && ( $2 == linux-zen || $2 == linux-lts ) ]]; }
  classify_hardware
  printf "%s\n" "${HARDWARE_PACKAGES[@]}"
' _ "$root")
grep -qxF linux-zen-headers <<<"$dual_kernel_headers"
grep -qxF linux-lts-headers <<<"$dual_kernel_headers"

grep -qF 'paccache.timer' "$root/scripts/configure-system.sh"
grep -qF 'btrfs-scrub@-.timer' "$root/scripts/configure-system.sh"
grep -qF '/etc/snapper/configs/root' "$root/scripts/configure-system.sh"
grep -qF 'systemctl start docker.socket' "$root/scripts/configure-system.sh"

grep -qF 'hl.exec_cmd("uwsm-app -- wallpaper-start")' "$root/dotfiles/hypr/.config/hypr/autostart.lua"
grep -qF 'awww-daemon --quiet' "$root/dotfiles/bin/.local/bin/wallpaper-start"
grep -qF 'awww img' "$root/dotfiles/bin/.local/bin/wallpaper-start"
grep -qF -- '--transition-type fade' "$root/dotfiles/bin/.local/bin/wallpaper-start"
grep -qF -- '--transition-duration 0.7' "$root/dotfiles/bin/.local/bin/wallpaper-start"
grep -qF 'pkill -x swaybg' "$root/dotfiles/bin/.local/bin/wallpaper-start"
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

tmux_config="$root/dotfiles/tmux/.config/tmux/tmux.conf"
grep -qF 'bind -n M-t split-window -h -c "#{pane_current_path}"' "$tmux_config"
grep -qF 'bind -n M-T split-window -v -c "#{pane_current_path}"' "$tmux_config"
grep -qF 'bind -n M-q kill-pane' "$tmux_config"
grep -qF 'bind -n M-h select-pane -L' "$tmux_config"
grep -qF 'bind -n M-j select-pane -D' "$tmux_config"
grep -qF 'bind -n M-k select-pane -U' "$tmux_config"
grep -qF 'bind -n M-l select-pane -R' "$tmux_config"
grep -qF 'bind C run-shell "tmux-new-session"' "$tmux_config"
if grep -qE 'bind -n C-M-(Left|Right|Up|Down) select-pane' "$tmux_config"; then
  echo 'Arrow-based tmux pane navigation remains configured' >&2
  exit 1
fi
if grep -qE 'bind -n M-(Enter|S-Enter|Escape) ' "$tmux_config"; then
  echo 'Legacy tmux Alt pane bindings remain configured' >&2
  exit 1
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
