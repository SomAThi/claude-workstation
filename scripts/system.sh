#!/usr/bin/env bash
set -Eeuo pipefail
MODE=$2
apt-get update -qq
apt-get install -y --no-install-recommends ca-certificates curl gnupg xz-utils python3 git tmux build-essential cifs-utils jq unzip dbus-x11 xserver-xorg-core xserver-xorg-video-dummy x11-xserver-utils x11-utils xauth lightdm lightdm-gtk-greeter xfce4-session xfce4-panel xfce4-settings xfwm4 xfdesktop4 thunar xfce4-terminal xfce4-notifyd mousepad fonts-dejavu fonts-liberation fonts-noto-color-emoji xclip xdotool wmctrl scrot shellcheck nftables libayatana-appindicator3-1 at-spi2-core
if ! id workstation >/dev/null 2>&1; then useradd -m -s /bin/bash workstation; fi
[[ $(id -u workstation) -ne 0 ]] && ! id -nG workstation | tr ' ' '\n' | grep -qx sudo || { echo 'workstation must be a non-root non-sudo user'; exit 1; }
chmod 700 /home/workstation
install -d -o workstation -g workstation -m 700 /home/workstation/.config /home/workstation/.local /home/workstation/.local/share /home/workstation/Projects /home/workstation/Documents /home/workstation/.config/autostart /home/workstation/.local/bin /home/workstation/.local/share/applications /home/workstation/.local/state
# Existing swap stays active. Add only a dedicated deficit file on ext4.
TOTAL=$(awk 'NR>1 {s+=$3} END {print s+0}' /proc/swaps)
if (( TOTAL < 4190000 )); then
  [[ $(findmnt -no FSTYPE /) == ext4 ]] || { echo 'Swap creation only validated on ext4; configure swap manually'; exit 1; }
  SWAP=/var/lib/claude-workstation/swap.extra
  if [[ ! -e $SWAP ]]; then
    MIB=$(( (4194304-TOTAL+1023)/1024 ))
    (( $(df --output=avail -k / | tail -1) > (MIB+4096)*1024 ))
    (umask 077; fallocate -l "${MIB}M" "$SWAP")
    chmod 600 "$SWAP"; mkswap "$SWAP"
  fi
  swapon --show=NAME --noheadings | grep -Fxq "$SWAP" || swapon "$SWAP"
  grep -Fq "$SWAP " /etc/fstab || printf '%s none swap sw 0 0\n' "$SWAP" >> /etc/fstab
fi
printf 'vm.swappiness=20\n' > /etc/sysctl.d/70-claude-workstation.conf
sysctl -p /etc/sysctl.d/70-claude-workstation.conf
if [[ $MODE == FULL ]]; then
  apt-get install -y --no-install-recommends qemu-system-x86 ovmf virtiofsd
  usermod -aG kvm workstation
fi
# No zram: one predictable disk-backed swap policy, no compression CPU overhead on 2 vCPU.
