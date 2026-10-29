#!/usr/bin/env bash
set -euo pipefail

# Remove native release artifacts after a release is finished.
# Database deletion is deliberately separate and requires explicit confirmation.

BACKUP_DIR="${BACKUP_DIR:-/opt/backup/postgres-backup}"
STATE_DIR="${STATE_DIR:-/var/lib/wayfarer/restore-state}"
LOG_DIR="${LOG_DIR:-/var/log/wayfarer}"

usage() {
  printf '%s\n' \
    "Usage: $0 <release-id> [--drop-target --confirm-release <release-id>]" \
    "  Removes the dump, restore state, and log for a completed release." \
    "  Database deletion is not performed unless both flags are supplied."
}

release_id="${1:-}"
[[ -n "$release_id" && "$release_id" != -* ]] || { usage >&2; exit 2; }
shift

drop_target=false
confirm_release=""
while (($#)); do
  case "$1" in
    --drop-target) drop_target=true ;;
    --confirm-release)
      shift
      confirm_release="${1:-}"
      ;;
    *) usage >&2; exit 2 ;;
  esac
  shift
done

if $drop_target && [[ "$confirm_release" != "$release_id" ]]; then
  printf 'Refusing database deletion: --confirm-release must equal release-id\n' >&2
  exit 1
fi

rm -f \
  "$BACKUP_DIR/$release_id.dump" \
  "$STATE_DIR/$release_id.state" \
  "$LOG_DIR/$release_id.log"


if $drop_target; then
  : "${DB_HOST:?DB_HOST is required when dropping a database}"
  : "${DB_PORT:=5432}"
  : "${DB_ADMIN_USER:?DB_ADMIN_USER is required when dropping a database}"
  : "${DB_ADMIN_PASSWORD:?DB_ADMIN_PASSWORD is required when dropping a database}"
  : "${TARGET_DB:?TARGET_DB is required when dropping a database}"
  [[ "$TARGET_DB" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]] || { printf 'Invalid TARGET_DB\n' >&2; exit 2; }
  PGPASSWORD="$DB_ADMIN_PASSWORD" psql \
    --host="$DB_HOST" --port="$DB_PORT" --username="$DB_ADMIN_USER" \
    --dbname="${DB_ADMIN_DB:-postgres}" --set=ON_ERROR_STOP=1 \
    --command="SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname='${TARGET_DB}' AND pid <> pg_backend_pid();"
  PGPASSWORD="$DB_ADMIN_PASSWORD" dropdb \
    --host="$DB_HOST" --port="$DB_PORT" --username="$DB_ADMIN_USER" \
    --if-exists "$TARGET_DB"
  printf 'Dropped target database: %s\n' "$TARGET_DB"
fi