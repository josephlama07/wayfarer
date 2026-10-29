#!/usr/bin/env bash
set -euo pipefail

STATE_DIR="${STATE_DIR:-/var/lib/mysql/restore-state}"
LOG_DIR="${LOG_DIR:-/var/log/mysql-restore}"
release_id="${1:?release-id is required}"
state_file="$STATE_DIR/$release_id.state"
log_file="$LOG_DIR/$release_id.log"
[[ -f "$state_file" ]] || { printf 'unknown release=%s\n' "$release_id"; exit 1; }
# shellcheck disable=SC1090
source "$state_file"
if kill -0 "$pid" 2>/dev/null; then
  printf 'running release=%s pid=%s target_db=%s\n' "$release_id" "$pid" "$target_db"
elif grep -q '^restore_completed_at=' "$log_file"; then
  printf 'completed release=%s target_db=%s\n' "$release_id" "$target_db"
else
  printf 'failed release=%s target_db=%s\n' "$release_id" "$target_db"
  cat "$log_file" >&2
  exit 1
fi
