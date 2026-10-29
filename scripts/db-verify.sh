#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
source "$script_dir/db-common.sh"

require_feature_name
expected_tables="${EXPECTED_TABLES:-waypoints,trips}"
PGPASSWORD="$DB_ADMIN_PASSWORD" psql \
  --host="$DB_HOST" --port="$DB_PORT" --username="$DB_ADMIN_USER" \
  --dbname="$TARGET_DB" --set=ON_ERROR_STOP=1 --tuples-only --no-align \
  --command='SELECT 1' >/dev/null

IFS=',' read -r -a tables <<< "$expected_tables"
for table in "${tables[@]}"; do
  [[ "$table" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || { printf 'Invalid expected table: %s\n' "$table" >&2; exit 2; }
  found="$(PGPASSWORD="$DB_ADMIN_PASSWORD" psql \
    --host="$DB_HOST" --port="$DB_PORT" --username="$DB_ADMIN_USER" \
    --dbname="$TARGET_DB" --tuples-only --no-align \
    --command="SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='public' AND table_name='$table'")"
  [[ "$found" == 1 ]] || { printf 'Missing expected table: %s\n' "$table" >&2; exit 1; }
done
printf 'Database verification passed: %s\n' "$TARGET_DB"
