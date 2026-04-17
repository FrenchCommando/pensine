#!/usr/bin/env bash
# Overrides the iOS simulator status bar with App Store-style values:
# 9:41 clock, full battery, full signal. Acts on $UDID (set by the boot step).
set -euo pipefail

UDID=${UDID:?UDID env var required}

xcrun simctl status_bar "$UDID" override \
  --time "9:41" \
  --batteryState charged \
  --batteryLevel 100 \
  --cellularBars 4 \
  --wifiBars 3
