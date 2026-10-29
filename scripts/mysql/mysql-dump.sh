#!/usr/bin/env bash
set -euo pipefail
script_dir="$(cd "$(dirname "$0")" && pwd)"
source "$script_dir/mysql-common.sh"
release_id="${1:?release-id is required}"
dump_file="$(backup_path "$release_id")"
[[ ! -e "$dump_file" ]] || { printf 'Refusing to overwrite existing dump: %s\n' "$dump_file" >&2; exit 1; }
mkdir -p "$BACKUP_DIR"
check_space "$BACKUP_DIR"
MYSQL_PWD="$DB_ADMIN_PASSWORD" mysqladmin --host="$DB_HOST" --port="$DB_PORT" --user="$DB_ADMIN_USER" ping
MYSQL_PWD="$DB_ADMIN_PASSWORD" mysqldump --host="$DB_HOST" --port="$DB_PORT" --user="$DB_ADMIN_USER" --single-transaction --routines --triggers --events "$SOURCE_DB" | gzip -c > "$dump_file"
chmod 600 "$dump_file"
printf 'MySQL dump completed: %s\n' "$dump_file"
