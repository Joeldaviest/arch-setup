#!/bin/bash
#
# Not run by setup.sh. Run by hand, after launching Floorp, signing into
# Firefox Sync, letting the "Work" container land, and quitting Floorp
# (Floorp rewrites prefs.js on quit and would clobber concurrent edits).

set -Eeuo pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)/scripts/lib/common.sh"

command_exists jq || die "jq is required"
pgrep -x floorp >/dev/null 2>&1 && die "Quit Floorp before running this script"

profile_root="$HOME/.floorp"
[[ -d $profile_root ]] || profile_root="${XDG_CONFIG_HOME:-$HOME/.config}/floorp"
[[ -d $profile_root ]] || die "No Floorp profile found under ~/.floorp or ~/.config/floorp. Launch Floorp and sign in first."

profiles_ini="$profile_root/profiles.ini"
[[ -f $profiles_ini ]] || die "Missing $profiles_ini"
profile_path=$(awk -F= '/^Path=/{print $2; exit}' "$profiles_ini")
[[ -n $profile_path ]] || die "Could not resolve the Floorp profile path from $profiles_ini"
[[ $profile_path == /* ]] || profile_path="$profile_root/$profile_path"
[[ -d $profile_path ]] || die "Floorp profile directory does not exist: $profile_path"

containers_json="$profile_path/containers.json"
[[ -f $containers_json ]] || die "Missing $containers_json — sign into Firefox Sync and let containers land first"
work_id=$(jq -r '.identities[] | select(.name=="Work" and .public==true) | .userContextId' "$containers_json")
[[ -n $work_id ]] || die "No 'Work' container found in $containers_json — sign into Firefox Sync and wait for containers to sync"

note "Using Floorp profile: $profile_path"
note "Work container userContextId: $work_id"

prefs_js="$profile_path/prefs.js"
[[ -f $prefs_js ]] || die "Missing $prefs_js"

set_pref() {
  local key=$1 value=$2
  grep -qF "user_pref(\"$key\"," "$prefs_js" && return
  printf 'user_pref("%s", %s);\n' "$key" "$value" >>"$prefs_js"
}

note "Seeding Workspaces"
personal_ws_id="11111111-1111-4111-8111-111111111111"
work_ws_id="22222222-2222-4222-8222-222222222222"
workspaces_store=$(jq -nc \
  --arg personal_id "$personal_ws_id" \
  --arg work_ws_id "$work_ws_id" \
  --argjson work_context "$work_id" \
  '{
    defaultID: $personal_id,
    data: [
      [$personal_id, {name: "Personal", userContextId: 0, isSelected: true, isDefault: true}],
      [$work_ws_id, {name: "Work", userContextId: $work_context, isSelected: null, isDefault: null}]
    ],
    order: [$personal_id, $work_ws_id]
  }')
set_pref "floorp.workspaces.enabled" "true"
set_pref "floorp.workspaces.v4.store" "$(jq -R . <<<"$workspaces_store")"

note "Seeding webapp (SSB) records"
ssb_dir="$profile_path/ssb"
mkdir -p "$ssb_dir"
ssb_json="$ssb_dir/ssb.json"
[[ -f $ssb_json ]] || echo '{}' >"$ssb_json"

app_dir="$HOME/.local/share/applications"
icon_dir="$app_dir/icons"
mkdir -p "$icon_dir"

install_webapp() {
  local id=$1 name=$2 start_url=$3 icon_file=$4 context=${5:-0}
  install -m644 "$SETUP_ROOT/assets/icons/$icon_file" "$icon_dir/$icon_file"
  local icon_dest="$icon_dir/$icon_file"

  local key="${start_url}:${context}"
  local record
  record=$(jq -nc --arg id "$id" --arg name "$name" --arg start_url "$start_url" \
    --arg icon "$icon_dest" --argjson context "$context" \
    '{id: $id, name: $name, start_url: $start_url, icon: $icon, userContextId: $context}')
  jq --arg key "$key" --argjson record "$record" '.[$key] = $record' "$ssb_json" >"$ssb_json.tmp"
  mv "$ssb_json.tmp" "$ssb_json"

  local desktop="$app_dir/floorp-$id.desktop"
  local exec_cmd
  exec_cmd=$(printf '%q ' floorp --name "floorp-$id" --profile "$profile_path" --start-ssb "$id")
  {
    printf '%s\n' '[Desktop Entry]' 'Version=1.0' 'Type=Application' "Name=$name" "Comment=$name"
    printf 'Exec=%s\n' "$exec_cmd"
    printf 'Icon=%s\n' "$icon_dest"
    printf '%s\n' 'Terminal=false' 'Categories=Network;WebBrowser;' 'StartupNotify=true' \
      "StartupWMClass=floorp-$id" 'X-MultipleArgs=false' "X-Floorp-StartUrl=$start_url" "X-Floorp-Id=$id"
    [[ $name == "Gmail" ]] && printf '%s\n' 'MimeType=x-scheme-handler/mailto;'
  } >"$desktop"
  chmod 0755 "$desktop"
}

install_webapp whatsapp WhatsApp 'https://web.whatsapp.com/' WhatsApp.png
install_webapp google-maps 'Google Maps' 'https://maps.google.com/' 'Google Maps.png'
install_webapp youtube YouTube 'https://youtube.com/' YouTube.png
install_webapp github GitHub 'https://github.com/' GitHub.png
install_webapp personal-gmail Gmail 'https://mail.google.com/' Gmail.png
install_webapp navidrome Navidrome 'http://127.0.0.1:4533/' Navidrome.png
install_webapp work-gmail 'Work Gmail' 'https://mail.google.com/' Gmail.png "$work_id"
install_webapp work-github 'Work GitHub' 'https://github.com/' GitHub.png "$work_id"

update-desktop-database "$app_dir"

success "Floorp configured: Workspaces seeded, 8 webapps installed"
