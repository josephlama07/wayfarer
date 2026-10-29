#!/usr/bin/env bash
set -euo pipefail
script_dir="$(cd "$(dirname "$0")" && pwd)"
source "$script_dir/mysql-common.sh"
release_id="${1:?release-id is required}"
require_feature_name
dump_file="$(backup_path "$release_id")"
[[ -f "$dump_file" ]] || { printf 'Dump not found: %s\n' "$dump_file" >&2; exit 1; }
mysql_admin --batch --skip-column-names --execute="CREATE DATABASE IF NOT EXISTS \`$TARGET_DB\`;"
state_file="$(state_path "$release_id")"
log_file="$(log_path "$release_id")"
mkdir -p "$STATE_DIR" "$LOG_DIR"
[[ ! -e "$state_file" ]] || { printf 'Restore already exists: %s\n' "$state_file" >&2; exit 1; }
: > "$log_file"
(
  set -o pipefail
  printf 'restore_started_at=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  gzip -dc "$dump_file" | MYSQL_PWD="$DB_ADMIN_PASSWORD" mysql --host="$DB_HOST" --port="$DB_PORT" --user="$DB_ADMIN_USER" "$TARGET_DB"
  printf 'restore_completed_at=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
) >"$log_file" 2>&1 &
pid=$!
printf 'release_id=%s\npid=%s\ndump_file=%s\ntarget_db=%s\nlog_file=%s\nstatus=running\n' "$release_id" "$pid" "$dump_file" "$TARGET_DB" "$log_file" > "$state_file"
chmod 600 "$state_file" "$log_file"
printf 'MySQL restore started: release=%s pid=%s target_db=%s\n' "$release_id" "$pid" "$TARGET_DB"
