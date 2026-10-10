#!/usr/bin/env bash
# Install system packages and services for the Lumen desktop profile.
set -Eeuo pipefail

root_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
profile_names=(base desktop developer creator gaming)
package_files=()
aur_files=()
for profile in "${profile_names[@]}"; do
  package_files+=("$root_dir/profiles/$profile/packages.pacman")
  [[ -f "$root_dir/profiles/$profile/packages.aur" ]] && aur_files+=("$root_dir/profiles/$profile/packages.aur")
done

if [[ "${EUID}" -eq 0 ]]; then
  echo "Run this as your normal user; it invokes sudo only for system actions." >&2
  exit 1
fi
if ! command -v pacman >/dev/null; then
  echo "Lumen's installer supports Arch Linux and Arch-based systems only." >&2
  exit 1
fi

mapfile -t packages < <(sed -E '/^($|#)/d' "${package_files[@]}" | awk '!seen[$0]++')
printf 'Lumen will install %s official packages and enable desktop services.\n' "${#packages[@]}"
read -r -p 'Continue? [y/N] ' answer
[[ "$answer" =~ ^[Yy]$ ]] || { echo 'Cancelled.'; exit 0; }

sudo pacman -Syu --needed --noconfirm "${packages[@]}"
while IFS= read -r -d '' source; do
  target="/${source#"$root_dir/system/"}"
  sudo install -Dm644 "$source" "$target"
  [[ "$source" == */usr/local/bin/* || "$source" == */usr/lib/lumen/* ]] && sudo chmod 755 "$target"
done < <(find "$root_dir/system" -type f -print0)
for lumen_fragment in lumen-holds.conf lumen-local.conf; do
  include_line="Include = /etc/pacman.conf.d/$lumen_fragment"
  if ! sudo grep -Fqx "$include_line" /etc/pacman.conf; then
    if sudo grep -q '^LocalFileSigLevel = ' /etc/pacman.conf; then
      sudo sed -i "/^LocalFileSigLevel = /a $include_line" /etc/pacman.conf
    elif sudo grep -q '^\[options\]$' /etc/pacman.conf; then
      sudo sed -i "/^\[options\]$/a $include_line" /etc/pacman.conf
    else
      echo "Could not add $lumen_fragment to /etc/pacman.conf." >&2
      exit 1
    fi
  fi
done
sudo systemctl enable NetworkManager.service bluetooth.service sddm.service power-profiles-daemon.service
sudo systemctl enable docker.service
if ! groups "$USER" | grep -qw docker; then
  sudo usermod -aG docker "$USER"
  echo 'Added your user to the docker group (effective after the next login).'
fi
if [[ "$(getent passwd "$USER" | cut -d: -f7)" != "/usr/bin/zsh" ]]; then
  chsh -s /usr/bin/zsh "$USER" || echo 'Could not switch your shell automatically; run: chsh -s /usr/bin/zsh'
fi

if ! command -v yay >/dev/null; then
  build_dir="$(mktemp -d)"
  trap 'rm -rf "$build_dir"' EXIT
  echo 'Bootstrapping Yay from its AUR package recipe…'
  curl --fail --location --proto '=https' --tlsv1.2 \
    https://aur.archlinux.org/cgit/aur.git/snapshot/yay.tar.gz -o "$build_dir/yay.tar.gz"
  tar -xzf "$build_dir/yay.tar.gz" -C "$build_dir"
  (cd "$build_dir/yay" && makepkg -si --needed --noconfirm)
fi
mapfile -t aur_packages < <(sed -E '/^($|#)/d' "${aur_files[@]}" | grep -vx 'yay' | awk '!seen[$0]++' || true)
((${#aur_packages[@]})) && yay -S --needed --noconfirm "${aur_packages[@]}"

echo 'System profile installed. Run ./scripts/install-user.sh before logging in.'
