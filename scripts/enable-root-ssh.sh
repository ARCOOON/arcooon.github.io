#!/usr/bin/env bash
set -euo pipefail

CFG="${1:-/etc/ssh/sshd_config}"

if [ "$(id -u)" -ne 0 ]; then
  echo "Error: run as root (sudo $0)" >&2
  exit 1
fi

if [ ! -f "$CFG" ]; then
  echo "Error: $CFG not found" >&2
  exit 1
fi

# BACKUP="${CFG}.bak.$(date +%F_%H%M%S)"
BACKUP="${CFG}.bak"
cp -a "$CFG" "$BACKUP"

# If any PermitRootLogin line exists (commented or not), normalize it to "PermitRootLogin yes".
# Otherwise, append it.
if grep -Eq '^[[:space:]]*#*[[:space:]]*PermitRootLogin[[:space:]]+' "$CFG"; then
  sed -i -E 's/^[[:space:]]*#*[[:space:]]*PermitRootLogin[[:space:]]+.*/PermitRootLogin yes/' "$CFG"
else
  printf '\nPermitRootLogin yes\n' >> "$CFG"
fi

# Validate config and reload SSH
if command -v sshd >/dev/null 2>&1; then
  if sshd -t -f "$CFG"; then
    systemctl reload sshd 2>/dev/null \
      || systemctl reload ssh 2>/dev/null \
      || service sshd reload 2>/dev/null \
      || service ssh reload 2>/dev/null \
      || true
    echo "OK: Updated $CFG (backup: $BACKUP)."
  else
    echo "Error: sshd_config syntax check failed. Restoring backup." >&2
    cp -a "$BACKUP" "$CFG"
    exit 1
  fi
else
  echo "Note: sshd binary not found; skipped validation/reload. Backup: $BACKUP"
fi
