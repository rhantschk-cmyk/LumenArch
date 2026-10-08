# Lumen Arch — persistent handover notes

Read this file before changing the installer or ISO build.

## Goal

Lumen Arch is a personal, polished Arch desktop using Hyprland, Quickshell,
SDDM and a dark Lumen theme. The user requires a complete system directly from
the installation USB, never a bare Arch install followed by manual setup.

## Installer architecture

The old Archinstall handoff was rejected. The current design is an offline-first
full-screen installer:

- `iso/efiboot/loader/entries/01-lumen-installer.conf`: UEFI boot-menu entry.
- `iso/syslinux/lumen-installer.cfg`: BIOS menu entry.
- `iso/airootfs/usr/local/share/lumen-installer/app.py`: GTK fullscreen wizard
  for username, user password, root password, timezone and target disk.
- `iso/airootfs/usr/local/bin/lumen-offline-install`: wipes the chosen UEFI
  disk, creates GPT/EFI/ext4, installs from the ISO-local package repository,
  configures users/locale/timezone/systemd-boot, copies Lumen config and enables
  services.
- `scripts/build-iso.sh`: layers Lumen over ArchISO `releng`, embeds the source
  tree under `/opt/lumen`, downloads official package archives, builds AUR
  archives and creates a local pacman database.

The new full installer has passed static checks only. The next successful ISO
build plus VM/live boot is mandatory end-to-end validation.

## Build on NixOS

```bash
cd ~/Projekte/Distro/lumen-arch
./scripts/build-iso-container.sh
```

It uses privileged Docker because ArchISO needs mount/loop support. ISO output:
`build/iso/`. It will be much larger than the former 1.7 GB image.

Persistent caches:

- `build/container-pacman-cache/`
- `build/offline-package-cache/`
- `build/aur-package-cache/`

Do not commit `build/`.

## Active known issue

`hyprmoncfg` and `hyprpicker` AUR recipes request the removed package `wlroots`.
HyprMon was replaced successfully with `hyprmon-bin` (command `hyprmon`).
Remove the remaining `hyprpicker` line before rebuilding:

```bash
sed -i '/^hyprpicker$/d' profiles/desktop/packages.aur
bgt save 'Remove unmaintained Hyprpicker from offline package set'
./scripts/build-iso-container.sh
```

## Constraints

- Installer is UEFI-only, GPT + ext4, and erases the selected entire disk.
- No network is intended on the target during installation; the build host needs
  network for package download/AUR builds.
- Graphics payload includes Mesa, Intel/AMD Vulkan and `nvidia-open`.
- AUR recipes can break; prefer maintained `-bin` packages.

## Contents and key files

Requested apps: OBS, Git, Neovim, Tmux, Yay, Obsidian, Typora, Docker,
Zoxide, Eza, Bat, Fastfetch, Spaceship Prompt and HyprMon.

- `profiles/desktop/packages.pacman`, `packages.aur`: packages
- `home/.config/hypr/hyprland.conf`: session/bindings
- `home/.config/quickshell/lumen/shell.qml`: panel
- `home/.config/lumen/bin/`: launcher, screenshot, power and control menus
- `home/.zshrc`: Zoxide/Eza/Bat aliases
- `system/usr/share/sddm/themes/lumen/`: login theme

## Version-control

Use `bgt`, not normal Git. The GitHub remote was not created because the old
environment could not resolve `api.github.com`; local commits exist on `main`.

Relevant commits:

```text
34677d0 Persist Arch and AUR package caches across ISO builds
7c456c0 Use maintained HyprMon binary package for offline ISO builds
3d0c373 Grant AUR builder access to its temporary workspace
ebeabeb Allow offline AUR package builds to resolve dependencies
9964e3a Replace Archinstall handoff with full offline graphical installer
```
