#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=db-common.sh
source "$script_dir/db-common.sh"

release_id="${1:?release-id is required}"
require_target_db
[[ -f "$(backup_path "$release_id")" ]] || { printf 'Dump not found for release: %s\n' "$release_id" >&2; exit 1; }
[[ -n "$APP_PASSWORD" ]] || { printf 'APP_PASSWORD is required\n' >&2; exit 2; }

printf 'Preparing target database: %s\n' "$TARGET_DB"
if [[ "$APP_USER" != "$DB_ADMIN_USER" ]]; then
psql_admin <<SQL
DO \$\$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = '${APP_USER}') THEN
    CREATE ROLE ${APP_USER} LOGIN PASSWORD '${APP_PASSWORD}';
  ELSE
    ALTER ROLE ${APP_USER} WITH LOGIN PASSWORD '${APP_PASSWORD}';
  END IF;
END
\$\$;
SQL
fi

if ! psql_admin --tuples-only --no-align --command="SELECT 1 FROM pg_database WHERE datname='${TARGET_DB}'" | grep -qx 1; then
  psql_admin --command="CREATE DATABASE ${TARGET_DB}"
fi
psql_admin --command="GRANT CONNECT ON DATABASE ${TARGET_DB} TO ${APP_USER}"
PGPASSWORD="$DB_ADMIN_PASSWORD" psql --host="$DB_HOST" --port="$DB_PORT" --username="$DB_ADMIN_USER" --dbname="$TARGET_DB" --set=ON_ERROR_STOP=1 --command="GRANT USAGE,CREATE ON SCHEMA public TO ${APP_USER}"

state_file="$(state_path "$release_id")"
log_file="$(log_path "$release_id")"
mkdir -p "$STATE_DIR" "$LOG_DIR"
[[ ! -e "$state_file" ]] || { printf 'Restore already exists: %s\n' "$state_file" >&2; exit 1; }
: > "$log_file"
(
  printf 'restore_started_at=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  pg_restore \
    --host="$DB_HOST" --port="$DB_PORT" --username="$DB_ADMIN_USER" \
    --clean --if-exists --no-owner --no-privileges \
    --exit-on-error --format=custom --file=- "$(backup_path "$release_id")" \
    | sed '/^SET transaction_timeout = 0;$/d' \
    | PGPASSWORD="$DB_ADMIN_PASSWORD" psql \
        --host="$DB_HOST" --port="$DB_PORT" --username="$DB_ADMIN_USER" \
        --dbname="$TARGET_DB" --set=ON_ERROR_STOP=1
  printf 'restore_completed_at=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
) >"$log_file" 2>&1 &
pid=$!
printf 'release_id=%s\npid=%s\ndump_file=%s\ntarget_db=%s\nlog_file=%s\nstatus=running\n' "$release_id" "$pid" "$(backup_path "$release_id")" "$TARGET_DB" "$log_file" > "$state_file"
chmod 600 "$state_file" "$log_file"
printf 'Restore started: release=%s pid=%s target_db=%s\n' "$release_id" "$pid" "$TARGET_DB"
