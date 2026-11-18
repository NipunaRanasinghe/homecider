#!/bin/sh
# Installed as /usr/local/sbin/homecider-low-battery by modules/core/root.sh; @PCT@ is replaced at install.
# Shuts down cleanly when running on battery at or below the threshold.
batt="$(pmset -g batt)"
echo "$batt" | grep -q "'Battery Power'" || exit 0
pct="$(echo "$batt" | grep -Eo '[0-9]+%' | head -1 | tr -d '%')"
[ -n "$pct" ] && [ "$pct" -le @PCT@ ] && shutdown -h now "homecider: battery at ${pct}%"
exit 0
