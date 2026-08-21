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
  pacman() {
    [[ $1 == -Q && $2 == mako ]]
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
  grep -qE '^pacman -Syu .* swaync( |$)' "$command_log" || fail 'SwayNC was omitted from the pacman install command'
  grep -qxF 'pacman -R --noconfirm mako' "$command_log" || fail 'obsolete Mako package was not removed during upgrade'
  swaync_install_line=$(grep -nE '^pacman -Syu .* swaync( |$)' "$command_log" | cut -d: -f1)
  mako_remove_line=$(grep -nF 'pacman -R --noconfirm mako' "$command_log" | cut -d: -f1)
  [[ $swaync_install_line -lt $mako_remove_line ]] || fail 'Mako was removed before SwayNC was installed'

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

test_storage_status_reports_separate_filesystems_and_swap() (
  mock_bin="$test_root/storage-bin"
  meminfo="$test_root/storage-meminfo"
  mkdir -p "$mock_bin"
  printf '%s\n' \
    '#!/bin/bash' \
    'path=${@: -1}' \
    'printf "%s\n" "Filesystem 1024-blocks Used Available Capacity Mounted on"' \
    'case $path in' \
    '  /test-root) printf "%s\n" "/dev/root 47185920 17825792 27262976 38% /" ;;' \
    '  /test-home) printf "%s\n" "/dev/home 431104000 107776000 323328000 25% /home" ;;' \
    '  *) exit 1 ;;' \
    'esac' >"$mock_bin/df"
  chmod +x "$mock_bin/df"
  printf '%s\n' 'SwapTotal:       8060928 kB' 'SwapFree:        6045696 kB' >"$meminfo"

  output=$(ARCH_SETUP_ROOT_PATH=/test-root \
    ARCH_SETUP_HOME_PATH=/test-home \
    ARCH_SETUP_MEMINFO="$meminfo" \
    PATH="$mock_bin:$PATH" \
    "$root/dotfiles/bin/.local/bin/storage-status")

  [[ $(jq -r .text <<<"$output") == 'DISK 26%' ]] || fail 'storage status did not show combined filesystem usage'
  tooltip=$(jq -r .tooltip <<<"$output")
  [[ $tooltip == *'Root:'* && $tooltip == *'(38%)'* ]] || fail 'storage tooltip omitted root usage'
  [[ $tooltip == *'Home:'* && $tooltip == *'(25%)'* ]] || fail 'storage tooltip omitted home usage'
  [[ $tooltip == *'Swap:'* && $tooltip == *'(25%)'* ]] || fail 'storage tooltip omitted swap usage'
  [[ $tooltip != *'\n'* ]] || fail 'storage tooltip rendered escaped newlines literally'
  [[ $(grep -c '^' <<<"$tooltip") == 3 ]] || fail 'storage tooltip did not render one line per storage area'
)

test_power_profile_cycle_sets_next_profile_and_notifies() (
  mock_bin="$test_root/power-profile-bin"
  state="$test_root/power-profile-state"
  notifications="$test_root/power-profile-notifications"
  mkdir -p "$mock_bin"
  printf '%s\n' balanced >"$state"
  printf '%s\n' \
    '#!/bin/bash' \
    'case $1 in' \
    '  list) printf "%s\n" "  performance:" "* balanced:" "  power-saver:" ;;' \
    '  get) cat "$POWER_PROFILE_TEST_STATE" ;;' \
    '  set) printf "%s\n" "$2" >"$POWER_PROFILE_TEST_STATE" ;;' \
    '  *) exit 1 ;;' \
    'esac' >"$mock_bin/powerprofilesctl"
  printf '%s\n' \
    '#!/bin/bash' \
    'printf "%s\n" "$*" >>"$POWER_PROFILE_TEST_NOTIFICATIONS"' >"$mock_bin/notify-send"
  chmod +x "$mock_bin/powerprofilesctl" "$mock_bin/notify-send"

  POWER_PROFILE_TEST_STATE="$state" \
    POWER_PROFILE_TEST_NOTIFICATIONS="$notifications" \
    PATH="$mock_bin:$PATH" \
    "$root/dotfiles/bin/.local/bin/power-profile-cycle"

  [[ $(<"$state") == power-saver ]] || fail 'battery click did not cycle to the next power profile'
  grep -qF 'Power saver' "$notifications" || fail 'power profile change did not produce feedback'
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

test_dotfile_setup_migrates_running_mako_to_swaync() (
  test_home="$test_root/mako-migration-home"
  mock_bin="$test_root/mako-migration-bin"
  command_log="$test_root/mako-migration-commands"
  mkdir -p "$test_home/.config/mako" "$mock_bin"
  ln -s "$root/dotfiles/mako/.config/mako/config" "$test_home/.config/mako/config"

  printf '#!/bin/bash\nexit 0\n' >"$mock_bin/stow"
  printf '%s\n' \
    '#!/bin/bash' \
    '[[ $1 == -x && $2 == mako ]]' >"$mock_bin/pgrep"
  printf '%s\n' \
    '#!/bin/bash' \
    'printf "pkill %s\\n" "$*" >>"$MIGRATION_COMMAND_LOG"' >"$mock_bin/pkill"
  printf '%s\n' \
    '#!/bin/bash' \
    'printf "setsid %s\\n" "$*" >>"$MIGRATION_COMMAND_LOG"' >"$mock_bin/setsid"
  chmod +x "$mock_bin/stow" "$mock_bin/pgrep" "$mock_bin/pkill" "$mock_bin/setsid"

  HOME=$test_home \
    WAYLAND_DISPLAY=wayland-test \
    MIGRATION_COMMAND_LOG=$command_log \
    PATH="$mock_bin:$PATH" \
    "$root/scripts/configure-dotfiles.sh"

  [[ ! -L $test_home/.config/mako/config ]] || fail 'legacy managed Mako link survived migration'
  grep -qxF 'pkill -x mako' "$command_log" || fail 'running Mako was not stopped during migration'
  grep -qxF 'setsid uwsm-app -- swaync' "$command_log" || fail 'SwayNC was not started after stopping Mako'
)

test_dotfile_setup_preserves_personal_mako_config() (
  test_home="$test_root/personal-mako-home"
  mock_bin="$test_root/personal-mako-bin"
  mkdir -p "$test_home/.config/mako" "$mock_bin"
  printf 'personal Mako config\n' >"$test_home/.config/mako/config"
  printf '#!/bin/bash\nexit 0\n' >"$mock_bin/stow"
  printf '#!/bin/bash\nexit 1\n' >"$mock_bin/pgrep"
  chmod +x "$mock_bin/stow" "$mock_bin/pgrep"

  HOME=$test_home PATH="$mock_bin:$PATH" "$root/scripts/configure-dotfiles.sh"
  grep -qxF 'personal Mako config' "$test_home/.config/mako/config" || fail 'personal Mako config was removed during migration'
)

seed_floorp_profile() {
  local test_home=$1 work_context=${2:-2}
  mkdir -p "$test_home/.floorp/default"
  cat >"$test_home/.floorp/profiles.ini" <<EOF
[Profile0]
Name=default
IsRelative=1
Path=default
Default=1

[General]
StartWithLastProfile=1
Version=2
EOF
  touch "$test_home/.floorp/default/prefs.js"
  jq -n --argjson work_context "$work_context" '{
    version: 6, lastUserContextId: 5,
    identities: [
      {userContextId: 1, public: true, icon: "fingerprint", color: "blue", l10nId: "user-context-personal"},
      {userContextId: $work_context, public: true, icon: "briefcase", color: "orange", name: "Work"}
    ]
  }' >"$test_home/.floorp/default/containers.json"
}

test_configure_floorp_creates_every_launcher() (
  test_home="$test_root/floorp-home"
  mkdir -p "$test_home"
  seed_floorp_profile "$test_home"

  HOME=$test_home "$root/scripts/configure-floorp.sh" >/dev/null

  app_dir="$test_home/.local/share/applications"
  for id in whatsapp google-maps youtube github personal-gmail navidrome work-gmail work-github; do
    [[ -x $app_dir/floorp-$id.desktop ]] || fail "web app launcher was not installed: $id"
    grep -qF 'Exec=' "$app_dir/floorp-$id.desktop" || fail "web app launcher has no command: $id"
    grep -qF -- "--start-ssb $id" "$app_dir/floorp-$id.desktop" || fail "web app launcher has the wrong SSB id: $id"
  done

  grep -qF 'MimeType=x-scheme-handler/mailto;' "$app_dir/floorp-personal-gmail.desktop" || \
    fail 'Gmail mailto association is missing'
  if grep -qF 'MimeType=x-scheme-handler/mailto;' "$app_dir/floorp-whatsapp.desktop"; then
    fail 'mailto association leaked into a non-Gmail launcher'
  fi

  ssb_json="$test_home/.floorp/default/ssb/ssb.json"
  [[ $(jq '."https://mail.google.com/:0".id' "$ssb_json") == '"personal-gmail"' ]] || \
    fail 'personal Gmail SSB record is missing or wrong'
  [[ $(jq '."https://mail.google.com/:2".id' "$ssb_json") == '"work-gmail"' ]] || \
    fail 'work Gmail SSB record is missing or wrong'
  [[ $(jq '."https://github.com/:2".id' "$ssb_json") == '"work-github"' ]] || \
    fail 'work GitHub SSB record is missing or wrong'

  prefs_js="$test_home/.floorp/default/prefs.js"
  grep -qF 'user_pref("floorp.workspaces.enabled", true);' "$prefs_js" || fail 'workspaces were not enabled'
  store_line=$(grep -F 'user_pref("floorp.workspaces.v4.store"' "$prefs_js")
  [[ -n $store_line ]] || fail 'workspace store pref is missing'
  quoted_value=$(sed -E 's/^user_pref\("floorp\.workspaces\.v4\.store", (.*)\);$/\1/' <<<"$store_line")
  store_json=$(jq -r . <<<"$quoted_value")
  echo "$store_json" | jq -e '.data[] | select(.[1].name=="Work") | .[1].userContextId == 2' >/dev/null || \
    fail 'workspace store does not bind Work to the Work container'
)

test_configure_floorp_fails_without_work_container() (
  test_home="$test_root/floorp-home-no-work"
  mkdir -p "$test_home/.floorp/default"
  cat >"$test_home/.floorp/profiles.ini" <<'EOF'
[Profile0]
Name=default
IsRelative=1
Path=default
Default=1
EOF
  touch "$test_home/.floorp/default/prefs.js"
  echo '{"version":6,"lastUserContextId":1,"identities":[]}' >"$test_home/.floorp/default/containers.json"

  if HOME=$test_home "$root/scripts/configure-floorp.sh" >/dev/null 2>&1; then
    fail 'configure-floorp.sh should fail when no Work container exists'
  fi
)

test_configure_floorp_is_idempotent() (
  test_home="$test_root/floorp-home-idempotent"
  mkdir -p "$test_home"
  seed_floorp_profile "$test_home"

  HOME=$test_home "$root/scripts/configure-floorp.sh" >/dev/null
  HOME=$test_home "$root/scripts/configure-floorp.sh" >/dev/null

  prefs_js="$test_home/.floorp/default/prefs.js"
  [[ $(grep -cF 'user_pref("floorp.workspaces.enabled"' "$prefs_js") == 1 ]] || \
    fail 're-running configure-floorp.sh duplicated the workspaces.enabled pref'
  [[ $(grep -cF 'user_pref("floorp.workspaces.v4.store"' "$prefs_js") == 1 ]] || \
    fail 're-running configure-floorp.sh duplicated the workspace store pref'

  ssb_json="$test_home/.floorp/default/ssb/ssb.json"
  [[ $(jq 'keys | length' "$ssb_json") == 8 ]] || fail 're-running configure-floorp.sh duplicated SSB records'
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
  grep -qF 'VERSION: "10l"' "$compose" || fail 'compose file is missing the Windows version'
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
test_storage_status_reports_separate_filesystems_and_swap
test_power_profile_cycle_sets_next_profile_and_notifies
test_dotfile_setup_copies_wallpapers_and_backs_up_conflicts
test_dotfile_setup_migrates_running_mako_to_swaync
test_dotfile_setup_preserves_personal_mako_config
test_configure_floorp_creates_every_launcher
test_configure_floorp_fails_without_work_container
test_configure_floorp_is_idempotent
test_desktop_firmware_check_refreshes_then_lists_updates
test_desktop_firmware_rejects_unknown_action
test_windows_vm_render_writes_loopback_compose
test_windows_vm_render_omits_usb_by_default
test_windows_vm_render_includes_configured_usb
test_windows_vm_rejects_unknown_subcommand

echo 'Behavior checks passed'
