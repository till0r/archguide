#!/bin/bash
set -euo pipefail

### Re-enroll TPM
systemd-cryptenroll /dev/nvme0n1p2 --wipe-slot=1 --tpm2-device=auto

