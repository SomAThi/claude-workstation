#!/usr/bin/env bash
set -Eeuo pipefail
ROOT=$1
# Managed files are created once. Existing user configurations are preserved.
put_once() { local p=$1; if [[ -e $p ]]; then cat >/dev/null; else cat > "$p"; chmod 644 "$p"; fi; }
install -d /etc/X11/xorg.conf.d /etc/lightdm/lightdm.conf.d
# Snap moves Chromium out of the launcher's scope. Limit its actual dynamic scope too.
install -d /etc/systemd/user/snap.chromium.chromium-.scope.d
put_once /etc/systemd/user/snap.chromium.chromium-.scope.d/50-cw-memory.conf <<'CONF'
[Scope]
MemoryHigh=900M
MemoryMax=1200M
TasksMax=256
CONF
if [[ -S /run/user/$(id -u workstation)/bus ]]; then
 runuser -u workstation -- env "XDG_RUNTIME_DIR=/run/user/$(id -u workstation)" "DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u workstation)/bus" systemctl --user daemon-reload
fi
put_once /etc/X11/xorg.conf.d/20-cw-dummy.conf <<'CONF'
Section "Device"
 Identifier "CWDevice"
 Driver "dummy"
 VideoRam 256000
EndSection
Section "Monitor"
 Identifier "CWMonitor"
 HorizSync 28.0-80.0
 VertRefresh 48.0-75.0
 Modeline "1920x1080" 148.50 1920 2008 2052 2200 1080 1084 1089 1125 +HSync +VSync
EndSection
Section "Screen"
 Identifier "CWScreen"
 Device "CWDevice"
 Monitor "CWMonitor"
 DefaultDepth 24
 SubSection "Display"
  Depth 24
  Modes "1920x1080"
 EndSubSection
EndSection
Section "ServerFlags"
 Option "DontVTSwitch" "true"
EndSection
CONF
put_once /etc/lightdm/lightdm.conf.d/60-cw.conf <<'CONF'
[Seat:*]
user-session=xfce
xserver-command=X -core -nolisten tcp
allow-guest=false
greeter-hide-users=false
CONF
put_once /home/workstation/.config/autostart/claude-workstation.desktop <<'CONF'
[Desktop Entry]
Type=Application
Name=Claude Workstation
Exec=claude-desktop
Terminal=false
OnlyShowIn=XFCE;
X-GNOME-Autostart-enabled=true
CONF
put_once /home/workstation/.local/bin/chromium-workstation <<'CONF'
#!/bin/bash
set -euo pipefail
cd "$HOME"
exec 9>"$HOME/.local/state/cw-manual-browser.lock"
flock -n 9 || { echo 'Manual browser already open'; exit 0; }
BROWSER=/snap/bin/chromium
export XDG_RUNTIME_DIR=/run/user/$(id -u)
export DBUS_SESSION_BUS_ADDRESS=unix:path=$XDG_RUNTIME_DIR/bus
exec systemd-run --user --scope --quiet -p MemoryHigh=900M -p MemoryMax=1200M -p TasksMax=256 "$BROWSER" --user-data-dir="$HOME/.local/share/cw-chromium" --renderer-process-limit=2 --disable-dev-shm-usage "$@"
CONF
chmod 755 /home/workstation/.local/bin/chromium-workstation
put_once /home/workstation/.local/bin/playwright-mcp-workstation <<'CONF'
#!/bin/bash
set -euo pipefail
export PATH=/opt/claude-workstation/node/bin:$PATH
cd "$HOME"
exec 9>"$HOME/.local/state/cw-mcp-browser.lock"
flock -n 9 || { echo 'One Playwright MCP session already active' >&2; exit 1; }
BROWSER=/opt/claude-workstation/chromium/chrome
export XDG_RUNTIME_DIR=/run/user/$(id -u)
export DBUS_SESSION_BUS_ADDRESS=unix:path=$XDG_RUNTIME_DIR/bus
exec systemd-run --user --scope --quiet -p MemoryHigh=900M -p MemoryMax=1200M -p TasksMax=256 node /opt/claude-workstation/browser/node_modules/@playwright/mcp/cli.js --executable-path "$BROWSER" --sandbox --isolated --headless --timeout-navigation 30000 "$@"
CONF
chmod 755 /home/workstation/.local/bin/playwright-mcp-workstation
put_once /home/workstation/.config/autostart/rustdesk.desktop <<'CONF'
[Desktop Entry]
Type=Application
Name=RustDesk managed service only
Hidden=true
CONF
put_once /home/workstation/.local/bin/cw-session-setup <<'CONF'
#!/bin/bash
set -eu
# Initial defaults only: keep later user preferences.
if ! xfconf-query -c keyboard-layout -p /Default/XkbLayout >/dev/null 2>&1; then
 xfconf-query -c keyboard-layout -p /Default/XkbLayout -n -t string -s us,ru
 xfconf-query -c keyboard-layout -p /Default/XkbOptions/Group -n -t string -s grp:alt_shift_toggle
fi
if [[ $(cat /var/lib/claude-workstation/mode 2>/dev/null || echo LITE) == LITE ]]; then
 [[ -e $HOME/.local/state/cw-xfce-defaults ]] || { xfconf-query -c xfwm4 -p /general/use_compositing -s false; touch "$HOME/.local/state/cw-xfce-defaults"; }
fi
CONF
chmod 755 /home/workstation/.local/bin/cw-session-setup
put_once /home/workstation/.config/autostart/cw-session-setup.desktop <<'CONF'
[Desktop Entry]
Type=Application
Name=Workstation initial defaults
Exec=/home/workstation/.local/bin/cw-session-setup
OnlyShowIn=XFCE;
CONF
put_once /home/workstation/.local/share/applications/chromium-workstation.desktop <<'CONF'
[Desktop Entry]
Type=Application
Name=Chromium Workstation
Exec=/home/workstation/.local/bin/chromium-workstation %U
Icon=web-browser
Categories=Network;WebBrowser;
Terminal=false
CONF
put_once /home/workstation/.local/share/applications/claude-code-workstation.desktop <<'CONF'
[Desktop Entry]
Type=Application
Name=Claude Code Terminal
Exec=xfce4-terminal --working-directory=/home/workstation/Projects -e claude
Icon=utilities-terminal
Categories=Development;
Terminal=false
CONF
chown -R workstation:workstation /home/workstation/.config/autostart /home/workstation/.local/bin /home/workstation/.local/share/applications
# Do not alter Desktop's internal MCP configuration or auth state.
if ! runuser -u workstation -- env HOME=/home/workstation claude mcp get playwright-workstation >/dev/null 2>&1; then
 runuser -u workstation -- env HOME=/home/workstation claude mcp add --scope user playwright-workstation /home/workstation/.local/bin/playwright-mcp-workstation
fi
# New account password: generated once, never printed in installer logs.
if [[ $(passwd -S workstation | awk '{print $2}') == L && ! -f /var/lib/claude-workstation/initial-login-password ]]; then
 python3 - <<'PY'
import os,secrets,subprocess
p=secrets.token_urlsafe(24)
fd=os.open('/var/lib/claude-workstation/initial-login-password',os.O_CREAT|os.O_EXCL|os.O_WRONLY,0o600)
with os.fdopen(fd,'w') as f:f.write(p+'\n')
subprocess.run(['chpasswd'],input='workstation:'+p+'\n',text=True,check=True)
PY
fi
# OOM diagnostics contain resource counters only, not user command lines or secrets.
install -m 755 "$ROOT/scripts/resource-snapshot.sh" /usr/local/sbin/cw-resource-snapshot
put_once /etc/systemd/system/cw-resources.service <<'CONF'
[Unit]
Description=Claude workstation memory snapshot
[Service]
Type=oneshot
ExecStart=/usr/local/sbin/cw-resource-snapshot
CONF
put_once /etc/systemd/system/cw-resources.timer <<'CONF'
[Unit]
Description=Periodic workstation resource counters
[Timer]
OnBootSec=2min
OnUnitActiveSec=5min
[Install]
WantedBy=timers.target
CONF
systemctl daemon-reload
systemctl enable --now cw-resources.timer
systemctl enable lightdm
systemctl is-active --quiet lightdm || systemctl start lightdm
# RustDesk stays masked until tailnet auth and explicit secure activation.
echo 'RustDesk installed; activate with scripts/enable-rustdesk.sh after tailscale login. No public remote-access service started.'
dpkg-query -W -f='${Package}\t${Version}\n' claude-desktop claude-code rustdesk tailscale xfce4-session xserver-xorg-core > /var/lib/claude-workstation/installed-versions.tsv
