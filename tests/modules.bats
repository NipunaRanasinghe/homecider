#!/usr/bin/env bats
# Tests for module manifests (modules/<m>/module.env) and the helpers that read them (lib/common.sh).
# HC_CONFIG and HC_STATE point at the per-test temporary directory; nothing is written to the real home folder.

setup() {
  REPO="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  export HC_ROOT="$REPO"
  export HC_CONFIG="$BATS_TEST_TMPDIR/homecider.env"
  export HC_STATE="$BATS_TEST_TMPDIR/state"
  : > "$HC_CONFIG"
  unset MODULES
}

load_common() { . "$HC_ROOT/lib/common.sh"; }

@test "module_field: reads a field from the module's manifest" {
  load_common
  [ "$(module_field photos MOD_TITLE)" = Immich ]
  [ "$(module_field media MOD_STATUS)" = "jellyfin http://localhost:8096 /health" ]
  [ "$(module_field photos MOD_BACKUP_PATHS)" = "$PHOTOS_DIR" ]
}

@test "module_field: empty for a field the module does not set, and for a module without a manifest" {
  load_common
  [ -z "$(module_field media MOD_COMPOSE)" ]     # photos sets it; must not leak into media
  [ -z "$(module_field downloads MOD_TITLE)" ]
  [ -z "$(module_field core MOD_STATUS)" ]
  [ -z "$(module_field no-such-module MOD_STATUS)" ]
}

@test "module_field: unknown field name fails" {
  load_common
  run module_field photos MOD_TYPO
  [ "$status" -ne 0 ]
  [[ "$output" == *"unknown module field MOD_TYPO"* ]]
}

@test "manifests: every MOD_ assignment is a known field" {
  load_common
  for f in "$REPO"/modules/*/module.env; do
    for v in $(sed -n 's/^\(MOD_[A-Z_]*\)=.*/\1/p' "$f"); do
      case " $HC_MOD_FIELDS " in *" $v "*) ;; *) echo "$f: unknown field $v"; return 1 ;; esac
    done
  done
}

# Scripts call module_field and modules_with inside $(...), where die for an unknown field only ends the
# subshell and the caller gets an empty list. This catches a mistyped field name in CI instead.
@test "scripts: every MOD_ name used in the scripts is a known field" {
  load_common
  cd "$REPO"
  for v in $(grep -ohE '(^|[^A-Z_])MOD_[A-Z][A-Z_]*' bin/homecider lib/*.sh modules/*/*.sh | sed 's/^[^M]*//' | sort -u); do
    case " $HC_MOD_FIELDS " in *" $v "*) ;; *) echo "unknown field $v: $(grep -lw "$v" bin/homecider lib/*.sh modules/*/*.sh)"; return 1 ;; esac
  done
}

@test "manifests: MOD_ fields are not left set after loading common.sh" {
  load_common
  for v in $HC_MOD_FIELDS; do
    eval "[ -z \"\${$v+set}\" ]" || { echo "$v is set"; return 1; }
  done
}

@test "modules_with: enabled modules in MODULES order; all includes disabled modules" {
  echo 'MODULES="core dashboard photos media"' > "$HC_CONFIG"
  load_common
  [ "$(modules_with MOD_STATUS | tr '\n' ' ')" = "dashboard photos media " ]
  [ "$(modules_with MOD_ALERT | tr '\n' ' ')" = "photos media " ]
  MODULES="core media"
  [ "$(modules_with MOD_COMPOSE)" = "" ]
  [ "$(modules_with MOD_COMPOSE all | tr '\n' ' ')" = "dashboard downloads photos " ]
}

@test "backup: paths and excludes of disabled modules are still included" {
  d="$BATS_TEST_TMPDIR/d"; mkdir -p "$d/photos" "$d/data/downloads"
  printf '%s\n' 'MODULES="core media backup"' "DATA_DIR=$d/data" "PHOTOS_DIR=$d/photos" 'BACKUP_REPOSITORY=s3:x' > "$HC_CONFIG"
  export RESTIC_PASSWORD=x AWS_ACCESS_KEY_ID=x AWS_SECRET_ACCESS_KEY=x
  load_common
  . "$REPO/modules/backup/env.sh"
  backup_paths | grep -qxF "$d/photos"
  backup_paths | grep -qxF "$d/data/downloads"
  backup_excludes | grep -qxF "$d/photos/thumbs"
  backup_excludes | grep -qxF "$d/data/immich-postgres"
}

# A module made of only a manifest and user.sh must reach status, alerts, update, uninstall and backup with no
# other file changed. Runs on a copy of the repository with an extra module zz.
@test "new module: a manifest is enough to be picked up by the core scripts" {
  root="$BATS_TEST_TMPDIR/repo"; mkdir -p "$root"
  cp -R "$REPO/bin" "$REPO/lib" "$REPO/modules" "$root/"
  mkdir -p "$root/modules/zz" "$BATS_TEST_TMPDIR/zz-data"
  cat > "$root/modules/zz/module.env" <<EOF
: "\${ZZ_DIR:=$BATS_TEST_TMPDIR/zz-data}"
MOD_TITLE=Zed
MOD_STATUS="zed http://localhost:1 /ping"
MOD_ALERT=yes
MOD_COMPOSE=yes
MOD_RELEASE="example/zz ZZ_VERSION"
MOD_BACKUP_PATHS="\$ZZ_DIR"
MOD_BACKUP_EXCLUDES="\$ZZ_DIR/cache"
MOD_KEPT="\$ZZ_DIR"
EOF
  printf '#!/bin/sh\n# zz: test module\n' > "$root/modules/zz/user.sh"
  printf '%s\n' 'MODULES="core zz"' 'BACKUP_REPOSITORY=s3:x' > "$HC_CONFIG"
  export HC_ROOT="$root" RESTIC_PASSWORD=x AWS_ACCESS_KEY_ID=x AWS_SECRET_ACCESS_KEY=x
  load_common
  [ "$ZZ_DIR" = "$BATS_TEST_TMPDIR/zz-data" ]                  # default from the manifest
  uses_docker                                                    # OrbStack install, update pull loop
  for f in MOD_STATUS MOD_ALERT MOD_COMPOSE MOD_RELEASE; do     # status, alerts, update
    [ "$(modules_with "$f")" = zz ] || { echo "$f: $(modules_with "$f")"; return 1; }
  done
  [ "$(modules_with MOD_KEPT all | grep -c zz)" = 1 ]            # uninstall
  . "$root/modules/backup/env.sh"
  backup_paths | grep -qxF "$ZZ_DIR"
  backup_excludes | grep -qxF "$ZZ_DIR/cache"
  run sh "$root/bin/homecider" status
  [[ "$output" == *"zed          DOWN  http://localhost:1"* ]]
  run sh "$root/bin/homecider" apply --dry-run
  [[ "$output" == *"zz: test module"* ]]
}

# Places outside a module's folder that call has_module <module> or use a setting defaulted in its manifest.
# Each line is a deliberate exception (out of scope in issue #1): doctor's downloads checks, the Jellyfin cask in
# apply and update, dashboard running last in apply, the VPN alert, the dashboard status job run by alerts, the
# dashboard tiles, and downloads creating folders in the media folder. Adding a line here needs a reason; removing
# coupling means removing its line.
coupling() {
  for f in modules/*/module.env; do
    m="$(basename "$(dirname "$f")")"
    vars="$(sed -n 's/^: "\${\([A-Z_]*\):=.*/\1/p' "$f")"
    for file in bin/homecider lib/*.sh modules/*/*.sh; do
      case "$file" in modules/"$m"/*) continue ;; esac
      if grep -v '^[[:space:]]*#' "$file" | grep -qw "has_module $m"; then echo "$file has_module $m"; fi
      for v in $vars; do
        if grep -v '^[[:space:]]*#' "$file" | grep -qw "$v"; then echo "$file $v"; fi
      done
    done
  done | sort
}

@test "coupling: module references outside the module's folder match the allow-list" {
  cd "$REPO"
  found="$(coupling)"
  expected="bin/homecider DOWNLOADS_ACCEPT_RESPONSIBILITY
bin/homecider DOWNLOADS_NETWORK
bin/homecider has_module dashboard
bin/homecider has_module downloads
bin/homecider has_module media
modules/core/alerts.sh DOWNLOADS_NETWORK
modules/core/alerts.sh has_module dashboard
modules/core/alerts.sh has_module downloads
modules/core/update.sh has_module media
modules/dashboard/config.sh DOWNLOADS_CONFIG_DIR
modules/dashboard/config.sh DOWNLOADS_NETWORK
modules/dashboard/config.sh has_module downloads
modules/dashboard/config.sh has_module media
modules/dashboard/config.sh has_module photos
modules/dashboard/user.sh has_module media
modules/dashboard/user.sh has_module photos
modules/downloads/user.sh MEDIA_DIR"
  [ "$found" = "$expected" ] || { diff <(echo "$expected") <(echo "$found"); return 1; }
}

@test "doctor: fails for a folder setting with a space or a glob character" {
  printf '%s\n' 'PHOTOS_DIR="/x/my photos"' 'MEDIA_DIR=/x/media*' > "$HC_CONFIG"
  run sh "$REPO/bin/homecider" doctor
  [[ "$output" == *"FAIL  PHOTOS_DIR must not contain spaces or * ? [ (/x/my photos)"* ]]
  [[ "$output" == *"FAIL  MEDIA_DIR must not contain spaces or * ? [ (/x/media*)"* ]]
  [[ "$output" != *"FAIL  DATA_DIR"* ]]
}
