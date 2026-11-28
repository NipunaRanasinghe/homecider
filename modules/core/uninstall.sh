#!/bin/sh
# homecider uninstall: stop the services and jobs and remove what apply installed into the system.
# Kept: media, photos, app data, Jellyfin data, vaults, homecider.env, secrets.env, logs, the backup repository
# and the Homebrew apps (OrbStack, Jellyfin, restic).
# Not changed back, because the values before apply are not recorded: firewall and stealth mode, sharing services
# (off), the macOS update policy and home-folder permissions.
# Runs as the owner; calls itself once with sudo for the root part.
set -eu
HC_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"; . "$HC_ROOT/lib/common.sh"

if [ "${1:-}" = root ]; then
  [ "$(id -u)" = 0 ] || die "uninstall root part must run as root"
  for j in jellyfin low-battery; do
    launchctl bootout "system/$HC_LABEL.$j" 2>/dev/null || true
    rm -f "/Library/LaunchDaemons/$HC_LABEL.$j.plist"
  done
  rm -f /usr/local/sbin/homecider-low-battery /etc/sudoers.d/homecider-jellyfin
  # SSH: back to the macOS default, which allows password login.
  rm -f /etc/ssh/sshd_config.d/000-homecider.conf
  # Power: macOS default sleep settings.
  pmset -a disablesleep 0
  pmset restoredefaults >/dev/null
  # Hidden user _jellyfin, its group and its access to the home folder.
  if dscl . -read /Users/_jellyfin >/dev/null 2>&1; then
    chmod -a "user:_jellyfin allow search" "$HC_HOME" 2>/dev/null || true
    dscl . -delete /Users/_jellyfin
  fi
  dscl . -read /Groups/_jellyfin >/dev/null 2>&1 && dscl . -delete /Groups/_jellyfin
  log "uninstall (root): launch daemons, SSH config, power settings, sudoers rule and user _jellyfin removed"
  exit 0
fi

[ "$(id -u)" != 0 ] || die "run uninstall as your user, not with sudo (it asks for sudo itself)"
printf 'Remove HomeCider services and system settings from this Mac? Data is kept. Type yes: '
read -r answer
[ "$answer" = yes ] || die "cancelled"

# Containers: stop and remove; volumes, images and data folders stay. Every Compose project apply created has a
# folder with a .env in HC_COMPOSE, including modules turned off since.
for e in "$HC_COMPOSE"/*/.env; do
  [ -f "$e" ] || continue
  m="$(basename "$(dirname "$e")")"
  dc "$m" down || warn "could not stop the $m containers (is OrbStack running?); remove them with: docker compose down"
done

for j in alerts update backup; do
  launchctl bootout "gui/$HC_UID/$HC_LABEL.$j" 2>/dev/null || true
  rm -f "$HC_HOME/Library/LaunchAgents/$HC_LABEL.$j.plist"
done

# The docker PATH line that apply added to ~/.zshenv.
line="export PATH=\"/Applications/OrbStack.app/Contents/MacOS/xbin:/opt/homebrew/bin:\$PATH\""
if grep -qxF "$line" "$HC_HOME/.zshenv" 2>/dev/null; then
  grep -vxF "$line" "$HC_HOME/.zshenv" > "$HC_HOME/.zshenv.tmp" || true
  cat "$HC_HOME/.zshenv.tmp" > "$HC_HOME/.zshenv"; rm -f "$HC_HOME/.zshenv.tmp"
fi

log "root steps (sudo)"
sudo sh "$HC_ROOT/modules/core/uninstall.sh" root

log "uninstall finished. SSH password login and sleep are back to the macOS defaults."
kept=""; for m in $(modules_with MOD_KEPT all); do kept="$kept$(module_field "$m" MOD_KEPT), "; done
log "kept: $kept$DATA_DIR, $HC_CONFIG, $HC_STATE"
log "left as set: firewall, sharing services (off), update policy, home-folder permissions (System Settings changes them)"
log "to remove the apps: brew uninstall --cask orbstack jellyfin"
