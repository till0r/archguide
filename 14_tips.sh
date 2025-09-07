#!/bin/bash
set -euo pipefail


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

