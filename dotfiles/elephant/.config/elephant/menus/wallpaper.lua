Name = "wallpaper"
NamePretty = "Wallpapers"
Icon = "preferences-desktop-wallpaper"
Cache = false
HideFromProviderlist = true
Description = "Preview and select a desktop wallpaper"
SearchName = true

local function shell_quote(value)
    return "'" .. value:gsub("'", "'\\''") .. "'"
end

local function command_output(command)
    local handle = io.popen(command)
    if not handle then
        return ""
    end
    local output = handle:read("*a") or ""
    handle:close()
    return output:gsub("\n$", "")
end

local function wallpaper_directory()
    local configured = os.getenv("ARCH_SETUP_WALLPAPER_DIR")
    if configured and configured ~= "" then
        return configured
    end
    return os.getenv("HOME") .. "/.config/wallpapers"
end

function GetEntries()
    local directory = wallpaper_directory()
    local current = command_output("readlink -f -- " .. shell_quote(directory .. "/current") .. " 2>/dev/null")
    local command = "find " .. shell_quote(directory) ..
        " -maxdepth 1 -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png'" ..
        " -o -iname '*.webp' -o -iname '*.bmp' -o -iname '*.gif' \\) -print0 2>/dev/null | sort -z"
    local handle = io.popen(command)
    local entries = {}

    if not handle then
        return entries
    end

    local output = handle:read("*a") or ""
    handle:close()

    for path in output:gmatch("([^%z]+)%z") do
        local filename = path:match("([^/]+)$") or path
        local is_current = path == current
        table.insert(entries, {
            Text = (is_current and "✓ " or "") .. filename,
            Subtext = is_current and "Current wallpaper" or "Wallpaper",
            Value = path,
            Preview = path,
            PreviewType = "file",
            Actions = {
                select = "lua:SetWallpaper",
            },
        })
    end

    return entries
end

function SetWallpaper(value)
    if not value or value == "" then
        return
    end
    os.execute("wallpaper-select --set " .. shell_quote(value))
end
