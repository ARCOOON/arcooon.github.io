#!/bin/bash

set -e

# --- Verify this is a Proxmox PVE host ---
#if ! grep -qi "proxmox" /etc/os-release; then
#    echo "❗ This script must be run on a Proxmox PVE host."
#    exit 1
#fi

# --- Prompt for Container ID ---
read -rp "Enter LXC container ID: " CTID
CONF_PATH="/etc/pve/lxc/${CTID}.conf"

# --- Validate LXC exists ---
if [[ ! -f "$CONF_PATH" ]]; then
    echo "❗ LXC container $CTID does not exist."
    exit 1
fi

# --- Check if tailscale is already installed ---
echo "[*] Checking install status"
pct exec "$CTID" -- tailscale version >/dev/null && echo "✅ Installed" && exit 0 || echo "❌ Not installed"

# --- Inject Tailscale device permissions if not already present ---
echo "[*] Checking and patching $CONF_PATH..."

append_if_missing() {
    local line="$1"
    if ! grep -Fxq "$line" "$CONF_PATH"; then
        echo "$line" >>"$CONF_PATH"
        echo "  ✅ Added: $line"
    else
        echo "  🆗 Config already patched"
    fi
}

# --- Run commands inside the container ---
echo "[*] Installing Tailscale in container $CTID..."

pct exec "$CTID" -- bash -c '
  set -e
  apt update
  apt install -y curl
  curl -fsSL https://tailscale.com/install.sh | sh

  if command -v tailscale >/dev/null && command -v tailscaled >/dev/null; then
    echo "✅ Tailscale installation verified."
  else
    echo "❌ Tailscale installation failed or incomplete." >&2
    exit 1
  fi
'

# Patching container config
append_if_missing "lxc.cgroup2.devices.allow: c 10:200 rwm"
append_if_missing "lxc.mount.entry: /dev/net/tun dev/net/tun none bind,create=file"

echo "✅ Tailscale setup complete for LXC $CTID."
