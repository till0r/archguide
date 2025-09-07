#!/bin/bash
set -euo pipefail

### Prepare ssh environment
sudo mkdir -p /srv/restic/{ssh,cache,excludes}
# repo password for restic (NOT your SSH key passphrase)
echo 'change-me-long-random' | sudo tee /srv/restic/password.txt >/dev/null
sudo chmod 600 /srv/restic/password.txt

# put your SSH private key here (or copy existing)
sudo cp ~/.ssh/id_ed25519 /srv/restic/ssh/
sudo chmod 600 /srv/restic/ssh/id_ed25519

ssh-keyscan -p 22 backup.example.com | sudo tee -a /srv/restic/ssh/known_hosts >/dev/null
sudo chmod 644 /srv/restic/ssh/known_hosts

sudo tee /srv/restic/ssh/config >/dev/null <<'EOF'
Host restic-target
    HostName backup.example.com
    User u12345
    Port 22
    IdentityFile /root/.ssh/id_ed25519
EOF
sudo chmod 644 /srv/restic/ssh/config

sudo tee /srv/restic/restic.env >/dev/null <<'EOF'
# Use SSH alias above (or use sftp://u@host:22//path syntax)
RESTIC_REPOSITORY=sftp:restic-target:/home/u12345/restic-repo
RESTIC_PASSWORD_FILE=/config/password.txt
RESTIC_CACHE_DIR=/cache
# Quiet progress in logs (optional)
RESTIC_PROGRESS_FPS=0
EOF
sudo chmod 640 /srv/restic/restic.env

sudo tee /srv/restic/excludes/folderA.txt >/dev/null <<'EOF'
# one path per line, relative to the mounted source
subfolder-to-skip/
another-subfolder/
EOF

### Init the repo
podman run --rm --network host   -v /srv/restic:/config:ro   -v /srv/restic/ssh:/root/.ssh:ro   -v /srv/restic/cache:/cache   -e RESTIC_REPOSITORY="sftp:restic-storagebox:/backups/restic-repo"   -e RESTIC_PASSWORD_FILE="/config/secret/password.txt"   docker.io/restic/restic:latest init

### Quadlets
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

[Unit]
Description=Timer: restic-backup-srv

[Timer]
OnCalendar=*-*-* 00:00:00
RandomizedDelaySec=1m
Persistent=true

[Install]
WantedBy=timers.target

