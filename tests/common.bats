#!/usr/bin/env bats
# Tests for lib/common.sh. Run: bats tests
# common.sh reads the real user's home with dscl, so it needs macOS. Every test points HC_CONFIG, HC_STATE and
# HC_SECRETS at the per-test temporary directory, so nothing is written to the real home folder.

setup() {
  REPO="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  HC_ROOT="$REPO"
  HC_CONFIG="$BATS_TEST_TMPDIR/homecider.env"
  : > "$HC_CONFIG"
  unset MODULES MEDIA_DIR TEST_SECRET OTHER_SECRET
}

load_common() {
  . "$REPO/lib/common.sh"
  HC_STATE="$BATS_TEST_TMPDIR/state"
  HC_SECRETS="$HC_STATE/secrets.env"
}

# Values that must survive being written to secrets.env and sourced back.
special_values() {
  printf '%s\n' 'plain' "it's" 'two  spaces' 'a $HOME b' 'back`id`ticks' 'a & b; c | d' \
    'back\slash' 'double "quotes"' "'leading and trailing'" '$(id)' '#hash' '='
}

@test "sq: quoted value evaluates back to the original" {
  load_common
  special_values | while IFS= read -r v; do
    eval "x=$(sq "$v")"
    [ "$x" = "$v" ] || { echo "mismatch: [$v] -> [$x]"; return 1; }
  done
}

@test "set_secret: round trip through secrets.env with special characters" {
  load_common
  special_values | while IFS= read -r v; do
    set_secret TEST_SECRET "$v"
    [ "$TEST_SECRET" = "$v" ]
    got="$(unset TEST_SECRET; . "$HC_SECRETS"; printf '%s' "$TEST_SECRET")"
    [ "$got" = "$v" ] || { echo "mismatch: [$v] -> [$got]"; return 1; }
  done
}

@test "set_secret: replaces an existing name, keeps other names, mode 600" {
  load_common
  set_secret TEST_SECRET first
  set_secret OTHER_SECRET kept
  set_secret TEST_SECRET second
  [ "$(grep -c '^TEST_SECRET=' "$HC_SECRETS")" -eq 1 ]
  (. "$HC_SECRETS"; [ "$TEST_SECRET" = second ] && [ "$OTHER_SECRET" = kept ])
  [ "$(stat -f %Lp "$HC_SECRETS")" = 600 ]
  [ ! -e "$HC_SECRETS.tmp" ]
}

@test "ensure_secret: generates a missing secret once, with special characters" {
  load_common
  ensure_secret TEST_SECRET printf '%s' "a 'b' \$c"
  [ "$TEST_SECRET" = "a 'b' \$c" ]
  ensure_secret TEST_SECRET printf '%s' 'not used'
  [ "$(grep -c '^TEST_SECRET=' "$HC_SECRETS")" -eq 1 ]
  (unset TEST_SECRET; . "$HC_SECRETS"; [ "$TEST_SECRET" = "a 'b' \$c" ])
  [ "$(stat -f %Lp "$HC_SECRETS")" = 600 ]
}

@test "ensure_secret: does nothing when the secret is already set" {
  load_common
  TEST_SECRET=existing
  ensure_secret TEST_SECRET false
  [ "$TEST_SECRET" = existing ]
  [ ! -e "$HC_SECRETS" ]
}

@test "has_module: matches whole module names only" {
  echo 'MODULES="core media backup"' > "$HC_CONFIG"
  load_common
  has_module core
  has_module media
  has_module backup
  run has_module photos;  [ "$status" -eq 1 ]
  run has_module med;     [ "$status" -eq 1 ]
}

@test "uses_docker: false without photos, downloads or dashboard" {
  echo 'MODULES="core media"' > "$HC_CONFIG"
  load_common
  run uses_docker; [ "$status" -eq 1 ]
  MODULES="core photos";    uses_docker
  MODULES="core downloads"; uses_docker
}

@test "defaults: empty config gets the documented defaults" {
  load_common
  [ "$MODULES" = "core media photos" ]
  [ "$DATA_DIR" = "$HC_HOME/Library/HomeCider" ]
  [ "$MEDIA_DIR" = "$HC_HOME/Media" ]
  [ "$PHOTOS_DIR" = "$HC_HOME/Photos/immich" ]
  [ "$IMMICH_DB_DIR" = "$HC_HOME/Library/HomeCider/immich-postgres" ]
  [ "$DOWNLOADS_CONFIG_DIR" = "$HC_HOME/Library/HomeCider/downloads" ]
  [ "$DOWNLOADS_NETWORK" = vpn ]
  [ "$DOWNLOADS_ALLOW_HOME_IP" = false ]
  [ "$DOCKER_MEMORY_MIB" = 6144 ]
  [ "$DISK_ALERT_PCT" = 85 ]
  [ "$BATTERY_SHUTDOWN_PCT" = 15 ]
  [ "$UPDATE_WEEKDAY" = 0 ]
  [ "$UPDATE_HOUR" = 4 ]
  [ "$UPDATE_ALL_HOMEBREW" = false ]
  [ "$UPDATE_PRUNE_IMAGES" = true ]
  [ "$JELLYFIN_UID" = 450 ]
  [ -n "$TZ" ]
}

@test "defaults: values in homecider.env are kept" {
  printf '%s\n' 'MEDIA_DIR=/Volumes/Media' 'DISK_ALERT_PCT=90' > "$HC_CONFIG"
  load_common
  [ "$MEDIA_DIR" = /Volumes/Media ]
  [ "$DISK_ALERT_PCT" = 90 ]
  [ "$PHOTOS_DIR" = "$HC_HOME/Photos/immich" ]
}

@test "missing config: exits with a pointer to homecider init" {
  HC_CONFIG="$BATS_TEST_TMPDIR/missing.env"
  run env HC_ROOT="$REPO" HC_CONFIG="$HC_CONFIG" sh -c '. "$1"' sh "$REPO/lib/common.sh"
  [ "$status" -eq 1 ]
  [[ "$output" == *"run: homecider init"* ]]
}

@test "HC_ROOT_STABLE: Homebrew Cellar path becomes the opt path" {
  HC_ROOT=/opt/homebrew/Cellar/homecider/0.1.0/libexec
  load_common
  [ "$HC_ROOT_STABLE" = /opt/homebrew/opt/homecider/libexec ]
}

@test "uses_docker: true with dashboard" {
  echo 'MODULES="core dashboard"' > "$HC_CONFIG"
  load_common
  uses_docker
}
