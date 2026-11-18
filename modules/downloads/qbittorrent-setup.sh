#!/bin/sh
# Apply qBittorrent settings through its web API. Run by user.sh after the container starts. No sudo.
# Logs in with QBIT_PASSWORD from .env (written by user.sh), or on first start with the temporary password from the container log.
set -eu
dir="$(cd "$(dirname "$0")" && pwd)"
. "$dir/.env"
U=http://127.0.0.1:8080
J="$(mktemp)"; trap 'rm -f "$J"' EXIT
for i in $(seq 1 30); do curl -s -o /dev/null "$U" && break; sleep 2; done
login() { curl -s -o /dev/null -w "%{http_code}" -c "$J" --referer "$U" --data-urlencode "username=admin" --data-urlencode "password=$1" "$U/api/v2/auth/login"; }
tmp="$(docker logs qbittorrent 2>&1 | sed -n 's/.*temporary password is provided for this session: //p' | tail -1)"
[ "$(login "$QBIT_PASSWORD")" = 204 ] || [ "$(login "$tmp")" = 204 ] || { echo "qBittorrent login failed" >&2; exit 1; }

# Network interface for torrent traffic: QBIT_INTERFACE in .env (eth0 = home connection), default tun0 (VPN only;
# with no VPN container, tun0 does not exist and qBittorrent sends nothing).
prefs="$(QBIT_PASSWORD="$QBIT_PASSWORD" QBIT_INTERFACE="${QBIT_INTERFACE:-tun0}" python3 -c '
import json, os
print(json.dumps({
  "web_ui_password": os.environ["QBIT_PASSWORD"],
  "current_network_interface": os.environ["QBIT_INTERFACE"],
  "upnp": False,
  "save_path": "/data/torrents",
  "temp_path_enabled": False,
  "excluded_file_names_enabled": True,
  "excluded_file_names": "\n".join(["*.exe", "*.scr", "*.lnk", "*.bat", "*.cmd", "*.msi", "*.zip", "*.rar"]),
  "max_ratio_enabled": True, "max_ratio": 1,                      # stop seeding at ratio 1
  "max_seeding_time_enabled": True, "max_seeding_time": 1440,     # or after 1 day
  "max_ratio_act": 0,                                             # 0 = stop; Radarr/Sonarr then remove it
  # VPN mode: the Gluetun port-forwarding hook calls this API from 127.0.0.1 inside the shared network.
  # The web UI is published on 127.0.0.1 of the Mac only, and those requests arrive from the Docker gateway.
  "bypass_local_auth": os.environ["QBIT_INTERFACE"] == "tun0",
}))')"
curl -sf -o /dev/null -b "$J" --referer "$U" --data-urlencode "json=$prefs" "$U/api/v2/app/setPreferences"
echo "qBittorrent settings applied"
