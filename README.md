Arch Install with Encrypted Root, Secure Boot, and TPM2
=======================================================

Before booting, you may need your OPAL PSID to factory reset the SSD. 
This is usually written on the SSD. (E.G. Look on bottom of Samsung 990
Pro with Heatsink.) Take a picture with your phone of the PSID for your 
records.

Configure install envionment
----------------------------

### Verify the boot mode
To verify the boot mode, check the UEFI bitness (should be 64):
```sh
cat /sys/firmware/efi/fw_platform_size
```

### Connect to the internet
```sh
iwctl --passphrase PASSPHRASE station wlan0 connect SSID
```

Make sure connected by running (press Ctrl-c to stop):
```sh
ping archlinux.org
```

### Update the system clock
```sh
timedatectl
```

Configure the SSD
-----------------

### Identify the SSD
To identify these devices, use lsblk or fdisk:

```sh
lsblk
fdisk -l
```

### Perform a secure disk erasure
SSDs with encryption are always encrypting their data even with no password
user password set. In this way, hardware encryption is "free" performance-wise
(though the implementation might still be vulnerable to hacking). 

If you don't know your SSD's OPAL Admin password, or if one was never set on a
new device, you should perform a secure disk erasure. The computer's 
firmware/UEFI/BIOS can sometimes help you set the Admin Password too. (Look 
under Security.)

To perform a factory reset/secure erasure, you'll need the OPAL PSID. The 
PSID is usually written on SSD. (Look on bottom of Samsung 990 Pro with 
Heatsink, for example). Don't foreget, resetting the device will reset
the OPAL password if it's set.

```sh
cryptsetup erase -v --hw-opal-factory-reset /dev/nvme0n1
```

### Nuke Partitions if necessary
```sh
sgdisk --zap-all /dev/nvme0n1
```

### Partition the disks
Use a partitioning tool like fdisk to modify partition tables:
```sh
# Create EFI partition: 4 GiB, starting at default first sector
sgdisk --new=1:0:+4G --typecode=1:ef00 /dev/nvme0n1

# Create Linux root partition: uses remaining space
sgdisk --new=2:0:0 --typecode=2:8304 /dev/nvme0n1

# Verify partitioning
lsblk
fdisk -l
```


### Encrypt ssd, format and mount partitions
Create and mount the encrypted root partition. The passphrase will be wiped 
later, so it's ok to use a blank one. However, you need to remember the 
OPAL Admin password that you set. `cryptsetup` should choose a fitting sector-size automatically (see https://man7.org/linux/man-pages/man8/cryptsetup-luksFormat.8.html).
```sh
cryptsetup -v luksFormat --type luks2 --hw-opal-only /dev/nvme0n1p2
cryptsetup open /dev/nvme0n1p2 cryptroot
```

Format and mount encrypted root partition:
```sh
mkfs.btrfs -f -L archroot /dev/mapper/cryptroot
mount /dev/mapper/cryptroot /mnt
```

Setup btrfs subovlumes
```sh
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@root
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@log
btrfs subvolume create /mnt/@cache
btrfs subvolume create /mnt/@tmp
btrfs subvolume create /mnt/@pkg
btrfs subvolume create /mnt/@srv
umount /mnt
```

Mount with typical flag (inspired by cachyos)
```sh
mount -o subvol=@,defaults,noatime,compress=zstd,commit=120 /dev/mapper/cryptroot /mnt
mkdir -p /mnt/{boot,root,home,var/tmp,var/log,var/cache,srv}
mount -o subvol=@home,defaults,noatime,compress=zstd,commit=120 /dev/mapper/cryptroot /mnt/home
mount -o subvol=@root,defaults,noatime,compress=zstd,commit=120 /dev/mapper/cryptroot /mnt/root
mount -o subvol=@srv,defaults,noatime,compress=zstd,commit=120 /dev/mapper/cryptroot /mnt/srv
mount -o subvol=@cache,defaults,noatime,compress=zstd,commit=120 /dev/mapper/cryptroot /mnt/var/cache
mount -o subvol=@tmp,defaults,noatime,compress=zstd,commit=120 /dev/mapper/cryptroot /mnt/var/tmp
mount -o subvol=@log,defaults,noatime,compress=zstd,commit=120 /dev/mapper/cryptroot /mnt/var/log
mkdir -p /mnt/var/cache/pacman/pkg
mount -o subvol=@pkg,defaults,noatime,compress=no,commit=120 /dev/mapper/cryptroot /mnt/var/cache/pacman/pkg
```

Format and mount EFI Partition:
```sh
mkfs.fat -F32 /dev/nvme0n1p1
mount --mkdir -o defaults,umask=0077 /dev/nvme0n1p1 /mnt/boot
```

- [ ] TODO: tmpfs

Install essential packages
--------------------------
```sh
pacstrap -K /mnt base linux linux-firmware alsa-utils gpm intel-ucode man-db man-pages vim networkmanager sbctl sudo tpm2-tss
```

Generate fstab
--------------
```sh
genfstab -U /mnt >> /mnt/etc/fstab
```

Enter the new system environment
--------------------------------
```sh
arch-chroot /mnt
```

### Disable CoW for /var/cache/pacman/pkg
Verification is done by pacman nevertheless.
```sh
chattr +C /var/cache/pacman/pkg
```

### Time
Set time zone:
```sh
ln -sf "/usr/share/zoneinfo/$(tzselect)" /etc/localtime
```

Syncronize real-time clock:
```sh
hwclock -w
```

Add NTP servers:
```sh
mkdir /etc/systemd/timesyncd.conf.d/
vim /etc/systemd/timesyncd.conf.d/01_ntp.conf
```

Example contents:
```text
[Time]
NTP=0.us.pool.ntp.org 1.us.pool.ntp.org 2.us.pool.ntp.org 3.us.pool.ntp.org
FallbackNTP=0.arch.pool.ntp.org 1.arch.pool.ntp.org 2.arch.pool.ntp.org 3.arch.pool.ntp.org
```

### Localization
Use `less /etc/local.gen` to see available options. Uncomment lines with
locales en_US.UTF-8 and others in locale.gen
```sh
sed -i '/en_US.UTF-8/s/^#//' /etc/locale.gen
sed -i '/es_US.UTF-8/s/^#//' /etc/locale.gen
```

Generate locales:
```sh
locale-gen
```

Set locale config:
```sh
echo 'LANG=en_US.UTF-8' > /etc/locale.conf
```

### Network
```sh
echo 'COMPUTERNAME' > /etc/hostname
```

### Sudo setup
```sh
EDITOR=vim visudo -f /etc/sudoers.d/01_config
```

Contents:
```sh
%wheel ALL=(ALL:ALL) ALL
Defaults editor=/usr/bin/rvim
Defaults umask=0022
Defaults umask_override
```

If you made a mistake, when you exit vim then you'll get a message like

	What now?

In that case, type `e` to go back and fix your mistake.

Configure initial ramdisk & kernel hooks
-------------------------------------------------------------------
NOTE: ORDER IS IMPORTANT!!! Make sure has systemd, sd-vconsole, and sd-encrypt hooks. Example:
```sh
sed -i 's/^HOOKS=.*/HOOKS=(base systemd autodetect microcode modconf kms keyboard sd-vconsole keymap consolefont block sd-encrypt filesystems fsck)/' /etc/mkinitcpio.conf
```
 
Edit Preset file
```sh
# Comment the default image
sed -i 's|^default_image="/boot/initramfs-linux\.img"|#&|' /etc/mkinitcpio.d/linux.preset
# Activate UKI for the default
sudo sed -i 's|^#default_uki="/efi/EFI/Linux/arch-linux\.efi"|default_uki="/boot/EFI/Linux/arch-linux.efi"|' /etc/mkinitcpio.d/linux.preset

# Similarly, comment the default fallback image
sed -i 's|^fallback_image="/boot/initramfs-linux-fallback\.img"|#&|' /etc/mkinitcpio.d/linux.preset
# Activate UKI for the fallback
sudo sed -i 's|^#fallback_uki="/efi/EFI/Linux/arch-linux-fallback\.efi"|fallback_uki="/boot/EFI/Linux/arch-linux-fallback.efi"|' /etc/mkinitcpio.d/linux.preset
```

Create /etc/vconsole.conf
```sh
touch /etc/vconsole.conf
```

- [ ] TODO: add us layout

Install & Configure systemd-boot
--------------------------------
Install systemd-boot on the EFI partition:
```sh
bootctl install
```

Add kernel cmdline required for btrfs with luks
---------------------------------------------------------------------------
This step is necessary, because we put `.` into a subvolume (`\@`) and `/etc/fstab` is not yet available. If we were using ext4 this step would not be necessary, because the partition could be used without further explaination.
```sh
# Get the UUID of the encrypted partition
UUID=$(blkid -s UUID -o value /dev/nvme0n1p2)

cat <<EOF | sudo tee /etc/kernel/cmdline > /dev/null
root=/dev/mapper/cryptroot rw rootflags=subvol=@,defaults,noatime,compress=zstd,commit=120
rd.luks.uuid=$UUID rd.luks.name=$UUID=cryptroot quiet
EOF
```

Regenerate initial ramdisk
--------------------------
```sh
mkinitcpio -P
```

Setup users
-----------

### Set Root password
```sh
passwd
```

### Make a new user
```sh
useradd -m -G wheel USERNAME
passwd USERNAME
```

Enable services
---------------
```sh
systemctl enable gpm
systemctl enable NetworkManager
systemctl enable systemd-boot-update
systemctl enable systemd-resolved
systemctl enable systemd-timesyncd
```
 
Reboot
------
Remove installation media before booting.
```sh
exit
reboot
```

Secure Boot
-----------
Before starting, goto BIOS/UEFI put Secure Boot into Setup Mode. On some 
computers (like the GMKtec G3 Plus), you need to set an administrator
password for the BIOS/UEFI in order for Setup Mode to be available.

### Check secure boot status:
```sh
sbctl status
```

### Create and enroll secure boot keys:

You may need root access. Just prepend sbctl with `sudo ` if so. Using `-m` adds the current Microsoft keys as well (needed for dual booting).
```sh
sbctl create-keys
sbctl enroll-keys
```

Check status is installed:
```sh
sbctl status
```

### Check which files need signed:
```sh
sbctl verify
```


### Remove bootstrap images
```sh
rm /boot/initramfs-linux*
```

- [ ] TODO: Delete all other unverifiable files as well?

### Automatically sign via mkinitcpio

`mkinitcpio` will sign some files automatically via a Hook
```sh
mkinitcpio -P
```

### Sign all unsigned keys:

You can also sign them by hand individually like so:
```sh
sbctl sign -s /boot/vmlinuz-linux
sbctl sign -s /boot/EFI/BOOT/BOOTX64.EFI
sbctl sign -s /boot/EFI/Linux/arch-linux-fallback.efi
sbctl sign -s /boot/EFI/Linux/arch-linux.efi
sbctl sign -s /boot/EFI/systemd/systemd-bootx64.efi
```

Verify which files have not been signed yet
```sh
sbctl verify
```

Sign boot loader so automatically signs new files when linux kernel,
systemd, or boot loader updated (https://wiki.archlinux.org/title/Unified_Extensible_Firmware_Interface/Secure_Boot#Automatic_signing_with_the_pacman_hook):

```sh
sbctl sign -s -o \
/usr/lib/systemd/boot/efi/systemd-bootx64.efi.signed \
/usr/lib/systemd/boot/efi/systemd-bootx64.efi
```

### Verify worked
```sh
reboot
```

After rebooting, make sure UEFI/BIOS has secure boot turned on. Sometimes it is still turned off after booting into setup mode. Reboot and enter UEFI/BIOS to correct if you find that Secure Boot is disabled. 
```sh
sbctl status
```

Enroll TPM
----------
The following may need root privlidges. Just prepend with `sudo ` as usual if so.

### Create recovery key.
Transcribe it to a safe place.
```sh
systemd-cryptenroll /dev/nvme0n1p2 --recovery-key
```

### Enroll keys into TPM2.
Enter your encryption password after below command. This will use `pcr=7` only. See https://man.archlinux.org/man/systemd-cryptenroll.1#TPM2_PCRs_and_policies for more details.
```sh
systemd-cryptenroll /dev/nvme0n1p2 --wipe-slot=empty --tpm2-device=auto
```

### Verify enrolled:
```sh
cryptsetup luksDump /dev/nvme0n1p2
```

Look for `systemd-tpm2` entry under tokens.

### Reboot
```sh
reboot
```

> May whatever God you believe in have mercy on your soul. - Q

Enable zram
-----------
Adaption of https://wiki.archlinux.org/title/Zram#Using_a_udev_rule
```sh
# Create dirs (harmless if they already exist)
install -d -m 0755 /etc/modules-load.d /etc/modprobe.d /etc/udev/rules.d

# Load zram and request one device
tee /etc/modules-load.d/zram.conf >/dev/null <<'EOF'
zram
EOF
tee /etc/modprobe.d/zram.conf >/dev/null <<'EOF'
options zram num_devices=1
EOF

# Setup udev rule
tee /etc/udev/rules.d/99-zram.rules >/dev/null <<'EOF'
ACTION=="add", KERNEL=="zram0", ATTR{initstate}=="0", \
  ATTR{comp_algorithm}="zstd", ATTR{disksize}="32G", TAG+="systemd"
EOF

# Append the fstab entry if it's not already there
zram_line='/dev/zram0 none swap defaults,pri=100,x-systemd.makefs 0 0'
grep -qF "$zram_line" /etc/fstab || echo "$zram_line" | tee -a /etc/fstab >/dev/null
```

After a reboot you can verify this setup via
```sh
# zram should be visible as a device
lsblk

# zram shoulb be visible in free
free -h
```

Configure new system
--------------------

### Wifi connection
To setup without connecting until next boot, use the following:

	nmcli con add type wifi ssid SSID \
	wifi-sec.key wpa-psk wifi-sec.psk PASSPHRASE \
	con.id NAME con.mdns yes con.zone FIREWALLDZONE

To setup and connect right now, use:

	nmcli device wifi connect SSID password PASSPHRASE
	nmcli con modify SSID con.zone FIREWALLDZONE con.mdns yes

### Mouse support
This may not be necessary. My mouse was recognized without this step after logging in the first time.

Use `gpm -t help` to list supported mice. For example for Logitec mice:

	gpm -m /dev/input/mice -t logim

Tips
====

Keyboard shortcuts
------------------
* BASH defaults
    - Ctrl-k = cut to end of line
    - Ctrl-y = paste

BASH tips
---------
* This uncomments all:

		sed '/PATTERN/s/^#//g' -i FILE

	Explanation: searches for lines containing PATTERN and removes #
	from start of line. g means global; remove g for 1st instance only.

* This comments all:

		sed '/PATTERN/s/^/#/g' -i FILE

* BASH quotes:
    - 'text' is literal
    - "text" interprets $VARS \escapes \`tics\` and !history
    - $'\u2717 text' Interprets hex code unicode in the string escaped with \uXXXX

Checks
------

### Check Internet Connection
	ping archlinux.org

### Check Microcode
Microcode & CPU Family/Model/Stepping:

	journalctl -k --grep='CPU0:|microcode:'

For [Intel's Microcode](https://github.com/intel/Intel-Linux-Processor-Microcode-Data-Files),
goto the file `releasenote.md` in their repository.

### Check Security

#### Secure Boot
	sbctl status

#### TPM2
	cryptsetup luksDump /dev/nvme0n1p2

### Check Sound
	speaker-test -c 2

### Check Swap file

#### Ways to check if swap file is used
	swapon --show
	cat /proc/swaps

#### Ways to check if swap in memory
	vmstat
	free
	cat /proc/meminfo

### Check Time/Date status
	timedatectl

Maintainance
------------

### Re-enroll TPM
```
systemd-cryptenroll /dev/nvme0n1p2 --wipe-slot=1 --tpm2-device=auto
```
