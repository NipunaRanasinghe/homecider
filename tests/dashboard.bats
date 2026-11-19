#!/usr/bin/env bats
# Tests for modules/dashboard/config.sh (Homepage config) and status.sh (Mac panel).
# HC_CONFIG and HC_STATE point at the per-test temporary directory; nothing is written to the real home folder.
# YAML is checked with Ruby's YAML library (macOS and the CI runner have Ruby).

setup() {
  REPO="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  export HC_ROOT="$REPO"
  export HC_CONFIG="$BATS_TEST_TMPDIR/homecider.env"
  export HC_STATE="$BATS_TEST_TMPDIR/state"
  OUT="$BATS_TEST_TMPDIR/config"
  mkdir -p "$HC_STATE"
  : > "$HC_CONFIG"
  unset MODULES JELLYFIN_API_KEY IMMICH_API_KEY RADARR_API_KEY SONARR_API_KEY PROWLARR_API_KEY QBIT_PASSWORD \
    VPN_SERVICE_PROVIDER DOWNLOADS_NETWORK DOWNLOADS_CONFIG_DIR
}

config() { sh "$REPO/modules/dashboard/config.sh" "$OUT" mac.example.ts.net; }
# Print a YAML file as JSON.
as_json() { ruby -ryaml -rjson -e 'puts JSON.generate(YAML.load_file(ARGV[0]))' "$1" 2>/dev/null; }
# Run a Python expression against services.yaml, loaded as `s` (list of {group: [{name: {...}}]}).
services() {
  as_json "$OUT/services.yaml" | python3 -c '
import json, sys
s = json.load(sys.stdin)
groups = {list(g)[0]: {list(e)[0]: list(e.values())[0] for e in list(g.values())[0]} for g in s}
sys.exit(0 if eval(sys.argv[1]) else 1)' "$1"
}

@test "config: every file is valid YAML" {
  echo 'MODULES="core media photos downloads dashboard"' > "$HC_CONFIG"
  config
  for f in settings widgets bookmarks docker services; do
    as_json "$OUT/$f.yaml" >/dev/null || { echo "invalid: $f.yaml"; return 1; }
  done
  [ "$(stat -f %Lp "$OUT/services.yaml")" = 600 ]
}

@test "config: core only has just the Mac panel" {
  echo 'MODULES="core dashboard"' > "$HC_CONFIG"
  config
  services 'list(groups) == ["Mac"]'
  services 'groups["Mac"]["HomeCider"]["widget"]["url"] == "http://status:8080/status.json"'
}

@test "config: no keys means links and container status, no widgets" {
  echo 'MODULES="core media photos dashboard"' > "$HC_CONFIG"
  config
  services 'groups["Media"]["Jellyfin"]["href"] == "http://mac.example.ts.net:8096"'
  services '"widget" not in groups["Media"]["Jellyfin"] and "widget" not in groups["Media"]["Immich"]'
  services 'groups["Media"]["Immich"]["container"] == "immich_server" and groups["Media"]["Immich"]["server"] == "homecider"'
}

@test "config: keys from secrets.env become widgets, quoted" {
  echo 'MODULES="core media photos dashboard"' > "$HC_CONFIG"
  printf '%s\n' "JELLYFIN_API_KEY='abc'\\''\"def'" "IMMICH_API_KEY='imm123'" > "$HC_STATE/secrets.env"
  config
  services 'groups["Media"]["Jellyfin"]["widget"] == {"type": "jellyfin", "url": "http://host.docker.internal:8096", "key": "abc'"'"'\"def", "version": 2}'
  services 'groups["Media"]["Immich"]["widget"]["key"] == "imm123"'
}

@test "config: downloads reads the Seerr key and hides links for localhost-only apps" {
  mkdir -p "$BATS_TEST_TMPDIR/dl/seerr"
  echo '{"main": {"apiKey": "seerrkey"}}' > "$BATS_TEST_TMPDIR/dl/seerr/settings.json"
  printf '%s\n' 'MODULES="core downloads dashboard"' "DOWNLOADS_CONFIG_DIR=$BATS_TEST_TMPDIR/dl" > "$HC_CONFIG"
  printf '%s\n' "RADARR_API_KEY='r1'" "QBIT_PASSWORD='q1'" > "$HC_STATE/secrets.env"
  config
  services 'groups["Downloads"]["Seerr"]["widget"]["key"] == "seerrkey"'
  services 'groups["Downloads"]["Radarr"]["widget"]["key"] == "r1" and "widget" not in groups["Downloads"]["Sonarr"]'
  services 'groups["Downloads"]["qBittorrent"]["widget"]["password"] == "q1" and "href" not in groups["Downloads"]["qBittorrent"]'
  services '"href" not in groups["Downloads"]["Maintainerr"] and "Gluetun VPN" not in groups["Downloads"]'
}

@test "config: Gluetun listed only with a VPN configured" {
  printf '%s\n' 'MODULES="core downloads dashboard"' 'VPN_SERVICE_PROVIDER=protonvpn' > "$HC_CONFIG"
  config
  services 'groups["Downloads"]["Gluetun VPN"]["container"] == "gluetun"'
}

@test "status: writes valid JSON with every field" {
  echo 'MODULES="core dashboard"' > "$HC_CONFIG"
  mkdir -p "$HC_STATE/alerts"; touch "$HC_STATE/alerts/disk" "$HC_STATE/alerts/immich-v9"
  sh "$REPO/modules/dashboard/status.sh"
  python3 -c '
import json, sys
d = json.load(open(sys.argv[1]))
assert set(d) == {"updated", "disk", "memory_free", "load", "battery", "alerts", "backup", "jobs"}, d
assert isinstance(d["disk"], int) and d["alerts"] == "disk" and d["backup"] == "module off", d
' "$HC_STATE/dashboard/status.json"
  [ "$(stat -f %Lp "$HC_STATE/dashboard/status.json")" = 644 ]
  [ ! -e "$HC_STATE/dashboard/status.json.tmp" ]
}
