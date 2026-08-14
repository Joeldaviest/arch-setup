#!/bin/bash

set -Eeuo pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)/scripts/lib/common.sh"

install_app() {
  local name=$1 url=$2 icon=$3 exec_command=${4:-}
  local app_dir="$HOME/.local/share/applications"
  mkdir -p "$app_dir/icons"
  install -m644 "$SETUP_ROOT/assets/icons/$icon" "$app_dir/icons/$icon"
  WEBAPP_NAME=$name WEBAPP_URL=$url WEBAPP_ICON="$app_dir/icons/$icon" WEBAPP_EXEC=$exec_command \
    "$SETUP_ROOT/scripts/render-webapp.sh" >"$app_dir/$name.desktop"
  chmod 0755 "$app_dir/$name.desktop"
}

note "Installing Chromium web applications"
install_app WhatsApp 'https://web.whatsapp.com/' WhatsApp.png
install_app 'Google Maps' 'https://maps.google.com/' 'Google Maps.png'
install_app YouTube 'https://youtube.com/' YouTube.png
install_app GitHub 'https://github.com/' GitHub.png
install_app Gmail 'https://mail.google.com/' Gmail.png 'gmail-handler %u'

