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
    [[ $1 == -Q && ( $2 == floorp-bin || $2 == chromium || $2 == mako || $2 == swaybg || $2 == mise ) ]]
  }
  sudo() {
    printf '%s\n' "$*" >>"$command_log"
  }
  yay() {
    printf 'yay %s\n' "$*" >>"$command_log"
    return 0
  }
  install_packages >/dev/null
  grep -qE '^pacman -Syu .* steam( |$)' "$command_log" || fail 'steam was omitted from the pacman install command'
  grep -qE '^pacman -Syu .* lib32-mesa( |$)' "$command_log" || fail 'lib32-mesa was omitted from the pacman install command'
  grep -qE '^pacman -Syu .* umu-launcher( |$)' "$command_log" || fail 'umu-launcher was omitted from the pacman install command'
  grep -qE '^pacman -Syu .* swaync( |$)' "$command_log" || fail 'SwayNC was omitted from the pacman install command'
  grep -qE '^pacman -Syu .* awww( |$)' "$command_log" || fail 'awww was omitted from the pacman install command'
  grep -qE '^pacman -Syu .* firefox( |$)' "$command_log" || fail 'Firefox was omitted from the pacman install command'
  obsolete_remove='pacman -Rns --noconfirm floorp-bin chromium mako swaybg mise'
  grep -qxF "$obsolete_remove" "$command_log" || fail 'obsolete managed packages and dependencies were not removed during upgrade'
  swaync_install_line=$(grep -nE '^pacman -Syu .* swaync( |$)' "$command_log" | cut -d: -f1)
  awww_install_line=$(grep -nE '^pacman -Syu .* awww( |$)' "$command_log" | cut -d: -f1)
  mako_remove_line=$(grep -nF "$obsolete_remove" "$command_log" | cut -d: -f1)
  [[ $swaync_install_line -lt $mako_remove_line ]] || fail 'Mako was removed before SwayNC was installed'
  [[ $awww_install_line -lt $mako_remove_line ]] || fail 'swaybg was removed before awww was installed'

  provider_line=$(grep -nE '^yay .* elephant-bin( |$)' "$command_log" | cut -d: -f1)
  walker_line=$(grep -nE '^yay .* walker-bin( |$)' "$command_log" | cut -d: -f1)
  [[ -n $provider_line && -n $walker_line && $provider_line -lt $walker_line ]] || \
    fail 'Elephant binary provider was not installed before Walker'
)

test_claude_code_uses_native_installer_once() (
  source "$root/scripts/lib/common.sh"
  source "$root/scripts/lib/packages.sh"
  HOME="$test_root/claude-home"

  curl() {
    [[ $1 == -fsSL && $2 == https://claude.ai/install.sh ]] || fail 'called an unexpected Claude Code installer URL'
    printf '%s\n' \
      '#!/bin/bash' \
      'mkdir -p "$HOME/.local/bin"' \
      'touch "$HOME/.local/bin/claude"' \
      'chmod +x "$HOME/.local/bin/claude"'
  }

  install_claude_code >/dev/null
  [[ -x $HOME/.local/bin/claude ]] || fail 'native Claude Code launcher was not installed'

  curl() {
    fail 'reran the Claude Code installer for an existing native installation'
  }
  install_claude_code >/dev/null
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

test_weather_status_uses_rich_cached_conditions() (
  test_home="$test_root/weather-home"
  mock_bin="$test_root/weather-bin"
  cache_dir="$test_root/weather-cache"
  fixture="$test_root/weather.json"
  curl_log="$test_root/weather-curl.log"
  mkdir -p "$test_home/.config/weather-status" "$mock_bin"
  printf 'Bengaluru\n' >"$test_home/.config/weather-status/location"
  printf 'Selected Bengaluru, India\n' >"$test_home/.config/weather-status/location-label"

  cat >"$fixture" <<'EOF'
{
  "current_condition": [{
    "temp_C": "27", "FeelsLikeC": "29", "humidity": "71",
    "weatherDesc": [{"value": "Partly cloudy"}], "winddir16Point": "SW",
    "windspeedKmph": "12", "visibility": "10", "uvIndex": "6"
  }],
  "nearest_area": [{
    "areaName": [{"value": "Bengaluru"}], "region": [{"value": "Karnataka"}]
  }],
  "weather": [
    {
      "mintempC": "21", "maxtempC": "31",
      "hourly": [{"chanceofrain": "20"}, {"chanceofrain": "35"}],
      "astronomy": [{"sunrise": "06:05 AM", "sunset": "06:42 PM"}]
    },
    {
      "mintempC": "22", "maxtempC": "30",
      "hourly": [{"chanceofrain": "45"}],
      "astronomy": [{"sunrise": "06:05 AM", "sunset": "06:41 PM"}]
    }
  ]
}
EOF

  cat >"$mock_bin/curl" <<'EOF'
#!/bin/bash
printf 'curl\n' >>"$WEATHER_CURL_LOG"
if [[ ${WEATHER_CURL_FAIL:-0} == 1 ]]; then
  exit 22
fi
cat "$WEATHER_FIXTURE"
EOF
  chmod +x "$mock_bin/curl"

  weather_json=$(HOME="$test_home" WEATHER_CACHE_DIR="$cache_dir" \
    WEATHER_FIXTURE="$fixture" WEATHER_CURL_LOG="$curl_log" \
    PATH="$mock_bin:$PATH" "$root/dotfiles/bin/.local/bin/weather-status" --json)
  jq -e '
    .text == "27°C" and .class == "normal" and
    (.tooltip | contains("Selected Bengaluru, India") and contains("Partly cloudy") and
      contains("feels like 29°C") and contains("Today 21–31°C") and
      contains("Tomorrow 22–30°C"))
  ' <<<"$weather_json" >/dev/null || fail 'weather-status did not build the compact rich Waybar output'

  detail=$(HOME="$test_home" WEATHER_CACHE_DIR="$cache_dir" \
    WEATHER_FIXTURE="$fixture" WEATHER_CURL_LOG="$curl_log" \
    PATH="$mock_bin:$PATH" "$root/dotfiles/bin/.local/bin/weather-status" --detail)
  [[ $detail == *'Weather · Selected Bengaluru, India'* && $detail == *'UV index     6'* && \
     $detail == *'Sunrise      06:05 AM'* ]] || fail 'weather-status detail view omitted forecast data'
  [[ $(wc -l <"$curl_log") == 1 ]] || fail 'weather-status ignored its fresh cache'

  stale_json=$(HOME="$test_home" WEATHER_CACHE_DIR="$cache_dir" WEATHER_CACHE_MAX_AGE=0 \
    WEATHER_CURL_FAIL=1 WEATHER_FIXTURE="$fixture" WEATHER_CURL_LOG="$curl_log" \
    PATH="$mock_bin:$PATH" "$root/dotfiles/bin/.local/bin/weather-status" --json)
  jq -e '.text == "27°C" and .class == "stale" and (.tooltip | contains("Cached conditions"))' \
    <<<"$stale_json" >/dev/null || fail 'weather-status did not retain stale cached conditions'

  empty_cache="$test_root/weather-empty-cache"
  unavailable=$(HOME="$test_home" WEATHER_CACHE_DIR="$empty_cache" WEATHER_CACHE_MAX_AGE=0 \
    WEATHER_CURL_FAIL=1 WEATHER_FIXTURE="$fixture" WEATHER_CURL_LOG="$curl_log" \
    PATH="$mock_bin:$PATH" "$root/dotfiles/bin/.local/bin/weather-status" --json)
  jq -e '.text == "--°C" and .class == "unavailable"' <<<"$unavailable" >/dev/null || \
    fail 'weather-status did not report an unavailable uncached forecast'
)

test_weather_location_searches_and_selects_coordinates() (
  test_home="$test_root/weather-location-home"
  mock_bin="$test_root/weather-location-bin"
  picker_log="$test_root/weather-location-picker.log"
  curl_log="$test_root/weather-location-curl.log"
  signal_log="$test_root/weather-location-signal.log"
  mkdir -p "$test_home" "$mock_bin"

  cat >"$mock_bin/walker" <<'EOF'
#!/bin/bash
printf '%s\n' "$*" >>"$WEATHER_PICKER_LOG"
cat >/dev/null
if [[ ${WEATHER_PICKER_MODE:-search} == automatic ]]; then
  printf 'Automatic location (IP)\n'
elif [[ " $* " == *' --inputonly '* ]]; then
  printf 'Kochi\n'
elif [[ $* == *'Choose weather location'* ]]; then
  printf 'Kochi, Kerala, India  ·  9.9312, 76.2673\n'
else
  printf 'Search for a city or postcode…\n'
fi
EOF
  cat >"$mock_bin/curl" <<'EOF'
#!/bin/bash
printf '%s\n' "$*" >>"$WEATHER_LOCATION_CURL_LOG"
cat <<'JSON'
{"results":[
  {"name":"Kochi","admin1":"Kerala","country":"India","latitude":9.9312,"longitude":76.2673},
  {"name":"Kochi","admin1":"Shikoku","country":"Japan","latitude":33.56,"longitude":133.53}
]}
JSON
EOF
  cat >"$mock_bin/notify-send" <<'EOF'
#!/bin/bash
exit 0
EOF
  cat >"$mock_bin/pkill" <<'EOF'
#!/bin/bash
printf '%s\n' "$*" >>"$WEATHER_SIGNAL_LOG"
EOF
  chmod +x "$mock_bin"/*

  HOME="$test_home" WEATHER_PICKER_COMMAND="$mock_bin/walker" \
    WEATHER_PICKER_LOG="$picker_log" WEATHER_LOCATION_CURL_LOG="$curl_log" \
    WEATHER_SIGNAL_LOG="$signal_log" PATH="$mock_bin:$PATH" \
    "$root/dotfiles/bin/.local/bin/weather-location"

  config_dir="$test_home/.config/weather-status"
  [[ $(<"$config_dir/location") == '~9.9312,76.2673' ]] || \
    fail 'weather-location did not save the selected coordinates'
  [[ $(<"$config_dir/location-label") == 'Kochi, Kerala, India' ]] || \
    fail 'weather-location did not save the selected display label'
  grep -qxF $'Kochi, Kerala, India\t9.9312\t76.2673' "$config_dir/recent-locations.tsv" || \
    fail 'weather-location did not remember the selected location'
  [[ $(wc -l <"$picker_log") == 3 ]] || fail 'weather-location did not run its three picker stages'
  grep -qF 'name=Kochi' "$curl_log" || fail 'weather-location did not search for the entered city'
  grep -qxF -- '-RTMIN+8 -x waybar' "$signal_log" || fail 'weather-location did not refresh Waybar'

  HOME="$test_home" WEATHER_PICKER_COMMAND="$mock_bin/walker" WEATHER_PICKER_MODE=automatic \
    WEATHER_PICKER_LOG="$picker_log" WEATHER_SIGNAL_LOG="$signal_log" PATH="$mock_bin:$PATH" \
    "$root/dotfiles/bin/.local/bin/weather-location"
  [[ ! -e $config_dir/location && ! -e $config_dir/location-label ]] || \
    fail 'weather-location did not restore automatic IP detection'
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

test_desktop_power_lock_uses_independent_scope() (
  mock_bin="$test_root/power-lock-bin"
  command_log="$test_root/power-lock-commands"
  mkdir -p "$mock_bin"
  cat >"$mock_bin/pgrep" <<'EOF'
#!/bin/bash
exit 1
EOF
  cat >"$mock_bin/setsid" <<'EOF'
#!/bin/bash
printf '%s\n' "$*" >>"$POWER_LOCK_LOG"
EOF
  cat >"$mock_bin/hyprctl" <<'EOF'
#!/bin/bash
exit 0
EOF
  chmod +x "$mock_bin/pgrep" "$mock_bin/setsid" "$mock_bin/hyprctl"

  POWER_LOCK_LOG="$command_log" PATH="$mock_bin:$PATH" \
    "$root/dotfiles/bin/.local/bin/desktop-power" lock-only

  [[ $(<"$command_log") == '-f uwsm-app -- hyprlock' ]] || \
    fail 'desktop power lock did not launch hyprlock in an independent UWSM scope'
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

test_tmux_new_session_names_from_current_directory() (
  mock_bin="$test_root/tmux-session-bin"
  command_log="$test_root/tmux-session-commands"
  mkdir -p "$mock_bin"
  cat >"$mock_bin/tmux" <<'EOF'
#!/bin/bash
case $1 in
  display-message) printf '%s\n' '/work/arch.setup' ;;
  has-session) [[ ${@: -1} == '=arch-setup' ]] ;;
  new-session|switch-client) printf '%s\n' "$*" >>"$TMUX_SESSION_LOG" ;;
  *) exit 2 ;;
esac
EOF
  chmod +x "$mock_bin/tmux"

  TMUX_PANE='%7' TMUX_SESSION_LOG="$command_log" PATH="$mock_bin:$PATH" \
    "$root/dotfiles/bin/.local/bin/tmux-new-session"

  grep -qxF 'new-session -d -s arch-setup-2 -c /work/arch.setup' "$command_log" || \
    fail 'tmux-new-session did not derive a unique name from the current directory'
  grep -qxF 'switch-client -t arch-setup-2' "$command_log" || \
    fail 'tmux-new-session did not switch to the new session'
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
test_claude_code_uses_native_installer_once
test_wallpaper_start
test_wallpaper_apply_recovers_daemon_and_preserves_fallback
test_wallpaper_select_previews_and_applies_safely
test_weather_status_uses_rich_cached_conditions
test_weather_location_searches_and_selects_coordinates
test_idle_suspend_is_laptop_only
test_desktop_power_lock_uses_independent_scope
test_idle_brightness_never_increases_and_restores
test_storage_status_reports_separate_filesystems_and_swap
test_tmux_new_session_names_from_current_directory
test_power_profile_cycle_sets_next_profile_and_notifies
test_dotfile_setup_copies_wallpapers_and_backs_up_conflicts
test_dotfile_setup_migrates_running_mako_to_swaync
test_dotfile_setup_preserves_personal_mako_config
test_dotfile_setup_restarts_running_hypridle
test_desktop_firmware_check_refreshes_then_lists_updates
test_desktop_firmware_rejects_unknown_action
test_windows_vm_render_writes_loopback_compose
test_windows_vm_render_omits_usb_by_default
test_windows_vm_render_includes_configured_usb
test_windows_vm_rejects_unknown_subcommand

echo 'Behavior checks passed'
