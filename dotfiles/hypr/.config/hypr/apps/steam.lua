-- Float Steam
hl.window_rule({
  match = { class = "steam", title = "Friends List" },
  float = true,
  size = "460 800",
})

hl.window_rule({
  match = { class = "steam.*" },
  tag = "-default-opacity",
  opacity = "1 1",
})

hl.window_rule({
  match = { class = "steam", title = "Steam" },
  fullscreen = true,
})

hl.window_rule({
  match = { class = "steam" },
  idle_inhibit = "fullscreen",
})
