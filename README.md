# Lumen Arch

Lumen Arch is a usable, personal Arch Linux desktop profile built around
Hyprland and Quickshell. It takes inspiration from the opinionated, polished
workflow of Omarchy while keeping the distribution definition small, readable,
and entirely owned by this repository.

It is an offline-first ISO installer. The Lumen boot-menu entry starts a
full-screen installer that erases the selected disk, creates a UEFI boot layout,
and installs the complete desktop from packages embedded in the ISO. No network
connection is required once the ISO has been built.

## What is included

- Hyprland Wayland session with sensible laptop/desktop keybindings
- Quickshell top bar, workspace indicator, clock, and system tray
- SDDM login manager, PipeWire/WirePlumber audio, NetworkManager, Bluetooth,
  portals, polkit, notifications, screen locking, idle management, and
  clipboard history
- Firefox, Thunar, image/PDF tools, terminal, launcher, screenshot tools,
  fonts, theming, and common archive/media support
- A declared package set and idempotent installation scripts

## Installation

Boot the ISO and select **Start Lumen Arch Installer**. The full-screen wizard
asks for username, user/root passwords, timezone, and a target disk. It shows
one explicit destructive confirmation before partitioning the selected drive.

## Daily use

| Action | Shortcut |
| --- | --- |
| Terminal | `Super + Return` |
| App launcher | `Super + Space` |
| File manager | `Super + E` |
| Browser | `Super + B` |
| Close window | `Super + Q` |
| Full screenshot | `Print` |
| Region screenshot | `Super + Print` |
| Lock | `Super + L` |
| Power menu | `Super + Escape` |

## Productivity shortcuts

| App or tool | Shortcut |
| --- | --- |
| OBS Studio | `Super + O` |
| Neovim | `Super + N` |
| Tmux workspace | `Super + T` |
| Git dashboard (LazyGit) | `Super + G` |
| Obsidian | `Super + M` |
| Typora | `Super + Shift + M` |
| Lumen update/install center | `Super + U` |
| Screenshot menu | `Super + S` |
| Docker dashboard | `Super + D` |
| Monitor configuration (HyprMon) | `Super + ,` |

The terminal opens in Zsh with Spaceship/Starship fallback, `cd` mapped to
Zoxide, `ls` mapped to Eza, and `cat` mapped to Bat. Run `fastfetch` for the
Lumen system card.

See `docs/architecture.md` for the component map and `docs/customization.md`
for the supported places to personalize the desktop.

## Build an installer ISO

On an Arch build host, install `archiso` and run:

```bash
./scripts/build-iso.sh
```

The resulting ISO is written to `build/iso/`. Its `lumen-install` command
starts Archinstall for the deliberately machine-specific disk and boot choices;
after first boot, apply the Lumen desktop profile using the fast path above.

On NixOS or another Linux distribution, enable Docker and run
`./scripts/build-iso-container.sh`. The container is privileged because
ArchISO needs mount and loop-device capabilities while generating the image.
