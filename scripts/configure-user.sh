#!/bin/bash

set -Eeuo pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)/scripts/lib/common.sh"

xdg-user-dirs-update
mkdir -p "$HOME/Pictures" "$HOME/Videos" "$HOME/.local/share/applications"

note "Starting Navidrome"
mkdir -p "$HOME/.local/share/navidrome" "$HOME/Music"
install -Dm644 "$SETUP_ROOT/docker/navidrome/docker-compose.yaml" "$HOME/.local/share/navidrome/docker-compose.yaml"
sudo -E docker compose -f "$HOME/.local/share/navidrome/docker-compose.yaml" up -d

note "Removing legacy Floorp web apps"
app_dir="$HOME/.local/share/applications"
for id in whatsapp google-maps youtube github personal-gmail navidrome work-gmail work-github; do
  rm -f -- "$app_dir/floorp-$id.desktop"
done
for icon in WhatsApp.png 'Google Maps.png' YouTube.png GitHub.png Gmail.png; do
  rm -f -- "$app_dir/icons/$icon"
done

if pgrep -x floorp >/dev/null 2>&1; then
  note "Floorp is running; quit it and re-run setup to remove legacy SSB records"
else
  managed_ids='["whatsapp","google-maps","youtube","github","personal-gmail","navidrome","work-gmail","work-github"]'
  for profile_root in "$HOME/.floorp" "${XDG_CONFIG_HOME:-$HOME/.config}/floorp"; do
    [[ -d $profile_root ]] || continue
    while IFS= read -r -d '' ssb_json; do
      jq --argjson managed "$managed_ids" \
        'to_entries | map(select(.value.id as $id | ($managed | index($id) | not))) | from_entries' \
        "$ssb_json" >"$ssb_json.tmp"
      mv "$ssb_json.tmp" "$ssb_json"
    done < <(find "$profile_root" -type f -path '*/ssb/ssb.json' -print0)
    while IFS= read -r -d '' prefs_js; do
      sed -i '/^user_pref("floorp\.workspaces\.enabled",/d;/^user_pref("floorp\.workspaces\.v4\.store",/d' "$prefs_js"
    done < <(find "$profile_root" -type f -name prefs.js -print0)
  done
fi

note "Installing Navidrome launcher"
navidrome_icon="$app_dir/icons/Navidrome.png"
install -Dm644 "$SETUP_ROOT/assets/icons/Navidrome.png" "$navidrome_icon"
{
  printf '%s\n' '[Desktop Entry]' 'Version=1.0' 'Type=Application' 'Name=Navidrome' 'Comment=Navidrome'
  printf '%s\n' 'Exec=floorp --new-tab http://127.0.0.1:4533/' "Icon=$navidrome_icon"
  printf '%s\n' 'Terminal=false' 'Categories=AudioVideo;Audio;Network;' 'StartupNotify=true'
} >"$app_dir/floorp-navidrome.desktop"
chmod 0755 "$app_dir/floorp-navidrome.desktop"

note "Configuring MIME defaults"
xdg-mime default org.gnome.Nautilus.desktop inode/directory
for mime in image/png image/jpeg image/gif image/webp image/bmp image/tiff; do
  xdg-mime default imv.desktop "$mime"
done
xdg-mime default com.github.xournalpp.xournalpp.desktop application/pdf
xdg-settings set default-web-browser floorp.desktop
xdg-mime default floorp.desktop x-scheme-handler/http
xdg-mime default floorp.desktop x-scheme-handler/https
xdg-mime default floorp.desktop x-scheme-handler/mailto
for mime in text/plain text/x-makefile text/x-c++hdr text/x-c++src text/x-chdr text/x-csrc application/x-shellscript application/xml text/xml; do
  xdg-mime default codium.desktop "$mime"
done
for mime in video/mp4 video/x-msvideo video/x-matroska video/webm video/quicktime audio/mpeg audio/ogg; do
  xdg-mime default mpv.desktop "$mime"
done

systemctl --user enable swayosd-server.service 2>/dev/null || true

# elephant has no packaged systemd unit; its own CLI generates
# ~/.config/systemd/user/elephant.service on first run.
elephant service enable
# Restarting also makes an existing installation discover newly stowed menus.
systemctl --user restart elephant.service

if [[ $(getent passwd "$USER" | cut -d: -f7) != "/bin/zsh" ]]; then
  sudo chsh -s /bin/zsh "$USER"
fi

update-desktop-database "$HOME/.local/share/applications"
