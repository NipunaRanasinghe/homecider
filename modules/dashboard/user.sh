#!/bin/sh
# dashboard (opt-in): Homepage on port 3000 with the enabled services and a Mac panel (status.sh).
# Runs after the other modules (bin/homecider apply), so their API keys are already in secrets.env.
# Jellyfin and Immich keys are created by hand once: see docs/dashboard.md.
set -eu
HC_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"; . "$HC_ROOT/lib/common.sh"
dir="$HC_ROOT_STABLE/modules/dashboard"
proj="$HC_COMPOSE/dashboard"; mkdir -p "$proj/config"; chmod 700 "$HC_STATE" "$HC_COMPOSE" "$proj"

# Host names a browser may use for the dashboard. Homepage answers only these (HOMEPAGE_ALLOWED_HOSTS).
local_name="$(scutil --get LocalHostName).local"
lan_ip="$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || true)"
ts_name=""; ts_ip=""
if [ -x /opt/homebrew/bin/tailscale ]; then
  ts_ip="$(/opt/homebrew/bin/tailscale ip -4 2>/dev/null | head -1 || true)"
  ts_name="$(/opt/homebrew/bin/tailscale status --json 2>/dev/null |
    python3 -c 'import json, sys; print(json.load(sys.stdin)["Self"]["DNSName"].rstrip("."))' 2>/dev/null || true)"
fi
hosts="$local_name:3000"
for h in "$lan_ip" "$ts_name" "$ts_ip"; do [ -z "$h" ] || hosts="$hosts,$h:3000"; done
# Links open on the phone: the Tailscale name works at home and away (with Tailscale on); otherwise the local IP
# address. Not the .local name: Android cannot resolve .local names.
link="${ts_name:-${lan_ip:-$local_name}}"

sh "$dir/config.sh" "$proj/config" "$link"
sh "$dir/status.sh"

( umask 077; cat > "$proj/.env" <<EOT
# Written by homecider apply; edit homecider.env instead.
COMPOSE_FILE=$dir/docker-compose.yml
PUID=$HC_UID
PGID=$HC_GID
# Single quotes: the paths contain a space (Application Support).
CONFIG_DIR='$proj/config'
STATUS_DIR='$HC_STATE/dashboard'
ALLOWED_HOSTS=$hosts
EOT
)
compose_pull dashboard
dc dashboard up -d --remove-orphans

has_module media && [ -z "${JELLYFIN_API_KEY:-}" ] &&
  log "dashboard: no Jellyfin numbers yet; create an API key, then: homecider secret set JELLYFIN_API_KEY (docs/dashboard.md)"
has_module photos && [ -z "${IMMICH_API_KEY:-}" ] &&
  log "dashboard: no Immich numbers yet; create an API key, then: homecider secret set IMMICH_API_KEY (docs/dashboard.md)"
log "dashboard: http://$link:3000 (at home also http://${lan_ip:-$local_name}:3000)"
