#!/usr/bin/env bash
# Install Lumen's user-scoped configuration without overwriting untracked files.
set -Eeuo pipefail

root_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
source_dir="$root_dir/home"
backup_dir="$HOME/.local/share/lumen-arch/backups/$(date +%Y%m%d-%H%M%S)"

if [[ "${EUID}" -eq 0 ]]; then
  echo 'Run this as the desktop user, not root.' >&2
  exit 1
fi

copy_file() {
  local source="$1" target="$2"
  mkdir -p "$(dirname "$target")"
  if [[ -e "$target" ]] && ! cmp -s "$source" "$target"; then
    mkdir -p "$backup_dir/$(dirname "${target#"$HOME"/}")"
    cp -a "$target" "$backup_dir/${target#"$HOME"/}"
    echo "Backed up $target"
  fi
  if [[ "$source" == *.sh || "$source" == "$source_dir/.config/lumen/bin/"* ]]; then
    install -Dm755 "$source" "$target"
  else
    install -Dm644 "$source" "$target"
  fi
}

while IFS= read -r -d '' source; do
  relative="${source#"$source_dir"/}"
  copy_file "$source" "$HOME/$relative"
done < <(find "$source_dir" -type f -print0)

mkdir -p "$HOME/Pictures/Screenshots" "$HOME/.local/bin"
echo 'User configuration installed. Log out and select Hyprland in SDDM.'
