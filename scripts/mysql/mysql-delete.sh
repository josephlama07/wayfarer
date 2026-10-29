#!/usr/bin/env bash
set -euo pipefail

BACKUP_DIR="${BACKUP_DIR:-/opt/backup/mysql-backup}"
STATE_DIR="${STATE_DIR:-/var/lib/mysql/restore-state}"
LOG_DIR="${LOG_DIR:-/var/log/mysql-restore}"
release_id="${1:?release-id is required}"
shift || true
rm -f "$BACKUP_DIR/$release_id.sql.gz" "$STATE_DIR/$release_id.state" "$LOG_DIR/$release_id.log"
printf 'Removed MySQL release artifacts: %s\n' "$release_id"
