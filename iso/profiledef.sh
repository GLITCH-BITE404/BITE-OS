#!/usr/bin/env bash
# shellcheck disable=SC2034
# ━━━ BITE-OS — archiso profile definition ━━━
# This overlays the stock archiso `releng` profile. build-iso.sh copies releng
# then drops these custom files on top.

iso_name="bite-os"
iso_label="BITE_OS_$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y%m)"
iso_publisher="BITE-OS <https://tiktok.com/@glitchbite404>"
iso_application="BITE-OS Live / Install Medium"
iso_version="1.0"
install_dir="arch"
buildmodes=('iso')
bootmodes=('bios.syslinux.mbr' 'bios.syslinux.eltorito'
           'uefi-x64.systemd-boot.esp' 'uefi-x64.systemd-boot.eltorito')
arch="x86_64"
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
airootfs_image_tool_options=('-comp' 'zstd' '-Xcompression-level' '19' '-b' '1M')
bootstrap_tarball_compression=('zstd' '-c' '-T0' '--auto-threads=logical' '-19')
file_permissions=(
  ["/etc/shadow"]="0:0:400"
  ["/etc/gshadow"]="0:0:400"
  ["/root"]="0:0:750"
  ["/root/.automated_script.sh"]="0:0:755"
  ["/root/customize_airootfs.sh"]="0:0:755"
  ["/usr/local/bin/choose-mirror"]="0:0:755"
  ["/usr/local/bin/Installation_guide"]="0:0:755"
  ["/usr/local/bin/livecd-sound"]="0:0:755"
  ["/usr/local/bin/bite-os-live-setup"]="0:0:755"
  ["/usr/local/bin/install-bite-os"]="0:0:755"
  ["/usr/local/bin/bite-os-hyprland-session"]="0:0:755"
  ["/usr/local/bin/bite-os-launch-installer"]="0:0:755"
  ["/usr/local/bin/bite-os-installer-session"]="0:0:755"
  ["/usr/local/bin/bite-os-kiosk"]="0:0:755"
  ["/usr/local/bin/bite-os-firstboot-cleanup"]="0:0:755"
  ["/usr/local/bin/bite-os-verify-install"]="0:0:755"
)
