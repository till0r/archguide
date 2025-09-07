#!/bin/bash
set -euo pipefail

# The following setup will ensure that all users in `wheel` have access to the data.
sudo mkdir -p /mnt/media0
sudo chown root:wheel /mnt/media0
sudo chmod 2770 /mnt/media0    # 2 = setgid; ensures group inheritance for newly created files and directories

sudo systemd-cryptenroll /dev/sda --wipe-slot=empty --tpm2-device=auto

# Get the UUID of the encrypted partition
UUID=$(blkid -s UUID -o value /dev/sda)

# `/etc/crypttab`
cryptmedia0     UUID=973b0b1f-745d-490c-90fd-e5bdcba59954       none    luks,tpm2-device=auto

# `/etc/fstab`
# media0
/dev/mapper/cryptmedia0 /mnt/media0     ext4            defaults,grpid,nofail                                                  0 2

