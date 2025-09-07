#!/bin/bash
set -euo pipefail

ln -s ~/dotfiles/homeassistant.container ~/.config/containers/systemd/homeassistant.container

systemctl --user daemon-reload
systemctl --user start homeassistant.service
# systemctl --user restart homeassistant.service

# Enable start of service before first login.
loginctl enable-linger "$USER"

# Add user to uucp
sudo usermod -aG uucp $USER

# Use stow to deploy services
stow -d ~/quadlets -t ~/.config/containers/systemd -S paperless

# Unstow (remove symlinks):
#stow -d ~/quadlets -t ~/.config/containers/systemd -D paperless 

# Use ln instead
ln -s ~/quadlets/restic/restic-backup-srv.container ~/.config/containers/systemd/restic-backup-srv.container
ln -s ~/quadlets/restic/restic-backup-srv.timer ~/.config//systemd/user/restic-backup-srv.timer

# Verify links
ls -l ~/.config/containers/systemd | grep paperless

# Reload unit files
systemctl --user daemon-reload

# Check for quadlet errors
journalctl --user -b -e -g quadlet

# List unit files
systemctl --user list-unit-files

# Start a unit file or timer
systemctl --user start restic-backup-srv.service
systemctl --user enable --now restic-backup-srv.timer

# Follow a container along
journalctl --user -u restic-backup-srv.service -f

# Review past logs
journalctl --user -xeu restic-backup-srv.service

