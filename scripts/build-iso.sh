#!/usr/bin/env bash
# Build a bootable x86_64 Lumen Arch installer ISO on an Arch build host.
set -Eeuo pipefail
shopt -s nullglob
root_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
work_dir="$root_dir/build/archiso-work"
out_dir="$root_dir/build/iso"
package_cache="$root_dir/build/offline-package-cache"
aur_cache="$root_dir/build/aur-package-cache"

command -v mkarchiso >/dev/null || {
  echo 'Install the archiso package first: sudo pacman -S archiso' >&2
  exit 1
}
mkdir -p "$root_dir/build" "$out_dir" "$package_cache" "$aur_cache"
# This directory contains only mkarchiso intermediates. A previous failed build
# must not leak an incomplete airootfs into the next invocation.
rm -rf "$work_dir"
mkdir -p "$work_dir"
profile_dir="$(mktemp -d "$root_dir/build/archiso-profile.XXXXXX")"
trap 'rm -rf "$profile_dir"' EXIT

# Lumen overrides ArchISO's maintained releng profile. This preserves all
# BIOS/UEFI boot-loader files while keeping our customisation small and clear.
cp -a /usr/share/archiso/configs/releng/. "$profile_dir/"
cp "$profile_dir/packages.x86_64" "$profile_dir/packages.releng.x86_64"
cp -a "$root_dir/iso/." "$profile_dir/"
# The Lumen package file is additive. Releng supplies ArchISO itself, its
# initramfs hooks, firmware and the complete boot environment.
awk 'NF && !seen[$0]++' \
  "$profile_dir/packages.releng.x86_64" \
  "$profile_dir/packages.x86_64" \
  "$root_dir/profiles/installer/packages.pacman" \
  > "$profile_dir/packages.merged.x86_64"
mv "$profile_dir/packages.merged.x86_64" "$profile_dir/packages.x86_64"
rm "$profile_dir/packages.releng.x86_64"

# Embed the complete source tree and an immutable local pacman repository.
# The installed system therefore never needs network access during installation.
mkdir -p "$profile_dir/airootfs/opt/lumen/offline/repo"
stage_repo="$profile_dir/airootfs/opt/lumen/offline/repo"
# Hard links avoid duplicating several gigabytes while keeping a persistent
# cache between builds. A refreshed pacman database downloads only new versions.
find "$package_cache" -maxdepth 1 -type f -name '*.pkg.tar.zst' -exec ln -f {} "$stage_repo"/ \;
tar --exclude=.git --exclude=build -C "$root_dir" -cf - . | tar -C "$profile_dir/airootfs/opt/lumen" -xf -
profile_names=(base desktop developer creator gaming)
package_files=("$root_dir/profiles/installer/packages.pacman")
aur_files=()
for profile in "${profile_names[@]}"; do
  package_files+=("$root_dir/profiles/$profile/packages.pacman")
  [[ -f "$root_dir/profiles/$profile/packages.aur" ]] && aur_files+=("$root_dir/profiles/$profile/packages.aur")
done
mapfile -t offline_packages < <(sed -E '/^($|#)/d' "${package_files[@]}" | awk '!seen[$0]++')
mapfile -t aur_packages < <(sed -E '/^($|#)/d' "${aur_files[@]}" | awk '!seen[$0]++')
# Resolve in an empty root rather than against the build container's installed
# packages. This forces pacman to cache every transitive dependency required by
# the target system (glibc, X11, Vulkan, and so on), not only top-level apps.
offline_root="$(mktemp -d)"
offline_conf="$(mktemp)"
# Steam is part of the default Gaming profile.  Arch container images commonly
# ship multilib commented out; append an explicit enabled section instead of
# relying on the exact formatting of the image's pacman.conf.
sed "/^\[options\]/a CacheDir = $stage_repo" /etc/pacman.conf > "$offline_conf"
if ! grep -qx '\[multilib\]' "$offline_conf"; then
  cat >> "$offline_conf" <<'EOF'

[multilib]
Include = /etc/pacman.d/mirrorlist
EOF
fi
pacstrap -K -C "$offline_conf" "$offline_root" "${offline_packages[@]}"

# pacstrap may use the build container's normal pacman cache even when a
# CacheDir is supplied.  Use the target's local package database as the source
# of truth and copy every *installed exact version* from either cache.  This
# avoids a repository with X11 libraries but without their glibc dependency.
while IFS=' ' read -r package_name package_version; do
  staged_matches=("$stage_repo/$package_name-$package_version-"*.pkg.tar.zst)
  if ((${#staged_matches[@]})); then
    continue
  fi
  cached_matches=("/var/cache/pacman/pkg/$package_name-$package_version-"*.pkg.tar.zst)
  if ((${#cached_matches[@]} == 0)); then
    echo "Offline repository is missing $package_name $package_version" >&2
    exit 1
  fi
  ln -f "${cached_matches[0]}" "$stage_repo/"
done < <(pacman -Q --root "$offline_root")

rm -rf "$offline_root"
find "$stage_repo" -maxdepth 1 -type f -name '*.pkg.tar.zst' -exec ln -f {} "$package_cache"/ \;

# Build AUR applications while the build host has internet; only their finished
# package archives are put on the ISO, never an AUR network dependency.
useradd -m -r -s /bin/bash lumen-builder 2>/dev/null || true
printf 'lumen-builder ALL=(ALL) NOPASSWD: ALL\n' > /etc/sudoers.d/lumen-builder
chmod 440 /etc/sudoers.d/lumen-builder
aur_work="$(mktemp -d)"
chown lumen-builder:lumen-builder "$aur_work"
chmod 700 "$aur_work"
trap 'rm -rf "$profile_dir" "$aur_work"' EXIT
for aur_package in "${aur_packages[@]}"; do
  cached_aur=("$aur_cache"/"$aur_package"-*.pkg.tar.zst)
  if ((${#cached_aur[@]})); then
    ln -f "${cached_aur[@]}" "$stage_repo"/
    continue
  fi
  mkdir -p "$aur_work/$aur_package"
  curl --fail --location "https://aur.archlinux.org/cgit/aur.git/snapshot/$aur_package.tar.gz" -o "$aur_work/$aur_package.tar.gz"
  tar -xzf "$aur_work/$aur_package.tar.gz" -C "$aur_work/$aur_package" --strip-components=1
  chown -R lumen-builder:lumen-builder "$aur_work/$aur_package"
  runuser -u lumen-builder -- bash -lc "cd '$aur_work/$aur_package' && makepkg --syncdeps --noconfirm --cleanbuild"
  cp "$aur_work/$aur_package"/*.pkg.tar.zst "$stage_repo/"
  cp "$aur_work/$aur_package"/*.pkg.tar.zst "$aur_cache/"
done
repo-add "$stage_repo/lumen-offline.db.tar.gz" "$stage_repo"/*.pkg.tar.zst

# AUR packages may introduce official runtime dependencies which are absent
# from the explicitly requested profile packages.  Resolve the final set once
# more against the local repository and stage that exact closure as well.
printf '\n[lumen-build]\nSigLevel = Optional TrustAll\nServer = file://%s\n' "$stage_repo" >> "$offline_conf"
complete_root="$(mktemp -d)"
pacstrap -K -C "$offline_conf" "$complete_root" "${offline_packages[@]}" "${aur_packages[@]}"
while IFS=' ' read -r package_name package_version; do
  staged_matches=("$stage_repo/$package_name-$package_version-"*.pkg.tar.zst)
  if ((${#staged_matches[@]})); then
    continue
  fi
  cached_matches=("/var/cache/pacman/pkg/$package_name-$package_version-"*.pkg.tar.zst)
  if ((${#cached_matches[@]} == 0)); then
    echo "Offline repository is missing $package_name $package_version" >&2
    exit 1
  fi
  ln -f "${cached_matches[0]}" "$stage_repo/"
done < <(pacman -Q --root "$complete_root")
rm -rf "$complete_root" "$offline_conf"
repo-add "$stage_repo/lumen-offline.db.tar.gz" "$stage_repo"/*.pkg.tar.zst

if [[ "$EUID" -eq 0 ]]; then
  mkarchiso -v -r -w "$work_dir" -o "$out_dir" "$profile_dir"
else
  sudo mkarchiso -v -r -w "$work_dir" -o "$out_dir" "$profile_dir"
fi
