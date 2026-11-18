#!/bin/sh
# core, root part: key-only SSH, no sleep, low-battery shutdown (laptops), firewall, sharing off, update policy.
set -eu
HC_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"; . "$HC_ROOT/lib/common.sh"
[ "$(id -u)" = 0 ] || die "core/root.sh must run as root"

# SSH: key-only login for the owner. 000- loads before macOS's 100-macos.conf; sshd keeps the first value.
dst=/etc/ssh/sshd_config.d/000-homecider.conf
cat > "$dst.tmp" <<EOF
# Written by homecider (modules/core/root.sh).
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitRootLogin no
AllowUsers $HC_USER
EOF
chmod 644 "$dst.tmp"; mv "$dst.tmp" "$dst"
if ! sshd -t; then rm -f "$dst"; die "sshd rejected the config; removed $dst"; fi
grep -q 'ssh-' "$HC_HOME/.ssh/authorized_keys" 2>/dev/null ||
  warn "$HC_HOME/.ssh/authorized_keys has no key: SSH logins will fail until you add one"

# Power: never sleep, including with the lid closed; wake on network.
pmset -a sleep 0 disksleep 0 standby 0 powernap 0 displaysleep 2 womp 1 tcpkeepalive 1
pmset -a disablesleep 1

# Laptops: clean shutdown on battery at BATTERY_SHUTDOWN_PCT (sleep is disabled, so it would otherwise die hard).
plist="/Library/LaunchDaemons/$HC_LABEL.low-battery.plist"
if has_battery; then
  install -d -m 755 /usr/local/sbin
  sed "s/@PCT@/$BATTERY_SHUTDOWN_PCT/" "$HC_ROOT/modules/core/low-battery.sh" > /usr/local/sbin/homecider-low-battery
  chown root:wheel /usr/local/sbin/homecider-low-battery; chmod 755 /usr/local/sbin/homecider-low-battery
  cat > "$plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>$HC_LABEL.low-battery</string>
  <key>ProgramArguments</key><array><string>/usr/local/sbin/homecider-low-battery</string></array>
  <key>StartInterval</key><integer>60</integer>
</dict></plist>
EOF
  chown root:wheel "$plist"; chmod 644 "$plist"
  launchd_load system "$plist"
fi

# Firewall on, stealth mode, signed apps allowed (sshd and Jellyfin are signed). File/screen sharing and remote Apple events off.
fw=/usr/libexec/ApplicationFirewall/socketfilterfw
$fw --setglobalstate on >/dev/null
$fw --setstealthmode on >/dev/null
$fw --setallowsigned on >/dev/null
$fw --setallowsignedapp on >/dev/null
for svc in com.apple.smbd com.apple.AppleFileServer com.apple.screensharing com.apple.AEServer; do
  launchctl disable "system/$svc"
  launchctl bootout "system/$svc" 2>/dev/null || true
done

# macOS updates: check and download automatically; the owner installs (each install reboots into the FileVault screen).
p=/Library/Preferences/com.apple.SoftwareUpdate
defaults write $p AutomaticCheckEnabled -bool true
defaults write $p AutomaticDownload -bool true
defaults write $p AutomaticallyInstallMacOSUpdates -bool false
defaults write $p CriticalUpdateInstall -bool false   # Rapid Security Responses can reboot
defaults write $p ConfigDataInstall -bool true        # XProtect definitions, no reboot

log "core (root): SSH, power, firewall and update policy applied"
