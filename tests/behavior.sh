#!/bin/bash

set -Eeuo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
test_root=$(mktemp -d)
trap 'rm -rf -- "$test_root"' EXIT

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

test_multilib_check_is_deferred_when_disabled() (
  source "$root/scripts/lib/common.sh"
  source "$root/scripts/lib/packages.sh"
  SETUP_ROOT=$root

  command_exists() {
    [[ $1 == pacman || $1 == pacman-conf ]]
  }
  pacman_conf_calls=0
  pacman-conf() {
    ((pacman_conf_calls += 1))
    return 0
  }
  pacman() {
    [[ $1 == -Si ]] || return 1
    [[ $2 != steam && $2 != lib32-mesa ]] || fail "queried disabled multilib package $2"
  }

  output=$(check_package_manifests)
  [[ $output == *'multilib is disabled'* ]] || fail 'missing disabled multilib explanation'
)

test_multilib_check_runs_when_enabled() (
  source "$root/scripts/lib/common.sh"
  source "$root/scripts/lib/packages.sh"
  SETUP_ROOT=$root

  command_exists() {
    [[ $1 == pacman || $1 == pacman-conf ]]
  }
  pacman-conf() {
    printf '%s\n' core extra multilib
  }
  pacman() {
    [[ $1 == -Si ]] || return 1
    [[ $2 != steam ]] || return 7
  }

  if (check_package_manifests >/dev/null 2>&1); then
    fail 'accepted an unavailable package from enabled multilib'
  fi
)

test_install_includes_multilib_manifest() (
  source "$root/scripts/lib/common.sh"
  source "$root/scripts/lib/packages.sh"
  SETUP_ROOT=$root
  command_log="$test_root/install-commands"

  command_exists() {
    [[ $1 == yay ]]
  }
  pacman-conf() {
    printf '%s\n' core extra multilib
  }
  sudo() {
    printf '%s\n' "$*" >>"$command_log"
  }
  yay() {
    printf 'yay %s\n' "$*" >>"$command_log"
    return 0
  }
  mise() {
    printf 'mise %s\n' "$*" >>"$command_log"
    return 0
  }

  install_packages >/dev/null
  grep -qE '^pacman -Syu .* steam( |$)' "$command_log" || fail 'steam was omitted from the pacman install command'
  grep -qE '^pacman -Syu .* lib32-mesa( |$)' "$command_log" || fail 'lib32-mesa was omitted from the pacman install command'
  grep -qE '^pacman -Syu .* umu-launcher( |$)' "$command_log" || fail 'umu-launcher was omitted from the pacman install command'

  provider_line=$(grep -nE '^yay .* elephant-all-bin( |$)' "$command_log" | cut -d: -f1)
  walker_line=$(grep -nE '^yay .* walker-bin( |$)' "$command_log" | cut -d: -f1)
  [[ -n $provider_line && -n $walker_line && $provider_line -lt $walker_line ]] || \
    fail 'Elephant binary provider was not installed before Walker'
)

test_wallpaper_start() (
  test_home="$test_root/wallpaper-home"
  wallpaper_dir="$test_home/.config/wallpapers"
  mkdir -p "$wallpaper_dir"
  printf 'one' >"$wallpaper_dir/one.jpg"
  printf 'two' >"$wallpaper_dir/two.png"

  HOME=$test_home "$root/dotfiles/bin/.local/bin/wallpaper-start" --set-only
  selected=$(readlink -f "$wallpaper_dir/current")
  [[ $selected == "$wallpaper_dir/one.jpg" || $selected == "$wallpaper_dir/two.png" ]] || \
    fail 'selected a wallpaper outside the local wallpaper directory'

  if HOME=$test_home "$root/dotfiles/bin/.local/bin/wallpaper-start" invalid >/dev/null 2>&1; then
    fail 'accepted an invalid wallpaper-start argument'
  fi

  mock_bin="$test_root/wallpaper-bin"
  mkdir -p "$mock_bin"
  printf '#!/bin/bash\nprintf "%%s\\n" "$*"\n' >"$mock_bin/swaybg"
  chmod +x "$mock_bin/swaybg"
  swaybg_args=$(HOME=$test_home PATH="$mock_bin:$PATH" "$root/dotfiles/bin/.local/bin/wallpaper-start")
  [[ $swaybg_args == "-i $wallpaper_dir/current -m fill" ]] || \
    fail 'wallpaper-start did not launch swaybg with the stable background link'

  empty_home="$test_root/empty-wallpaper-home"
  mkdir -p "$empty_home/.config/wallpapers"
  if HOME=$empty_home "$root/dotfiles/bin/.local/bin/wallpaper-start" --set-only >/dev/null 2>&1; then
    fail 'accepted an empty wallpaper directory'
  fi
)

test_dotfile_setup_copies_wallpapers_and_backs_up_conflicts() (
  test_home="$test_root/configure-home"
  mock_bin="$test_root/mock-bin"
  mkdir -p "$test_home" "$mock_bin"
  printf '# existing zsh configuration\n' >"$test_home/.zshrc"

  printf '#!/bin/bash\nexit 0\n' >"$mock_bin/stow"
  chmod +x "$mock_bin/stow"

  HOME=$test_home PATH="$mock_bin:$PATH" "$root/scripts/configure-dotfiles.sh"

  local_wallpapers="$test_home/.config/wallpapers"
  [[ -d $local_wallpapers ]] || fail 'local wallpaper directory was not created'
  [[ $(find "$local_wallpapers" -maxdepth 1 -type f | wc -l) == $(find "$root/assets/wallpapers" -maxdepth 1 -type f | wc -l) ]] || \
    fail 'not all bundled wallpapers were copied'
  [[ $(readlink -f "$local_wallpapers/current") == "$local_wallpapers/"* ]] || \
    fail 'background still depends on the repository checkout'
  find "$test_home/.local/state/arch-setup/backups" -type f -path '*/.zshrc' -exec grep -qF '# existing zsh configuration' {} \; || \
    fail 'existing dotfile was not backed up'

  printf 'personal' >"$local_wallpapers/personal.jpg"
  HOME=$test_home PATH="$mock_bin:$PATH" "$root/scripts/configure-dotfiles.sh"
  [[ -f $local_wallpapers/personal.jpg ]] || fail 'setup removed a locally added wallpaper'
)

test_webapp_install_creates_every_launcher() (
  test_home="$test_root/webapp-home"
  mkdir -p "$test_home"

  HOME=$test_home "$root/scripts/install-webapps.sh" >/dev/null

  app_dir="$test_home/.local/share/applications"
  for app in WhatsApp 'Google Maps' YouTube GitHub Gmail; do
    [[ -x $app_dir/$app.desktop ]] || fail "web app launcher was not installed: $app"
    grep -qF 'Exec=' "$app_dir/$app.desktop" || fail "web app launcher has no command: $app"
  done
  grep -qF 'Exec=gmail-handler %u' "$app_dir/Gmail.desktop" || fail 'Gmail handler command is incorrect'
  grep -qF 'MimeType=x-scheme-handler/mailto;' "$app_dir/Gmail.desktop" || fail 'Gmail mailto association is missing'
  if grep -qF 'MimeType=x-scheme-handler/mailto;' "$app_dir/WhatsApp.desktop"; then
    fail 'mailto association leaked into a non-Gmail launcher'
  fi
)

test_desktop_firmware_check_refreshes_then_lists_updates() (
  mock_bin="$test_root/firmware-bin"
  command_log="$test_root/firmware-commands"
  mkdir -p "$mock_bin"
  cat >"$mock_bin/fwupdmgr" <<'EOF'
#!/bin/bash
printf '%s\n' "$*" >>"$FIRMWARE_LOG"
exit 0
EOF
  chmod +x "$mock_bin/fwupdmgr"

  FIRMWARE_LOG=$command_log PATH="$mock_bin:$PATH" "$root/dotfiles/bin/.local/bin/desktop-firmware" check
  [[ $(sed -n '1p' "$command_log") == 'refresh --force' ]] || fail 'desktop-firmware check did not refresh first'
  [[ $(sed -n '2p' "$command_log") == 'get-updates' ]] || fail 'desktop-firmware check did not list updates'
)

test_desktop_firmware_rejects_unknown_action() (
  if "$root/dotfiles/bin/.local/bin/desktop-firmware" bogus >/dev/null 2>&1; then
    fail 'desktop-firmware accepted an unknown action'
  fi
)

test_windows_vm_render_writes_loopback_compose() (
  test_home="$test_root/windows-vm-home"
  mkdir -p "$test_home/.config/windows-vm"
  cat >"$test_home/.config/windows-vm/vm.env" <<'EOF'
RAM_SIZE=8G
CPU_CORES=4
DISK_SIZE=128G
USERNAME=docker
PASSWORD=admin
EOF

  HOME=$test_home "$root/dotfiles/bin/.local/bin/windows-vm" render

  compose="$test_home/.config/windows-vm/docker-compose.yml"
  [[ -f $compose ]] || fail 'windows-vm render did not write docker-compose.yml'
  [[ $(stat -c %a "$compose") == 600 ]] || fail 'docker-compose.yml is not mode 600'
  grep -qF 'VERSION: "10-ltsc"' "$compose" || fail 'compose file is missing the Windows version'
  grep -qF 'RAM_SIZE: "8G"' "$compose" || fail 'compose file is missing RAM_SIZE'
  grep -qF 'CPU_CORES: "4"' "$compose" || fail 'compose file is missing CPU_CORES'
  grep -qF 'DISK_SIZE: "128G"' "$compose" || fail 'compose file is missing DISK_SIZE'
  grep -qF 'USERNAME: "docker"' "$compose" || fail 'compose file is missing USERNAME'
  grep -qF -- '- /dev/kvm' "$compose" || fail 'compose file is missing /dev/kvm'
  for port_bind in '127.0.0.1:8006:8006' '127.0.0.1:3389:3389/tcp' '127.0.0.1:3389:3389/udp'; do
    grep -qF "$port_bind" "$compose" || fail "compose file is missing loopback bind: $port_bind"
  done
)

test_windows_vm_render_omits_usb_by_default() (
  test_home="$test_root/windows-vm-no-usb"
  mkdir -p "$test_home/.config/windows-vm"
  cat >"$test_home/.config/windows-vm/vm.env" <<'EOF'
RAM_SIZE=4G
CPU_CORES=2
DISK_SIZE=64G
USERNAME=docker
PASSWORD=admin
EOF

  HOME=$test_home "$root/dotfiles/bin/.local/bin/windows-vm" render

  compose="$test_home/.config/windows-vm/docker-compose.yml"
  if grep -qF '/dev/bus/usb' "$compose"; then
    fail 'compose file mounted /dev/bus/usb with no USB devices configured'
  fi
  if grep -qF 'usb-host' "$compose"; then
    fail 'compose file referenced usb-host with no USB devices configured'
  fi
)

test_windows_vm_render_includes_configured_usb() (
  test_home="$test_root/windows-vm-usb"
  mkdir -p "$test_home/.config/windows-vm"
  cat >"$test_home/.config/windows-vm/vm.env" <<'EOF'
RAM_SIZE=4G
CPU_CORES=2
DISK_SIZE=64G
USERNAME=docker
PASSWORD=admin
EOF
  printf '046d:c52b Logitech USB Receiver\n1234:5678 Example Device\n' >"$test_home/.config/windows-vm/usb-devices"

  HOME=$test_home "$root/dotfiles/bin/.local/bin/windows-vm" render

  compose="$test_home/.config/windows-vm/docker-compose.yml"
  grep -qF -- '- /dev/bus/usb' "$compose" || fail 'compose file did not mount /dev/bus/usb for configured USB devices'
  grep -qF 'usb-host,vendorid=0x046d,productid=0xc52b' "$compose" || fail 'compose file is missing the first USB device'
  grep -qF 'usb-host,vendorid=0x1234,productid=0x5678' "$compose" || fail 'compose file is missing the second USB device'
)

test_windows_vm_rejects_unknown_subcommand() (
  if "$root/dotfiles/bin/.local/bin/windows-vm" bogus >/dev/null 2>&1; then
    fail 'windows-vm accepted an unknown subcommand'
  fi
)

test_multilib_check_is_deferred_when_disabled
test_multilib_check_runs_when_enabled
test_install_includes_multilib_manifest
test_wallpaper_start
test_dotfile_setup_copies_wallpapers_and_backs_up_conflicts
test_webapp_install_creates_every_launcher
test_desktop_firmware_check_refreshes_then_lists_updates
test_desktop_firmware_rejects_unknown_action
test_windows_vm_render_writes_loopback_compose
test_windows_vm_render_omits_usb_by_default
test_windows_vm_render_includes_configured_usb
test_windows_vm_rejects_unknown_subcommand

echo 'Behavior checks passed'
