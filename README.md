# Arch Install with Encrypted Root, Secure Boot, and TPM2 - powered by btrfs and cachyos

**Base System**
- OPAL/LUKS encrypted root
- TPM2 stored decryption key with auto-unlock
- Secure Boot protected UKI
- systemd-boot
- Snapshot-ready btrfs

**Optional**
- CachyOS repos
- sudo
- GNOME
- Podman/Quadlet server
- OpenSSH server
- restic backups

Before booting, you may need your OPAL PSID to factory reset the SSD. 
This is usually written on the SSD.

## Config
- [ ] TODO: Add config section

## Connect to Wi-Fi
iwctl --passphrase PASSPHRASE station wlan0 connect SSID

## Bootsrap
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
Use a partitioning tool like fdisk to modify partition tables - `--new` will implicitly create a new GPT partition table:
```sh
# Create EFI partition: 16 GiB, starting at default first sector
sgdisk --new=1:0:+16G --typecode=1:ef00 /dev/nvme0n1

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
mount -o subvol=@,defaults,noatime,compress=zstd:1,commit=120 /dev/mapper/cryptroot /mnt
mkdir -p /mnt/{boot,root,home,var/tmp,var/log,var/cache,srv}
mount -o subvol=@home,defaults,noatime,compress=zstd:1,commit=120 /dev/mapper/cryptroot /mnt/home
mount -o subvol=@root,defaults,noatime,compress=zstd:1,commit=120 /dev/mapper/cryptroot /mnt/root
mount -o subvol=@srv,defaults,noatime,compress=zstd:1,commit=120 /dev/mapper/cryptroot /mnt/srv
mount -o subvol=@cache,defaults,noatime,compress=zstd:1,commit=120 /dev/mapper/cryptroot /mnt/var/cache
mount -o subvol=@tmp,defaults,noatime,compress=zstd:1,commit=120 /dev/mapper/cryptroot /mnt/var/tmp
mount -o subvol=@log,defaults,noatime,compress=zstd:1,commit=120 /dev/mapper/cryptroot /mnt/var/log
mkdir -p /mnt/var/cache/pacman/pkg
mount -o subvol=@pkg,defaults,noatime,compress=no,commit=120 /dev/mapper/cryptroot /mnt/var/cache/pacman/pkg
```

Format and mount EFI Partition:
```sh
mkfs.fat -F32 /dev/nvme0n1p1
mount --mkdir -o defaults,umask=0077 /dev/nvme0n1p1 /mnt/boot
```

- [ ] TODO: tmpfs

### Install essential packages
```sh
pacstrap -K /mnt base linux linux-firmware alsa-utils gpm man-db man-pages vim networkmanager sbctl sudo tpm2-tss openssh pacman-contrib git
pacstrap /mnt intel-ucode
pacstrap /mnt dosfstools
```

### Generate fstab
```sh
genfstab -U /mnt >> /mnt/etc/fstab
```

## Enter the new system environment
```sh
arch-chroot /mnt
```

## Userspace
### Disable CoW for /var/cache/pacman/pkg
Verification is done by pacman nevertheless.
```sh
chattr +C /var/cache/pacman/pkg
```

### Time
Set time zone `tzselect` will ask you for your local timezone:
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

tee /etc/systemd/timesyncd.conf.d/01_ntp.conf > /dev/null <<'EOF'
[Time]
NTP=0.pool.ntp.org 1.pool.ntp.org 2.pool.ntp.org 3.pool.ntp.org
FallbackNTP=0.arch.pool.ntp.org 1.arch.pool.ntp.org 2.arch.pool.ntp.org 3.arch.pool.ntp.org
EOF
```

### Localization
Use `less /etc/local.gen` to see available options. Uncomment lines with
locales en_US.UTF-8 and others in locale.gen
```sh
sed -i '/en_US.UTF-8/s/^#//' /etc/locale.gen
sed -i '/en_IE.UTF-8/s/^#//' /etc/locale.gen
```

Generate locales:
```sh
locale-gen
```

Set locale config:
```sh
echo 'LANG=en_IE.UTF-8' > /etc/locale.conf
echo 'LC_MESSAGES=en_US.UTF-8' > /etc/locale.conf
```

### Network
```sh
echo 'COMPUTERNAME' > /etc/hostname
```


### Configure initial ramdisk & kernel hooks
NOTE: ORDER IS IMPORTANT!!! Make sure has systemd, sd-vconsole, and sd-encrypt hooks. Example:
```sh
sed -i 's/^HOOKS=.*/HOOKS=(base systemd autodetect microcode modconf kms keyboard sd-vconsole keymap consolefont block sd-encrypt filesystems fsck)/' /etc/mkinitcpio.conf
```
 
Edit Preset file
```sh
# Comment the default image
sed -i 's|^default_image="/boot/initramfs-linux\.img"|#&|' /etc/mkinitcpio.d/linux.preset
# Activate UKI for the default
sed -i 's|^#default_uki="/efi/EFI/Linux/arch-linux\.efi"|default_uki="/boot/EFI/Linux/arch-linux.efi"|' /etc/mkinitcpio.d/linux.preset

# Similarly, comment the default fallback image
sed -i 's|^fallback_image="/boot/initramfs-linux-fallback\.img"|#&|' /etc/mkinitcpio.d/linux.preset
# Activate UKI for the fallback
sed -i 's|^#fallback_uki="/efi/EFI/Linux/arch-linux-fallback\.efi"|fallback_uki="/boot/EFI/Linux/arch-linux-fallback.efi"|' /etc/mkinitcpio.d/linux.preset
```

Create /etc/vconsole.conf
```sh
touch /etc/vconsole.conf
```

- [ ] TODO: explicitly add us layout

### Install & Configure systemd-boot
Install systemd-boot on the EFI partition:
```sh
bootctl install
```

### Add kernel cmdline required for btrfs with luks
This step is necessary, because we put `.` into a subvolume (`\@`) and `/etc/fstab` is not yet available. If we were using ext4 this step would not be necessary, because the partition could be used without further explaination.
```sh
# Get the UUID of the encrypted partition
UUID=$(blkid -s UUID -o value /dev/nvme0n1p2)

cat <<EOF | tee /etc/kernel/cmdline > /dev/null
root=/dev/mapper/cryptroot rw rootflags=subvol=@,defaults,noatime,compress=zstd,commit=120 rd.luks.uuid=$UUID rd.luks.name=$UUID=cryptroot quiet libata.allow_tpm=1
EOF
```

### Regenerate initial ramdisk
```sh
mkinitcpio -P
```

### Set Root password
```sh
passwd
```

### Enable services
```sh
systemctl enable gpm
systemctl enable NetworkManager
systemctl enable systemd-boot-update
systemctl enable systemd-resolved
systemctl enable systemd-timesyncd
```
 
### Reboot
Remove installation media before booting.
```sh
exit
reboot
```

## Secure Boot
Before starting, goto BIOS/UEFI put Secure Boot into Setup Mode. On some 
computers (like the GMKtec G3 Plus), you need to set an administrator
password for the BIOS/UEFI in order for Setup Mode to be available.

### Check secure boot status:
```sh
sbctl status
```

### Create and enroll secure boot keys:

You may need root access. Using `-m` adds the current Microsoft keys as well (needed for dual booting).
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

## Enroll TPM
The following may need root privlidges.

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

## Enable zram
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

## Configure new system
### Sudo setup
Note, that it is best practice to edit `sudoers` config with `visudo` to avoid breaking your `sudo` config. Below version works for intial setups but you have been warned. :)
```sh
tee /etc/sudoers.d/01_config > /dev/null <<'EOF'
%wheel ALL=(ALL:ALL) ALL
Defaults editor=/usr/bin/vim
Defaults umask=0022
Defaults umask_override
EOF
```

### Network connection
Connect to Wi-Fi - where `SSID` is your SSID
```sh
nmcli device wifi connect SSID password PASSPHRASE
nmcli connection modify SSID connection.mdns 2
nmcli connection modify SSID connection.autoconnect no
```

Setup mdns for Wired
```sh
nmcli connection modify "Wired connection 1" connection.mdns 2
nmcli connection show
```

### Sign pacman key
```sh
pacman-key --init
pacman-key --populate archlinux
```


### Enable automatic pacman cache cleaning
```sh
tee /etc/pacman.d/hooks/clean_cache.hook > /dev/null <<'EOF'
[Trigger]
Operation = Install
Operation = Upgrade
Operation = Remove
Type = Package
Target = *

[Action]
Description = Trim pacman cache: keep 2 for installed, purge uninstalled
When = PostTransaction
Depends = pacman-contrib
Exec = /bin/sh -c '/usr/bin/paccache -r -k2 && /usr/bin/paccache -r -u -k0'
EOF
```

### Change to cachyos repos
```sh
wcurl https://mirror.cachyos.org/cachyos-repo.tar.xz
tar xvf cachyos-repo.tar.xz && cd cachyos-repo
./cachyos-repo.sh
```

CachyOS offers a neat tool to update your systems mirrors for their repos.
```sh
pacman -S cachyos-rate-mirrors
cachyos-rate-mirrors
```

### Add users
Add a user that is member of `wheel`.
```sh
useradd -mG wheel till
passwd till
```

## Desktop Experience
### Install graphics and sound
```sh
pacman -S vulkan-intel  # TODO: only for intel
pacman -S pipewire pipewire-alsa pipewire-pulse pipewire-jack wireplumber
```

### Install GNOME
```sh
pacman -S gnome-shell gnome-settings-daemon gnome-tweaks gnome-shell-extensions xdg-desktop-portal-gnome gdm
pacman -S noto-fonts noto-fonts-cjk noto-fonts-emoji ttf-dejavu

pacman -S gnome-control-center gnome-disk-utility gnome-font-viwer gnome-keyring gnome-menus gnome-system-monitor loupe natilus papers papers-lib-docs snapshot sushi ptyxis gnome-browser-connector gnome-font-viewer

pacman -S ttf-0xproto-nerd

pacman -S --needed power-profiles-daemon
systemctl enable --now power-profiles-daemon

pacman -S --needed cups system-config-printer
systemctl enable --now cups

pacman -S firefox ffmpeg

systemctl enable --now gdm
```

- [ ] TODO: Hardware acceleration https://wiki.archlinux.org/title/Hardware_video_acceleration

## Server Experience
### Config and start ssh
```sh
sudo sed -i 's/^[#[:space:]]*PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config

systemctl enable --now sshd.service
```

### Install msmtp
```sh
pacman -S msmtp msmtp-mta s-nail
```

- [ ] Create `config` in `$XDG_CONFIG_HOME/msmtp/` and apply `chmod 600`

Test msmtp config.
```sh
printf "To: test@example.org\nSubject: msmtp test\n\nBody\n" | msmtp -a default -t
```

### Install Cockpit
```sh
pacman -S cockpit cockpit-podman cockpit-storaged cockpit-packagekit udisks2-btrfs udisks2-docs udisks2-lvm2
```

```sh
mkdir -p /etc/systemd/system/cockpit.socket.d/

tee /etc/systemd/system/cockpit.socket.d/listen.conf > /dev/null <<'EOF'
[Socket]
ListenStream=
ListenStream=443
EOF
```

```sh
systemctl enable --now cockpit.socket
```

### Disable Notebook Lid
```sh
sudo sed -i 's/^[#[:space:]]*HandleLidSwitch=.*/HandleLidSwitch=ignore/' /etc/systemd/logind.conf
systemctl restart systemd-logind.service
```

### Disable bluetooth and wifi
```sh
rfkill block wifi
rfkill block bluetooth
```

## Add more encrypted disks
If we aim to encrypt the entire disk, we do not need to use `sgdisk` to create a partition. That's why in the following there is no partition specifier used.
Note, that `--hw-opal-only` cannot be used with USB disks - `sedutil` can be used for that, but at the sake of comfort.
```sh
sudo cryptsetup -v luksFormat --type luks2 --hw-opal-only /dev/sda
sudo cryptsetup open /dev/sda cryptmedia0
```

The partition needs to be formatted.
```sh
sudo mkfs.ext4 /dev/mapper/cryptmedia0
```

The following setup will ensure that all users in `wheel` have access to the data.
```sh
sudo mkdir -p /mnt/media0
sudo chown till:wheel /mnt/media0
chmod 2770 /mnt/media0    # 2 = setgid; ensures group inheritance for newly created files and directories (notice no longer sudo)

sudo systemd-cryptenroll /dev/sda --wipe-slot=empty --tpm2-device=auto

# Get the UUID of the encrypted partition
UUID=$(blkid -s UUID -o value /dev/sda)
```

`/etc/crypttab`
```sh
cryptmedia0     UUID=973b0b1f-745d-490c-90fd-e5bdcba59954       none    luks,tpm2-device=auto,nofail,timeout=0
```

`/etc/fstab`
Add the drive to fstab and tell the ssystem to not block boot `nofail`, create a systemd automount unit (which we can use to only start certain servies, if the mount point becomes available) and a wait forever for the device, which again is useful for USB disks etc.
```sh
# media0
/dev/mapper/cryptmedia0 /mnt/media0     ext4            defaults,grpid,nofail,x-systemd.automount,x-systemd.device-timeout=0                                                0 2
```

## Run quadlets
```sh
ln -s ~/dotfiles/homeassistant.container ~/.config/containers/systemd/homeassistant.container

systemctl --user daemon-reload
systemctl --user start homeassistant.service
# systemctl --user restart homeassistant.service
```

Enable start of service before first login.
```sh
loginctl enable-linger "$USER"
```

Add user to uucp
```sh
sudo usermod -aG uucp $USER
```

Use stow to deploy services
```sh
stow -d ~/quadlets -t ~/.config/containers/systemd -S paperless

# Unstow (remove symlinks):
#stow -d ~/quadlets -t ~/.config/containers/systemd -D paperless 
```

Use ln instead
```sh
ln -s ~/quadlets/restic/restic-backup-srv.container ~/.config/containers/systemd/restic-backup-srv.container
ln -s ~/quadlets/restic/restic-backup-srv.timer ~/.config//systemd/user/restic-backup-srv.timer
```

Verify links
```sh
ls -l ~/.config/containers/systemd | grep paperless
```

Reload unit files
```sh
systemctl --user daemon-reload
```

Check for quadlet errors
```sh
journalctl --user -b -e -g quadlet
```

List unit files
```sh
systemctl --user list-unit-files
```

Start a unit file or timer
```sh
systemctl --user start restic-backup-srv.service
systemctl --user enable --now restic-backup-srv.timer
```

Follow a container along
```sh
journalctl --user -u restic-backup-srv.service -f
```

Review past logs
```sh
journalctl --user -xeu restic-backup-srv.service
```

## Backups via restic
### Prepare ssh environment
```sh
sudo mkdir -p /srv/restic/{ssh,cache,excludes}
# repo password for restic (NOT your SSH key passphrase)
echo 'change-me-long-random' | sudo tee /srv/restic/password.txt >/dev/null
sudo chmod 600 /srv/restic/password.txt

# put your SSH private key here (or copy existing)
sudo cp ~/.ssh/id_ed25519 /srv/restic/ssh/
sudo chmod 600 /srv/restic/ssh/id_ed25519
```

```sh
ssh-keyscan -p 22 backup.example.com | sudo tee -a /srv/restic/ssh/known_hosts >/dev/null
sudo chmod 644 /srv/restic/ssh/known_hosts
```

```sh
sudo tee /srv/restic/ssh/config >/dev/null <<'EOF'
Host restic-target
    HostName backup.example.com
    User u12345
    Port 22
    IdentityFile /root/.ssh/id_ed25519
EOF
sudo chmod 644 /srv/restic/ssh/config
```

```sh
sudo tee /srv/restic/restic.env >/dev/null <<'EOF'
# Use SSH alias above (or use sftp://u@host:22//path syntax)
RESTIC_REPOSITORY=sftp:restic-target:/home/u12345/restic-repo
RESTIC_PASSWORD_FILE=/config/password.txt
RESTIC_CACHE_DIR=/cache
# Quiet progress in logs (optional)
RESTIC_PROGRESS_FPS=0
EOF
sudo chmod 640 /srv/restic/restic.env
```

```sh
sudo tee /srv/restic/excludes/folderA.txt >/dev/null <<'EOF'
# one path per line, relative to the mounted source
subfolder-to-skip/
another-subfolder/
EOF
```

### Init the repo
```sh
podman run --rm --network host   -v /srv/restic:/config:ro   -v /srv/restic/ssh:/root/.ssh:ro   -v /srv/restic/cache:/cache   -e RESTIC_REPOSITORY="sftp:restic-storagebox:/backups/restic-repo"   -e RESTIC_PASSWORD_FILE="/config/secret/password.txt"   docker.io/restic/restic:latest init
```

### Quadlets
```toml
[Unit]
Description=Restic backup /srv

[Container]
Image=docker.io/restic/restic:latest
ContainerName=restic-backup-srv
Network=host
Volume=/srv/restic:/config:ro
Volume=/srv/restic/ssh:/root/.ssh:ro
Volume=/srv/restic/cache:/cache
Volume=/srv:/srv:ro
EnvironmentFile=/srv/restic/restic.env
Exec=backup /srv --one-file-system --exclude-file /config/srv_backup_excludes.txt
NoNewPrivileges=true
ReadOnly=true

[Service]
RuntimeMaxSec=1h

[Install]
WantedBy=default.target
```

```toml
[Unit]
Description=Timer: restic-backup-srv

[Timer]
OnCalendar=*-*-* 00:00:00
RandomizedDelaySec=1m
Persistent=true

[Install]
WantedBy=timers.target
```

## Tips

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

## Maintainance
### Re-enroll TPM
```
systemd-cryptenroll /dev/nvme0n1p2 --wipe-slot=1 --tpm2-device=auto
```

## Non-Urgent TODOs
- [ ] Add a [plymouth splash with SimpleDRM](https://wiki.archlinux.org/title/Plymouth#Using_SimpleDRM)
