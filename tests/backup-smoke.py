#!/usr/bin/env python3
import io, os, subprocess, tarfile, tempfile, uuid
from pathlib import Path
root=Path(__file__).resolve().parents[1]
h=Path.home();work=h/'Projects'/('cw-backup-test-'+uuid.uuid4().hex);work.mkdir()
(work/'document.txt').write_text('backup smoke\n');(work/'.env').write_text('DUMMY_NOT_A_SECRET=1\n');(work/'outside-link').symlink_to('/etc/passwd')
with tempfile.TemporaryDirectory(prefix='cw-backup-test-') as tmp:
 archive=Path(tmp)/'backup.tar.gz'
 subprocess.run([str(root/'scripts/backup.sh'),str(archive)],check=True)
 with tarfile.open(archive) as t:
  names=t.getnames()
  assert f'Projects/{work.name}/document.txt' in names
  assert not any(x.endswith('/.env') or x.endswith('/outside-link') for x in names)
 subprocess.run([str(root/'scripts/restore.sh'),str(archive)],input='RESTORE\n',text=True,check=True)
 assert (work/'document.txt').read_text()=='backup smoke\n'
 evil=Path(tmp)/'evil.tar.gz'
 with tarfile.open(evil,'w:gz') as t:
  item=tarfile.TarInfo('../cw-outside');item.size=1;t.addfile(item,io.BytesIO(b'x'))
 result=subprocess.run([str(root/'scripts/restore.sh'),str(evil)],input='RESTORE\n',text=True,capture_output=True)
 assert result.returncode!=0
 print('BACKUP_ALLOWLIST_PASS RESTORE_STAGING_PASS TRAVERSAL_REJECT_PASS')
print('New test project retained for inspection:',work)
