#!/bin/bash
set -Eeuo pipefail
[[ $EUID == 0 ]] || { echo 'Use sudo'; exit 1; }
tailscale status --json | python3 -c 'import json,sys;sys.exit(json.load(sys.stdin).get("BackendState")!="Running")' || { echo 'Authorize Tailscale first: tailscale up --accept-routes=false --accept-dns=false'; exit 1; }
# cgroup-v2 BPF filtering must be available; do not fall back to unfiltered service.
[[ $(stat -fc %T /sys/fs/cgroup) == cgroup2fs ]] || { echo 'cgroup v2 required'; exit 1; }
[[ -r /sys/kernel/btf/vmlinux ]] || { echo 'Kernel BTF unavailable: verify BPF support before activation'; exit 1; }
install -d -m 755 /etc/systemd/system/rustdesk.service.d
cat > /etc/systemd/system/rustdesk.service.d/30-tailnet-only.conf <<'CONF'
[Service]
IPAddressDeny=any
IPAddressAllow=localhost
IPAddressAllow=100.64.0.0/10
IPAddressAllow=fd7a:115c:a1e0::/48
CONF
# Verify enforcement with a separate transient process before exposing RustDesk.
python3 -c 'import socket; socket.create_connection(("1.1.1.1",443),timeout=5).close()'
systemd-run --quiet --wait --pipe --unit="cw-bpf-test-$$" -p IPAddressDeny=any /usr/bin/python3 -c '
import errno,socket,sys
try:
 socket.create_connection(("1.1.1.1",443),timeout=3)
except OSError as e:
 sys.exit(0 if isinstance(e,TimeoutError) or e.errno in (errno.EPERM,errno.EACCES) else 2)
sys.exit(1)
' || { echo 'Network deny could not be verified; aborting'; exit 1; }
systemctl daemon-reload
touch /var/lib/claude-workstation/rustdesk-enabled
systemctl unmask rustdesk.service
# First start is already confined to localhost/tailnet. No public relays reachable.
systemctl enable --now rustdesk.service
sleep 2
rustdesk --option direct-server Y
rustdesk --option direct-access-port 21118
rustdesk --option enable-lan-discovery N
rustdesk --option whitelist '100.64.0.0/10,fd7a:115c:a1e0::/48'
rustdesk --option approve-mode password
rustdesk --option verification-method use-permanent-password
rustdesk --option enable-file-transfer N
rustdesk --option enable-tunnel N
rustdesk --option enable-terminal N
rustdesk --option enable-clipboard Y
# A unique high-entropy password, root-readable only; never printed.
python3 - <<'PY'
import os,secrets,subprocess
path='/var/lib/claude-workstation/rustdesk-password'
if not os.path.exists(path):
 fd=os.open(path,os.O_CREAT|os.O_EXCL|os.O_WRONLY,0o600)
 with os.fdopen(fd,'w') as f:f.write(secrets.token_urlsafe(32)+'\n')
p=open(path).read().strip()
subprocess.run(['rustdesk','--password',p],check=True,stdout=subprocess.DEVNULL)
PY
systemctl restart rustdesk
for _ in {1..15}; do
 if ss -lntp | grep -q ':21118 '; then break; fi
 sleep 1
done
ss -lntp | grep ':21118 ' || { echo 'Direct listener missing: inspect RustDesk configuration'; exit 1; }
echo 'Connect from Mac to Tailscale-IP:21118. Retrieve unique password only via your root SSH terminal. Real client connection still needs testing.'
