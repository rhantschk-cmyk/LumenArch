# Customization

The files below are designed to be edited directly after installation:

- `~/.config/hypr/hyprland.conf` — monitors, keyboard layout, bindings, rules
- `~/.config/quickshell/lumen/shell.qml` — panel layout and colors
- `~/.config/lumen/wallpaper.svg` — the wallpaper source; restarting Hyprland
  regenerates its PNG automatically
- `~/.config/fuzzel/fuzzel.ini` — launcher size and palette

After editing the Quickshell file, press `Super + R` to reload it. Hyprland
configuration can be reloaded with `hyprctl reload` from a terminal.

To use another keyboard layout, change `kb_layout = de` in the `input` block.
For a US layout, set it to `us`. Do not edit generated files under
`~/.local/share/lumen-arch`; they are replaced from their source configuration.

## Terminal workflow

Lumen uses Zsh by default. `cd` becomes Zoxide's ranked directory jump, `ls`
uses Eza with icons and Git context, and `cat` uses Bat. `Super + T` opens a
named Tmux workspace; `Super + G` opens LazyGit. The `lumenctl` TUI provides
updates, an app catalogue, Docker's LazyDocker dashboard, system cleanup, and
HyprMon monitor layout without requiring users to memorize package commands.
