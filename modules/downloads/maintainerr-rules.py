#!/usr/bin/env python3
"""Create the Maintainerr cleanup rules through its API (localhost:6246). Skips groups that already exist.

Films:   watched at least once, last watched more than 6 days ago -> "Leaving soon" collection in Jellyfin,
         deleted from Radarr (with files) 1 day later. About 7 days after the last view in total.
Seasons: at least one user watched every episode, newest episode view more than 6 days ago -> same collection,
         Sonarr unmonitors the season and deletes its files 1 day later (the show and later seasons stay).
Unwatched media is never matched. Maintainerr evaluates rules every 8 h, so deletion is 7-8 days after the last view.
Rule values: day amounts are seconds; ids come from GET /api/rules/constants (Jellyfin = app 6).
"""
import json, urllib.request

API = "http://localhost:6246/api"
SIX_DAYS = str(6 * 24 * 3600)
NUMBER, BEFORE, BIGGER, COUNT_BIGGER = 0, 5, 0, 16
JELLYFIN = 6


def call(path, data=None):
    req = urllib.request.Request(API + path, data=json.dumps(data).encode() if data is not None else None,
                                 headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=60) as r:
        body = r.read()
        return json.loads(body) if body else None


def rule(prop, action, value, first=False):
    return {"operator": None if first else 0, "firstVal": [JELLYFIN, prop], "action": action,
            "customVal": {"ruleTypeId": NUMBER, "value": value}, "section": 0}


libs = {l["title"]: l["id"] for l in call("/media-server/libraries")}
radarr = call("/settings/radarr")[0]["id"]
sonarr = call("/settings/sonarr")[0]["id"]
existing = {g["name"] for g in call("/rules")}

groups = [
    {"name": "Leaving soon - films", "libraryId": libs["Movies"], "dataType": "movie",
     "description": "Watched films, 7 days after the last view.",
     "arrAction": 0, "radarrSettingsId": radarr,                       # DELETE (with files)
     "rules": [rule(5, BIGGER, "0", first=True),                       # Times viewed > 0
               rule(7, BEFORE, SIX_DAYS)]},                            # Last view date before 6 days ago
    {"name": "Leaving soon - seasons", "libraryId": libs["Shows"], "dataType": "season",
     "description": "Fully watched seasons, 7 days after the last episode view.",
     "arrAction": 2, "sonarrSettingsId": sonarr,                       # UNMONITOR_DELETE_EXISTING
     "rules": [rule(12, COUNT_BIGGER, "0", first=True),                # users who watched every episode > 0
               rule(13, BEFORE, SIX_DAYS)]},                           # newest episode view before 6 days ago
]
for g in groups:
    if g["name"] in existing:
        print("exists:", g["name"]); continue
    g.update(isActive=True, useRules=True, listExclusions=False, cleanupLeftoverFolders=False,
             forceSeerr=False, forceOmbi=False, tagInArr=False, keepInMaintainerrOnly=False,
             collection={"visibleOnRecommended": False, "visibleOnHome": True, "deleteAfterDays": 1,
                         "manualCollection": False, "keepLogsForMonths": 6})
    call("/rules", g)
    print("created:", g["name"])
