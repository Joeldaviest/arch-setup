-- Disable mouse focus so IDE popups do not unexpectedly steal keyboard focus.
hl.window_rule({
  name = "jetbrains-focus",
  match = { class = "^(jetbrains-.*)$" },
  no_follow_mouse = true,
})
