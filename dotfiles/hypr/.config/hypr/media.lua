-- Laptop multimedia keys for volume and LCD brightness (with OSD)
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("desktop-osd --output-volume raise"), { locked = true, repeating = true, description = "Volume up" })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("desktop-osd --output-volume lower"), { locked = true, repeating = true, description = "Volume down" })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("desktop-osd --output-volume mute-toggle"), { locked = true, repeating = true, description = "Mute" })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("audio-input-mute"), { locked = true, repeating = true, description = "Mute microphone" })
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("display-brightness +5%"), { locked = true, repeating = true, description = "Brightness up" })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("display-brightness 5%-"), { locked = true, repeating = true, description = "Brightness down" })
hl.bind("SHIFT + XF86MonBrightnessUp", hl.dsp.exec_cmd("display-brightness 100%"), { locked = true, repeating = true, description = "Brightness maximum" })
hl.bind("SHIFT + XF86MonBrightnessDown", hl.dsp.exec_cmd("display-brightness 1%"), { locked = true, repeating = true, description = "Brightness minimum" })
hl.bind("XF86KbdBrightnessUp", hl.dsp.exec_cmd("keyboard-brightness up"), { locked = true, repeating = true, description = "Keyboard brightness up" })
hl.bind("XF86KbdBrightnessDown", hl.dsp.exec_cmd("keyboard-brightness down"), { locked = true, repeating = true, description = "Keyboard brightness down" })
hl.bind("XF86KbdLightOnOff", hl.dsp.exec_cmd("keyboard-brightness cycle"), { locked = true, description = "Keyboard backlight cycle" })
hl.bind("XF86TouchpadToggle", hl.dsp.exec_cmd("touchpad-toggle"), { locked = true, description = "Toggle touchpad" })
hl.bind("XF86TouchpadOn", hl.dsp.exec_cmd("touchpad-toggle on"), { locked = true, description = "Enable touchpad" })
hl.bind("XF86TouchpadOff", hl.dsp.exec_cmd("touchpad-toggle off"), { locked = true, description = "Disable touchpad" })

-- Precise 1% multimedia adjustments with Alt modifier
hl.bind("ALT + XF86AudioRaiseVolume", hl.dsp.exec_cmd("desktop-osd --output-volume +1"), { locked = true, repeating = true, description = "Volume up precise" })
hl.bind("ALT + XF86AudioLowerVolume", hl.dsp.exec_cmd("desktop-osd --output-volume -1"), { locked = true, repeating = true, description = "Volume down precise" })
hl.bind("ALT + XF86MonBrightnessUp", hl.dsp.exec_cmd("display-brightness +1%"), { locked = true, repeating = true, description = "Brightness up precise" })
hl.bind("ALT + XF86MonBrightnessDown", hl.dsp.exec_cmd("display-brightness 1%-"), { locked = true, repeating = true, description = "Brightness down precise" })

-- Requires playerctl
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("desktop-osd --playerctl next"), { locked = true, description = "Next track" })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("desktop-osd --playerctl play-pause"), { locked = true, description = "Pause" })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("desktop-osd --playerctl play-pause"), { locked = true, description = "Play" })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("desktop-osd --playerctl previous"), { locked = true, description = "Previous track" })

-- Switch audio output with Super + Mute
hl.bind("SUPER + XF86AudioMute", hl.dsp.exec_cmd("audio-output-switch"), { locked = true, description = "Switch audio output" })
