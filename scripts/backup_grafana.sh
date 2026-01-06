#!/bin/bash
set -e

VOLUME_NAME="pihole_monitoring_grafana-data"
BACKUP_DIR="./backups"
TIMESTAMP=$(date +%F_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/grafana-backup-$TIMESTAMP.tar.gz"
BASENAME=$(basename "$BACKUP_FILE")
RETENTION_COUNT=7

# Create backups directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

# Use a temporary container to read the named volume and write the tarball to the bind-mounted backups dir
# Pass the target filename via env to avoid complex quoting problems.
docker run --rm \
  -e BACKUP_NAME="$BASENAME" \
  -v "$VOLUME_NAME":/data:ro \
  -v "$BACKUP_DIR":/backup \
  alpine:3.18 \
  sh -c 'cd /data && tar czf "/backup/$BACKUP_NAME" .'

if [ $? -eq 0 ]; then
  echo "Backup saved to: $BACKUP_FILE"
  echo "Backup size: $(du -h "$BACKUP_FILE" | cut -f1)"
else
  echo "Backup failed" >&2
  exit 1
fi

# Cleanup old backups, keeping only the last RETENTION_COUNT
echo "Cleaning up old backups (keeping last $RETENTION_COUNT)..."
cd "$BACKUP_DIR"
ls -1t grafana-backup-*.tar.gz 2>/dev/null | tail -n +$((RETENTION_COUNT + 1)) | xargs -r rm -v
cd - > /dev/null

echo "Backup complete."
