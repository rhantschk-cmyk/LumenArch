#!/usr/bin/env bash
# Static validation: safe to run on any Linux host.
set -Eeuo pipefail
root_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

for script in "$root_dir"/scripts/*.sh; do bash -n "$script"; done
for script in "$root_dir"/iso/airootfs/usr/local/bin/*; do bash -n "$script"; done
for script in "$root_dir"/home/.config/lumen/scripts/*.sh; do bash -n "$script"; done
for script in "$root_dir"/home/.config/lumen/bin/*; do bash -n "$script"; done
for script in "$root_dir"/system/usr/local/bin/* "$root_dir"/system/usr/lib/lumen/*; do bash -n "$script"; done
while IFS= read -r package; do
  [[ "$package" =~ ^[a-z0-9@._+:-]+$ ]] || { echo "Invalid package: $package" >&2; exit 1; }
done < <(find "$root_dir/profiles" -type f \( -name 'packages.pacman' -o -name 'packages.aur' \) -print0 | xargs -0 sed -E '/^($|#)/d')
grep -qx 'seatd' "$root_dir/profiles/installer/packages.pacman"
! rg -q 'archinstall|bios\.syslinux' "$root_dir/iso"
test -f "$root_dir/offline/target-pacman.conf"
grep -q 'LocalFileSigLevel = Optional' "$root_dir/offline/target-pacman.conf"
grep -qx 'Include = /etc/pacman.conf.d/lumen-holds.conf' "$root_dir/offline/target-pacman.conf"
grep -qx 'Include = /etc/pacman.conf.d/lumen-local.conf' "$root_dir/offline/target-pacman.conf"
grep -q 'ShellRoot' "$root_dir/home/.config/quickshell/lumen/shell.qml"
grep -q 'hl.on("hyprland.start"' "$root_dir/home/.config/hypr/hyprland.lua"
grep -q 'hl.exec_cmd("quickshell -c lumen")' "$root_dir/home/.config/hypr/hyprland.lua"
grep -q 'alias cd=.z.' "$root_dir/home/.zshrc"
grep -q 'lumen/bin/' "$root_dir/scripts/install-user.sh"
grep -q 'chown -R "$user:$user" "/home/$user"' "$root_dir/iso/airootfs/usr/local/bin/lumen-offline-install"
test -x "$root_dir/home/.config/lumen/bin/lumen-applications"
test -x "$root_dir/home/.config/lumen/bin/lumen-clipboard"
test -f "$root_dir/home/.config/nvim/init.lua"
test -f "$root_dir/home/.config/nvim/lua/config/lazy.lua"
grep -q 'LazyVim/LazyVim' "$root_dir/home/.config/nvim/lua/config/lazy.lua"
test -f "$root_dir/home/.local/share/applications/xfce4-about.desktop"
test -x "$root_dir/system/usr/local/bin/lumen"
test -x "$root_dir/system/usr/lib/lumen/lumen-repo-sync"
test -f "$root_dir/system/etc/lumen/repo.conf"
test -f "$root_dir/system/etc/pacman.conf.d/lumen-local.conf"
test -f "$root_dir/system/etc/pacman.d/hooks/lumen-repo.hook"
grep -qx 'qt6-declarative' "$root_dir/profiles/desktop/packages.pacman"
test -f "$root_dir/system/usr/share/sddm/themes/lumen/Main.qml"
python -c 'import sys; compile(open(sys.argv[1], encoding="utf-8").read(), sys.argv[1], "exec")' "$root_dir/iso/airootfs/usr/local/share/lumen-installer/app.py"
echo 'Static validation passed.'
