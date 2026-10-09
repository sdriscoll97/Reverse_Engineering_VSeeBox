#!/bin/bash
# Pull HeatLive / HeatVOD APKs + app data + logs from a VSeeBox over adb.
#
# Usage:
#   ./pull_heatlive.sh                # uses already-connected adb device
#   ./pull_heatlive.sh 192.168.10.2   # connects first (network adb)
#
# Requires: adb on PATH (or ANDROID_HOME set). Run from anywhere.
set -euo pipefail

IP="${1:-}"
ADB="${ANDROID_HOME:+${ANDROID_HOME}/platform-tools/}adb"
command -v "$ADB" >/dev/null 2>&1 || ADB="adb"

OUT="${HOME}/firstproject/heatlive_apks"
mkdir -p "$OUT"

if [ -n "$IP" ]; then
    "$ADB" connect "$IP"
fi

echo "[*] Devices:"; "$ADB" devices

echo "[*] Heat-related packages:"
"$ADB" shell pm list packages -f 2>/dev/null | grep -iE "heat" | tee "$OUT/packages.txt"

# Pull every heat-related APK (path + package)
"$ADB" shell pm list packages -f 2>/dev/null | grep -iE "heat" | while read -r line; do
    path="${line#package:}"; path="${path%%=*}"
    pkg="${line##*=}"
    safe="$(echo "$pkg" | tr -c 'a-zA-Z0-9._-' '_')"
    echo "[*] Pulling $pkg -> $OUT/${safe}.apk"
    "$ADB" pull "$path" "$OUT/${safe}.apk"
done

# Pull app-private data (SharedPreferences / databases hold tokens + server config)
for pkg in com.google.heatlive com.google.heatvod com.google.heatvodultra; do
    dir="/data/data/$pkg"
    if "$ADB" shell "[ -d $dir ]" 2>/dev/null; then
        echo "[*] Pulling $dir"
        "$ADB" pull "$dir" "$OUT/data_$pkg" || true
    fi
done

# Useful platform config + a logcat snapshot
"$ADB" pull /etc/cms.txt "$OUT/cms.txt" 2>/dev/null || true
"$ADB" pull /etc/mqtt.txt "$OUT/mqtt.txt" 2>/dev/null || true
"$ADB" pull /etc/appstore.conf "$OUT/appstore.conf" 2>/dev/null || true
"$ADB" shell dumpsys package com.google.heatlive 2>/dev/null > "$OUT/dumpsys_heatlive.txt" || true
"$ADB" logcat -d > "$OUT/logcat_boot.txt" 2>/dev/null || true

echo "[+] Done. Files in $OUT"
ls -la "$OUT"
