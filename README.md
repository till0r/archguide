Arch with encrypted root, Secure Boot, and TPM2
===============================================

Verify the boot mode
--------------------
To verify the boot mode, check the UEFI bitness (should be 64):

	cat /sys/firmware/efi/fw_platform_size

Connect to the internet
-----------------------
	iwctl --passphrase PASSWORD station wlan0 connect SSID
	ping archlinux.org

Update the system clock
-----------------------
	timedatectl

Partition the disks
-------------------
To identify these devices, use lsblk or fdisk:

	fdisk -l

Use a partitioning tool like fdisk to modify partition tables:

	fdisk /dev/nvme0n1

Create table:

* g - Create a new GPT partition table
* n - Create new partition (EFI)
    - Accept default partition number
    - Accept default first sector
    - Enter "+4G" for size
* n - Create new partition (Linux filesystem)
    - Accept defaults to use the remaining space
* w - Write changes and exit

Encrypt ssd, format and mount partitions
----------------------------------------
Create and mount the encrypted root partition:

	cryptsetup -v luksFormat --hw-opal-only /dev/nvme0n1p2
	cryptsetup open /dev/nvme0n1p2 root

Format and mount encrypted root partition:

	mkfs.ext4 /dev/mapper/root
	mount /dev/mapper/root /mnt

Check the mapping works as intended:

	umount /mnt
	cryptsetup close root
	cryptsetup open /dev/nvme0n1p2 root
	mount /dev/mapper/root /mnt

Format and mount EFI Partition:

	mkfs.fat -F32 /dev/nvme0n1p1
	mount --mkdir /dev/nvme0n1p1 /mnt/boot

Install essential packages
--------------------------
	pacstrap /mnt alsa-utils base firewalld gpm \
    intel-ucode linux linux-firmware man-db man-pages \
    nano networkmanager sbctl sudo tpm2-tss

Enter the new system environment
--------------------------------
	arch-chroot /mnt

Setup initial settings
----------------------
	systemd-firstboot --prompt

Syncronize real-time clock
--------------------------
	hwclock -w

Add NTP servers
---------------
	mkdir /etc/systemd/timesyncd.conf.d/
	nano /etc/systemd/timesyncd.conf.d/01_ntp.conf

Contents:

	[Time]
	NTP=0.us.pool.ntp.org 1.us.pool.ntp.org 2.us.pool.ntp.org 3.us.pool.ntp.org
	FallbackNTP=0.arch.pool.ntp.org 1.arch.pool.ntp.org 2.arch.pool.ntp.org 3.arch.pool.ntp.org

Localization
------------
Edit locale.gen to uncomment value of $LANG

	sed -i "/$LANG/s/^#//" /etc/locale.gen

Generate locale:

	locale-gen

Mouse support
-------------
(use `gpm -m /dev/input/mice -t help` to list supported mice)

	gpm -m /dev/input/mice -t logim

Sudo setup
----------
    mkdir /etc/sudoers.d/
    EDITOR=nano visudo -f /etc/sudoers.d/01_config

Contents:

	%wheel ALL=(ALL:ALL) ALL
	Defaults editor=/usr/bin/rnano
	Defaults pwfeedback
	Defaults umask = 0022
	Defaults umask_override

Swapfile (16GB)
---------------
	fallocate -l 16GB /swapfile
	chmod 600 /swapfile
	mkswap /swapfile
	swapon /swapfile

Add to systemd:

	systemctl -fl edit swapfile.swap

Contents:

	[Swap]
	What=/swapfile
	
	[Install]
	WantedBy=swap.target

Wifi setup
----------
	nmcli con add type wifi ssid SSID \
	wifi-sec.key wpa-psk wifi-sec.psk PASSWORD \
	con.id "NETWORKNAME" con.mdns yes con.zone FIREWALLDZONE

Enable services
---------------
	systemctl enable firewalld.service
	systemctl enable gpm.service
	systemctl enable NetworkManager.service
	systemctl enable swapfile.swap
	systemctl enable systemd-resolved.service
	systemctl enable systemd-timesyncd.service

Configure mkinitcpio
--------------------
	mkdir /etc/mkinitcpio.conf.d/
	sed '/^HOOKS/p' /etc/mkinitcpio.conf \
    > /etc/mkinitcpio.conf.d/01_hooks.conf
	nano /etc/mkinitcpio.conf.d/01_hooks.conf

NOTE: ORDER IS IMPORTANT!!! Make sure has systemd, sd-vconsole, and 
sd-encrypt hooks. Example:

	HOOKS=(base systemd autodetect microcode modconf kms keyboard sd-vconsole block sd-encrypt filesystems fsck)

Install & Configure systemd-boot
--------------------------------
Install systemd-boot on the EFI partition:

	bootctl install

Enable updates when bootloader updated.

	bootctl --no-variables --graceful update

Regenerate initial ramdisk
--------------------------
	mkinitcpio -P

Reboot
------
Remove installation media before booting.

	exit
	swapoff /mnt/swapfile
	umount -a
	reboot

Secure Boot
-----------
Before starting, goto BIOS/UEFI put Secure Boot into Setup mode.
Check secure boot status:

	sbctl status

Create and enroll secure boot keys:

	sbctl create-keys
	sbctl enroll-keys -m

Check status is installed:

	sbctl status

Check which files need signed:

	sbctl verify

Sign all unsigned keys:
(Usually just kernel and boot loarder, used in example below)

	sbctl sign -s /boot/vmlinuz-linux
	sbctl sign -s /boot/EFI/BOOT/BOOTX64.EFI

Tip: If a lot of files need verified, use following:

	sbctl verify | sed 's/✗ /sbctl sign -s /e'

Sign boot loader so automatically signs new files when linux kernel,
systemd, or boot loader updated:

	sbctl sign -s -o \
    /usr/lib/systemd/boot/efi/systemd-bootx64.efi.signed \
    /usr/lib/systemd/boot/efi/systemd-bootx64.efi

Enroll TPM
----------
Create recovery key.

	systemd-cryptenroll /dev/nvme0n1p2 --recovery-key

Add `--tpm2-with-pin=yes` at end to require a pin to unlock drive.

	systemd-cryptenroll /dev/nvme0n1p2 \
	--wipe-slot=empty --tpm2-device=auto --tpm2-pcrs=7

Make a new user
---------------
	useradd -m -G wheel <username>
	passwd <username>

Reboot
------
	reboot

Tips
====

* BASH/nano defaults
    - Ctrl-k = cut to end of line
    - Ctrl-Y = paste

* This uncomments all:

		sed '/PATTERN/s/^#//g' -i FILE

	Explanation: searches for lines containing PATTERN and removes #
	from start of line. g means global; remove g for 1st instance only.

* This comments all:

		sed '/PATTERN/s/^/#/g' -i FILE

* BASH quotes:
    - 'text' is literal
    - "text" interprets $VARS \escapes \`tics\` and !history

Checks
======

Check Internet Connection
-------------------------
    ping archlinux.org

Check Microcode
---------------
Microcode & CPU Family/Model/Stepping:

    journalctl -k --grep='CPU0:|microcode:'

For Intel, look up on github page, goto releasenote.md at 
https://github.com/intel/Intel-Linux-Processor-Microcode-Data-Files

An alternative to check that microcode is installed is to verify that
/boot/intel-ucode.img exists (for Intel).

Another alternative is to check that kernel/x86/microcode/GenuineIntel.bin
is in the output of:

    lsinitcpio --early /boot/initramfs-linux.img | grep microcode

Check Sound
-----------
    speaker-test -c 2

Ways to check if swap file is used
----------------------------------
    swapon --show
    cat /proc/swaps

Ways to check if swap in memory
-------------------------------
    vmstat
    free
    cat /proc/meminfo

Check Time/Date status
----------------------
    timedatectl
