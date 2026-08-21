-- Portable Hyprland configuration
require("./environment.lua")
require("./looknfeel.lua")
require("./input.lua")
require("./windows.lua")
require("./media.lua")
require("./clipboard.lua")
require("./tiling.lua")
require("./bindings.lua")
require("./autostart.lua")

-- Safe fallback for every output; machine-specific monitor rules below can override it.
hl.monitor({
  output = "",
  mode = "preferred",
  position = "auto",
  scale = 1.0,
})

-- Per-machine, untracked overrides
local function requireLocal(name)
  local ok, err = pcall(require, "./local/" .. name .. ".lua")
  if not ok then
    print("arch-setup: skipping local/" .. name .. ".lua (" .. tostring(err) .. ")")
  end
end

requireLocal("monitors")
requireLocal("input")
requireLocal("environment")
requireLocal("autostart")

-- Application workspace assignments
hl.window_rule({ match = { class = "^Alacritty$" }, workspace = "1 silent" })
hl.window_rule({ match = { class = "^[fF]loorp" }, workspace = "2 silent" })
hl.window_rule({ match = { class = "^(codium|VSCodium)$" }, workspace = "3 silent" })
hl.window_rule({ match = { class = "^steam$" }, workspace = "4 silent" })
hl.window_rule({ match = { class = "^(Lutris|lutris)$" }, workspace = "5 silent" })
