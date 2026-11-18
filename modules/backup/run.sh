#!/bin/sh
# Nightly backup (launchd), also run by `homecider backup now`.
# Backup every night; forget + prune on Sundays; read-check 5% of the data on the 1st of the month.
set -u
HC_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"; . "$HC_ROOT/lib/common.sh"; . "$HC_ROOT/modules/backup/env.sh"
echo "== $(date)"
ex="$(mktemp)"; trap 'rm -f "$ex"' EXIT
backup_excludes > "$ex"
failed=""

backup_paths | tr '\n' '\0' | xargs -0 restic backup --exclude-file "$ex" --exclude-caches --one-file-system || failed="backup"
if [ -z "$failed" ] && [ "$(date +%u)" = 7 ]; then
  restic forget --keep-daily 7 --keep-weekly 5 --keep-monthly 12 --prune || failed="prune"
fi
if [ -z "$failed" ] && [ "$(date +%d)" = 01 ]; then
  restic check --read-data-subset 5% || failed="check"
fi

if [ -n "$failed" ]; then
  notify "Backup failed: $failed" "See $HC_LOGS/backup.log." warning
  exit 1
fi
mkdir -p "$HC_STATE"; date +%s > "$HC_STATE/backup-ok"
echo "backup ok"
