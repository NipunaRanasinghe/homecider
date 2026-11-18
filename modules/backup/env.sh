# Sourced by the backup scripts: restic settings from homecider.env and secrets.env.
: "${BACKUP_REPOSITORY:=}"
: "${BACKUP_HOUR:=2}"
: "${VAULT_DIR:=$HC_HOME/Vault}"
[ -n "$BACKUP_REPOSITORY" ] || die "set BACKUP_REPOSITORY in homecider.env (see docs/backup.md)"
for s in RESTIC_PASSWORD AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY; do
  eval "v=\${$s:-}"; [ -n "$v" ] || die "secret $s missing: run homecider secret set $s"
done
export RESTIC_REPOSITORY="$BACKUP_REPOSITORY" RESTIC_PASSWORD AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY
export RESTIC_CACHE_DIR="$HC_HOME/Library/Caches/restic"

# What to back up: photos (with Immich's own daily database dumps in backups/), app data, homecider config and
# secrets, the vault folder, and BACKUP_EXTRA_PATHS. Media is not backed up (it can be downloaded again).
backup_paths() {
  for p in "$PHOTOS_DIR" "$DATA_DIR" "$DOWNLOADS_CONFIG_DIR" "$HC_STATE" "$HC_CONFIG" "$VAULT_DIR" ${BACKUP_EXTRA_PATHS:-}; do
    [ -e "$p" ] && echo "$p"
  done | sort -u
}
# Regenerable or unsafe to copy while running: thumbnails, transcoded video, the live Postgres directory, caches, logs.
backup_excludes() {
  printf '%s\n' "$PHOTOS_DIR/thumbs" "$PHOTOS_DIR/encoded-video" "$IMMICH_DB_DIR" \
    '*/logs' '*/Logs' '*/cache' '*/Cache' '*/MediaCover' '.DS_Store'
}
