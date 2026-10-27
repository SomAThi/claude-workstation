#!/bin/bash
set -euo pipefail
[[ $EUID == 0 ]] || { echo 'Use sudo'; exit 1; }
# Signed repositories only. Never upgrade the entire OS or restart the GUI automatically.
apt-get update
apt-get --simulate install --only-upgrade claude-desktop claude-code tailscale
read -r -p 'Close applications and type UPDATE to apply the displayed package updates: ' answer
[[ $answer == UPDATE ]] || exit 1
NEEDRESTART_MODE=l apt-get install -y --only-upgrade claude-desktop claude-code tailscale
"$(dirname "$0")/verify.sh"
echo 'RustDesk/Node/Playwright remain pinned. Update versions.json, package-lock.json and validate in staging before reinstalling.'
