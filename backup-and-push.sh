#!/bin/bash
set -uo pipefail

REPO_DIR="/home/ubuntu/n8n-backups/My-Oracle-N8N-Auto-Backup"
DATE=$(date +%Y-%m-%d_%H-%M)
FILENAME="n8n_backup_${DATE}.tar.gz"
TMP_PATH="/tmp/${FILENAME}"
MIN_SIZE_BYTES=51200
LOG="/home/ubuntu/n8n-backups/backup.log"

log() { echo "$(date '+%Y-%m-%d %H:%M:%S') $1" >> "$LOG"; }

docker run --rm \
  -v n8n_data:/data \
  -v /tmp:/backup \
  alpine tar czf /backup/${FILENAME} -C /data .

ACTUAL_SIZE=$(stat -c%s "$TMP_PATH" 2>/dev/null || echo 0)

if [ "$ACTUAL_SIZE" -lt "$MIN_SIZE_BYTES" ]; then
  log "FAILED: backup too small (${ACTUAL_SIZE} bytes) - NOT pushed. Check docker volume/container."
  rm -f "$TMP_PATH"
  exit 1
fi

if ! tar -tzf "$TMP_PATH" > /dev/null 2>&1; then
  log "FAILED: not a valid tar.gz - NOT pushed."
  rm -f "$TMP_PATH"
  exit 1
fi

mv "$TMP_PATH" "${REPO_DIR}/${FILENAME}"
cd "$REPO_DIR"
find "$REPO_DIR" -name "n8n_backup_*.tar.gz" -mtime +14 -delete

git add .
git commit -m "Automated n8n backup: ${FILENAME} (${ACTUAL_SIZE} bytes)" || log "Nothing new to commit"
git push origin HEAD

log "SUCCESS: ${FILENAME} (${ACTUAL_SIZE} bytes) pushed to GitHub."

