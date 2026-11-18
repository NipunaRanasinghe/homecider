#!/bin/sh
# core, user part: ntfy topic, OrbStack (when a Docker module is on), alert checks every 5 min, weekly update job.
set -eu
HC_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"; . "$HC_ROOT/lib/common.sh"

mkdir -p "$HC_STATE" "$HC_LOGS" "$HOME/Library/LaunchAgents"
ensure_secret NTFY_TOPIC sh -c 'echo "hc-$(openssl rand -hex 12)"'

if uses_docker; then
  xbin=/Applications/OrbStack.app/Contents/MacOS/xbin
  [ -x "$xbin/docker" ] || die "OrbStack is not installed (brew install --cask orbstack)"
  # docker on PATH for SSH sessions, compose/buildx plugins, start at login, VM memory cap.
  line="export PATH=\"$xbin:/opt/homebrew/bin:\$PATH\""
  grep -qxF "$line" "$HOME/.zshenv" 2>/dev/null || echo "$line" >> "$HOME/.zshenv"
  mkdir -p "$HOME/.docker/cli-plugins"
  ln -sf "$xbin/docker-compose" "$HOME/.docker/cli-plugins/docker-compose"
  ln -sf "$xbin/docker-buildx" "$HOME/.docker/cli-plugins/docker-buildx"
  orbctl config set app.start_at_login true >/dev/null
  if [ "$(orbctl config get memory_mib 2>/dev/null)" != "$DOCKER_MEMORY_MIB" ]; then
    orbctl config set memory_mib "$DOCKER_MEMORY_MIB" >/dev/null
    orbctl stop && orbctl start
  fi
  orbctl start >/dev/null 2>&1 || true
fi

agent() {   # label, script, schedule XML, log name
  plist="$HOME/Library/LaunchAgents/$HC_LABEL.$1.plist"
  cat > "$plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>$HC_LABEL.$1</string>
  <key>ProgramArguments</key><array><string>/bin/sh</string><string>$HC_ROOT/modules/core/$2</string></array>
  $3
  <key>StandardOutPath</key><string>$HC_LOGS/$1.log</string>
  <key>StandardErrorPath</key><string>$HC_LOGS/$1.log</string>
</dict></plist>
EOF
  launchd_load gui "$plist"
}
agent alerts alerts.sh '<key>StartInterval</key><integer>300</integer><key>RunAtLoad</key><true/>'
agent update update.sh "<key>StartCalendarInterval</key><dict><key>Weekday</key><integer>$UPDATE_WEEKDAY</integer><key>Hour</key><integer>$UPDATE_HOUR</integer><key>Minute</key><integer>0</integer></dict>"

log "core (user): alerts every 5 min, weekly update (weekday $UPDATE_WEEKDAY, $UPDATE_HOUR:00); ntfy topic: $NTFY_TOPIC"
