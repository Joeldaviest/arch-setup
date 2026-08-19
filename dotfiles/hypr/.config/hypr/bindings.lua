-- Application bindings
hl.bind("SUPER + SHIFT + F", hl.dsp.exec_cmd("uwsm-app -- nautilus --new-window"), { description = "File manager" })
hl.bind("SUPER + SHIFT + M", hl.dsp.exec_cmd('webapp-focus Navidrome "http://127.0.0.1:4533/"'), { description = "Music" })
hl.bind("SUPER + SHIFT + N", hl.dsp.exec_cmd("desktop-editor"), { description = "VSCodium" })
hl.bind("SUPER + SHIFT + D", hl.dsp.exec_cmd("tui-launch lazydocker"), { description = "Docker" })
hl.bind("SUPER + SHIFT + SLASH", hl.dsp.exec_cmd("uwsm-app -- bitwarden"), { description = "Passwords" })

hl.bind("SUPER + SHIFT + Y", hl.dsp.exec_cmd('webapp-launch "https://youtube.com/"'), { description = "YouTube" })
hl.bind("SUPER + SHIFT + ALT + G", hl.dsp.exec_cmd('webapp-focus WhatsApp "https://web.whatsapp.com/"'), { description = "WhatsApp" })

hl.bind(
  "SUPER + T",
  hl.dsp.exec_cmd('uwsm-app -- xdg-terminal-exec --dir="$(terminal-cwd)" bash -c "tmux attach || tmux new -s Work"'),
  { description = "Tmux" }
)
hl.bind("SUPER + SHIFT + T", hl.dsp.exec_cmd('uwsm-app -- xdg-terminal-exec --dir="$(terminal-cwd)"'), { description = "Alacritty" })
hl.bind("SUPER + G", hl.dsp.exec_cmd("desktop-browser"), { description = "Chromium" })
hl.bind("SUPER + Q", hl.dsp.window.close(), { description = "Close window" })
hl.bind("SUPER + P", hl.dsp.exec_cmd("desktop-launcher"), { description = "Launch apps" })
hl.bind("SUPER + H", hl.dsp.focus({ direction = "left" }), { description = "Focus left" })
hl.bind("SUPER + J", hl.dsp.focus({ direction = "down" }), { description = "Focus down" })
hl.bind("SUPER + L", hl.dsp.focus({ direction = "right" }), { description = "Focus right" })
hl.bind("SUPER + K", hl.dsp.focus({ direction = "up" }), { description = "Focus up" })
hl.bind("SUPER + SHIFT + H", hl.dsp.window.swap({ direction = "left" }), { description = "Move window left" })
hl.bind("SUPER + SHIFT + J", hl.dsp.window.swap({ direction = "down" }), { description = "Move window down" })
hl.bind("SUPER + SHIFT + K", hl.dsp.window.swap({ direction = "up" }), { description = "Move window up" })
hl.bind("SUPER + SHIFT + L", hl.dsp.window.swap({ direction = "right" }), { description = "Move window right" })
hl.bind("SUPER + SHIFT + S", hl.dsp.exec_cmd("desktop-screenshot"), { description = "Screenshot" })
hl.bind("SUPER + SHIFT + SPACE", hl.dsp.window.float(), { description = "Toggle window floating/tiling" })
hl.bind("SUPER + SHIFT + C", hl.dsp.exec_cmd("hyprctl reload"), { description = "Reload Hyprland" })
hl.bind("SUPER + SHIFT + E", hl.dsp.exec_cmd("uwsm-app -- alacritty --class TUI.power -o window.dimensions.columns=50 -o window.dimensions.lines=14 -e desktop-power menu"), { description = "System menu" })
hl.bind("SUPER + ESCAPE", hl.dsp.exec_cmd("desktop-power lock"), { description = "Lock system" })

-- Standalone desktop utilities
hl.bind("SUPER + ALT + S", hl.dsp.exec_cmd("desktop-screenrecord"), { description = "Screen recording" })
hl.bind("SUPER + W", hl.dsp.exec_cmd("wallpaper-select"), { description = "Select wallpaper" })
hl.bind("SUPER + ALT + R", hl.dsp.exec_cmd("reminder show"), { description = "Show reminders" })
hl.bind("SUPER + SHIFT + R", hl.dsp.exec_cmd("uwsm-app -- alacritty --class TUI.reminder -o window.dimensions.columns=50 -o window.dimensions.lines=8 -e reminder-set"), { description = "Set reminder" })
hl.bind("SUPER + SHIFT + CTRL + R", hl.dsp.exec_cmd("reminder clear"), { description = "Clear reminders" })
hl.bind("SUPER + SHIFT + A", hl.dsp.exec_cmd("desktop-audio"), { description = "Audio controls" })
hl.bind("SUPER + SHIFT + B", hl.dsp.exec_cmd("desktop-bluetooth"), { description = "Bluetooth controls" })
hl.bind("SUPER + SHIFT + W", hl.dsp.exec_cmd("desktop-wifi"), { description = "Wi-Fi controls" })
hl.bind("XF86PowerOff", hl.dsp.exec_cmd("desktop-power menu"), { locked = true, description = "Power menu" })

-- Relocated Omarchy functions that conflict with the i3 mappings
hl.bind("SUPER + E", hl.dsp.group.toggle(), { description = "Toggle tabs/tiling" })
hl.bind("SUPER + ALT + K", hl.dsp.exec_cmd("keybindings"), { description = "Show key bindings" })

-- Function row media controls from the previous i3 configuration
hl.bind("F1", hl.dsp.exec_cmd("desktop-osd --output-volume mute-toggle"), { locked = true, repeating = true, description = "Mute" })
hl.bind("F2", hl.dsp.exec_cmd("desktop-osd --output-volume lower"), { locked = true, repeating = true, description = "Volume down" })
hl.bind("F3", hl.dsp.exec_cmd("desktop-osd --output-volume raise"), { locked = true, repeating = true, description = "Volume up" })
hl.bind("F4", hl.dsp.exec_cmd("audio-input-mute"), { locked = true, repeating = true, description = "Mute microphone" })
hl.bind("F5", hl.dsp.exec_cmd("display-brightness 5%-"), { locked = true, repeating = true, description = "Brightness down" })
hl.bind("F6", hl.dsp.exec_cmd("display-brightness +5%"), { locked = true, repeating = true, description = "Brightness up" })

-- i3-style resize submap
hl.bind("SUPER + R", hl.dsp.submap("resize"), { description = "Resize mode" })
hl.define_submap("resize", function()
  hl.bind("LEFT", hl.dsp.window.resize({ x = -10, y = 0, relative = true }), { repeating = true, description = "Shrink width" })
  hl.bind("DOWN", hl.dsp.window.resize({ x = 0, y = 10, relative = true }), { repeating = true, description = "Grow height" })
  hl.bind("UP", hl.dsp.window.resize({ x = 0, y = -10, relative = true }), { repeating = true, description = "Shrink height" })
  hl.bind("RIGHT", hl.dsp.window.resize({ x = 10, y = 0, relative = true }), { repeating = true, description = "Grow width" })
  hl.bind("RETURN", hl.dsp.submap("reset"))
  hl.bind("ESCAPE", hl.dsp.submap("reset"))
  hl.bind("SUPER + R", hl.dsp.submap("reset"))
end)

-- Add extra bindings
-- hl.bind("SUPER + SHIFT + R", hl.dsp.exec_cmd("alacritty -e ssh your-server"))

-- Add other local bindings in ~/.config/hypr/local/input.lua or autostart.lua.

-- Logitech MX Keys
-- hl.bind("SUPER + SHIFT + S", hl.dsp.exec_cmd("desktop-screenshot"))      -- Print Screen Button
-- hl.bind("SUPER + PERIOD", hl.dsp.exec_cmd("desktop-launcher -m symbols")) -- Emoji Button
