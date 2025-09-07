#!/bin/bash
set -euo pipefail

### Disable CoW for /var/cache/pacman/pkg
# Verification is done by pacman nevertheless.
chattr +C /var/cache/pacman/pkg

### Time
# Set time zone `tzselect` will ask you for your local timezone:
ln -sf "/usr/share/zoneinfo/$(tzselect)" /etc/localtime

# Syncronize real-time clock:
hwclock -w

# Add NTP servers:
mkdir /etc/systemd/timesyncd.conf.d/

tee /etc/systemd/timesyncd.conf.d/01_ntp.conf > /dev/null <<'EOF'
[Time]
NTP=0.pool.ntp.org 1.pool.ntp.org 2.pool.ntp.org 3.pool.ntp.org
FallbackNTP=0.arch.pool.ntp.org 1.arch.pool.ntp.org 2.arch.pool.ntp.org 3.arch.pool.ntp.org
EOF

### Localization
# Use `less /etc/local.gen` to see available options. Uncomment lines with
# locales en_US.UTF-8 and others in locale.gen
sed -i '/en_US.UTF-8/s/^#//' /etc/locale.gen
sed -i '/en_IE.UTF-8/s/^#//' /etc/locale.gen

# Generate locales:
locale-gen

# Set locale config:
echo 'LANG=en_IE.UTF-8' > /etc/locale.conf
echo 'LC_MESSAGES=en_US.UTF-8' > /etc/locale.conf

### Network
echo 'COMPUTERNAME' > /etc/hostname


### Configure initial ramdisk & kernel hooks
# NOTE: ORDER IS IMPORTANT!!! Make sure has systemd, sd-vconsole, and sd-encrypt hooks. Example:
sed -i 's/^HOOKS=.*/HOOKS=(base systemd autodetect microcode modconf kms keyboard sd-vconsole keymap consolefont block sd-encrypt filesystems fsck)/' /etc/mkinitcpio.conf
#  
# Edit Preset file
# Comment the default image
sed -i 's|^default_image="/boot/initramfs-linux\.img"|#&|' /etc/mkinitcpio.d/linux.preset
# Activate UKI for the default
sed -i 's|^#default_uki="/efi/EFI/Linux/arch-linux\.efi"|default_uki="/boot/EFI/Linux/arch-linux.efi"|' /etc/mkinitcpio.d/linux.preset

# Similarly, comment the default fallback image
sed -i 's|^fallback_image="/boot/initramfs-linux-fallback\.img"|#&|' /etc/mkinitcpio.d/linux.preset
# Activate UKI for the fallback
sed -i 's|^#fallback_uki="/efi/EFI/Linux/arch-linux-fallback\.efi"|fallback_uki="/boot/EFI/Linux/arch-linux-fallback.efi"|' /etc/mkinitcpio.d/linux.preset

# Create /etc/vconsole.conf
touch /etc/vconsole.conf

# - [ ] TODO: explicitly add us layout

### Install & Configure systemd-boot
# Install systemd-boot on the EFI partition:
bootctl install

### Add kernel cmdline required for btrfs with luks
# This step is necessary, because we put `.` into a subvolume (`\@`) and `/etc/fstab` is not yet available. If we were using ext4 this step would not be necessary, because the partition could be used without further explaination.
# Get the UUID of the encrypted partition
UUID=$(blkid -s UUID -o value /dev/nvme0n1p2)

cat <<EOF | tee /etc/kernel/cmdline > /dev/null
root=/dev/mapper/cryptroot rw rootflags=subvol=@,defaults,noatime,compress=zstd,commit=120
rd.luks.uuid=$UUID rd.luks.name=$UUID=cryptroot quiet
EOF

### Regenerate initial ramdisk
mkinitcpio -P

### Set Root password
passwd

### Enable services
systemctl enable gpm
systemctl enable NetworkManager
systemctl enable systemd-boot-update
systemctl enable systemd-resolved
systemctl enable systemd-timesyncd
#  
### Reboot
# Remove installation media before booting.
exit
reboot

