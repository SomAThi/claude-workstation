#!/bin/bash
set -euo pipefail
[[ $(id -un) == workstation ]] || { echo 'Run as workstation, not root'; exit 1; }
[[ $# == 1 ]] || { echo 'Usage: restore.sh archive.tar.gz'; exit 2; }
read -r -p 'Restore into a NEW staging folder only? Type RESTORE: ' answer
[[ $answer == RESTORE ]] || exit 1
python3 - "$1" <<'PY'
import os,sys,tarfile,tempfile,shutil
from pathlib import Path, PurePosixPath
os.umask(0o077)
stage=Path(tempfile.mkdtemp(prefix='workstation-restore-',dir=Path.home()))
limit=20*2**30
with tarfile.open(sys.argv[1],'r:gz') as t:
    members=t.getmembers()
    if sum(m.size for m in members)>limit or len(members)>100000:raise SystemExit('Archive exceeds safety limits')
    for m in members:
        p=PurePosixPath(m.name)
        if p.is_absolute() or '..' in p.parts or not p.parts or not(m.isfile() or m.isdir()):raise SystemExit('Unsafe archive member')
        if p.parts[0] not in {'Projects','Documents','.config','.local'}:raise SystemExit('Unexpected archive path')
        dst=stage.joinpath(*p.parts)
        if m.isdir():dst.mkdir(parents=True,exist_ok=True);continue
        dst.parent.mkdir(parents=True,exist_ok=True)
        with t.extractfile(m) as src,open(dst,'xb') as out:shutil.copyfileobj(src,out)
        os.chmod(dst,0o600)
print('Staged only, no existing files overwritten:',stage)
print('Review contents and permissions, then copy selected files manually. No application login state restored.')
PY
