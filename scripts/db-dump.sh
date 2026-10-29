#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=db-common.sh
source "$script_dir/db-common.sh"

release_id="${1:?release-id is required}"
dump_file="$(backup_path "$release_id")"
[[ ! -e "$dump_file" ]] || { printf 'Refusing to overwrite existing dump: %s\n' "$dump_file" >&2; exit 1; }

mkdir -p "$BACKUP_DIR"
check_space "$BACKUP_DIR"
printf 'Checking source database connectivity...\n'
PGPASSWORD="$DB_ADMIN_PASSWORD" pg_isready --host="$DB_HOST" --port="$DB_PORT" --username="$DB_ADMIN_USER" --dbname="$SOURCE_DB"
printf 'Creating dump: %s\n' "$dump_file"
PGPASSWORD="$DB_ADMIN_PASSWORD" pg_dump \
  --host="$DB_HOST" --port="$DB_PORT" --username="$DB_ADMIN_USER" \
  --dbname="$SOURCE_DB" --format=custom --no-owner --no-privileges \
  --file="$dump_file"
chmod 600 "$dump_file"
printf 'Dump completed: %s\n' "$dump_file"
