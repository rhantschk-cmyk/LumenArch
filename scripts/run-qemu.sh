#!/usr/bin/env bash
# Start the newest Lumen ISO in a disposable UEFI QEMU test machine.
set -Eeuo pipefail

script_path="$(readlink -f -- "$0")"
root_dir="$(cd -- "$(dirname -- "$script_path")/.." && pwd)"

if [[ "${LUMEN_QEMU_SHELL:-}" != "1" ]]; then
  exec nix shell nixpkgs#qemu nixpkgs#OVMF -c env LUMEN_QEMU_SHELL=1 "$script_path"
fi

iso_dir="${LUMEN_ISO_DIR:-$root_dir/build/iso}"
iso="$(find "$iso_dir" -maxdepth 1 -type f -name '*.iso' -printf '%T@ %p\n' | sort -n | tail -n1 | cut -d' ' -f2-)"
[[ -n "$iso" && -f "$iso" ]] || { echo "No ISO found in $iso_dir." >&2; exit 1; }
mapfile -t newer_inputs < <(find "$root_dir"/profiles "$root_dir"/iso "$root_dir"/offline \
  "$root_dir"/home "$root_dir"/system "$root_dir"/scripts -type f -newer "$iso" -print)
if ((${#newer_inputs[@]})); then
  echo "The newest ISO is older than the current source tree: $iso" >&2
  echo 'Build a fresh ISO before running QEMU; refusing to test a stale image.' >&2
  exit 1
fi

vm_dir="${LUMEN_VM_DIR:-$HOME/VMs/lumen-test}"
mkdir -p "$vm_dir"
disk="$vm_dir/lumen.qcow2"
vars="$vm_dir/OVMF_VARS.fd"
ovmf_dir="$(nix build --no-link --print-out-paths nixpkgs#OVMF.fd)"
code="$(find "$ovmf_dir" -type f -name 'OVMF_CODE*.fd' -print -quit)"
vars_template="$(find "$ovmf_dir" -type f -name 'OVMF_VARS*.fd' -print -quit)"
[[ -n "$code" && -n "$vars_template" ]] || { echo 'Could not locate OVMF firmware.' >&2; exit 1; }

[[ -f "$disk" ]] || qemu-img create -f qcow2 "$disk" 64G
[[ -f "$vars" ]] || cp "$vars_template" "$vars"

echo "Booting: $iso"
echo "Virtual disk: $disk"
exec qemu-system-x86_64 \
  -enable-kvm -machine q35,accel=kvm -cpu host -m 8G -smp 4 \
  -display gtk -device virtio-vga \
  -drive if=pflash,format=raw,readonly=on,file="$code" \
  -drive if=pflash,format=raw,file="$vars" \
  -drive file="$iso",media=cdrom,readonly=on \
  -drive file="$disk",format=qcow2,if=virtio \
  -boot order=d -nic user,model=virtio-net-pci
