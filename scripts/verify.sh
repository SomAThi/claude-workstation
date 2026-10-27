#!/bin/bash
set -uo pipefail
errors=0
check() { local label=$1; shift; if "$@"; then echo "AUTO_PASS $label"; else echo "ERROR $label"; errors=$((errors+1)); fi; }
check claude-cli runuser -u workstation -- env HOME=/home/workstation claude --version
for p in claude-desktop rustdesk tailscale xfce4-session; do check "package-$p" dpkg-query -W "$p"; done
check lightdm systemctl is-active lightdm
check tailscaled systemctl is-active tailscaled
check x11-socket test -S /tmp/.X11-unix/X0
check browser-root-owned bash -c '[[ $(stat -c %U /opt/claude-workstation/chromium/chrome) == root ]]'
check apparmor-userns-profile test -f /etc/apparmor.d/cw-playwright-chromium
check chromium-snap snap list chromium
if DISPLAY=:0 XAUTHORITY=/var/run/lightdm/root/:0 wmctrl -l 2>/dev/null | grep -q ' Claude$'; then echo AUTO_PASS claude-window; else echo WAIT_USER graphical-login-Claude-window; fi
check resource-timer systemctl is-active cw-resources.timer
check ssh-listener bash -c 'ss -lnt | grep -q ":22 "'
if tailscale status --json | python3 -c 'import json,sys;sys.exit(json.load(sys.stdin).get("BackendState")!="Running")'; then echo AUTO_PASS tailscale-auth; else echo WAIT_USER tailscale-auth; fi
if systemctl is-active --quiet rustdesk; then echo INSTALLED_RUNNING rustdesk-client-test-pending; else echo WAIT_USER rustdesk-secure-activation; fi
if [[ $(cat /var/lib/claude-workstation/mode) == FULL ]]; then
 check kvm-user runuser -u workstation -- python3 "$(dirname "$0")/preflight.py" --kvm-only
 echo WAIT_USER Cowork-real-VM-launch-folder-read-write
else echo NOT_SUPPORTED Cowork-on-this-LITE-host; fi
printf '%s\n' 'WAIT_USER Claude-auth-Code-tab-project' 'WAIT_USER Mac-RustDesk-clipboard-reconnect' 'WAIT_USER SMB-test-file' 'WAIT_USER reboot-test' 'NOT_TESTED clean-second-Ubuntu-deployment'
exit "$errors"
