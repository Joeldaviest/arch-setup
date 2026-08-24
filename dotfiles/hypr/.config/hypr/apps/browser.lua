-- Firefox browser windows
hl.window_rule({
  match = { class = "^[fF]irefox" },
  tag = "+firefox-browser",
})
hl.window_rule({
  match = { tag = "firefox-browser" },
  tag = "-default-opacity",
})

-- Only a subtle opacity change
hl.window_rule({
  match = { tag = "firefox-browser" },
  opacity = "1.0 0.985",
})

-- Hide the screen-sharing notification bar (the "Hide" button on it is broken on Wayland)
hl.window_rule({
  match = { title = ".*is sharing.*" },
  workspace = "special silent",
})
