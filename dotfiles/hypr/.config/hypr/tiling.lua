-- Control tiling
hl.bind("SUPER + F", hl.dsp.window.fullscreen({ mode = "fullscreen" }), { description = "Full screen" })
hl.bind("SUPER + O", hl.dsp.exec_cmd("window-pop"), { description = "Pop window out (float & pin)" })

-- Switch workspaces with SUPER + [1-9; 0]
-- Move active window to a workspace with SUPER + SHIFT + [1-9; 0]
-- Move active window silently (stay on current workspace) with SUPER + SHIFT + ALT + [1-9; 0]
for i = 1, 10 do
  local key = i % 10 -- 10 maps to key 0
  local keycode = "code:" .. (9 + i) -- code:10 .. code:19, matching the previous hyprlang binds

  hl.bind("SUPER + " .. keycode, hl.dsp.focus({ workspace = i }), { description = "Switch to workspace " .. key })
  hl.bind("SUPER + SHIFT + " .. keycode, hl.dsp.window.move({ workspace = i }), { description = "Move window to workspace " .. key })
  hl.bind(
    "SUPER + SHIFT + ALT + " .. keycode,
    hl.dsp.window.move({ workspace = i, follow = false }),
    { description = "Move window silently to workspace " .. key }
  )
end

-- Scroll through existing workspaces with SUPER + scroll
hl.bind("SUPER + mouse_down", hl.dsp.focus({ workspace = "e+1" }), { description = "Scroll active workspace forward" })
hl.bind("SUPER + mouse_up", hl.dsp.focus({ workspace = "e-1" }), { description = "Scroll active workspace backward" })

-- Move/resize windows with mainMod + LMB/RMB and dragging
hl.bind("SUPER + mouse:272", hl.dsp.window.drag(), { mouse = true, description = "Move window" })
hl.bind("SUPER + mouse:273", hl.dsp.window.resize(), { mouse = true, description = "Resize window" })

-- Cycle monitor scaling with SUPER + -/=
hl.bind("SUPER + MINUS", hl.dsp.exec_cmd("monitor-scale --reverse"), { description = "Cycle monitor scaling backwards" })
hl.bind("SUPER + EQUAL", hl.dsp.exec_cmd("monitor-scale"), { description = "Cycle monitor scaling" })
