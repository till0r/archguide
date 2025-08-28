
# Before starting, goto BIOS/UEFI put Secure Boot into Setup Mode. On some 
# computers (like the GMKtec G3 Plus), you need to set an administrator
# password for the BIOS/UEFI in order for Setup Mode to be available.

### Check secure boot status:
sbctl status

### Create and enroll secure boot keys:

# You may need root access. Using `-m` adds the current Microsoft keys as well (needed for dual booting).
sbctl create-keys
sbctl enroll-keys

# Check status is installed:
sbctl status

### Check which files need signed:
sbctl verify


### Remove bootstrap images
rm /boot/initramfs-linux*

# - [ ] TODO: Delete all other unverifiable files as well?

### Automatically sign via mkinitcpio

# `mkinitcpio` will sign some files automatically via a Hook
mkinitcpio -P

### Sign all unsigned keys:

# You can also sign them by hand individually like so:
sbctl sign -s /boot/vmlinuz-linux
sbctl sign -s /boot/EFI/BOOT/BOOTX64.EFI
sbctl sign -s /boot/EFI/Linux/arch-linux-fallback.efi
sbctl sign -s /boot/EFI/Linux/arch-linux.efi
sbctl sign -s /boot/EFI/systemd/systemd-bootx64.efi

# Verify which files have not been signed yet
sbctl verify

# Sign boot loader so automatically signs new files when linux kernel,
# systemd, or boot loader updated (https://wiki.archlinux.org/title/Unified_Extensible_Firmware_Interface/Secure_Boot#Automatic_signing_with_the_pacman_hook):

sbctl sign -s -o \
/usr/lib/systemd/boot/efi/systemd-bootx64.efi.signed \
/usr/lib/systemd/boot/efi/systemd-bootx64.efi

### Verify worked
reboot

# After rebooting, make sure UEFI/BIOS has secure boot turned on. Sometimes it is still turned off after booting into setup mode. Reboot and enter UEFI/BIOS to correct if you find that Secure Boot is disabled. 
sbctl status

