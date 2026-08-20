-- Browser types
--
-- Floorp's PWA windows don't get distinct per-site Wayland classes (verified:
-- --name/StartupWMClass doesn't reach the live app_id under native Wayland,
-- see https://github.com/Floorp-Projects/Floorp/issues/2649), so every
-- Floorp window — the main browser and every installed webapp — shares one
-- generic class. The video-app exemption below matches by title instead,
-- since titles differ by site (only collide across containers for the same
-- site).
hl.window_rule({
  match = { class = "^[fF]loorp" },
  tag = "+floorp-browser",
})
hl.window_rule({
  match = { tag = "floorp-browser" },
  tag = "-default-opacity",
})

-- Video apps: remove the floorp-browser tag so they don't get opacity applied
hl.window_rule({
  match = { title = "^YouTube" },
  tag = "-floorp-browser",
})
hl.window_rule({
  match = { title = "^YouTube" },
  tag = "-default-opacity",
})

-- Force floorp windows into a tile to deal with the same --app-style bug
-- Chromium had; re-verify whether Floorp still needs this.
hl.window_rule({
  match = { tag = "floorp-browser" },
  tile = true,
})

-- Only a subtle opacity change, but not for video sites
hl.window_rule({
  match = { tag = "floorp-browser" },
  opacity = "1.0 0.985",
})

-- Hide the screen-sharing notification bar (the "Hide" button on it is broken on Wayland)
hl.window_rule({
  match = { title = ".*is sharing.*" },
  workspace = "special silent",
})
