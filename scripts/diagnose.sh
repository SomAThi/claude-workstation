#!/bin/bash
set -uo pipefail
# Read-only; does not dump application configs, tokens, browser profiles or passwords.
date -u
uname -a
free -h
swapon --show
findmnt /
df -h /
systemctl --no-pager --full status lightdm tailscaled rustdesk cw-resources.timer 2>/dev/null || true
ss -lntup
journalctl -k --since '24 hours ago' --grep='Out of memory|oom-kill|Killed process' --no-pager
journalctl -u cw-resources.service -n 40 --no-pager
cat /var/lib/claude-workstation/preflight.json /var/lib/claude-workstation/installed-versions.tsv
