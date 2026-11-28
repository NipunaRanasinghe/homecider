#!/bin/sh
# Runs weekly (launchd). Upgrades Homebrew casks, pulls newer container images and recreates those containers,
# then sends one ntfy message if anything changed or failed. Apps pinned with MOD_RELEASE (Immich): one message
# per new release.
set -u
HC_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"; . "$HC_ROOT/lib/common.sh"
failed=""
echo "== $(date)"

images() { docker ps -q | xargs docker inspect -f '{{.Name}} {{.Image}}' 2>/dev/null | sort; }

# Only HomeCider's own apps by default; UPDATE_ALL_HOMEBREW=true upgrades every Homebrew app on the Mac.
casks=""; uses_docker && casks="$casks orbstack"; has_module media && casks="$casks jellyfin"
formulae=""; has_module backup && formulae="restic"
casks_before="$(brew list --cask --versions)"
if [ "$UPDATE_ALL_HOMEBREW" = true ]; then
  # Every outdated app except HomeCider itself: a new HomeCider version takes effect only after `homecider apply`.
  if brew update && outdated="$(brew outdated --greedy --quiet)"; then
    outdated="$(printf '%s\n' "$outdated" | grep -Ev '(^|/)homecider$' || true)"
    # shellcheck disable=SC2086  # word splitting of the app list is intended
    { [ -z "$outdated" ] || brew upgrade --greedy $outdated; } || failed="$failed brew"
  else
    failed="$failed brew"
  fi
else
  brew update || failed="$failed brew"
  # shellcheck disable=SC2086  # word splitting of the app lists is intended
  { [ -z "$casks" ] || brew upgrade --cask --greedy $casks; } || failed="$failed brew"
  # shellcheck disable=SC2086
  { [ -z "$formulae" ] || brew upgrade $formulae; } || failed="$failed brew"
fi
casks_after="$(brew list --cask --versions)"
casks_changed="$(echo "$casks_after" | grep -vxF "$casks_before")"
if echo "$casks_changed" | grep -q '^jellyfin '; then
  sudo -n /bin/launchctl kickstart -k "system/$HC_LABEL.jellyfin" || failed="$failed jellyfin-restart"
fi

images_changed=""
if uses_docker; then
  orbctl start >/dev/null 2>&1 || failed="$failed orbstack"   # a cask upgrade quits OrbStack
  images_before="$(images)"
  for m in $(modules_with MOD_COMPOSE); do
    { dc "$m" pull -q && dc "$m" up -d; } || failed="$failed $m"
  done
  # Removes dangling images only (untagged and unused, e.g. the previous version after a pull); UPDATE_PRUNE_IMAGES=false keeps them.
  [ "$UPDATE_PRUNE_IMAGES" = false ] || docker image prune -f >/dev/null
  images_changed="$(images | grep -vxF "$images_before" | cut -d' ' -f1 | tr -d / | tr '\n' ' ')"
fi

# MOD_RELEASE is "<GitHub owner/repo> <version setting>", e.g. "immich-app/immich IMMICH_VERSION".
mkdir -p "$HC_STATE/alerts"
for m in $(modules_with MOD_RELEASE); do
  read -r repo var <<EOT
$(module_field "$m" MOD_RELEASE)
EOT
  running=""; eval "running=\${$var:-}"
  title="$(module_field "$m" MOD_TITLE)"
  latest="$(curl -fsS -m 15 "https://api.github.com/repos/$repo/releases/latest" | sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p')"
  if [ -n "$latest" ] && [ "$latest" != "$running" ] && [ ! -e "$HC_STATE/alerts/release-$m-$latest" ]; then
    notify "$title $latest released" "Running $running. Read the release notes, then set $var in homecider.env and run homecider apply." package \
      && touch "$HC_STATE/alerts/release-$m-$latest"
  fi
done

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
