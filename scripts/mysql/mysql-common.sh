#!/usr/bin/env bash
set -euo pipefail

DB_HOST="${DB_HOST:?DB_HOST is required}"
DB_PORT="${DB_PORT:-3306}"
DB_ADMIN_USER="${DB_ADMIN_USER:?DB_ADMIN_USER is required}"
DB_ADMIN_PASSWORD="${DB_ADMIN_PASSWORD:?DB_ADMIN_PASSWORD is required}"
SOURCE_DB="${SOURCE_DB:-wayfarer_source}"
FEATURE_NAME="${FEATURE_NAME:-}"
TARGET_DB="${TARGET_DB:-}"
BACKUP_DIR="${BACKUP_DIR:-/opt/backup/mysql-backup}"
STATE_DIR="${STATE_DIR:-/var/lib/mysql/restore-state}"
LOG_DIR="${LOG_DIR:-/var/log/mysql-restore}"
MIN_FREE_KB="${MIN_FREE_KB:-1048576}"

require_identifier() { [[ "$1" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || { printf 'Invalid MySQL identifier: %s\n' "$1" >&2; exit 2; }; }
require_feature_name() {
  [[ -n "$FEATURE_NAME" ]] || { printf 'FEATURE_NAME is required\n' >&2; exit 2; }
  require_identifier "$FEATURE_NAME"
  [[ -n "$TARGET_DB" ]] || TARGET_DB="wayfarer_feature_${FEATURE_NAME}"
  require_identifier "$TARGET_DB"
}
mysql_admin() { MYSQL_PWD="$DB_ADMIN_PASSWORD" mysql --host="$DB_HOST" --port="$DB_PORT" --user="$DB_ADMIN_USER" "$@"; }
backup_path() { printf '%s/%s.sql.gz\n' "$BACKUP_DIR" "$1"; }
state_path() { printf '%s/%s.state\n' "$STATE_DIR" "$1"; }
log_path() { printf '%s/%s.log\n' "$LOG_DIR" "$1"; }
check_space() {
  local available_kb
  available_kb="$(df -Pk "$1" | awk 'NR == 2 {print $4}')"
  [[ "$available_kb" =~ ^[0-9]+$ ]] || { printf 'Unable to determine free space\n' >&2; exit 1; }
  (( available_kb >= MIN_FREE_KB )) || { printf 'Insufficient free space: %s KiB available, %s KiB required\n' "$available_kb" "$MIN_FREE_KB" >&2; exit 1; }
}
