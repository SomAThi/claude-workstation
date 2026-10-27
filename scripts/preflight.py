#!/usr/bin/env python3
import argparse, fcntl, json, os, platform, shutil, sys

def kvm_check():
    try:
        with open('/dev/kvm', 'rb+', buffering=0) as f:
            api = fcntl.ioctl(f, 0xAE00, 0)
            vm = fcntl.ioctl(f, 0xAE01, 0)
            os.close(vm)
        return api == 12
    except (OSError, ValueError):
        return False

def choose(mode, ram, disk, kvm, cpu_flag):
    capable = ram >= 7500 and disk >= 50 and kvm and cpu_flag
    if mode == 'FULL' and not capable:
        raise ValueError('FULL needs >=7500 MiB physical RAM, >=50 GiB free, CPU virtualization flag, KVM API 12 and successful KVM_CREATE_VM')
    if ram < 3500 or disk < 20:
        raise ValueError('LITE needs >=3500 MiB physical RAM and >=20 GiB free')
    return ('FULL' if capable else 'LITE') if mode == 'AUTO' else mode

if __name__ == '__main__':
    ap = argparse.ArgumentParser(); ap.add_argument('--mode', choices=['AUTO','LITE','FULL'], default='AUTO'); ap.add_argument('--kvm-only', action='store_true'); a=ap.parse_args()
    if a.kvm_only:
        ok=kvm_check(); print(json.dumps({'kvm_create_vm':ok})); sys.exit(0 if ok else 1)
    release=dict(line.strip().split('=',1) for line in open('/etc/os-release') if '=' in line)
    if release.get('ID','').strip('"') != 'ubuntu' or release.get('VERSION_ID','').strip('"') != '24.04':
        sys.exit('This tested installer supports Ubuntu 24.04 only')
    if platform.machine() != 'x86_64': sys.exit('This release of the installer supports x86_64 only; do not guess ARM download URLs')
    ram=int(next(x.split()[1] for x in open('/proc/meminfo') if x.startswith('MemTotal:')))//1024
    disk=shutil.disk_usage('/').free/2**30
    flags=open('/proc/cpuinfo').read(); cpu_flag=any(x in flags.split() for x in ['vmx','svm'])
    kvm=kvm_check()
    try: selected=choose(a.mode,ram,disk,kvm,cpu_flag)
    except ValueError as e: sys.exit(str(e))
    print(json.dumps(dict(requested=a.mode, selected=selected, ram_mib=ram, disk_free_gib=round(disk,1), cpu=os.cpu_count(), kvm_create_vm=kvm, virtualization_cpu_flag=cpu_flag), indent=2))
