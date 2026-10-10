-- Lumen Arch — Hyprland session
-- Hyprland 0.55+ uses Lua configuration.  This file deliberately uses only
-- the public Lua API documented at https://wiki.hypr.land/.

local terminal = "alacritty"
local menu = "$HOME/.config/lumen/bin/lumen-menu"
local files = "thunar"
local browser = "firefox"

hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto", vrr = 1 })

hl.env("XCURSOR_SIZE", "24")
hl.env("QT_QPA_PLATFORM", "wayland")
hl.env("MOZ_ENABLE_WAYLAND", "1")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")

hl.config({
    general = {
        gaps_in = 5,
        gaps_out = 12,
        border_size = 2,
        layout = "dwindle",
        col = {
            active_border = {
                colors = { "rgba(cba6f7ee)", "rgba(89b4faee)" },
                angle = 45,
            },
            inactive_border = "rgba(313244bb)",
        },
    },
    decoration = {
        rounding = 12,
        active_opacity = 1.0,
        inactive_opacity = 0.94,
        shadow = {
            enabled = true,
            range = 18,
            render_power = 3,
            color = "rgba(00000066)",
        },
        blur = {
            enabled = true,
            size = 5,
            passes = 3,
            vibrancy = 0.18,
        },
    },
    input = {
        kb_layout = "de",
        follow_mouse = 1,
        touchpad = {
            natural_scroll = true,
            tap_to_click = true,
        },
    },
    dwindle = {
        preserve_split = true,
    },
    misc = {
        disable_hyprland_logo = true,
        force_default_wallpaper = 0,
        vrr = 1,
    },
})

hl.curve("soft", {
    type = "bezier",
    points = { { 0.25, 0.9 }, { 0.2, 1.0 } },
})

hl.animation({ leaf = "windows", enabled = true, speed = 5, bezier = "soft", style = "slide" })
hl.animation({ leaf = "border", enabled = true, speed = 6, bezier = "soft" })
hl.animation({ leaf = "fade", enabled = true, speed = 5, bezier = "soft" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 4, bezier = "soft", style = "slidevert" })

hl.on("hyprland.start", function()
    hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
    hl.exec_cmd("systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
    hl.exec_cmd("/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1")
    hl.exec_cmd("nm-applet --indicator")
    hl.exec_cmd("swaync")
    hl.exec_cmd("quickshell -c lumen")
    hl.exec_cmd("hypridle")
    hl.exec_cmd("$HOME/.config/lumen/scripts/wallpaper.sh")
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")
end)

hl.bind("SUPER + Return", hl.dsp.exec_cmd(terminal))
hl.bind("SUPER + Space", hl.dsp.exec_cmd(menu))
hl.bind("SUPER + E", hl.dsp.exec_cmd(files))
hl.bind("SUPER + B", hl.dsp.exec_cmd(browser))
hl.bind("SUPER + O", hl.dsp.exec_cmd("obs"))
hl.bind("SUPER + N", hl.dsp.exec_cmd(terminal .. " -e nvim"))
hl.bind("SUPER + T", hl.dsp.exec_cmd(terminal .. " -e tmux new-session -A -s workspace"))
hl.bind("SUPER + G", hl.dsp.exec_cmd(terminal .. " -e lazygit"))
hl.bind("SUPER + M", hl.dsp.exec_cmd("obsidian"))
hl.bind("SUPER + SHIFT + M", hl.dsp.exec_cmd("typora"))
hl.bind("SUPER + U", hl.dsp.exec_cmd(terminal .. " -e $HOME/.config/lumen/bin/lumenctl"))
hl.bind("SUPER + S", hl.dsp.exec_cmd("$HOME/.config/lumen/bin/lumen-screenshot"))
hl.bind("SUPER + D", hl.dsp.exec_cmd(terminal .. " -e lazydocker"))
hl.bind("SUPER + comma", hl.dsp.exec_cmd(terminal .. " -e hyprmon"))
hl.bind("SUPER + Q", hl.dsp.window.close())
hl.bind("SUPER + F", hl.dsp.window.fullscreen())
hl.bind("SUPER + V", hl.dsp.window.float())
hl.bind("SUPER + SHIFT + L", hl.dsp.exec_cmd("hyprlock"))
hl.bind("SUPER + Escape", hl.dsp.exec_cmd("swaync-client -t -sw"))
hl.bind("Print", hl.dsp.exec_cmd([[grim "$HOME/Pictures/Screenshots/$(date +'%Y-%m-%d_%H-%M-%S').png"]]))
hl.bind("SUPER + Print", hl.dsp.exec_cmd([[slurp | grim -g - "$HOME/Pictures/Screenshots/$(date +'%Y-%m-%d_%H-%M-%S').png"]]))
hl.bind("SUPER + SHIFT + V", hl.dsp.exec_cmd("$HOME/.config/lumen/bin/lumen-clipboard"))
hl.bind("SUPER + R", hl.dsp.exec_cmd("quickshell -c lumen -r"))

hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"), { repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { repeating = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true })
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl set +5%"), { repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl set 5%-"), { repeating = true })

hl.bind("SUPER + left", hl.dsp.focus({ direction = "l" }))
hl.bind("SUPER + right", hl.dsp.focus({ direction = "r" }))
hl.bind("SUPER + up", hl.dsp.focus({ direction = "u" }))
hl.bind("SUPER + down", hl.dsp.focus({ direction = "d" }))
hl.bind("SUPER + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind("SUPER + mouse:273", hl.dsp.window.resize(), { mouse = true })

for workspace = 1, 5 do
    hl.bind("SUPER + " .. workspace, hl.dsp.focus({ workspace = tostring(workspace) }))
    hl.bind("SUPER + SHIFT + " .. workspace, hl.dsp.window.move({ workspace = tostring(workspace) }))
end
hl.bind("SUPER + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind("SUPER + mouse_up", hl.dsp.focus({ workspace = "e-1" }))

hl.window_rule({
    match = { class = "^(pavucontrol|org.gnome.FileRoller|org.gnome.Evince)$" },
    float = true,
    size = { 900, 650 },
})
