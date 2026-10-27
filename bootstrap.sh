#!/usr/bin/env bash
# Download a versioned source tree; runtime and credentials live separately.
set -Eeuo pipefail
REPO=https://github.com/SomAThi/claude-workstation.git
REF=v1.0.0
MODE=AUTO
usage() { echo 'Usage: sudo bash bootstrap.sh [--ref <full-commit-sha|vX.Y.Z>] [--mode AUTO|LITE|FULL]'; }
while (($#)); do
 case "$1" in
  --ref) [[ $# -ge 2 ]] || { usage; exit 2; }; REF=$2; shift 2;;
  --mode) [[ $# -ge 2 ]] || { usage; exit 2; }; MODE=$2; shift 2;;
  -h|--help) usage; exit 0;;
  *) usage; exit 2;;
 esac
done
[[ $REF =~ ^[0-9a-f]{40}$ || $REF =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo 'Use a full commit SHA or a version tag'; exit 2; }
[[ $MODE == AUTO || $MODE == LITE || $MODE == FULL ]] || { usage; exit 2; }
[[ $EUID == 0 ]] || { echo 'Run with sudo'; exit 1; }
[[ -r /etc/os-release ]] || { echo 'Ubuntu 24.04 required'; exit 1; }
# shellcheck disable=SC1091
source /etc/os-release
[[ $ID == ubuntu && $VERSION_ID == 24.04 && $(uname -m) == x86_64 ]] || { echo 'This release supports Ubuntu 24.04 x86_64 only'; exit 1; }
[[ $(ps -p 1 -o comm=) == systemd ]] || { echo 'A booted Ubuntu VPS with systemd is required'; exit 1; }
export DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=l
apt-get update -qq
apt-get install -y --no-install-recommends git ca-certificates python3
install -d -m 755 /opt/claude-workstation-sources
CW_SOURCE=$(mktemp -d /opt/claude-workstation-sources/source.XXXXXXXX)
# Keep failed source downloads for diagnosis; never overwrite an existing checkout.
echo "Downloading $REPO ($REF) into $CW_SOURCE"
git -C "$CW_SOURCE" init -q
git -C "$CW_SOURCE" remote add origin "$REPO"
git -C "$CW_SOURCE" fetch --depth=1 origin "$REF"
git -C "$CW_SOURCE" checkout --detach -q FETCH_HEAD
CW_COMMIT=$(git -C "$CW_SOURCE" rev-parse HEAD)
if [[ $REF =~ ^[0-9a-f]{40}$ && $CW_COMMIT != "$REF" ]]; then echo 'Downloaded commit mismatch'; exit 1; fi
printf '%s\n' "$CW_COMMIT" > "$CW_SOURCE/SOURCE_COMMIT"
echo "Source commit: $CW_COMMIT"
bash "$CW_SOURCE/install.sh" --mode "$MODE"
echo "Source and next-step scripts: $CW_SOURCE"
echo "Next: sudo tailscale up --accept-routes=false --accept-dns=false"
echo "Then: sudo bash $CW_SOURCE/scripts/enable-rustdesk.sh"
echo 'Claude sign-in and optional Mac folder setup require the owner.'
