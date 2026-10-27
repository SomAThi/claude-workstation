#!/usr/bin/env bash
set -Eeuo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
MODE=AUTO
while (($#)); do
  case "$1" in
    --mode) MODE=${2^^}; shift 2;;
    --preflight-only) exec python3 "$ROOT/scripts/preflight.py" --mode "$MODE";;
    *) echo "Usage: sudo ./install.sh [--mode AUTO|LITE|FULL] [--preflight-only]" >&2; exit 2;;
  esac
done
[[ $EUID == 0 ]] || { echo 'Run with sudo'; exit 1; }
exec 9>/run/lock/claude-workstation.lock
flock -n 9 || { echo 'Another installer is running'; exit 1; }
install -d -m 700 /var/log/claude-workstation /var/lib/claude-workstation
LOG=/var/log/claude-workstation/install-$(date -u +%Y%m%dT%H%M%SZ).log
exec > >(tee -a "$LOG") 2>&1
on_error() { local status=$?; echo "FAILED near line ${BASH_LINENO[0]} (code $status). Log: $LOG. Fix cause and rerun; user data is preserved."; exit "$status"; }
trap on_error ERR
python3 "$ROOT/scripts/preflight.py" --mode "$MODE" > /var/lib/claude-workstation/preflight.json
cat /var/lib/claude-workstation/preflight.json
MODE=$(python3 -c 'import json; print(json.load(open("/var/lib/claude-workstation/preflight.json"))["selected"])')
printf '%s\n' "$MODE" > /var/lib/claude-workstation/mode
export DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=l
bash "$ROOT/scripts/system.sh" "$ROOT" "$MODE"
bash "$ROOT/scripts/applications.sh" "$ROOT" "$MODE"
bash "$ROOT/scripts/configure.sh" "$ROOT" "$MODE"
"$ROOT/scripts/verify.sh" | tee /var/lib/claude-workstation/verification.txt
printf 'Installation finished; GUI login, Claude auth, Tailscale auth, RustDesk client and SMB tests remain manual. Mode: %s\n' "$MODE"
