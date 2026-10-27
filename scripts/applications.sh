#!/usr/bin/env bash
set -Eeuo pipefail
ROOT=$1
install -d -m 755 /etc/apt/keyrings /opt/claude-workstation
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
for product in claude-desktop claude-code; do
  URL=https://downloads.claude.ai/claude-desktop/key.asc
  [[ $product == claude-code ]] && URL=https://downloads.claude.ai/keys/claude-code.asc
  curl --proto '=https' --tlsv1.2 -fsSL "$URL" -o "$TMP/$product.asc"
  FPR=$(gpg --show-keys --with-colons "$TMP/$product.asc" | awk -F: '$1=="fpr" {print $10;exit}')
  [[ $FPR == 31DDDE24DDFAB679F42D7BD2BAA929FF1A7ECACE ]] || { echo 'Anthropic signing key mismatch'; exit 1; }
  install -m 644 "$TMP/$product.asc" "/etc/apt/keyrings/$product.asc"
  printf 'deb [signed-by=/etc/apt/keyrings/%s.asc] https://downloads.claude.ai/%s/apt/stable stable main\n' "$product" "$product" > "/etc/apt/sources.list.d/cw-$product.list"
done
curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/noble.noarmor.gpg -o "$TMP/tailscale.gpg"
gpg --show-keys "$TMP/tailscale.gpg"
install -m 644 "$TMP/tailscale.gpg" /etc/apt/keyrings/cw-tailscale.gpg
printf 'deb [signed-by=/etc/apt/keyrings/cw-tailscale.gpg] https://pkgs.tailscale.com/stable/ubuntu noble main\n' > /etc/apt/sources.list.d/cw-tailscale.list
apt-get update
# QEMU dependencies may be pulled by Desktop even in LITE. No Cowork launch or KVM emulation is performed.
apt-get install -y --no-install-recommends claude-desktop claude-code tailscale
NODE=$(jq -r .node_version "$ROOT/config/versions.json")
NODE_SHA=$(jq -r .node_sha256 "$ROOT/config/versions.json")
if [[ ! -x /opt/claude-workstation/node/bin/node ]]; then
  curl -fsSL "https://nodejs.org/dist/v$NODE/node-v$NODE-linux-x64.tar.xz" -o "$TMP/node.tar.xz"
  echo "$NODE_SHA  $TMP/node.tar.xz" | sha256sum -c -
  mkdir "$TMP/node"; tar -xJf "$TMP/node.tar.xz" --strip-components=1 -C "$TMP/node"
  mv "$TMP/node" /opt/claude-workstation/node
fi
export PATH=/opt/claude-workstation/node/bin:$PATH
[[ $(node --version) == "v$NODE" ]] || { echo 'Node pin differs; explicit upgrade required'; exit 1; }
for bin in node npm npx; do
  if [[ ! -e /usr/local/bin/$bin ]]; then ln -s "/opt/claude-workstation/node/bin/$bin" "/usr/local/bin/$bin"; fi
done
if [[ ! -e /opt/claude-workstation/browser/package-lock.json ]] || ! cmp -s "$ROOT/config/package-lock.json" /opt/claude-workstation/browser/package-lock.json; then
  install -d -o workstation -g workstation -m 755 /opt/claude-workstation/browser
  install -o workstation -g workstation -m 644 "$ROOT/config/package.json" "$ROOT/config/package-lock.json" /opt/claude-workstation/browser/
  runuser -u workstation -- env HOME=/home/workstation PATH="$PATH" sh -c 'cd /opt/claude-workstation/browser && npm ci --ignore-scripts'
fi
/opt/claude-workstation/browser/node_modules/.bin/playwright install-deps chromium
runuser -u workstation -- env HOME=/home/workstation PATH="$PATH" /opt/claude-workstation/browser/node_modules/.bin/playwright install chromium
# Permit sandbox user namespaces only for a fixed, root-owned browser executable.
BROWSER_SOURCE=$(HOME=/home/workstation /opt/claude-workstation/node/bin/node -e 'console.log(require("/opt/claude-workstation/browser/node_modules/playwright").chromium.executablePath())')
BROWSER_ID=$(basename "$(dirname "$(dirname "$BROWSER_SOURCE")")")
if [[ ! -d /opt/claude-workstation/$BROWSER_ID ]]; then
  cp -a "$(dirname "$BROWSER_SOURCE")" "/opt/claude-workstation/$BROWSER_ID"
  chown -R root:root "/opt/claude-workstation/$BROWSER_ID"
  chmod -R go-w "/opt/claude-workstation/$BROWSER_ID"
fi
ln -sfn "/opt/claude-workstation/$BROWSER_ID" /opt/claude-workstation/chromium
cat > /etc/apparmor.d/cw-playwright-chromium <<CONF
abi <abi/4.0>,
include <tunables/global>
profile cw-playwright-chromium /opt/claude-workstation/$BROWSER_ID/chrome flags=(unconfined) {
  userns,
}
CONF
apparmor_parser -r /etc/apparmor.d/cw-playwright-chromium
apt-get install -y --no-install-recommends chromium-browser
# Snap may auto-install cups; workstation does not need a public print daemon.
if snap list cups >/dev/null 2>&1; then snap stop --disable cups; fi
RUST_VER=$(jq -r .rustdesk_version "$ROOT/config/versions.json")
RUST_SHA=$(jq -r .rustdesk_sha256 "$ROOT/config/versions.json")
  install -d /etc/systemd/system/rustdesk.service.d
  cat > /etc/systemd/system/rustdesk.service.d/10-cw-activation-gate.conf <<'CONF'
[Unit]
ConditionPathExists=/var/lib/claude-workstation/rustdesk-enabled
[Service]
IPAddressDeny=any
IPAddressAllow=localhost
IPAddressAllow=100.64.0.0/10
IPAddressAllow=fd7a:115c:a1e0::/48
CONF
  systemctl daemon-reload
if [[ $(dpkg-query -W -f='${Version}' rustdesk 2>/dev/null || true) != "$RUST_VER" ]]; then
  curl -fL "https://github.com/rustdesk/rustdesk/releases/download/$RUST_VER/rustdesk-$RUST_VER-x86_64.deb" -o "$TMP/rustdesk.deb"
  echo "$RUST_SHA  $TMP/rustdesk.deb" | sha256sum -c -
  # Prevent package postinst starting an unconfigured remote service.
  apt-get install -y --no-install-recommends "$TMP/rustdesk.deb"
fi
if [[ ! -e /var/lib/claude-workstation/rustdesk-enabled ]]; then
  systemctl disable --now rustdesk.service
  systemctl mask rustdesk.service
fi
systemctl enable --now tailscaled
