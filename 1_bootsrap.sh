
### Verify the boot mode
# To verify the boot mode, check the UEFI bitness (should be 64):
cat /sys/firmware/efi/fw_platform_size

### Connect to the internet
iwctl --passphrase PASSPHRASE station wlan0 connect SSID

# Make sure connected by running (press Ctrl-c to stop):
ping archlinux.org

### Update the system clock
timedatectl

### Identify the SSD
# To identify these devices, use lsblk or fdisk:

lsblk
fdisk -l

### Perform a secure disk erasure
# SSDs with encryption are always encrypting their data even with no password
# user password set. In this way, hardware encryption is "free" performance-wise
# (though the implementation might still be vulnerable to hacking). 

# If you don't know your SSD's OPAL Admin password, or if one was never set on a
# new device, you should perform a secure disk erasure. The computer's 
# firmware/UEFI/BIOS can sometimes help you set the Admin Password too. (Look 
# under Security.)

# To perform a factory reset/secure erasure, you'll need the OPAL PSID. The 
# PSID is usually written on SSD. (Look on bottom of Samsung 990 Pro with 
# Heatsink, for example). Don't foreget, resetting the device will reset
# the OPAL password if it's set.

cryptsetup erase -v --hw-opal-factory-reset /dev/nvme0n1

### Nuke Partitions if necessary
sgdisk --zap-all /dev/nvme0n1

### Partition the disks
# Use a partitioning tool like fdisk to modify partition tables:
# Create EFI partition: 4 GiB, starting at default first sector
sgdisk --new=1:0:+4G --typecode=1:ef00 /dev/nvme0n1

# Create Linux root partition: uses remaining space
sgdisk --new=2:0:0 --typecode=2:8304 /dev/nvme0n1

# Verify partitioning
lsblk
fdisk -l


### Encrypt ssd, format and mount partitions
# Create and mount the encrypted root partition. The passphrase will be wiped 
# later, so it's ok to use a blank one. However, you need to remember the 
# OPAL Admin password that you set. `cryptsetup` should choose a fitting sector-size automatically (see https://man7.org/linux/man-pages/man8/cryptsetup-luksFormat.8.html).
cryptsetup -v luksFormat --type luks2 --hw-opal-only /dev/nvme0n1p2
cryptsetup open /dev/nvme0n1p2 cryptroot

# Format and mount encrypted root partition:
mkfs.btrfs -f -L archroot /dev/mapper/cryptroot
mount /dev/mapper/cryptroot /mnt

# Setup btrfs subovlumes
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@root
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@log
btrfs subvolume create /mnt/@cache
btrfs subvolume create /mnt/@tmp
btrfs subvolume create /mnt/@pkg
btrfs subvolume create /mnt/@srv
umount /mnt

# Mount with typical flag (inspired by cachyos)
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

# Format and mount EFI Partition:
mkfs.fat -F32 /dev/nvme0n1p1
mount --mkdir -o defaults,umask=0077 /dev/nvme0n1p1 /mnt/boot

# - [ ] TODO: tmpfs

### Install essential packages
pacstrap -K /mnt base linux linux-firmware alsa-utils gpm man-db man-pages vim networkmanager sbctl sudo tpm2-tss openssh pacman-contrib
pacstrap /mnt intel-ucode

### Generate fstab
genfstab -U /mnt >> /mnt/etc/fstab

