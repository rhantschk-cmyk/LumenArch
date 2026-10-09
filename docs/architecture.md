# Architecture

Lumen is an Arch profile, not a fork of Arch. Pacman remains the package
manager and, after installation, uses the normal signed Arch repositories.
The ISO-local repository exists only to make the initial installation fully
offline.

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

- `profiles/base/`: kernel, firmware and required system services
- `profiles/desktop/`: base graphical desktop
- `profiles/developer/`, `creator/`, `gaming/`: optional package profiles;
  all are selected by default and can be deselected in the installer
- `home/`: files copied to `$HOME`; safe to modify after installation
- `scripts/install-system.sh`: package/service changes requiring sudo
- `scripts/install-user.sh`: user configuration and timestamped backups

The current graphical installer deliberately supports UEFI whole-disk installs
only. It offers ext4 or Btrfs, hostname, console keyboard layout, timezone and
optional package profiles. Encryption and dual boot are not implemented yet.
