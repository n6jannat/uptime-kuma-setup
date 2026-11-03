#!/usr/bin/env bash
#
# backup.sh - back up Uptime Kuma's data folder to a .tar.gz.
#
# Usage: ./backup.sh [backup-dir]     (default: ./backups, keeps last 7)

set -euo pipefail
cd "$(dirname "$0")"

DEST="${1:-./backups}"
KEEP="${KEEP:-7}"
SUDO=""
[[ $EUID -ne 0 ]] && SUDO="sudo"

mkdir -p "$DEST"
FILE="$DEST/uptime-kuma-$(date +%Y%m%d-%H%M%S).tar.gz"

# Stop briefly so the SQLite database is copied in a consistent state.
echo "==> Stopping Uptime Kuma"
$SUDO docker compose stop uptime-kuma
trap '$SUDO docker compose start uptime-kuma >/dev/null' EXIT

echo "==> Writing $FILE"
$SUDO tar -czf "$FILE" data

echo "==> Removing old backups (keeping $KEEP)"
find "$DEST" -name 'uptime-kuma-*.tar.gz' -printf '%T@ %p\n' \
    | sort -rn | tail -n +$((KEEP + 1)) | cut -d' ' -f2- | xargs -r rm -f

echo "Done: $FILE"
