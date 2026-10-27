#!/bin/bash
set -euo pipefail
[[ $EUID == 0 ]] || exit 1
read -r -p 'Close files using the share. Type DISCONNECT to stop its automount: ' answer
[[ $answer == DISCONNECT ]] || exit 1
systemctl stop 'mnt-mac\x2dshared.automount' 'mnt-mac\x2dshared.mount'
echo 'Remove the dedicated /mnt/mac-shared fstab line and /etc/claude-workstation/mac-smb.credentials manually to disable permanently. No Mac documents deleted.'
