#!/bin/bash
set -euo pipefail

### Install graphics and sound
pacman -S vulkan-intel  # TODO: only for intel
pacman -S pipewire pipewire-alsa pipewire-pulse pipewire-jack wireplumber

### Install GNOME
pacman -S gnome-shell gnome-settings-daemon gnome-tweaks gnome-shell-extensions xdg-desktop-portal-gnome gdm
pacman -S noto-fonts noto-fonts-cjk noto-fonts-emoji ttf-dejavu

pacman -S gnome-control-center gnome-disk-utility gnome-font-viwer gnome-keyring gnome-menus gnome-system-monitor loupe natilus papers papers-lib-docs snapshot sushi ptyxis gnome-browser-connector

pacman -S --needed power-profiles-daemon
systemctl enable --now power-profiles-daemon

pacman -S --needed cups system-config-printer
systemctl enable --now cups

pacman -S firefox ffmpeg

systemctl enable --now gdm

# - [ ] TODO: Hardware acceleration https://wiki.archlinux.org/title/Hardware_video_acceleration

