#!/bin/bash
set -euo pipefail

### Sudo setup
# Note, that it is best practice to edit `sudoers` config with `visudo` to avoid breaking your `sudo` config. Below version works for intial setups but you have been warned. :)
tee /etc/sudoers.d/01_config > /dev/null <<'EOF'
%wheel ALL=(ALL:ALL) ALL
Defaults editor=/usr/bin/vim
Defaults umask=0022
Defaults umask_override
EOF

### Network connection
# Connect to Wi-Fi
nmcli device wifi connect SSID password PASSPHRASE
nmcli con modify SSID con.mdns 1

# Setup mdns for Wired
nmcli connection modify "Wired connection 1" connection.mdns 1
nmcli connection show

### Sign pacman key
pacman-key --init
pacman-key --populate archlinux


### Enable automatic pacman cache cleaning
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

### Change to cachyos repos
wcurl https://mirror.cachyos.org/cachyos-repo.tar.xz
tar xvf cachyos-repo.tar.xz && cd cachyos-repo
./cachyos-repo.sh

# CachyOS offers a neat tool to update your systems mirrors for their repos.
pacman -S cachyos-rate-mirrors
cachyos-rate-mirrors

### Add users
# Add a user that is member of `wheel`.
useradd -mG wheel till
passwd till

