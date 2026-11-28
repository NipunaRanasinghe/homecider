#!/bin/sh
# Writes $HC_STATE/dashboard/status.json, the Mac panel on the dashboard: disk, memory, load, battery, active
# alerts, last backup and launchd jobs. Run by the alerts job every 5 minutes and by apply. No secrets in it.
set -u
HC_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"; . "$HC_ROOT/lib/common.sh"
out="$HC_STATE/dashboard"
mkdir -p "$out"; chmod 755 "$out"

disk="$(df -P /System/Volumes/Data | awk 'NR==2 {gsub("%", "", $5); print $5}')"
mem="$(memory_pressure -Q 2>/dev/null | awk -F': ' '/free percentage/ {gsub("%", "", $2); print $2}')"
load="$(sysctl -n vm.loadavg | awk '{print $2}')"
if has_battery; then
  # "89%; discharging; 9:49 remaining" -> "89% discharging"
  battery="$(pmset -g batt | grep -Eo '[0-9]+%; [a-zA-Z ]+' | head -1 | tr -d ';')"
else
  battery="no battery"
fi

alerts=""
for a in "$HC_STATE"/alerts/*; do
  [ -e "$a" ] || continue
  case "$(basename "$a")" in release-*) ;; *) alerts="$alerts $(basename "$a")" ;; esac
done
alerts="${alerts# }"

if has_module backup; then
  backup="$( [ -f "$HC_STATE/backup-ok" ] && date -r "$(cat "$HC_STATE/backup-ok")" '+%Y-%m-%d %H:%M' || echo never)"
else
  backup="module off"
fi

missing=""; jobs="alerts update"; has_module backup && jobs="$jobs backup"
for j in $jobs; do launchctl print "gui/$HC_UID/$HC_LABEL.$j" >/dev/null 2>&1 || missing="$missing $j"; done

# Every value is a number, or text built from fixed words, numbers and alert names (no quotes or backslashes).
printf '{"updated":"%s","disk":%s,"memory_free":%s,"load":"%s","battery":"%s","alerts":"%s","backup":"%s","jobs":"%s"}\n' \
  "$(date '+%Y-%m-%d %H:%M')" "${disk:-null}" "${mem:-null}" "${load:-?}" "$battery" "${alerts:-none}" "$backup" \
  "$( [ -z "$missing" ] && echo loaded || echo "missing:$missing")" > "$out/status.json.tmp"
chmod 644 "$out/status.json.tmp"
mv "$out/status.json.tmp" "$out/status.json"
