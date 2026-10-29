#!/usr/bin/env bash
set -euo pipefail

DB_HOST="${DB_HOST:?DB_HOST is required}"
DB_PORT="${DB_PORT:-5432}"
DB_ADMIN_USER="${DB_ADMIN_USER:?DB_ADMIN_USER is required}"
DB_ADMIN_PASSWORD="${DB_ADMIN_PASSWORD:?DB_ADMIN_PASSWORD is required}"
DB_ADMIN_DB="${DB_ADMIN_DB:-postgres}"
SOURCE_DB="${SOURCE_DB:-wayfarer_source}"
FEATURE_NAME="${FEATURE_NAME:-}"
TARGET_DB="${TARGET_DB:-}"
APP_USER="${APP_USER:-wayfarer_app}"
APP_PASSWORD="${APP_PASSWORD:-}"
BACKUP_DIR="${BACKUP_DIR:-/opt/backup/postgres-backup}"
STATE_DIR="${STATE_DIR:-/var/lib/wayfarer/restore-state}"
LOG_DIR="${LOG_DIR:-/var/log/wayfarer}"
MIN_FREE_KB="${MIN_FREE_KB:-1048576}"

require_identifier() {
  [[ "$1" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]] || { printf 'Invalid PostgreSQL identifier: %s\n' "$1" >&2; exit 2; }
}

require_feature_name() {
  [[ -n "$FEATURE_NAME" ]] || { printf 'FEATURE_NAME is required\n' >&2; exit 2; }
  require_identifier "$FEATURE_NAME"
  if [[ -z "$TARGET_DB" ]]; then TARGET_DB="wayfarer_feature_${FEATURE_NAME}"; fi
  require_identifier "$TARGET_DB"
}

psql_admin() {
  PGPASSWORD="$DB_ADMIN_PASSWORD" psql --host="$DB_HOST" --port="$DB_PORT" --username="$DB_ADMIN_USER" --dbname="$DB_ADMIN_DB" --set=ON_ERROR_STOP=1 "$@"
}

backup_path() { printf '%s/%s.dump\n' "$BACKUP_DIR" "$1"; }
state_path() { printf '%s/%s.state\n' "$STATE_DIR" "$1"; }
log_path() { printf '%s/%s.log\n' "$LOG_DIR" "$1"; }

check_space() {
  local path="$1" available_kb
  available_kb="$(df -Pk "$path" | awk 'NR == 2 {print $4}')"
  [[ "$available_kb" =~ ^[0-9]+$ ]] || { printf 'Unable to determine free space for: %s\n' "$path" >&2; exit 1; }
  (( available_kb >= MIN_FREE_KB )) || { printf 'Insufficient free space at %s: %s KiB available, %s KiB required\n' "$path" "$available_kb" "$MIN_FREE_KB" >&2; exit 1; }
  printf 'Free space at %s: %s KiB\n' "$path" "$available_kb"
}
