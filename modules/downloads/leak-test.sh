#!/bin/sh
# VPN leak test for the downloads module (run: homecider leaktest). Passes only if
#  1. qBittorrent's public IP differs from this Mac's public IP,
#  2. qBittorrent has no internet access while Gluetun is stopped (kill switch).
set -u
HC_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"; . "$HC_ROOT/lib/common.sh"
cd "$HC_ROOT/modules/downloads"
ipof() { docker exec "$1" sh -c 'wget -qO- -T 10 https://api.ipify.org 2>/dev/null || curl -fsS -m 10 https://api.ipify.org' 2>/dev/null; }
fail=0
docker inspect gluetun >/dev/null 2>&1 || die "no gluetun container: configure a VPN (docs/downloads.md) and run homecider apply"

home_ip="$(curl -fsS -m 10 https://api.ipify.org)"
vpn_ip="$(ipof qbittorrent)"
echo "Mac public IP:          $home_ip"
echo "qBittorrent public IP:  ${vpn_ip:-none}"
if [ -z "$vpn_ip" ]; then echo "FAIL: qBittorrent has no internet access through the VPN"; fail=1
elif [ "$vpn_ip" = "$home_ip" ]; then echo "FAIL: qBittorrent uses the home IP"; fail=1
else echo "ok: qBittorrent goes through the VPN"; fi

echo "Stopping Gluetun to test the kill switch..."
docker stop gluetun >/dev/null
leak="$(ipof qbittorrent)"
docker start gluetun >/dev/null
if [ -n "$leak" ]; then echo "FAIL: with the VPN stopped, qBittorrent reached the internet as $leak"; fail=1
else echo "ok: with the VPN stopped, qBittorrent has no internet access"; fi
echo "Restarting qBittorrent and Prowlarr on the new Gluetun network..."
docker compose up -d --force-recreate qbittorrent prowlarr >/dev/null 2>&1
[ $fail = 0 ] && echo "PASS" || { echo "LEAK TEST FAILED: do not download anything"; exit 1; }
