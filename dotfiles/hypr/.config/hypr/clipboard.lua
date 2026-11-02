-- Copy / Paste
-- Alacritty handles SUPER + C/V itself (alacritty.toml). A synthetic Insert sent to
-- it can get stuck pressed and auto-repeat ^[[2~, so the bind lets the key through.
local function is_alacritty(window)
  local file = window and io.open("/proc/" .. window.pid .. "/comm")
  if not file then return false end
  local comm = file:read("l")
  file:close()
  return comm == "alacritty"
end

local function universal(mods, key)
  local shortcut = hl.dsp.send_shortcut({ mods = mods, key = key, window = "activewindow" })
  return function()
    if not is_alacritty(hl.get_active_window()) then hl.dispatch(shortcut) end
  end
end

hl.bind("SUPER + C", universal("CTRL", "Insert"), { non_consuming = true, description = "Universal copy" })
hl.bind("SUPER + V", universal("SHIFT", "Insert"), { non_consuming = true, description = "Universal paste" })
hl.bind("SUPER + X", hl.dsp.send_shortcut({ mods = "CTRL", key = "X", window = "activewindow" }), { description = "Universal cut" })
hl.bind("SUPER + ALT + V", hl.dsp.exec_cmd("desktop-launcher -m clipboard"), { description = "Clipboard manager" })
