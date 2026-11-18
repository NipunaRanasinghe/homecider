#!/bin/sh
# media, root part: run Jellyfin (Homebrew cask) as the hidden user _jellyfin from a LaunchDaemon.
# _jellyfin can read MEDIA_DIR and nothing else in the owner's home: it is not in the staff group, it gets
# traverse-only access to the home folder, and home entries that other users could read are made private.
# Reason: Jellyfin's FFmpeg reads downloaded files outside a container; an exploit must not reach personal files.
set -eu
HC_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"; . "$HC_ROOT/lib/common.sh"
[ "$(id -u)" = 0 ] || die "media/root.sh must run as root"
[ -x /Applications/Jellyfin.app/Contents/MacOS/jellyfin ] || die "Jellyfin is not installed (brew install --cask jellyfin)"

name=_jellyfin
data="/Library/Application Support/jellyfin"; cache=/Library/Caches/jellyfin; logf=/Library/Logs/jellyfin.log
label="$HC_LABEL.jellyfin"; plist="/Library/LaunchDaemons/$label.plist"

# Hidden user and group: no password, no login shell.
if ! dscl . -read /Groups/$name >/dev/null 2>&1; then
  dscl . -list /Groups PrimaryGroupID | awk '{print $2}' | grep -qx "$JELLYFIN_UID" && die "GID $JELLYFIN_UID is taken; set JELLYFIN_UID"
  dscl . -create /Groups/$name PrimaryGroupID "$JELLYFIN_UID"
  dscl . -create /Groups/$name Password '*'
fi
if ! dscl . -read /Users/$name >/dev/null 2>&1; then
  dscl . -list /Users UniqueID | awk '{print $2}' | grep -qx "$JELLYFIN_UID" && die "UID $JELLYFIN_UID is taken; set JELLYFIN_UID"
  dscl . -create /Users/$name UniqueID "$JELLYFIN_UID"
  dscl . -create /Users/$name PrimaryGroupID "$JELLYFIN_UID"
  dscl . -create /Users/$name UserShell /usr/bin/false
  dscl . -create /Users/$name NFSHomeDirectory "$data"
  dscl . -create /Users/$name RealName Jellyfin
  dscl . -create /Users/$name Password '*'
  dscl . -create /Users/$name IsHidden 1
fi

# Media folder must exist and be readable by others (Radarr/Sonarr create files 644, folders 755).
as_user mkdir -p "$MEDIA_DIR/Movies" "$MEDIA_DIR/Shows"

# Home folder: closed to other users; _jellyfin may only traverse it (no listing) to reach MEDIA_DIR.
case "$MEDIA_DIR/" in
  "$HC_HOME"/*)
    media_top="${MEDIA_DIR#"$HC_HOME"/}"; media_top="${media_top%%/*}"
    chmod 750 "$HC_HOME"
    ls -led "$HC_HOME" | grep -q "user:$name allow search" || chmod +a "user:$name allow search" "$HC_HOME"
    # Every other home entry readable by other users becomes private (e.g. ~/Photos, ~/Public, dotfolders).
    for e in "$HC_HOME"/* "$HC_HOME"/.[!.]*; do
      [ -e "$e" ] || continue
      [ "$(basename "$e")" = "$media_top" ] && continue
      [ -n "$(find "$e" -maxdepth 0 \( -perm -004 -o -perm -001 \))" ] && chmod o-rwx "$e"
    done ;;
esac

as_user mkdir -p "$HC_STATE"
mkdir -p "$data" "$cache"; touch "$logf"
chown -R $name:$name "$data" "$cache" "$logf"
chmod 700 "$data" "$cache"

# Let the weekly update job (runs as the owner) restart Jellyfin after a Homebrew upgrade, and nothing else.
sudoers=/etc/sudoers.d/homecider-jellyfin
echo "$HC_USER ALL=(root) NOPASSWD: /bin/launchctl kickstart -k system/$label" > "$sudoers.tmp"
chmod 440 "$sudoers.tmp"
visudo -cf "$sudoers.tmp" >/dev/null && mv "$sudoers.tmp" "$sudoers"

app=/Applications/Jellyfin.app/Contents
cat > "$plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>$label</string>
  <key>UserName</key><string>$name</string>
  <key>GroupName</key><string>$name</string>
  <key>ProgramArguments</key><array>
    <string>$app/MacOS/jellyfin</string>
    <string>--webdir</string><string>$app/Resources/jellyfin-web</string>
    <string>--ffmpeg</string><string>$app/MacOS/ffmpeg</string>
    <string>--datadir</string><string>$data</string>
    <string>--cachedir</string><string>$cache</string>
  </array>
  <key>EnvironmentVariables</key><dict><key>HOME</key><string>$data</string></dict>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>ThrottleInterval</key><integer>30</integer>
  <key>StandardOutPath</key><string>$logf</string>
  <key>StandardErrorPath</key><string>$logf</string>
</dict></plist>
EOF
chown root:wheel "$plist"; chmod 644 "$plist"
# Restart only when the plist changed or the job is not running, so re-running apply does not interrupt playback.
if ! launchctl print "system/$label" >/dev/null 2>&1 || ! cmp -s "$plist" "$HC_STATE/.jellyfin.plist" 2>/dev/null; then
  launchd_load system "$plist"
  cp "$plist" "$HC_STATE/.jellyfin.plist"; chown "$HC_USER" "$HC_STATE/.jellyfin.plist"
fi
log "media (root): Jellyfin runs as $name on http://localhost:8096 with read access to $MEDIA_DIR"
