hl.window_rule({
  match = { class = "TUI\\.float|org.gnome.NautilusPreviewer|com.gabm.satty|Omarchy|About|imv|mpv" },
  tag = "+floating-window",
})

-- These are terminal-hosted TUIs launched with an explicit character-grid
-- size (see tui-launch --size and the desktop-* scripts), so the terminal
-- itself computes the right pixel size for the current font/monitor scale.
-- Only float + center them here; no `size`, or we'd fight that computation.
hl.window_rule({
  match = { class = "^TUI\\.(bluetooth|wifi|audio|power|reminder|btop)$" },
  float = true,
  center = true,
})

hl.window_rule({
  match = {
    class = "xdg-desktop-portal-gtk|sublime_text|DesktopEditors|org.gnome.Nautilus",
    title = "^(Open.*Files?|Open [F|f]older.*|Save.*Files?|Save.*As|Save|All Files|.*wants to [open|save].*|[C|c]hoose.*)",
  },
  tag = "+floating-window",
})

-- Fullscreen screensaver (leftover from the omarchy base; no screensaver app is
-- installed by this repo, so this rule currently matches nothing)
hl.window_rule({
  match = { class = "org.omarchy.screensaver" },
  fullscreen = true,
  float = true,
  animation = "slide",
})

-- No transparency on media windows
hl.window_rule({
  match = { class = "^(mpv|imv|org.gnome.NautilusPreviewer)$" },
  tag = "-default-opacity",
  opacity = "1 1",
})

-- Popped window rounding
hl.window_rule({
  match = { tag = "pop" },
  rounding = 8,
})

-- Prevent idle while open
hl.window_rule({
  match = { tag = "noidle" },
  idle_inhibit = "always",
})
