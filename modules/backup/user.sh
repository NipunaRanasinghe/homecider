#!/bin/sh
# backup: restic (Homebrew) to an S3-compatible bucket such as Backblaze B2, every night at BACKUP_HOUR.
# Creates the repository on first run. See docs/backup.md for the bucket and key setup.
set -eu
HC_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"; . "$HC_ROOT/lib/common.sh"; . "$HC_ROOT/modules/backup/env.sh"

command -v restic >/dev/null || brew install restic
if ! restic cat config >/dev/null 2>&1; then
  log "backup: creating restic repository in $BACKUP_REPOSITORY"
  restic init
fi

plist="$HOME/Library/LaunchAgents/$HC_LABEL.backup.plist"
cat > "$plist" <<EOT
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>$HC_LABEL.backup</string>
  <key>ProgramArguments</key><array><string>/bin/sh</string><string>$HC_ROOT_STABLE/modules/backup/run.sh</string></array>
  <key>StartCalendarInterval</key><dict><key>Hour</key><integer>$BACKUP_HOUR</integer><key>Minute</key><integer>30</integer></dict>
  <key>LowPriorityIO</key><true/>
  <key>Nice</key><integer>10</integer>
  <key>StandardOutPath</key><string>$HC_LOGS/backup.log</string>
  <key>StandardErrorPath</key><string>$HC_LOGS/backup.log</string>
</dict></plist>
EOT
launchd_load gui "$plist"
log "backup: nightly at $BACKUP_HOUR:30 to $BACKUP_REPOSITORY; paths: $(backup_paths | tr '\n' ' ')"
