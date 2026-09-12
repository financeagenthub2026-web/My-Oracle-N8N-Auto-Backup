#!/bin/bash
set -uo pipefail

REPO_DIR="/home/ubuntu/n8n-backups/My-Oracle-N8N-Auto-Backup"
DATE=$(date +%Y-%m-%d_%H-%M)
FILENAME="n8n_backup_${DATE}.tar.gz"
TMP_PATH="/tmp/${FILENAME}"
MIN_SIZE_BYTES=51200
LOG="/home/ubuntu/n8n-backups/backup.log"
HOST_UID=$(id -u)
HOST_GID=$(id -g)

log() { echo "$(date '+%Y-%m-%d %H:%M:%S') $1" >> "$LOG"; }

if ! docker run --rm \
  -v n8n_data:/data:ro \
  -v /tmp:/backup \
  alpine sh -c "tar czf /backup/${FILENAME} -C /data . && chown ${HOST_UID}:${HOST_GID} /backup/${FILENAME}"; then
  log "FAILED: docker/tar step returned an error (permission issue reading volume) - NOT pushed."
  rm -f "$TMP_PATH"
  exit 1
fi

ACTUAL_SIZE=$(stat -c%s "$TMP_PATH" 2>/dev/null || echo 0)

if [ "$ACTUAL_SIZE" -lt "$MIN_SIZE_BYTES" ]; then
  log "FAILED: backup too small (${ACTUAL_SIZE} bytes) - NOT pushed."
  rm -f "$TMP_PATH"
  exit 1
fi

if ! tar -tzf "$TMP_PATH" > /dev/null 2>&1; then
  log "FAILED: not a valid tar.gz - NOT pushed."
  rm -f "$TMP_PATH"
  exit 1
fi

mv "$TMP_PATH" "${REPO_DIR}/${FILENAME}"
if [ ! -f "${REPO_DIR}/${FILENAME}" ]; then
  log "FAILED: could not move backup into repo folder - NOT pushed."
  exit 1
fi

cd "$REPO_DIR"
find "$REPO_DIR" -name "n8n_backup_*.tar.gz" -mtime +14 -delete

git add .
git commit -m "Automated n8n backup: ${FILENAME} (${ACTUAL_SIZE} bytes)" || true

if git push origin HEAD; then
  log "SUCCESS: ${FILENAME} (${ACTUAL_SIZE} bytes) pushed to GitHub."
else
  log "FAILED: git push failed - backup saved locally/committed but NOT on GitHub. Check token permissions."
  exit 1
fi
