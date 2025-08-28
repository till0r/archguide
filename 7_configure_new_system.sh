

### Sudo setup
# Note, that it is best practice to edit `sudoers` config with `visudo` to avoid breaking your `sudo` config. Below version works for intial setups but you have been warned. :)
sudo tee /etc/sudoers.d/01_config > /dev/null <<'EOF'
%wheel ALL=(ALL:ALL) ALL
Defaults editor=/usr/bin/vim
Defaults umask=0022
Defaults umask_override
EOF

### Network connection
# Connect to Wi-Fi
nmcli device wifi connect SSID password PASSPHRASE
nmcli con modify SSID con.mdns yes

# Setup mdns for Wired
# - [ ] TODO: Test this
# nmcli connection modify "Wired connection 1" connection.mdns yes
# nmcli connection show

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

### Add users
# Add a user that is member of `wheel`.
useradd -mG wheel till
passwd till

### Change to cachyos repos
wcurl https://mirror.cachyos.org/cachyos-repo.tar.xz
tar xvf cachyos-repo.tar.xz && cd cachyos-repo
./cachyos-repo.sh

### Install graphics and sound
pacman -S vulkan-intel  # TODO: only for intel
pacman -S pipewire pipewire-alsa pipewire-pulse pipewire-jack wireplumber

### Install GNOME
pacman -S gnome-shell gnome-settings-daemon gnome-tweaks gnome-shell-extensions xdg-desktop-portal-gnome gdm
pacman -S noto-fonts noto-fonts-cjk noto-fonts-emoji ttf-dejavu

pacman -S gnome-control-center gnome-disk-utility gnome-font-viwer gnome-keyring gnome-menus gnome-system-monitor loupe natilus papers papers-lib-docs snapshot sushi ptyxis

pacman -S --needed power-profiles-daemon
systemctl enable --now power-profiles-daemon

pacman -S --needed cups system-config-printer
systemctl enable --now cups

pacman -S firefox ffmpeg

systemctl enable --now gdm

# - [ ] TODO: Hardware acceleration https://wiki.archlinux.org/title/Hardware_video_acceleration

# Tips
# ====

# Keyboard shortcuts
# ------------------
# * BASH defaults
#     - Ctrl-k = cut to end of line
#     - Ctrl-y = paste

# BASH tips
# ---------
# * This uncomments all:

# 		sed '/PATTERN/s/^#//g' -i FILE

# 	Explanation: searches for lines containing PATTERN and removes #
# 	from start of line. g means global; remove g for 1st instance only.

# * This comments all:

# 		sed '/PATTERN/s/^/#/g' -i FILE

# * BASH quotes:
#     - 'text' is literal
#     - "text" interprets $VARS \escapes \`tics\` and !history
#     - $'\u2717 text' Interprets hex code unicode in the string escaped with \uXXXX

# Checks
# ------

### Check Internet Connection
# 	ping archlinux.org

### Check Security

#### Secure Boot
# 	sbctl status

#### TPM2
# 	cryptsetup luksDump /dev/nvme0n1p2

### Check Sound
# 	speaker-test -c 2

### Check Swap file

#### Ways to check if swap file is used
# 	swapon --show
# 	cat /proc/swaps

#### Ways to check if swap in memory
# 	vmstat
# 	free
# 	cat /proc/meminfo

### Check Time/Date status
# 	timedatectl

# Maintainance
# ------------

### Re-enroll TPM
systemd-cryptenroll /dev/nvme0n1p2 --wipe-slot=1 --tpm2-device=auto

