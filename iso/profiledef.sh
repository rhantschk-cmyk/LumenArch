#!/usr/bin/env bash
# ArchISO profile used to create a Lumen installation medium.
iso_name="lumen-arch"
iso_label="LUMEN_$(date +%Y%m)"
iso_publisher="Lumen Arch <https://github.com/your-account/lumen-arch>"
iso_application="Lumen Arch installer"
iso_version="$(date +%Y.%m.%d)"
install_dir="arch"
buildmodes=('iso')
bootmodes=('bios.syslinux' 'uefi.systemd-boot')
arch="x86_64"
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
airootfs_image_tool_options=('-comp' 'zstd' '-Xcompression-level' '15')
file_permissions=(
  ["/root/customize_airootfs.sh"]="0:0:755"
  ["/root/.bash_profile"]="0:0:644"
  ["/usr/local/bin/lumen-install"]="0:0:755"
  ["/usr/local/bin/lumen-offline-install"]="0:0:755"
  ["/usr/local/share/lumen-installer/app.py"]="0:0:755"
)
