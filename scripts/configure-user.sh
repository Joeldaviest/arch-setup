#!/bin/bash

set -Eeuo pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)/scripts/lib/common.sh"

xdg-user-dirs-update
mkdir -p "$HOME/Pictures" "$HOME/Videos" "$HOME/.local/share/applications"

note "Starting Navidrome"
mkdir -p "$HOME/.local/share/navidrome" "$HOME/Music"
install -Dm644 "$SETUP_ROOT/docker/navidrome/docker-compose.yaml" "$HOME/.local/share/navidrome/docker-compose.yaml"
sudo -E docker compose -f "$HOME/.local/share/navidrome/docker-compose.yaml" up -d

note "Configuring MIME defaults"
xdg-mime default org.gnome.Nautilus.desktop inode/directory
for mime in image/png image/jpeg image/gif image/webp image/bmp image/tiff; do
  xdg-mime default imv.desktop "$mime"
done
xdg-mime default com.github.xournalpp.xournalpp.desktop application/pdf
xdg-settings set default-web-browser chromium.desktop
xdg-mime default chromium.desktop x-scheme-handler/http
xdg-mime default chromium.desktop x-scheme-handler/https
xdg-mime default Gmail.desktop x-scheme-handler/mailto
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
systemctl --user start elephant.service

if [[ $(getent passwd "$USER" | cut -d: -f7) != "/bin/zsh" ]]; then
  sudo chsh -s /bin/zsh "$USER"
fi

update-desktop-database "$HOME/.local/share/applications"

