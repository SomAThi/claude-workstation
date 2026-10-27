#!/bin/bash
set -euo pipefail
[[ $(id -un) == workstation ]] || { echo 'Run as workstation, not root'; exit 1; }
umask 077
DEST=${1:-"$HOME/workstation-backup-$(date -u +%Y%m%dT%H%M%SZ).tar.gz"}
[[ ! -e $DEST ]] || { echo 'Destination exists'; exit 1; }
# Deliberately narrow allowlist. Projects/Documents can contain secrets placed there by the owner: review before export.
python3 - "$DEST" <<'PY'
import os,sys,tarfile
from pathlib import Path
h=Path.home(); out=Path(sys.argv[1]).resolve()
if any(out.is_relative_to(h/x) for x in ['Projects','Documents']): raise SystemExit('Archive must be outside Projects/Documents')
roots=['Projects','Documents','.config/autostart/claude-workstation.desktop','.local/share/applications/chromium-workstation.desktop','.local/share/applications/claude-code-workstation.desktop']
def allowed(info):
    p=Path(info.name)
    if info.issym() or info.islnk() or not (info.isfile() or info.isdir()): return None
    if any(x in {'.git','.ssh','.gnupg','.aws','.azure','.claude','node_modules','.venv','__pycache__'} for x in p.parts): return None
    if p.name.startswith('.env') or p.suffix in {'.key','.pem','.p12','.pfx'} or p.name in {'credentials','credentials.json','cookies','cookies.sqlite','Cookies','Login Data','auth.json','.npmrc','.netrc'}: return None
    return info
with open(out,'xb') as f:
    os.chmod(out,0o600)
    with tarfile.open(fileobj=f,mode='w:gz',dereference=False) as t:
        for r in roots:
            if (h/r).exists():t.add(h/r,arcname=r,filter=allowed)
print(out)
PY
