#!/bin/bash

set -Eeuo pipefail
exec_command=${WEBAPP_EXEC:-webapp-launch "$WEBAPP_URL"}
printf '%s\n' \
  '[Desktop Entry]' \
  'Version=1.0' \
  "Name=$WEBAPP_NAME" \
  "Comment=Open $WEBAPP_NAME in Chromium" \
  "Exec=$exec_command" \
  'Terminal=false' \
  'Type=Application' \
  "Icon=$WEBAPP_ICON" \
  'StartupNotify=true'
[[ $WEBAPP_NAME == "Gmail" ]] && printf '%s\n' 'MimeType=x-scheme-handler/mailto;'
