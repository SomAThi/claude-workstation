#!/usr/bin/env python3
"""Optional, interactive root-only SMB setup. Never log credentials."""
import getpass, ipaddress, os, re, subprocess, uuid
from pathlib import Path
if os.geteuid()!=0:raise SystemExit('Run with sudo from an interactive terminal')
ip=input('Mac Tailscale IP: ').strip()
a=ipaddress.ip_address(ip)
if not any(a in ipaddress.ip_network(n) for n in ['100.64.0.0/10','fd7a:115c:a1e0::/48'] if a.version==ipaddress.ip_network(n).version):raise SystemExit('Only Tailscale IPs accepted')
subprocess.run(['tailscale','ping','--c','1',ip],check=True)
share=input('SMB share name (e.g. Claude-Shared): ').strip()
user=input('Dedicated sharing-only Mac username: ').strip()
if not re.fullmatch(r'[A-Za-z0-9_-]+',share) or not re.fullmatch(r'[A-Za-z0-9_.-]+',user):raise SystemExit('Unsupported share/user characters')
password=getpass.getpass('SMB password (not saved in logs): ')
if '\n' in password or '\r' in password or not password:raise SystemExit('Invalid password')
os.umask(0o077)
config=Path('/etc/claude-workstation');config.mkdir(mode=0o700,exist_ok=True)
cred=config/'mac-smb.credentials'
if cred.exists():raise SystemExit('Credentials already exist; disconnect first or edit them securely')
fstab=Path('/etc/fstab');original=fstab.read_text()
if '/mnt/mac-shared' in original:raise SystemExit('Mountpoint already configured; refusing to overwrite')
subprocess.run(['install','-d','-o','workstation','-g','workstation','-m','0700','/mnt/mac-shared'],check=True)
with cred.open('x') as f:f.write(f'username={user}\npassword={password}\n')
os.chmod(cred,0o600)
uid=subprocess.check_output(['id','-u','workstation'],text=True).strip();gid=subprocess.check_output(['id','-g','workstation'],text=True).strip()
host=f'[{ip}]' if a.version==6 else ip
line=f'//{host}/{share} /mnt/mac-shared cifs credentials={cred},vers=3.1.1,seal,uid={uid},gid={gid},file_mode=0600,dir_mode=0700,nosuid,nodev,noexec,_netdev,nofail,x-systemd.automount,x-systemd.idle-timeout=60,x-systemd.mount-timeout=15 0 0\n'
backup=config/f'fstab-before-smb-{uuid.uuid4().hex}'
backup.write_text(original);os.chmod(backup,0o600)
with fstab.open('a') as f:f.write('\n# Claude Workstation optional tailnet SMB\n'+line)
subprocess.run(['systemctl','daemon-reload'],check=True)
subprocess.run(['systemctl','start','mnt-mac\\x2dshared.automount'],check=True)
# Reading/writing only a newly created test file, under the non-root account.
subprocess.run(['runuser','-u','workstation','--','python3','-c',
 'from pathlib import Path; import uuid; p=Path("/mnt/mac-shared")/("cw-test-"+uuid.uuid4().hex+".txt"); p.write_text("test one\\n"); assert p.read_text()=="test one\\n"; p.write_text("test two\\n"); assert p.read_text()=="test two\\n"; print("READ_WRITE_PASS",p)'],check=True)
print('Encrypted SMB3 mount configured. Test document intentionally retained. If Mac is offline, access waits up to mount timeout.')
