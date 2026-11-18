# Shared helpers, sourced by bin/homecider, module scripts and launchd jobs.
# The caller sets HC_ROOT (repository root) before sourcing.

[ -n "${HC_ROOT:-}" ] || { echo "homecider: HC_ROOT not set" >&2; exit 1; }
HC_CONFIG="${HC_CONFIG:-$HC_ROOT/homecider.env}"
[ -f "$HC_CONFIG" ] || { echo "homecider: $HC_CONFIG not found; run: homecider init" >&2; exit 1; }
# shellcheck disable=SC1090
. "$HC_CONFIG"

# The account that owns the server. Under sudo, SUDO_USER is the person who ran homecider.
HC_USER="${HC_USER:-${SUDO_USER:-$(id -un)}}"
HC_HOME="$(dscl . -read "/Users/$HC_USER" NFSHomeDirectory 2>/dev/null | awk '{print $2}')"
[ -n "$HC_HOME" ] || { echo "homecider: user $HC_USER not found" >&2; exit 1; }
HC_UID="$(id -u "$HC_USER")"
HC_GID="$(id -g "$HC_USER")"
HC_STATE="$HC_HOME/Library/Application Support/homecider"   # secrets and alert state
HC_SECRETS="$HC_STATE/secrets.env"
HC_LOGS="$HC_HOME/Library/Logs/homecider"
HC_LABEL=io.homecider                                          # launchd label prefix
# shellcheck disable=SC1090
[ -f "$HC_SECRETS" ] && . "$HC_SECRETS"

# Defaults for everything homecider.env may leave out (documented in homecider.env.example).
: "${MODULES:=core media photos}"
: "${TZ:=$(readlink /etc/localtime | sed 's#.*/zoneinfo/##')}"
: "${DATA_DIR:=$HC_HOME/Library/HomeCider}"
: "${MEDIA_DIR:=$HC_HOME/Media}"
: "${PHOTOS_DIR:=$HC_HOME/Photos/immich}"
: "${IMMICH_DB_DIR:=$DATA_DIR/immich-postgres}"
: "${IMMICH_VERSION:=v3.4.1}"
: "${DOWNLOADS_CONFIG_DIR:=$DATA_DIR/downloads}"
: "${DOWNLOADS_NETWORK:=vpn}"
: "${DOWNLOADS_ALLOW_HOME_IP:=false}"
: "${DOCKER_MEMORY_MIB:=6144}"
: "${DISK_ALERT_PCT:=85}"
: "${BATTERY_SHUTDOWN_PCT:=15}"
: "${UPDATE_WEEKDAY:=0}"
: "${UPDATE_HOUR:=4}"
: "${JELLYFIN_UID:=450}"

export PATH="/Applications/OrbStack.app/Contents/MacOS/xbin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"
export TZ

log()  { printf 'homecider: %s\n' "$*"; }
warn() { printf 'homecider: warning: %s\n' "$*" >&2; }
die()  { printf 'homecider: %s\n' "$*" >&2; exit 1; }

has_module()  { case " $MODULES " in *" $1 "*) return 0 ;; esac; return 1; }
has_battery() { pmset -g batt | grep -q InternalBattery; }
uses_docker() { has_module photos || has_module downloads; }

# Run a command as the server owner (used by root scripts).
as_user() { if [ "$(id -u)" = 0 ]; then sudo -u "$HC_USER" -H "$@"; else "$@"; fi; }

# Ensure a secret exists in secrets.env (mode 600); generate it with the given command if missing.
ensure_secret() {
  name="$1"; shift
  eval "current=\${$name:-}"
  [ -n "$current" ] && return 0
  value="$("$@")"
  mkdir -p "$HC_STATE"
  ( umask 077; printf '%s=%s\n' "$name" "$value" >> "$HC_SECRETS" )
  eval "$name=\$value"
}
set_secret() {   # name value: add or replace
  mkdir -p "$HC_STATE"; touch "$HC_SECRETS"; chmod 600 "$HC_SECRETS"
  grep -v "^$1=" "$HC_SECRETS" > "$HC_SECRETS.tmp" || true
  printf '%s=%s\n' "$1" "$2" >> "$HC_SECRETS.tmp"
  mv "$HC_SECRETS.tmp" "$HC_SECRETS"; chmod 600 "$HC_SECRETS"
  eval "$1=\$2"
}

# ntfy push message: title, body, tag. Does nothing without a topic.
notify() {
  [ -n "${NTFY_TOPIC:-}" ] || return 0
  curl -fsS -m 15 -H "Title: $1" -H "Tags: $3" -d "$2" "https://ntfy.sh/$NTFY_TOPIC" >/dev/null
}

# Load a launchd job from a plist file: domain (system | gui), plist path.
launchd_load() {
  target="$1"; [ "$target" = gui ] && target="gui/$HC_UID"
  launchctl bootout "$target" "$2" 2>/dev/null || true
  launchctl bootstrap "$target" "$2"
}

# docker compose pull with 3 attempts; registries sometimes rate-limit parallel pulls. If it still fails, continue
# with the images already on this Mac (up -d then fails on its own if an image is really missing).
compose_pull() {
  for attempt in 1 2 3; do
    docker compose pull -q && return 0
    warn "image pull failed (attempt $attempt of 3)"; sleep $((attempt * 20))
  done
  warn "continuing with local images"
}
