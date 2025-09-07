#!/bin/bash
set -euo pipefail

### Config and start ssh
sudo sed -i 's/^[#[:space:]]*PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config

systemctl enable --now sshd.service

### Install Cockpit
pacman -S cockpit cockpit-podman cockpit-storaged cockpit-packagekit

mkdir -p /etc/systemd/system/cockpit.socket.d/

tee /etc/systemd/system/cockpit.socket.d/listen.conf > /dev/null <<'EOF'
[Socket]
ListenStream=
ListenStream=443
EOF

systemctl enable --now cockpit.socket

### Disable Notebook Lid
sudo sed -i 's/^[#[:space:]]*HandleLidSwitch=.*/HandleLidSwitch=ignore/' /etc/systemd/logind.conf
systemctl restart systemd-logind.service

### Disable bluetooth and wifi
rfkill block wifi
rfkill block bluetooth

