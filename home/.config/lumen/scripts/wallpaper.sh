#!/usr/bin/env bash
set -Eeuo pipefail
wallpaper="$HOME/.local/share/lumen-arch/wallpaper.png"
source="$HOME/.config/lumen/wallpaper.svg"
mkdir -p "$(dirname "$wallpaper")"
if [[ ! -f "$wallpaper" || "$source" -nt "$wallpaper" ]]; then magick "$source" "$wallpaper"; fi
pkill swaybg 2>/dev/null || true
exec swaybg -i "$wallpaper" -m fill
