# Lumen Arch — persistent handover notes

Read this before modifying the ISO builder or installer. It records the design,
the debugging history and the current validation state after the project moved
from `~/Work/Projekte/Distro` to `~/Projekte/Distro`.

## Objective

Lumen Arch is a personal Arch Linux distribution with a polished Hyprland and
Quickshell desktop. The non-negotiable requirement is a complete system from
the USB installer: no Archinstall handoff and no post-install manual internet
setup. Kernel, firmware, drivers, desktop and requested programs must already
be available on the ISO.

Git history is managed with `bgt`, not normal Git. Use `bgt save 'message'`
after coherent changes. The repository may not have a working `origin`; a
failed push is not a build failure.

## Repository location and sandbox note

The real repository is:

```text
~/Projekte/Distro/lumen-arch
```

`~/Work/Projekte/Distro/lumen-arch` is a symlink kept for older tooling.
Some agent environments can read through it but cannot write to the resolved
real path. When that restriction applies, stage complete files in `/tmp` and
the user can copy them into the real repository.

## Installer architecture

The old Archinstall path is obsolete. The current installer is a full-screen
GTK application hosted in Cage on tty1:

- `iso/efiboot/loader/entries/01-lumen-installer.conf` — UEFI boot entry
- `iso/airootfs/etc/systemd/system/lumen-installer.service` — launches Cage
- `iso/airootfs/usr/local/share/lumen-installer/app.py` — form and log view
- `iso/airootfs/usr/local/bin/lumen-offline-install` — destructive backend

The wizard asks for username, user password, root password, timezone, hostname,
console keyboard, filesystem and target disk. Base/Desktop are mandatory;
Developer, Creator and Gaming are selectable and enabled by default. The
backend rejects the live installation medium, wipes the chosen disk, makes a
GPT/ESP layout with ext4 or Btrfs, uses the ISO-local Pacman repository with
`pacstrap`, creates users, installs AUR archives, writes systemd-boot
configuration, copies Lumen configuration and enables NetworkManager,
Bluetooth, SDDM, power profiles and Docker.

Current intentional limits: UEFI only, whole-disk GPT layout, no
encryption, no dual boot. Do not describe those as supported features.

## Live graphical environment

`cage` initially failed with an all-black screen because libseat could not find
a backend. The required final pieces are:

- `seatd` in `profiles/installer/packages.pacman`
- service `Requires=seatd.service` and `After=seatd.service`
- `Environment=LIBSEAT_BACKEND=seatd`
- `PAMName=login`, `TTYPath=/dev/tty1` and `XDG_RUNTIME_DIR`

The live installer now starts in QEMU. A message about failing to attach
`/dev/sr0` to a loopback device is a QEMU/systemd optical-drive quirk and is
harmless if the live environment starts.

## Offline package repository — crucial fix

The installer originally failed with messages equivalent to:

```text
cannot resolve "glibc", a dependency of "libxdmcp"
unable to satisfy dependency ... required by libX11/libxcb/libXext/...
```

Cause: merely running `pacman -Sw` is insufficient because packages already
installed in the Arch Docker build container are considered satisfied and their
archives are not copied to the ISO. Even `pacstrap` may cache part of the
closure in Docker's `/var/cache/pacman/pkg` instead of the staging directory.

`scripts/build-iso.sh` must do all of the following after `pacstrap` creates
`$offline_root`:

1. Run `pacman -Q --root "$offline_root"` to obtain the target's exact package
   name/version closure.
2. For every package, keep an existing matching archive in `$stage_repo`, or
   link the exact matching archive from `/var/cache/pacman/pkg`.
3. Only then remove `$offline_root`, cache the staged archives and run
   `repo-add`.

Important implementation detail: use separate `staged_matches` and
`cached_matches` arrays. Do not invoke `ln` if the archive already exists in
`$stage_repo`; doing so aborts under `set -e` with a “same file” message such
as the `7zip` failure.

The current corrected script was staged as `/tmp/lumen-build-iso.sh` during the
last debugging session. It must be copied into the repository before the next
build if it is not already there:

```bash
cp /tmp/lumen-build-iso.sh ~/Projekte/Distro/lumen-arch/scripts/build-iso.sh
cd ~/Projekte/Distro/lumen-arch
chmod +x scripts/build-iso.sh
bgt save 'Fix offline package staging links'
./scripts/build-iso-container.sh
```

After a successful build, verify that the ISO actually contains `glibc` before
spending time booting it. From an Arch environment, inspect it with `bsdtar` or
mount the ISO and check:

```text
opt/lumen/offline/repo/glibc-*.pkg.tar.zst
opt/lumen/offline/repo/lumen-offline.db.tar.gz
```

The final required validation is an end-to-end QEMU install followed by a boot
from its virtual disk; static checks and a graphical live boot alone are not
enough.

## Build on NixOS

```bash
cd ~/Projekte/Distro/lumen-arch
./scripts/build-iso-container.sh
```

The wrapper runs a privileged Arch Docker container and mounts
`build/container-pacman-cache` at `/var/cache/pacman/pkg`. Persistent caches:

- `build/container-pacman-cache/` — Arch downloads used by the container
- `build/offline-package-cache/` — archives staged for ISO reuse
- `build/aur-package-cache/` — completed AUR packages
- `build/offline-checkpoint/` — verified full offline closure; automatically
  reused when package inputs have not changed

A first full dependency closure is large (roughly 8 GB installed in the
temporary root) and can take considerably longer than previous builds. It is
normal for the temporary `build/archiso-profile.*` directory to grow first;
the persistent offline cache is updated later.

Once the package phase succeeds, the build writes
`build/offline-checkpoint/`. Re-running after a later failure, or after a
non-package change, skips dependency resolution and AUR builds. Set
`LUMEN_REBUILD_PACKAGES=1` to explicitly invalidate that checkpoint.

## Package notes

Requested software includes OBS, Git, Neovim, Tmux, Yay, Obsidian, Typora,
Docker, Zoxide, Bat, Eza, Fastfetch, Spaceship and HyprMon.

- `hyprpicker` was removed because its AUR package needs obsolete `wlroots`.
- Use `hyprmon-bin`, command `hyprmon`, rather than stale HyprMon recipes.
- AUR packages are built during ISO creation; the target installer must only
  run `pacman -U` on the embedded archives and must never need AUR network
  access.
- Keep an eye on newly broken AUR recipes; maintained `-bin` packages are
  generally safer for the offline ISO.

## QEMU

Run the newest image with:

```bash
cd ~/Projekte/Distro/lumen-arch
./scripts/run-qemu.sh
```

It uses Nix to provide QEMU and OVMF and creates:

```text
~/VMs/lumen-test/lumen.qcow2
~/VMs/lumen-test/OVMF_VARS.fd
```

For a fresh virtual drive use:

```bash
LUMEN_VM_DIR="$HOME/VMs/lumen-test-clean" ./scripts/run-qemu.sh
```

If `OVMF_VARS.fd` is not writable because an earlier command used sudo:

```bash
sudo chown -R "$USER:$(id -gn)" "$HOME/VMs/lumen-test"
chmod u+rw "$HOME/VMs/lumen-test/OVMF_VARS.fd"
```

## Key files

- `profiles/base/`, `desktop/`, `developer/`, `creator/`, `gaming/` — package
  profiles; optional profiles are enabled by default in the installer
- `profiles/installer/packages.pacman` — live installer dependencies
- `scripts/build-iso.sh` — local package repository creation
- `scripts/build-iso-container.sh` — NixOS/non-Arch Docker wrapper
- `scripts/run-qemu.sh` — one-command UEFI QEMU test
- `home/.config/hypr/hyprland.lua` — bindings and compositor config
- `home/.config/quickshell/lumen/shell.qml` — top bar
- `home/.config/lumen/bin/` — launcher, screenshots, power and update menus
- `home/.zshrc` — `cd → z`, `ls → eza`, `cat → bat` aliases
- `system/usr/share/sddm/themes/lumen/` — SDDM theme

## Current next action

1. Ensure the corrected `scripts/build-iso.sh` is present.
2. Build the ISO to completion.
3. Confirm `glibc` exists in the embedded offline repository.
4. Run QEMU with a new VM directory.
5. Install, reboot from the virtual disk, test SDDM, login, Hyprland,
   NetworkManager and the preinstalled applications.
6. Save validated changes with `bgt`.
