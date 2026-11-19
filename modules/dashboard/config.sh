#!/bin/sh
# Writes Homepage's config files into DIR from the enabled modules and the API keys in secrets.env.
# Usage: config.sh DIR LINK_HOST
#   LINK_HOST: host name in the links the phone opens (the Tailscale name, or the Mac's local IP address).
# Homepage reaches the services through host.docker.internal (the Mac, from inside OrbStack). A service gets a
# live widget only when its key is known; without one it is a link (and container status where it has a container).
set -eu
HC_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"; . "$HC_ROOT/lib/common.sh"
dir="$1"; link="$2"
H=http://host.docker.internal
mkdir -p "$dir"

# YAML single-quoted string.
yq() { printf "'%s'" "$(printf '%s' "$1" | sed "s/'/''/g")"; }

# Seerr keeps its API key in settings.json, created on its first start.
seerr_key=""
f="$DOWNLOADS_CONFIG_DIR/seerr/settings.json"
[ -f "$f" ] && seerr_key="$(python3 -c 'import json, sys; print(json.load(open(sys.argv[1]))["main"]["apiKey"])' "$f" 2>/dev/null || true)"

# service NAME ICON HREF CONTAINER: one entry; HREF and CONTAINER may be empty.
service() {
  echo "    - $1:"
  echo "        icon: $2"
  [ -z "$3" ] || echo "        href: $3"
  [ -z "$4" ] || { echo "        server: homecider"; echo "        container: $4"; }
}
# widget TYPE URL [KEY=VALUE ...]: values are quoted, except version (a number) and enableBlocks (true/false).
widget() {
  echo "        widget:"
  echo "          type: $1"
  echo "          url: $2"
  shift 2
  for kv in "$@"; do
    case "$kv" in version=*|enableBlocks=*) echo "          ${kv%%=*}: ${kv#*=}" ;; *) echo "          ${kv%%=*}: $(yq "${kv#*=}")" ;; esac
  done
}

( umask 077
cat > "$dir/settings.yaml" <<'EOT'
# Written by homecider apply; changes here are overwritten.
title: HomeCider
statusStyle: dot
EOT
printf '# Written by homecider apply.\n[]\n' > "$dir/widgets.yaml"
printf '# Written by homecider apply.\n[]\n' > "$dir/bookmarks.yaml"
cat > "$dir/docker.yaml" <<'EOT'
# Written by homecider apply. Read-only Docker API (socket-proxy in docker-compose.yml).
homecider:
  host: socket-proxy
  port: 2375
EOT

{
  echo "# Written by homecider apply; changes here are overwritten."
  echo "- Mac:"
  echo "    - HomeCider:"
  echo "        icon: mdi-apple"
  echo "        description: Updated every 5 minutes"
  echo "        widget:"
  echo "          type: customapi"
  echo "          url: http://status:8080/status.json"
  echo "          refreshInterval: 60000"
  echo "          display: list"
  echo "          mappings:"
  for m in "battery|Battery|text" "disk|Disk used|percent" "memory_free|Memory free|percent" "load|Load (1 min)|text" \
           "alerts|Active alerts|text" "backup|Last backup|text" "jobs|Jobs|text" "updated|Updated|text"; do
    echo "            - field: ${m%%|*}"
    m="${m#*|}"; echo "              label: ${m%%|*}"
    echo "              format: ${m#*|}"
  done

  if has_module media || has_module photos; then
    echo "- Media:"
    if has_module media; then
      service Jellyfin jellyfin.png "http://$link:8096" ""
      [ -z "${JELLYFIN_API_KEY:-}" ] || widget jellyfin "$H:8096" "key=$JELLYFIN_API_KEY" "version=2" "enableBlocks=true"
    fi
    if has_module photos; then
      service Immich immich.png "http://$link:2283" immich_server
      [ -z "${IMMICH_API_KEY:-}" ] || widget immich "$H:2283" "key=$IMMICH_API_KEY" "version=2"
    fi
  fi

  if has_module downloads; then
    echo "- Downloads:"
    service Seerr seerr.png "http://$link:5055" seerr
    [ -z "$seerr_key" ] || widget seerr "$H:5055" "key=$seerr_key"
    service Radarr radarr.png "http://$link:7878" radarr
    [ -z "${RADARR_API_KEY:-}" ] || widget radarr "$H:7878" "key=$RADARR_API_KEY"
    service Sonarr sonarr.png "http://$link:8989" sonarr
    [ -z "${SONARR_API_KEY:-}" ] || widget sonarr "$H:8989" "key=$SONARR_API_KEY"
    service Prowlarr prowlarr.png "http://$link:9696" prowlarr
    [ -z "${PROWLARR_API_KEY:-}" ] || widget prowlarr "$H:9696" "key=$PROWLARR_API_KEY"
    # qBittorrent and Maintainerr listen on 127.0.0.1 only: no link, status and widget only.
    service qBittorrent qbittorrent.png "" qbittorrent
    [ -z "${QBIT_PASSWORD:-}" ] || widget qbittorrent "$H:8080" "username=admin" "password=$QBIT_PASSWORD"
    service Maintainerr maintainerr.png "" maintainerr
    [ "$DOWNLOADS_NETWORK" != vpn ] || [ -z "${VPN_SERVICE_PROVIDER:-}" ] || service "Gluetun VPN" gluetun.png "" gluetun
  fi
} > "$dir/services.yaml"
)
