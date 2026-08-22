-- Floorp browser windows
hl.window_rule({
  match = { class = "^[fF]loorp" },
  tag = "+floorp-browser",
})
hl.window_rule({
  match = { tag = "floorp-browser" },
  tag = "-default-opacity",
})

-- Only a subtle opacity change
hl.window_rule({
  match = { tag = "floorp-browser" },
  opacity = "1.0 0.985",
})

-- Hide the screen-sharing notification bar (the "Hide" button on it is broken on Wayland)
hl.window_rule({
  match = { title = ".*is sharing.*" },
  workspace = "special silent",
})
