# Architecture

Lumen is an Arch profile, not a fork of Arch. Pacman remains the package
manager; all Lumen-owned state is either in this repository or copied into the
desktop user's home directory by `scripts/install-user.sh`.

```text
SDDM → Hyprland → dbus + portals + polkit
                   ├─ Quickshell panel / system tray
                   ├─ swaync notifications
                   ├─ NetworkManager applet
                   ├─ PipeWire + WirePlumber audio
                   ├─ hypridle → hyprlock
                   └─ swaybg → Lumen wallpaper
```

The display manager starts the standard Hyprland session. Hyprland starts the
user-facing services exactly once on login. Quickshell owns the top panel;
SwayNC owns notifications and the notification center. This split avoids two
components competing for the same desktop responsibility.

## Boundaries

- `profiles/desktop/`: package declaration only
- `home/`: files copied to `$HOME`; safe to modify after installation
- `scripts/install-system.sh`: package/service changes requiring sudo
- `scripts/install-user.sh`: user configuration and timestamped backups

The project deliberately does not prescribe a bootloader, disk layout, kernel,
or encryption scheme. Those are installation-specific decisions.
