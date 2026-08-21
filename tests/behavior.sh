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
    [[ $1 == -Q && ( $2 == mako || $2 == swaybg ) ]]
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
  grep -qE '^pacman -Syu .* awww( |$)' "$command_log" || fail 'awww was omitted from the pacman install command'
  grep -qxF 'pacman -R --noconfirm mako swaybg' "$command_log" || fail 'obsolete wallpaper or notification package was not removed during upgrade'
  swaync_install_line=$(grep -nE '^pacman -Syu .* swaync( |$)' "$command_log" | cut -d: -f1)
  awww_install_line=$(grep -nE '^pacman -Syu .* awww( |$)' "$command_log" | cut -d: -f1)
  mako_remove_line=$(grep -nF 'pacman -R --noconfirm mako swaybg' "$command_log" | cut -d: -f1)
  [[ $swaync_install_line -lt $mako_remove_line ]] || fail 'Mako was removed before SwayNC was installed'
  [[ $awww_install_line -lt $mako_remove_line ]] || fail 'swaybg was removed before awww was installed'

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
  cat >"$mock_bin/awww" <<'EOF'
#!/bin/bash
case $1 in
  query) exit 0 ;;
  img) printf '%s\n' "$*" ;;
esac
EOF
  printf '#!/bin/bash\nexit 0\n' >"$mock_bin/pkill"
  chmod +x "$mock_bin/awww" "$mock_bin/pkill"
  awww_args=$(HOME=$test_home PATH="$mock_bin:$PATH" "$root/dotfiles/bin/.local/bin/wallpaper-start")
  [[ $awww_args == "img --resize crop --transition-type fade --transition-duration 0.7 --transition-fps 60 "* ]] || \
    fail 'wallpaper-start did not apply the selected image with the expected awww transition'

  empty_home="$test_root/empty-wallpaper-home"
  mkdir -p "$empty_home/.config/wallpapers"
  if HOME=$empty_home "$root/dotfiles/bin/.local/bin/wallpaper-start" --set-only >/dev/null 2>&1; then
    fail 'accepted an empty wallpaper directory'
  fi
)

test_wallpaper_apply_recovers_daemon_and_preserves_fallback() (
  test_home="$test_root/wallpaper-recovery-home"
  wallpaper_dir="$test_home/.config/wallpapers"
  mock_bin="$test_root/wallpaper-recovery-bin"
  command_log="$test_root/wallpaper-recovery-commands"
  ready="$test_root/wallpaper-recovery-ready"
  mkdir -p "$wallpaper_dir" "$mock_bin"
  printf 'wallpaper' >"$wallpaper_dir/recovery image.jpg"
  ln -s "recovery image.jpg" "$wallpaper_dir/current"

  cat >"$mock_bin/awww" <<'EOF'
#!/bin/bash
case $1 in
  query) [[ -e $AWWW_TEST_READY ]] ;;
  img)
    printf 'awww %s\n' "$*" >>"$AWWW_TEST_LOG"
    [[ ${AWWW_TEST_FAIL_IMG:-0} != 1 ]]
    ;;
esac
EOF
  cat >"$mock_bin/setsid" <<'EOF'
#!/bin/bash
printf 'setsid %s\n' "$*" >>"$AWWW_TEST_LOG"
touch "$AWWW_TEST_READY"
EOF
  cat >"$mock_bin/pkill" <<'EOF'
#!/bin/bash
printf 'pkill %s\n' "$*" >>"$AWWW_TEST_LOG"
EOF
  chmod +x "$mock_bin/awww" "$mock_bin/setsid" "$mock_bin/pkill"

  HOME=$test_home \
    AWWW_TEST_READY=$ready \
    AWWW_TEST_LOG=$command_log \
    PATH="$mock_bin:$PATH" \
    "$root/dotfiles/bin/.local/bin/wallpaper-start" --apply

  grep -qF 'setsid uwsm-app -- ' "$command_log" || fail 'wallpaper apply did not recover a missing awww daemon'
  grep -qF ' --daemon' "$command_log" || fail 'wallpaper recovery did not use the managed daemon entry point'
  grep -qF 'awww img ' "$command_log" || fail 'wallpaper recovery did not retry the image after starting awww'
  grep -qxF 'pkill -x swaybg' "$command_log" || fail 'successful awww recovery did not retire swaybg'

  : >"$command_log"
  if HOME=$test_home \
    AWWW_TEST_READY=$ready \
    AWWW_TEST_LOG=$command_log \
    AWWW_TEST_FAIL_IMG=1 \
    PATH="$mock_bin:$PATH" \
    "$root/dotfiles/bin/.local/bin/wallpaper-start" --apply >/dev/null 2>&1; then
    fail 'wallpaper apply ignored an awww image failure'
  fi
  if grep -qF 'pkill -x swaybg' "$command_log"; then
    fail 'wallpaper apply removed the swaybg fallback after an awww failure'
  fi
)

test_wallpaper_select_previews_and_applies_safely() (
  test_home="$test_root/wallpaper-select-home"
  wallpaper_dir="$test_home/.config/wallpapers"
  mock_bin="$test_root/wallpaper-select-bin"
  command_log="$test_root/wallpaper-select-commands"
  mkdir -p "$wallpaper_dir" "$mock_bin"
  printf 'wallpaper' >"$wallpaper_dir/night's sky.jpg"
  printf 'unsupported' >"$wallpaper_dir/notes.txt"
  printf 'outside' >"$test_home/outside.png"

  cat >"$mock_bin/awww" <<'EOF'
#!/bin/bash
case $1 in
  query) exit 0 ;;
  img) printf 'awww %s\n' "$*" >>"$WALLPAPER_SELECT_LOG" ;;
esac
EOF
  cat >"$mock_bin/pkill" <<'EOF'
#!/bin/bash
printf 'pkill %s\n' "$*" >>"$WALLPAPER_SELECT_LOG"
EOF
  cat >"$mock_bin/desktop-launcher" <<'EOF'
#!/bin/bash
printf 'walker %s %s %s %s\n' "$WALKER_WIDTH" "$WALKER_MIN_HEIGHT" "$WALKER_MAX_HEIGHT" "$*" >>"$WALLPAPER_SELECT_LOG"
EOF
  chmod +x "$mock_bin/awww" "$mock_bin/pkill" "$mock_bin/desktop-launcher"

  ARCH_SETUP_WALLPAPER_DIR="$wallpaper_dir" \
    WALLPAPER_SELECT_LOG="$command_log" \
    PATH="$mock_bin:$PATH" \
    "$root/dotfiles/bin/.local/bin/wallpaper-select" --set "$wallpaper_dir/night's sky.jpg"

  [[ $(readlink -f "$wallpaper_dir/current") == "$wallpaper_dir/night's sky.jpg" ]] || \
    fail 'wallpaper-select did not update the stable wallpaper link'
  grep -qxF "awww img --resize crop --transition-type fade --transition-duration 0.7 --transition-fps 60 $wallpaper_dir/night's sky.jpg" "$command_log" || \
    fail 'wallpaper-select did not send the selected image to awww'
  awww_line=$(grep -nF 'awww img ' "$command_log" | head -1 | cut -d: -f1)
  swaybg_stop_line=$(grep -nF 'pkill -x swaybg' "$command_log" | head -1 | cut -d: -f1)
  [[ -n $awww_line && -n $swaybg_stop_line && $awww_line -lt $swaybg_stop_line ]] || \
    fail 'wallpaper-select stopped swaybg before awww displayed the replacement'

  if ARCH_SETUP_WALLPAPER_DIR="$wallpaper_dir" PATH="$mock_bin:$PATH" \
    "$root/dotfiles/bin/.local/bin/wallpaper-select" --set "$test_home/outside.png" >/dev/null 2>&1; then
    fail 'wallpaper-select accepted a file outside the wallpaper directory'
  fi
  if ARCH_SETUP_WALLPAPER_DIR="$wallpaper_dir" PATH="$mock_bin:$PATH" \
    "$root/dotfiles/bin/.local/bin/wallpaper-select" --set "$wallpaper_dir/notes.txt" >/dev/null 2>&1; then
    fail 'wallpaper-select accepted an unsupported file type'
  fi

  ARCH_SETUP_WALLPAPER_DIR="$wallpaper_dir" \
    WALLPAPER_SELECT_LOG="$command_log" \
    PATH="$mock_bin:$PATH" \
    "$root/dotfiles/bin/.local/bin/wallpaper-select"
  grep -qxF 'walker 1100 460 460 -m menus:wallpaper' "$command_log" || \
    fail 'wallpaper-select did not open the dedicated wide Walker menu'

  if command -v lua >/dev/null; then
    HOME=$test_home ARCH_SETUP_WALLPAPER_DIR="$wallpaper_dir" lua - "$root" <<'LUA'
local root = arg[1]
dofile(root .. "/dotfiles/elephant/.config/elephant/menus/wallpaper.lua")
local entries = GetEntries()
assert(#entries == 1, "wallpaper menu included unsupported or synthetic files")
assert(entries[1].Text:match("^✓ "), "wallpaper menu did not mark the current wallpaper")
assert(entries[1].Preview == entries[1].Value, "wallpaper menu preview path differs from its value")
assert(entries[1].PreviewType == "file", "wallpaper menu did not request a file preview")
LUA
  fi
)

test_idle_suspend_is_laptop_only() (
  mock_bin="$test_root/idle-suspend-bin"
  power_dir="$test_root/idle-power-supplies"
  command_log="$test_root/idle-suspend-commands"
  mkdir -p "$mock_bin" "$power_dir/AC0" "$power_dir/mouse_battery"
  printf 'Mains\n' >"$power_dir/AC0/type"
  printf 'System\n' >"$power_dir/AC0/scope"
  printf 'Unknown\n' >"$power_dir/AC0/status"
  printf 'Battery\n' >"$power_dir/mouse_battery/type"
  printf 'Device\n' >"$power_dir/mouse_battery/scope"
  printf 'Discharging\n' >"$power_dir/mouse_battery/status"
  cat >"$mock_bin/systemctl" <<'EOF'
#!/bin/bash
printf '%s\n' "$*" >>"$IDLE_SUSPEND_LOG"
EOF
  chmod +x "$mock_bin/systemctl"

  ARCH_SETUP_POWER_SUPPLY_DIR="$power_dir" \
    IDLE_SUSPEND_LOG="$command_log" \
    PATH="$mock_bin:$PATH" \
    "$root/dotfiles/bin/.local/bin/desktop-power" idle-suspend
  [[ ! -s $command_log ]] || fail 'desktop idle policy attempted to suspend a battery-less PC'

  mkdir -p "$power_dir/BAT0"
  printf 'Battery\n' >"$power_dir/BAT0/type"
  printf 'System\n' >"$power_dir/BAT0/scope"
  printf 'Charging\n' >"$power_dir/BAT0/status"
  ARCH_SETUP_POWER_SUPPLY_DIR="$power_dir" \
    IDLE_SUSPEND_LOG="$command_log" \
    PATH="$mock_bin:$PATH" \
    "$root/dotfiles/bin/.local/bin/desktop-power" idle-suspend
  [[ ! -s $command_log ]] || fail 'idle policy attempted to suspend a plugged-in laptop'

  printf 'Discharging\n' >"$power_dir/BAT0/status"
  ARCH_SETUP_POWER_SUPPLY_DIR="$power_dir" \
    IDLE_SUSPEND_LOG="$command_log" \
    PATH="$mock_bin:$PATH" \
    "$root/dotfiles/bin/.local/bin/desktop-power" idle-suspend
  [[ $(<"$command_log") == suspend ]] || fail 'laptop idle policy did not request suspend'
)

test_idle_brightness_never_increases_and_restores() (
  mock_bin="$test_root/idle-brightness-bin"
  backlight_dir="$test_root/idle-backlight"
  command_log="$test_root/idle-brightness-commands"
  mkdir -p "$mock_bin" "$backlight_dir/panel"
  cat >"$mock_bin/brightnessctl" <<'EOF'
#!/bin/bash
printf '%s\n' "$*" >>"$IDLE_BRIGHTNESS_LOG"
case ${*: -1} in
  get) printf '%s\n' "$IDLE_BRIGHTNESS_CURRENT" ;;
  max) printf '100\n' ;;
esac
EOF
  chmod +x "$mock_bin/brightnessctl"

  ARCH_SETUP_BACKLIGHT_DIR="$backlight_dir" \
    IDLE_BRIGHTNESS_LOG="$command_log" \
    IDLE_BRIGHTNESS_CURRENT=80 \
    PATH="$mock_bin:$PATH" \
    "$root/dotfiles/bin/.local/bin/display-brightness" idle-dim
  grep -qxF -- '-sd panel set 20' "$command_log" || fail 'idle dim did not cap a bright display at 20 percent'

  : >"$command_log"
  ARCH_SETUP_BACKLIGHT_DIR="$backlight_dir" \
    IDLE_BRIGHTNESS_LOG="$command_log" \
    IDLE_BRIGHTNESS_CURRENT=10 \
    PATH="$mock_bin:$PATH" \
    "$root/dotfiles/bin/.local/bin/display-brightness" idle-dim
  grep -qxF -- '-sd panel set 10' "$command_log" || fail 'idle dim increased an already dim display'

  : >"$command_log"
  ARCH_SETUP_BACKLIGHT_DIR="$backlight_dir" \
    IDLE_BRIGHTNESS_LOG="$command_log" \
    IDLE_BRIGHTNESS_CURRENT=10 \
    PATH="$mock_bin:$PATH" \
    "$root/dotfiles/bin/.local/bin/display-brightness" idle-restore
  grep -qxF -- '-rd panel' "$command_log" || fail 'idle resume did not restore saved display brightness'
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
  printf '%s\n' \
    '#!/bin/bash' \
    'case $1 in' \
    '  query) exit 0 ;;' \
    '  img) printf "awww %s\\n" "$*" >>"$MIGRATION_COMMAND_LOG" ;;' \
    'esac' >"$mock_bin/awww"
  chmod +x "$mock_bin/stow" "$mock_bin/pgrep" "$mock_bin/pkill" "$mock_bin/setsid" "$mock_bin/awww"

  HOME=$test_home \
    WAYLAND_DISPLAY=wayland-test \
    MIGRATION_COMMAND_LOG=$command_log \
    PATH="$mock_bin:$PATH" \
    "$root/scripts/configure-dotfiles.sh"

  [[ ! -L $test_home/.config/mako/config ]] || fail 'legacy managed Mako link survived migration'
  grep -qxF 'pkill -x mako' "$command_log" || fail 'running Mako was not stopped during migration'
  grep -qxF 'setsid uwsm-app -- swaync' "$command_log" || fail 'SwayNC was not started after stopping Mako'
  grep -qF 'awww img --resize crop --transition-type fade --transition-duration 0.7 --transition-fps 60 ' "$command_log" || \
    fail 'live upgrade did not apply a wallpaper through awww'
  awww_line=$(grep -nF 'awww img ' "$command_log" | cut -d: -f1)
  swaybg_stop_line=$(grep -nF 'pkill -x swaybg' "$command_log" | cut -d: -f1)
  [[ -n $awww_line && -n $swaybg_stop_line && $awww_line -lt $swaybg_stop_line ]] || \
    fail 'live upgrade stopped swaybg before awww displayed a wallpaper'
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

test_dotfile_setup_restarts_running_hypridle() (
  test_home="$test_root/hypridle-restart-home"
  mock_bin="$test_root/hypridle-restart-bin"
  command_log="$test_root/hypridle-restart-commands"
  stopped="$test_root/hypridle-stopped"
  mkdir -p "$test_home" "$mock_bin"

  printf '#!/bin/bash\nexit 0\n' >"$mock_bin/stow"
  cat >"$mock_bin/pgrep" <<'EOF'
#!/bin/bash
if [[ $1 == -x && $2 == hypridle && ! -e $HYPRIDLE_STOPPED ]]; then
  exit 0
fi
exit 1
EOF
  cat >"$mock_bin/pkill" <<'EOF'
#!/bin/bash
printf 'pkill %s\n' "$*" >>"$HYPRIDLE_RESTART_LOG"
[[ $1 == -x && $2 == hypridle ]] && touch "$HYPRIDLE_STOPPED"
EOF
  cat >"$mock_bin/setsid" <<'EOF'
#!/bin/bash
printf 'setsid %s\n' "$*" >>"$HYPRIDLE_RESTART_LOG"
EOF
  chmod +x "$mock_bin/stow" "$mock_bin/pgrep" "$mock_bin/pkill" "$mock_bin/setsid"

  HOME=$test_home \
    HYPRIDLE_STOPPED=$stopped \
    HYPRIDLE_RESTART_LOG=$command_log \
    PATH="$mock_bin:$PATH" \
    "$root/scripts/configure-dotfiles.sh"

  grep -qxF 'pkill -x hypridle' "$command_log" || fail 'upgrade did not stop the running Hypridle instance'
  grep -qxF 'setsid uwsm-app -- hypridle' "$command_log" || fail 'upgrade did not restart Hypridle with the new policy'
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
test_wallpaper_apply_recovers_daemon_and_preserves_fallback
test_wallpaper_select_previews_and_applies_safely
test_idle_suspend_is_laptop_only
test_idle_brightness_never_increases_and_restores
test_storage_status_reports_separate_filesystems_and_swap
test_power_profile_cycle_sets_next_profile_and_notifies
test_dotfile_setup_copies_wallpapers_and_backs_up_conflicts
test_dotfile_setup_migrates_running_mako_to_swaync
test_dotfile_setup_preserves_personal_mako_config
test_dotfile_setup_restarts_running_hypridle
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
