#!/usr/bin/env bash
# Build Lumen's ArchISO from a non-Arch Linux host, including NixOS.
set -Eeuo pipefail

root_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
if ! command -v docker >/dev/null; then
  echo 'Docker is required. On NixOS, enable virtualisation.docker.enable first.' >&2
  exit 1
fi

uid="$(id -u)"
gid="$(id -g)"
mkdir -p "$root_dir/build/container-pacman-cache"
docker_cmd=(docker)
if ! docker info >/dev/null 2>&1; then docker_cmd=(sudo docker); fi

exec "${docker_cmd[@]}" run --rm --privileged \
  --env HOST_UID="$uid" --env HOST_GID="$gid" \
  --volume "$root_dir/build/container-pacman-cache:/var/cache/pacman/pkg" \
  --volume "$root_dir:/workspace" --workdir /workspace \
  archlinux:base-devel bash -lc \
  'pacman -Syu --noconfirm archiso sudo pacman-contrib && ./scripts/build-iso.sh && chown -R "$HOST_UID:$HOST_GID" build'
