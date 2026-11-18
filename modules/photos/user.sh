#!/bin/sh
# photos: Immich with the official compose file (docker-compose.yml and example.env are unchanged from the release).
# Writes modules/photos/.env (mode 600) from homecider.env and secrets.env. The version is pinned by IMMICH_VERSION;
# upgrade by reading the release notes, changing IMMICH_VERSION, then running homecider apply.
set -eu
HC_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"; . "$HC_ROOT/lib/common.sh"
dir="$HC_ROOT/modules/photos"

# Immich accepts only A-Za-z0-9 in the database password.
ensure_secret IMMICH_DB_PASSWORD openssl rand -hex 24
( umask 077; cat > "$dir/.env" <<EOT
# Written by homecider apply; edit homecider.env instead.
UPLOAD_LOCATION=$PHOTOS_DIR
DB_DATA_LOCATION=$IMMICH_DB_DIR
TZ=$TZ
IMMICH_VERSION=$IMMICH_VERSION
DB_PASSWORD=$IMMICH_DB_PASSWORD
DB_USERNAME=postgres
DB_DATABASE_NAME=immich
EOT
)
case "$PHOTOS_DIR$IMMICH_DB_DIR" in *" "*) die "PHOTOS_DIR and IMMICH_DB_DIR must not contain spaces";; esac
mkdir -p "$PHOTOS_DIR" "$IMMICH_DB_DIR"
# Photos folder private when it sits inside the home folder (e.g. ~/Photos).
parent="$(dirname "$PHOTOS_DIR")"
case "$parent" in "$HC_HOME"/*) chmod 700 "$parent" ;; esac
cd "$dir"
compose_pull
docker compose up -d
log "photos: Immich $IMMICH_VERSION on http://localhost:2283 (photos in $PHOTOS_DIR)"
