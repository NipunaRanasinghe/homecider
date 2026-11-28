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

# Space-separated paths from one MOD_* field of every module's manifest, enabled or not, so data left by a module
# that was turned off is still backed up. Paths contain no spaces (homecider.env.example).
module_paths() { for m in $(modules_with "$1" all); do module_field "$m" "$1"; echo; done; }
# What to back up: each module's MOD_BACKUP_PATHS, app data, homecider config and secrets, the vault folder, and
# BACKUP_EXTRA_PATHS. Media is not backed up (it can be downloaded again).
backup_paths() {
  # shellcheck disable=SC2046
  for p in $(module_paths MOD_BACKUP_PATHS) "$DATA_DIR" "$HC_STATE" "$HC_CONFIG" "$VAULT_DIR" ${BACKUP_EXTRA_PATHS:-}; do
    [ -e "$p" ] && echo "$p"
  done | sort -u
}
# Regenerable or unsafe to copy while running: each module's MOD_BACKUP_EXCLUDES, caches, logs.
backup_excludes() {
  # shellcheck disable=SC2046
  printf '%s\n' $(module_paths MOD_BACKUP_EXCLUDES) \
    '*/logs' '*/Logs' '*/cache' '*/Cache' '*/MediaCover' '.DS_Store'
}
