-- Full opacity for the Windows VM RDP session; the global default-opacity
-- dimming would tint an entire remote desktop.
hl.window_rule({
  match = { class = "com.freerdp.freerdp" },
  tag = "-default-opacity",
  opacity = "1 1",
})

hl.window_rule({
  match = { class = "com.freerdp.freerdp" },
  idle_inhibit = "fullscreen",
})
