#!/bin/sh
# Restore test (homecider backup restore-test): restores 20 random photos from the latest snapshot into a temporary
# folder and compares them byte for byte with the originals. A backup counts only after this passes.
set -eu
HC_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"; . "$HC_ROOT/lib/common.sh"; . "$HC_ROOT/modules/backup/env.sh"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
restic ls latest --json 2>/dev/null | python3 -c '
import json, sys, random
files = [o["path"] for o in map(json.loads, sys.stdin) if o.get("type") == "file" and "/library/" in o.get("path", "")]
random.shuffle(files); print("\n".join(files[:20]))' > "$tmp/list"
n="$(wc -l < "$tmp/list" | tr -d ' ')"
[ "$n" -gt 0 ] || die "no photos found in the latest snapshot"
restic restore latest --target "$tmp/r" --include-file "$tmp/list" >/dev/null 2>&1 ||
  { while read -r f; do restic restore latest --target "$tmp/r" --include "$f" >/dev/null; done < "$tmp/list"; }
ok=0; bad=0
while read -r f; do
  if [ -f "$f" ] && cmp -s "$f" "$tmp/r$f"; then ok=$((ok+1)); else bad=$((bad+1)); echo "differs or missing: $f"; fi
done < "$tmp/list"
echo "restored $n files: $ok identical, $bad different"
[ "$bad" = 0 ] && echo PASS || { echo "FAIL (files changed or deleted since the snapshot also count)"; exit 1; }
