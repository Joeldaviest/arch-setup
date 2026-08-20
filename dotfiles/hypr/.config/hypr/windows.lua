-- See https://wiki.hypr.land/Configuring/Basics/Window-Rules/ for more

-- Ignore maximize requests from all apps. You'll probably like this.
hl.window_rule({
  match = { class = ".*" },
  suppress_event = "maximize",
})

-- Tag all windows for default opacity (apps can override with -default-opacity tag)
hl.window_rule({
  match = { class = ".*" },
  tag = "+default-opacity",
})

-- Fix some dragging issues with XWayland
hl.window_rule({
  match = {
    class = "^$",
    title = "^$",
    xwayland = true,
    float = true,
    fullscreen = false,
    pin = false,
  },
  no_focus = true,
})

-- Workspaces 2 (browser) and 3 (editor) default to tabbed groups
hl.window_rule({
  match = { workspace = "2" },
  group = "set",
})
hl.window_rule({
  match = { workspace = "3" },
  group = "set",
})

-- App-specific tweaks (may remove default-opacity tag)
require("./apps/*.lua")

-- Apply default opacity after apps have had a chance to opt out
hl.window_rule({
  match = { tag = "default-opacity" },
  opacity = "0.985 0.96",
})
