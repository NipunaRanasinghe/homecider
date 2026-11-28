#!/usr/bin/env bats
# Tests for the weekly update job (modules/core/update.sh) and uninstall (modules/core/uninstall.sh) with stub
# commands. lib/common.sh sets PATH itself, so each test runs on a copy of the repository whose common.sh puts the
# stub folder first on PATH and uses a temporary home folder. Stubs only append their arguments to $STUB_LOG:
# nothing is upgraded, pulled, stopped or removed on this Mac.

setup() {
  REPO="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  root="$BATS_TEST_TMPDIR/repo"; stubs="$BATS_TEST_TMPDIR/stubs"; home="$BATS_TEST_TMPDIR/home"
  mkdir -p "$root" "$stubs" "$home/Library/LaunchAgents"
  cp -R "$REPO/bin" "$REPO/lib" "$REPO/modules" "$root/"
  sed -i '' -e "s#^HC_HOME=.*#HC_HOME=\"$home\"#" -e "s#^export PATH=\"#export PATH=\"$stubs:#" "$root/lib/common.sh"
  grep -q "^HC_HOME=\"$home\"" "$root/lib/common.sh" && grep -q "PATH=\"$stubs:" "$root/lib/common.sh"

  export STUB_LOG="$BATS_TEST_TMPDIR/stub.log" STUB_TAG=v9.9.9
  : > "$STUB_LOG"
  cat > "$stubs/stub" <<'EOF'
#!/bin/sh
# Logs "name args"; curl also logs its stdin (ntfy URL and title) and answers GitHub release queries.
name="$(basename "$0")"
echo "$name $*" >> "$STUB_LOG"
case "$name $*" in
  "curl "*api.github.com*) printf '{"tag_name": "%s"}\n' "$STUB_TAG" ;;
  "curl "*" -K -"*) sed 's/^/  stdin: /' >> "$STUB_LOG" ;;
esac
exit 0
EOF
  chmod +x "$stubs/stub"
  for c in brew orbctl docker curl launchctl sudo softwareupdate; do ln -s stub "$stubs/$c"; done

  export HC_CONFIG="$BATS_TEST_TMPDIR/homecider.env" HC_STATE="$BATS_TEST_TMPDIR/state"
  printf '%s\n' 'MODULES="core media photos downloads dashboard"' 'IMMICH_VERSION=v1.0.0' 'NTFY_TOPIC=test-topic' > "$HC_CONFIG"
}

@test "update: pulls and recreates the containers of every enabled MOD_COMPOSE module" {
  run sh "$root/modules/core/update.sh"
  [ "$status" -eq 0 ]
  for m in photos downloads dashboard; do
    grep -qxF "docker compose --project-directory $HC_STATE/compose/$m pull -q" "$STUB_LOG"
    grep -qxF "docker compose --project-directory $HC_STATE/compose/$m up -d" "$STUB_LOG"
  done
  [ "$(grep -c ' pull -q$' "$STUB_LOG")" -eq 3 ]
}

@test "update: no compose pulls for modules that are not enabled" {
  echo 'MODULES="core media"' >> "$HC_CONFIG"
  run sh "$root/modules/core/update.sh"
  [ "$status" -eq 0 ]
  ! grep -q 'docker compose' "$STUB_LOG"
}

@test "update: one release message per new release, from MOD_RELEASE" {
  run sh "$root/modules/core/update.sh"
  [ "$status" -eq 0 ]
  grep -qF "curl -fsS -m 15 https://api.github.com/repos/immich-app/immich/releases/latest" "$STUB_LOG"
  grep -qF -- "-H Title: Immich v9.9.9 released" "$STUB_LOG"
  grep -qF -- "-d Running v1.0.0. Read the release notes, then set IMMICH_VERSION in homecider.env" "$STUB_LOG"
  [ -e "$HC_STATE/alerts/release-photos-v9.9.9" ]
  : > "$STUB_LOG"
  run sh "$root/modules/core/update.sh"
  ! grep -q "Title: Immich" "$STUB_LOG"
}

@test "update: no release message when the running version is the latest" {
  STUB_TAG=v1.0.0 run sh "$root/modules/core/update.sh"
  [ "$status" -eq 0 ]
  ! grep -q "released" "$STUB_LOG"
  ! ls "$HC_STATE/alerts/" | grep -q '^release-'
}

@test "uninstall: stops every Compose project apply created, including a module turned off since" {
  for m in photos dashboard; do mkdir -p "$HC_STATE/compose/$m"; touch "$HC_STATE/compose/$m/.env"; done
  mkdir -p "$HC_STATE/compose/downloads"    # no .env: apply never finished for it, nothing to stop
  echo 'MODULES="core media"' >> "$HC_CONFIG"
  touch "$home/Library/LaunchAgents/io.homecider.alerts.plist"
  run sh -c 'echo yes | sh "$1"' sh "$root/modules/core/uninstall.sh"
  [ "$status" -eq 0 ]
  grep -qxF "docker compose --project-directory $HC_STATE/compose/photos down" "$STUB_LOG"
  grep -qxF "docker compose --project-directory $HC_STATE/compose/dashboard down" "$STUB_LOG"
  ! grep -q "compose/downloads" "$STUB_LOG"
  grep -qF "sudo sh $root/modules/core/uninstall.sh root" "$STUB_LOG"
  [ ! -e "$home/Library/LaunchAgents/io.homecider.alerts.plist" ]
}

@test "uninstall: lists every module's MOD_KEPT folders, enabled or not" {
  printf '%s\n' 'MEDIA_DIR=/x/media' 'PHOTOS_DIR=/x/photos' 'DATA_DIR=/x/data' >> "$HC_CONFIG"
  echo 'MODULES="core"' >> "$HC_CONFIG"
  run sh -c 'echo yes | sh "$1"' sh "$root/modules/core/uninstall.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"kept: /x/media, /Library/Application Support/jellyfin, /x/photos, /x/data, $HC_CONFIG, $HC_STATE"* ]]
}

@test "uninstall: cancelled unless the answer is yes" {
  mkdir -p "$HC_STATE/compose/photos"; touch "$HC_STATE/compose/photos/.env"
  run sh -c 'echo no | sh "$1"' sh "$root/modules/core/uninstall.sh"
  [ "$status" -ne 0 ]
  [ ! -s "$STUB_LOG" ]
}
