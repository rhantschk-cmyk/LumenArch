# Lumen Arch

Lumen Arch is a personal, polished and offline-first Arch Linux desktop. It is
inspired by the focused Hyprland workflow of Omarchy, but every package,
configuration file and installer decision lives in this repository.

The ISO contains a complete local Pacman repository. The target computer needs
no internet connection while installing: the graphical installer partitions the
selected disk and installs the kernel, drivers, desktop, tools and user config
directly from the USB stick.

> **Warning:** the installer is currently intentionally simple and destructive.
> It erases the entire selected disk and requires UEFI. Choose ext4 or Btrfs
> in the installer; encryption and dual-boot mode are not implemented yet.

## Included desktop

- Hyprland, Quickshell, SDDM, Hyprlock and Hypridle
- PipeWire/WirePlumber, NetworkManager, Bluetooth, portals, Polkit and
  notifications
- Firefox, Thunar, terminal, launcher, screenshot and power menus
- OBS Studio, Neovim, Tmux, Git/LazyGit, Obsidian, Typora, Docker and Yay
- Zsh with Spaceship prompt, Zoxide, Eza, Bat and a custom Fastfetch setup
- HyprMon (`hyprmon`) for monitor configuration
- Intel/AMD Mesa + Vulkan and NVIDIA Open driver packages

## Shortcuts

| Action | Shortcut |
| --- | --- |
| Terminal | `Super + Return` |
| Launcher | `Super + Space` |
| File manager | `Super + E` |
| Browser | `Super + B` |
| Close window | `Super + Q` |
| Full screenshot | `Print` |
| Region screenshot | `Super + Print` |
| Screenshot menu | `Super + S` |
| Lock | `Super + L` |
| Power menu | `Super + Escape` |
| OBS Studio | `Super + O` |
| Neovim | `Super + N` |
| Tmux workspace | `Super + T` |
| LazyGit | `Super + G` |
| Obsidian | `Super + M` |
| Typora | `Super + Shift + M` |
| Update/install centre | `Super + U` |
| Docker dashboard | `Super + D` |
| HyprMon | `Super + ,` |

The terminal starts Zsh. `cd` invokes Zoxide (`z`), `ls` invokes Eza and `cat`
invokes Bat. Run `fastfetch` for the Lumen system card.

## Build on NixOS

Docker must be enabled on the host. The build uses a privileged Arch container
because ArchISO requires mount and loop-device access.

```bash
cd ~/Projekte/Distro/lumen-arch
./scripts/build-iso-container.sh
```

The resulting image is placed in `build/iso/`. Persistent caches make repeated
builds much faster:

- `build/container-pacman-cache/` — official Arch package downloads
- `build/offline-package-cache/` — packages embedded into the local repository
- `build/aur-package-cache/` — completed AUR package archives

Do not delete those directories unless a clean package download is desired.
Do not commit `build/`.

### Resumable release builds

After the first successful dependency stage, Lumen stores a verified offline
package checkpoint in `build/offline-checkpoint/`. A later failure during ISO
creation, or changes limited to the installer, theme, documentation or home
configuration, reuse this checkpoint automatically and skip Pacstrap's full
dependency resolution and AUR builds. Package-list or package-build-script
changes invalidate it automatically.

To deliberately rebuild that stage, run:

```bash
LUMEN_REBUILD_PACKAGES=1 ./scripts/build-iso-container.sh
```

The container reuses its Pacman archive cache and does not upgrade its build
environment on ordinary runs. Only use the following when you intentionally
want refreshed Arch build tooling:

```bash
LUMEN_REFRESH_BUILDER=1 ./scripts/build-iso-container.sh
```

## Test in QEMU

The helper starts the newest ISO with UEFI firmware and a persistent 64 GB
virtual disk:

```bash
./scripts/run-qemu.sh
```

To test again with a blank disk without deleting the usual VM, choose another
directory:

```bash
LUMEN_VM_DIR="$HOME/VMs/lumen-test-clean" ./scripts/run-qemu.sh
```

The QEMU message about attaching `/dev/sr0` to a loopback device is harmless
when the live environment and installer otherwise start.

### Fast installer-development loop

For GTK installer and live-session work, use a small non-installable preview
ISO instead of rebuilding the complete offline package repository:

```bash
LUMEN_DEV_ISO=1 ./scripts/build-iso-container.sh
LUMEN_ISO_DIR="$PWD/build/iso-dev" LUMEN_VM_DIR="$HOME/VMs/lumen-dev" ./scripts/run-qemu.sh
```

The preview labels itself as a Development ISO and disables disk installation.
Build the normal ISO for package-closure and end-to-end installation tests.

## Install from USB

1. Flash the ISO to the correct USB device, for example:

   ```bash
   sudo dd if=build/iso/lumen-arch-YYYY.MM.DD-x86_64.iso of=/dev/sdX bs=4M conv=fsync status=progress
   ```

   Replace `/dev/sdX` with the whole USB device, never a partition such as
   `/dev/sdX1`.
2. Boot it in UEFI mode and select **Start Lumen Arch Installer**.
3. Enter username, passwords, timezone, hostname, keyboard, filesystem, target
   disk and optional profiles. All profiles are selected by default.
4. Confirm the destructive disk operation. The finished system should boot to
   SDDM with all listed packages already installed.

## Offline repository implementation

`scripts/build-iso.sh` builds a clean temporary target root with `pacstrap`.
It then reads that root's Pacman database and copies every exact installed
package version into `opt/lumen/offline/repo` before generating
`lumen-offline.db.tar.gz`. This detail matters: dependencies such as `glibc`
can otherwise remain only in Docker's Pacman cache, leading to errors such as
“cannot resolve glibc, a dependency of libxdmcp” during installation.

The graphical installer lives at
`iso/airootfs/usr/local/share/lumen-installer/app.py`; its privileged installer
backend is `iso/airootfs/usr/local/bin/lumen-offline-install`.

After installation, the system switches back to a normal, signature-checking
Arch Pacman configuration. The ISO repository is deliberately not retained as
the target's package source.

## Project layout

- `profiles/base/` and `profiles/desktop/` — required system and desktop lists
- `profiles/developer/`, `creator/`, `gaming/` — optional, default-selected lists
- `profiles/installer/` — packages necessary in the live environment
- `iso/` — ArchISO overlay, boot-menu entries, service and installer
- `home/` — configuration copied into the installed user's home directory
- `system/` — system-wide SDDM and related configuration
- `scripts/` — ISO build, QEMU test and validation helpers
- `docs/` — architecture and customization notes

See [docs/architecture.md](docs/architecture.md) and
[docs/customization.md](docs/customization.md) for details.
