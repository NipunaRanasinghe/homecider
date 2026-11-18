#!/bin/sh
# Runs weekly (launchd). Upgrades Homebrew casks, pulls newer container images and recreates those containers,
# then sends one ntfy message if anything changed or failed. Immich is pinned: one message per new Immich release.
set -u
HC_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"; . "$HC_ROOT/lib/common.sh"
failed=""
echo "== $(date)"

images() { docker ps -q | xargs docker inspect -f '{{.Name}} {{.Image}}' 2>/dev/null | sort; }

casks_before="$(brew list --cask --versions)"
{ brew update && brew upgrade --greedy; } || failed="$failed brew"
casks_after="$(brew list --cask --versions)"
casks_changed="$(echo "$casks_after" | grep -vxF "$casks_before")"
if echo "$casks_changed" | grep -q '^jellyfin '; then
  sudo -n /bin/launchctl kickstart -k "system/$HC_LABEL.jellyfin" || failed="$failed jellyfin-restart"
fi

images_changed=""
if uses_docker; then
  orbctl start >/dev/null 2>&1 || failed="$failed orbstack"   # a cask upgrade quits OrbStack
  images_before="$(images)"
  for m in photos downloads; do
    has_module "$m" || continue
    (cd "$HC_ROOT/modules/$m" && docker compose pull -q && docker compose up -d) || failed="$failed $m"
  done
  docker image prune -f >/dev/null
  images_changed="$(images | grep -vxF "$images_before" | cut -d' ' -f1 | tr -d / | tr '\n' ' ')"
fi

if has_module photos; then
  latest="$(curl -fsS -m 15 https://api.github.com/repos/immich-app/immich/releases/latest | sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p')"
  mkdir -p "$HC_STATE/alerts"
  if [ -n "$latest" ] && [ "$latest" != "$IMMICH_VERSION" ] && [ ! -e "$HC_STATE/alerts/immich-$latest" ]; then
    notify "Immich $latest released" "Running $IMMICH_VERSION. Read the release notes, then set IMMICH_VERSION in homecider.env and run homecider apply." package \
      && touch "$HC_STATE/alerts/immich-$latest"
  fi
fi

msg=""
[ -n "$casks_changed" ] && msg="Apps: $(echo "$casks_changed" | tr '\n' ' ')"
[ -n "$images_changed" ] && msg="$msg
Containers: $images_changed"
echo "changed: ${msg:-nothing}; failed:${failed:- nothing}"
if [ -n "$failed" ]; then
  notify "Weekly update failed:$failed" "See $HC_LOGS/update.log.
$msg" warning
elif [ -n "$msg" ]; then
  notify "Weekly update done" "$msg" arrow_up
fi
