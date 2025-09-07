#!/bin/bash
set -euo pipefail

# The following may need root privlidges.

### Create recovery key.
# Transcribe it to a safe place.
systemd-cryptenroll /dev/nvme0n1p2 --recovery-key

### Enroll keys into TPM2.
# Enter your encryption password after below command. This will use `pcr=7` only. See https://man.archlinux.org/man/systemd-cryptenroll.1#TPM2_PCRs_and_policies for more details.
systemd-cryptenroll /dev/nvme0n1p2 --wipe-slot=empty --tpm2-device=auto

### Verify enrolled:
cryptsetup luksDump /dev/nvme0n1p2

# Look for `systemd-tpm2` entry under tokens.

### Reboot
reboot

