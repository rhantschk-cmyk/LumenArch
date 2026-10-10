# Lumen Arch

Lumen Arch is a polished, offline-first Arch Linux desktop and installer ISO.
It provides a carefully integrated Hyprland environment while preserving the
things that make Arch useful: ordinary Pacman packages, readable configuration
files, no custom package manager, and the freedom to remove or add components.

The installation medium contains a complete local Pacman repository. A target
machine does **not** need an internet connection to install the kernel, drivers,
desktop, profiles, applications, and their transitive dependencies.

> **Status and safety:** Lumen currently targets UEFI systems and deliberately
> erases the complete selected disk. ext4 and Btrfs are supported. Encryption,
> dual boot, and preserving an existing installation are not implemented.

## What is included

The standard installation enables every optional profile by default, so the
first boot is productive rather than a blank desktop.

| Area | Included tools |
| --- | --- |
| Session | Hyprland (Lua configuration), Quickshell panel, SDDM, Hyprlock, Hypridle, Polkit, portals and notifications |
| Connectivity | NetworkManager, Bluetooth, PipeWire/WirePlumber, screen-sharing portals and `nmcli` |
| Everyday desktop | Firefox, Thunar, Fuzzel, screenshots with Grim/Slurp, clipboard history with Cliphist, Pavucontrol and GParted |
| Development | Git, Neovim, Tmux, LazyGit, LazyDocker, Docker, Podman, Go, Node.js, Python, Rust, Java, CMake and Kubernetes tooling |
| Creation | OBS Studio, Obsidian, Typora, MPV, Evince, ImageMagick and FFmpeg |
| Gaming | Steam, GameMode and MangoHud |
| Terminal workflow | Zsh, Spaceship/Starship, Zoxide, Eza, Bat, FZF, Fastfetch and Btop |
| Hardware | Intel/AMD Mesa and Vulkan packages, NVIDIA Open driver packages, microcode and common firmware |

Base and Desktop are always installed. Developer, Creator, and Gaming can be
deselected in the installer when a smaller initial system is preferred.

## Install from USB

1. Build or download the ISO and flash it to the **whole** USB device. Never
   write it to a partition such as `/dev/sdX1`.

   ```bash
   sudo dd if=build/iso/lumen-arch-YYYY.MM.DD-x86_64.iso of=/dev/sdX \
     bs=4M conv=fsync status=progress
   ```

2. Boot the USB in UEFI mode. At the boot menu, select **Launch Lumen
   Installer** (shown by the ISO as **Start Lumen Arch Installer**). Do not
   continue with the ArchISO entry that is selected by default: that entry is
   the plain live environment for manual installation and does not launch the
   graphical installer.

3. In the installer, choose a username and passwords, timezone, hostname,
   keyboard layout, filesystem, target disk, and optional profiles. The
   Developer, Creator, and Gaming profiles are initially selected.

4. Confirm the destructive disk operation. After installation, remove the USB
   drive and reboot. SDDM starts the Lumen Hyprland session.

The installer packages the system exclusively from the USB's local repository;
target networking is not used. Internet can be configured after the first boot.

## Manual offline installation and custom package selection

Lumen is intentionally usable without the guided installer. This is for people
who want a leaner Arch installation, a custom partition layout, or complete
control over which parts some would call “bloat” are installed.

Boot the regular ArchISO live entry instead of **Launch Lumen Installer**. The
same ISO still exposes all Lumen package archives and manifests locally:

- local repository: `/opt/lumen/offline/repo`
- offline Pacman configuration: `/opt/lumen/offline/pacman.conf`
- package manifests: `/opt/lumen/profiles/*/packages.pacman`
- installer implementation: `/usr/local/bin/lumen-offline-install`

After you have partitioned and mounted a target at `/mnt`, you can bootstrap
only the packages you choose. For example, this installs a small bootable base
without a desktop profile:

```bash
pacstrap -G -C /opt/lumen/offline/pacman.conf /mnt \
  base linux linux-firmware networkmanager sudo systemd zsh
cp -a /opt/lumen /mnt/opt/lumen
```

Then configure fstab, locale, users, bootloader, and networking as you would on
normal Arch Linux. Before using Pacman in the installed system, initialise its
normal Arch keyring and restore the standard target configuration:

```bash
arch-chroot /mnt
pacman-key --init
pacman-key --populate archlinux
install -Dm644 /opt/lumen/offline/target-pacman.conf /etc/pacman.conf
```

While working from the USB, install any additional package available on the
medium with the same offline configuration, for example:

```bash
pacman -S --config /opt/lumen/offline/pacman.conf hyprland firefox neovim
```

Read the profile manifests to compose your own system: Base and Desktop contain
the platform and session, while Developer, Creator, and Gaming are independent
application collections. The ISO includes their full dependency closure, so
selecting individual packages from those manifests remains offline. Manual
installs are intentionally advanced: Lumen's graphical installer is the
supported path for a complete configured desktop.

## Desktop and shortcuts

The default session is Hyprland. Its configuration is ordinary Lua at
`~/.config/hypr/hyprland.lua`; user-facing Lumen scripts live in
`~/.config/lumen/`.

| Action | Shortcut |
| --- | --- |
| Terminal | `Super + Return` |
| App launcher | `Super + Space` |
| File manager | `Super + E` |
| Firefox | `Super + B` |
| Close / fullscreen / float | `Super + Q` / `Super + F` / `Super + V` |
| Full / region screenshot | `Print` / `Super + Print` |
| Screenshot menu | `Super + S` |
| Clipboard history | `Super + Shift + V` |
| Lock | `Super + Shift + L` |
| Power menu | `Super + Escape` |
| OBS Studio | `Super + O` |
| Neovim / Tmux / LazyGit | `Super + N` / `Super + T` / `Super + G` |
| Obsidian / Typora | `Super + M` / `Super + Shift + M` |
| Control Center | `Super + U` |
| LazyDocker | `Super + D` |
| HyprMon monitor setup | `Super + ,` |

The terminal launches Zsh. `cd` uses Zoxide (`z`), `ls` uses Eza, and `cat`
uses Bat. Run `fastfetch` for the Lumen system card.

Neovim starts with a small, normal user configuration at
`~/.config/nvim/` that bootstraps LazyVim. Lazy.nvim owns its plugin checkout
and performs the initial plugin installation when Neovim is first started with
internet access; Lumen does not vendor a second plugin manager or overwrite its
state.

## Control Center

Open the terminal-based Control Center with `Super + U` or `lumenctl`. It is a
front end for common maintenance tasks without hiding the underlying Arch
commands.

- **Update Lumen and packages** clones or fast-forwards the official Lumen
  repository, installs updated user configuration, updates Pacman/Yay packages,
  and can apply changed system files and package requirements.
- **Packages and applications** can fuzzy-search official repositories or the
  AUR, inspect packages, remove installed packages, and install a curated set
  of optional applications. Installation is delegated to `lumen install`, so a
  failed package reports its error and returns to the menu instead of closing
  the Control Center.
- **Create web app shortcut** creates a named Firefox launcher in
  `~/.local/share/applications/` from a name and HTTPS/HTTP URL.
- **Connect to Wi-Fi** lists visible networks with `nmcli`, prompts for a
  password when needed, and creates a normal NetworkManager connection.
- **Appearance and default apps** applies a real GTK/portal light or dark
  preference and assigns browser, editor, and file-manager MIME defaults.
- **Local offline repository** mirrors downloaded Pacman archives, lets you
  add an archive or named package, exclude an archive from the local mirror,
  and retain a compact number of older versions.
- **Configure monitors**, **LazyDocker**, cache cleanup, service control, and
  system overview remain available from the same menu.

LazyDocker is deliberately run as the normal user, never through `sudo`. The
installer adds the user to the `docker` group and enables Docker; a logout and
login is required before a newly added group becomes active.

## Lumen CLI and local package archive

`lumen` is the documented command-line interface behind the Control Center.
Run `lumen help` or a command's `--help` for a concise command reference.

```bash
lumen center                         # open the terminal Control Center
lumen update                         # update Lumen and installed packages
lumen search --select hypr           # choose an official package with FZF
lumen search --aur --select theme    # choose an AUR package with FZF
lumen install <package>              # official package, then Yay fallback
lumen appearance dark
lumen default set browser firefox.desktop
```

Lumen's package archive has a deliberate split between settings and data:

- `/etc/lumen/` contains human-readable repository settings, explicit package
  exclusions, and update holds.
- `/var/lib/lumen/repo/` contains downloaded package archives and the generated
  Pacman repository database. It can grow large and is safe to rebuild from
  Pacman's cache.

The `lumen-repo-sync` Pacman hook mirrors installed or updated package archives
into that repository. It is a normal local Pacman source, so packages can be
installed later without re-downloading them when the archive is present.

```bash
lumen repo status
lumen repo exclusions
lumen repo sync
lumen repo add firefox               # download once, retain in the local repo
lumen repo add /path/to/package.pkg.tar.zst
lumen repo exclude linux-firmware    # do not retain this archive locally
lumen repo unexclude linux-firmware
lumen repo prune                     # retain two local versions per package
lumen package hold linux             # exclude from normal Pacman updates
lumen package unhold linux
```

`repo exclude` controls only whether an archive is kept in Lumen's local
offline mirror. `package hold` writes an explicit Pacman `IgnorePkg` entry and
controls updates. The two operations are intentionally separate.

## Build in a container

The supported build path uses a privileged Arch Linux container. It works on
any Linux host with Docker because ArchISO needs mount and loop-device access.

```bash
cd ~/Projekte/Distro/lumen-arch
sudo -v
./scripts/build-iso-container.sh
```

The resulting image is written to `build/iso/`. The following persistent caches
make repeat builds and recovery after a failed build much faster:

- `build/container-pacman-cache/` — official Arch package archives
- `build/offline-package-cache/` — archives embedded in Lumen's local repo
- `build/aur-package-cache/` — completed AUR package archives
- `build/offline-checkpoint/` — verified, complete package closure

Do not delete these directories unless a fresh package download is wanted; do
not commit `build/`.

### Resumable builds

Once the dependency stage succeeds, Lumen stores a verified offline package
checkpoint. Changes limited to the installer, documentation, theme, or user
configuration reuse it automatically and skip full dependency resolution and
AUR builds. Package manifest changes only fetch what is missing from the caches
when possible.

Force a complete dependency-stage rebuild:

```bash
LUMEN_REBUILD_PACKAGES=1 ./scripts/build-iso-container.sh
```

Refresh the Arch build container intentionally:

```bash
LUMEN_REFRESH_BUILDER=1 ./scripts/build-iso-container.sh
```

## Test in QEMU

The test helper boots the newest ISO with UEFI firmware and a persistent 64 GB
virtual disk:

```bash
./scripts/run-qemu.sh
```

Use another directory for a clean test disk:

```bash
LUMEN_VM_DIR="$HOME/VMs/lumen-test-clean" ./scripts/run-qemu.sh
```

For fast installer and live-session iteration, build a small non-installable
preview ISO instead of the complete offline repository:

```bash
LUMEN_DEV_ISO=1 ./scripts/build-iso-container.sh
LUMEN_ISO_DIR="$PWD/build/iso-dev" LUMEN_VM_DIR="$HOME/VMs/lumen-dev" \
  ./scripts/run-qemu.sh
```

## Project layout

- `profiles/base/`, `profiles/desktop/` — required system and desktop packages
- `profiles/developer/`, `creator/`, `gaming/` — optional profile manifests
- `profiles/installer/` — live-environment runtime packages
- `iso/` — ArchISO overlay, boot entry, service, and installer
- `home/` — files copied into the installed user's home directory
- `system/` — system-wide files such as the SDDM theme
- `scripts/` — build, validation, installation, and QEMU helpers
- `docs/` — architecture and customization reference

See [docs/architecture.md](docs/architecture.md) and
[docs/customization.md](docs/customization.md) for implementation details and
post-install customization.
