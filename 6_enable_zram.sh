
# Adaption of https://wiki.archlinux.org/title/Zram#Using_a_udev_rule
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

# After a reboot you can verify this setup via
# zram should be visible as a device
lsblk

# zram shoulb be visible in free
free -h

