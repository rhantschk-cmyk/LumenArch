#!/usr/bin/env bash
# Static validation: safe to run on any Linux host.
set -Eeuo pipefail
root_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

for script in "$root_dir"/scripts/*.sh; do bash -n "$script"; done
for script in "$root_dir"/iso/airootfs/usr/local/bin/*; do bash -n "$script"; done
for script in "$root_dir"/iso/airootfs/usr/local/bin/*; do bash -n "$script"; done
for script in "$root_dir"/home/.config/lumen/scripts/*.sh; do bash -n "$script"; done
for script in "$root_dir"/home/.config/lumen/bin/*; do bash -n "$script"; done
while IFS= read -r package; do
  [[ "$package" =~ ^[a-z0-9@._+:-]+$ ]] || { echo "Invalid package: $package" >&2; exit 1; }
done < <(sed -E '/^($|#)/d' "$root_dir/profiles/desktop/packages.pacman")
grep -q 'ShellRoot' "$root_dir/home/.config/quickshell/lumen/shell.qml"
grep -q 'exec-once = quickshell -c lumen' "$root_dir/home/.config/hypr/hyprland.conf"
grep -q 'alias cd=.z.' "$root_dir/home/.zshrc"
test -f "$root_dir/system/usr/share/sddm/themes/lumen/Main.qml"
python -c 'import sys; compile(open(sys.argv[1], encoding="utf-8").read(), sys.argv[1], "exec")' "$root_dir/iso/airootfs/usr/local/share/lumen-installer/app.py"
echo 'Static validation passed.'
