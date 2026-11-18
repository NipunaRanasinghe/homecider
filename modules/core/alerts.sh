#!/bin/sh
# Runs every 5 minutes (launchd). Sends one ntfy message when a problem starts and one when it clears.
set -u
HC_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"; . "$HC_ROOT/lib/common.sh"
state="$HC_STATE/alerts"
mkdir -p "$state"

# check NAME ACTIVE(0|1) TITLE MESSAGE
check() {
  if [ "$2" = 1 ]; then
    [ -e "$state/$1" ] || { notify "$3" "$4" warning && touch "$state/$1"; }
  elif [ -e "$state/$1" ]; then
    notify "Resolved: $3" "Back to normal." white_check_mark && rm -f "$state/$1"
  fi
}
# Prints 1 only if the problem was also seen on the previous run, so restarts and updates don't alert.
twice() {
  if [ "$2" = 1 ]; then
    [ -e "$state/.$1" ] && echo 1 || { touch "$state/.$1"; echo 0; }
  else
    rm -f "$state/.$1"; echo 0
  fi
}
http_down() { curl -fsS -m 10 "$1" >/dev/null 2>&1 && echo 0 || echo 1; }

disk="$(df -P /System/Volumes/Data | awk 'NR==2 {gsub("%", "", $5); print $5}')"
check disk "$([ "$disk" -gt "$DISK_ALERT_PCT" ] && echo 1 || echo 0)" "Disk ${disk}% full" "Data volume is above ${DISK_ALERT_PCT}%."

if has_battery; then
  batt="$(pmset -g batt)"
  pct="$(echo "$batt" | grep -Eo '[0-9]+%' | head -1)"
  echo "$batt" | grep -q "'Battery Power'" && onbatt=1 || onbatt=0
  check on-battery "$onbatt" "On battery ($pct)" "Charger disconnected or power cut. Clean shutdown at ${BATTERY_SHUTDOWN_PCT}%."
  cond="$(system_profiler SPPowerDataType | awk -F': ' '/Condition/ {print $2; exit}')"
  check battery-condition "$([ "$cond" != Normal ] && echo 1 || echo 0)" "Battery condition: $cond" "macOS reports the battery needs service."
fi

if has_module media; then
  check jellyfin-down "$(twice jellyfin-down "$(http_down http://localhost:8096/health)")" "Jellyfin is down" "Health check failed twice, 5 min apart."
fi
if has_module photos; then
  check immich-down "$(twice immich-down "$(http_down http://localhost:2283/api/server/ping)")" "Immich is down" "Health check failed twice, 5 min apart."
fi
if uses_docker; then
  bad="$(docker ps -a --format '{{.Names}} ({{.Status}})' 2>/dev/null || echo 'docker not responding')"
  bad="$(echo "$bad" | grep -E 'Exited|Restarting|unhealthy|Dead|not responding' | tr '\n' ' ')"
  check containers "$(twice containers "$([ -n "$bad" ] && echo 1 || echo 0)")" "Container problem" "$bad"
fi

# macOS update waiting (checked at most once a day; the check is slow).
stamp="$state/.update-checked"
if [ -z "$(find "$stamp" -mtime -1 2>/dev/null)" ]; then
  touch "$stamp"
  softwareupdate -l 2>&1 | grep -q '^\* Label' && upd=1 || upd=0
  check macos-update "$upd" "macOS update waiting" "Install it when someone can unlock the Mac in person (FileVault)."
fi
