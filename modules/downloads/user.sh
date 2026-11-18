#!/bin/sh
# downloads (opt-in): start the download chain, apply qBittorrent settings, quality profiles and cleanup rules.
# Network: DOWNLOADS_NETWORK=vpn (default) binds qBittorrent to tun0, which only exists once a VPN container runs,
# so nothing is downloaded before a VPN is set up. DOWNLOADS_NETWORK=home uses the home connection and requires
# DOWNLOADS_ALLOW_HOME_IP=true: every peer and copyright monitor then sees the home IP address.
set -eu
HC_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"; . "$HC_ROOT/lib/common.sh"
dir="$HC_ROOT/modules/downloads"
cfg="$DOWNLOADS_CONFIG_DIR"

# Gluetun settings (see docs/downloads.md). Any of these may live in homecider.env or secrets.env.
VPN_VARS="VPN_SERVICE_PROVIDER VPN_TYPE WIREGUARD_PRIVATE_KEY WIREGUARD_PRESHARED_KEY WIREGUARD_ADDRESSES
  OPENVPN_USER OPENVPN_PASSWORD SERVER_COUNTRIES SERVER_CITIES SERVER_HOSTNAMES VPN_PORT_FORWARDING VPN_PORT_FORWARDING_PROVIDER"
compose_files=docker-compose.yml
case "$DOWNLOADS_NETWORK" in
  vpn)  qbit_if=tun0
        if [ -n "${VPN_SERVICE_PROVIDER:-}" ]; then
          compose_files=docker-compose.yml:docker-compose.vpn.yml
          ( umask 077; : > "$dir/vpn.env"
            for v in $VPN_VARS; do eval "val=\${$v:-}"; [ -n "$val" ] && printf '%s=%s\n' "$v" "$val" >> "$dir/vpn.env"; done )
        else
          rm -f "$dir/vpn.env"
          warn "no VPN configured (VPN_SERVICE_PROVIDER): qBittorrent stays offline; see docs/downloads.md"
        fi ;;
  home) [ "$DOWNLOADS_ALLOW_HOME_IP" = true ] ||
          die "DOWNLOADS_NETWORK=home exposes your home IP to every peer; set DOWNLOADS_ALLOW_HOME_IP=true to accept that"
        qbit_if=eth0 ;;
  *)    die "DOWNLOADS_NETWORK must be vpn or home" ;;
esac
case "$cfg$MEDIA_DIR" in *" "*) die "DOWNLOADS_CONFIG_DIR and MEDIA_DIR must not contain spaces";; esac

ensure_secret QBIT_PASSWORD openssl rand -hex 16
write_env() {
  ( umask 077; cat > "$dir/.env" <<EOT
# Written by homecider apply; edit homecider.env instead.
COMPOSE_FILE=$compose_files
PUID=$HC_UID
PGID=$HC_GID
TZ=$TZ
CONFIG_ROOT=$cfg
MEDIA_ROOT=$MEDIA_DIR
QBIT_PASSWORD=$QBIT_PASSWORD
QBIT_INTERFACE=$qbit_if
RADARR_API_KEY=${RADARR_API_KEY:-}
SONARR_API_KEY=${SONARR_API_KEY:-}
PROWLARR_API_KEY=${PROWLARR_API_KEY:-}
EOT
  )
}
write_env

mkdir -p "$MEDIA_DIR/Movies" "$MEDIA_DIR/Shows" "$MEDIA_DIR/torrents"
for app in radarr sonarr seerr maintainerr recyclarr prowlarr qbittorrent; do mkdir -p "$cfg/$app"; done

# Bind qBittorrent to tun0 before its first start, so it never sends traffic before its settings are applied.
qb="$cfg/qbittorrent/qBittorrent/qBittorrent.conf"
if [ ! -f "$qb" ]; then
  mkdir -p "$(dirname "$qb")"
  printf '[BitTorrent]\nSession\\Interface=tun0\n\n[Network]\nPortForwardingEnabled=false\n' > "$qb"
fi

cd "$dir"
compose_pull
docker compose up -d --remove-orphans

# API keys appear in each app's config.xml after its first start; keep them in secrets.env for Recyclarr and status.
for app in radarr sonarr prowlarr; do
  var="$(echo "$app" | tr a-z A-Z)_API_KEY"
  eval "have=\${$var:-}"
  [ -n "$have" ] && continue
  for i in $(seq 1 30); do [ -f "$cfg/$app/config.xml" ] && break; sleep 2; done
  key="$(sed -n 's:.*<ApiKey>\(.*\)</ApiKey>.*:\1:p' "$cfg/$app/config.xml")"
  [ -n "$key" ] && set_secret "$var" "$key"
done
write_env

sh "$dir/qbittorrent-setup.sh"
docker compose run --rm -T recyclarr sync < /dev/null

# Cleanup rules need Maintainerr connected to Jellyfin, Radarr and Sonarr (done once in its web UI).
if curl -fsS -m 10 http://localhost:6246/api/media-server/libraries 2>/dev/null | grep -q '"Movies"'; then
  python3 "$dir/maintainerr-rules.py"
else
  warn "Maintainerr is not connected yet; connect it (see docs), then run homecider apply again to add the cleanup rules"
fi
log "downloads: running; torrent traffic via $qbit_if ($DOWNLOADS_NETWORK)"
