#!/usr/bin/env bash
# Boots the iOS simulator matching $1 (device name) and writes UDID=<udid>
# to $GITHUB_ENV so subsequent workflow steps see it.
set -euo pipefail

DEVICE_NAME=${1:?device name required (e.g. "iPhone 16 Pro Max")}

UDID=$(xcrun simctl list devices available -j | python3 -c "
import json, sys
data = json.load(sys.stdin)
for runtime, devices in data['devices'].items():
    for d in devices:
        if d['name'] == '$DEVICE_NAME' and d['isAvailable']:
            print(d['udid'])
            sys.exit(0)
sys.exit(1)
")

xcrun simctl boot "$UDID"
xcrun simctl bootstatus "$UDID" -b
echo "UDID=$UDID" >> "$GITHUB_ENV"
