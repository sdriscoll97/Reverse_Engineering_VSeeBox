#!/bin/bash
# Decompile + install + launch an APK in the local Android emulator, then capture logs.
#
# Usage: ./run_apk_in_emulator.sh /path/to/HeatLive.apk [package.name]
#
# Handles ARM-only APKs (common for TV-box apps): if install fails with
# INSTALL_FAILED_NO_MATCHING_ABIS, strips lib/* and re-signs with a debug key.
# Caveat: apps that actually call the stripped native code will crash at that point;
# pure-UI / API / platform-MediaPlayer flows keep working.
#
# Prereqs: emulator AVD "vseebox" booted, jadx at /home/sean/.local/opt/jadx,
# ANDROID_HOME=/home/sean/android-sdk
set -euo pipefail

APK="${1:?usage: $0 <apk> [package]}"
PKG="${2:-}"
NAME="$(basename "$APK" .apk)"

export ANDROID_HOME="${ANDROID_HOME:-/home/sean/android-sdk}"
ADB="$ANDROID_HOME/platform-tools/adb"
AAPT="$ANDROID_HOME/build-tools/31.0.0/aapt"
APKSIGNER="$ANDROID_HOME/build-tools/31.0.0/apksigner"
KEYTOOL="/home/sean/.local/opt/jdk/bin/keytool"
JADX="/home/sean/.local/opt/jadx/bin/jadx"
DECOMP_DIR="${HOME}/firstproject/decompiled_apks/${NAME}_jadx"
LOGDIR="${HOME}/firstproject/heatlive_apks"
LOG="$LOGDIR/${NAME}_logcat.txt"
mkdir -p "$LOGDIR"

DEBUG_KEYSTORE="$LOGDIR/debug.keystore"
if [ ! -f "$DEBUG_KEYSTORE" ]; then
    "$KEYTOOL" -genkeypair -v -keystore "$DEBUG_KEYSTORE" -storepass android \
        -alias androiddebugkey -keypass android -keyalg RSA -keysize 2048 \
        -validity 10000 -dname "CN=Android Debug,O=Android,C=US" >/dev/null 2>&1
fi

fix_abi() {
    # Strip ARM native libs and re-sign so the APK installs on x86_64.
    local src="$1" fixed="$LOGDIR/${NAME}_x86.apk"
    echo "[*] ARM-only APK detected; stripping lib/* and re-signing..." >&2
    cp "$src" "$fixed"
    zip -q -d "$fixed" 'lib/*' || true
    "$APKSIGNER" sign --ks "$DEBUG_KEYSTORE" --ks-pass pass:android \
        --key-pass pass:android --out "$fixed.signed" "$fixed"
    mv "$fixed.signed" "$fixed"
    echo "$fixed"
}

echo "[*] Waiting for emulator..."
"$ADB" wait-for-device
until [ "$("$ADB" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = "1" ]; do sleep 3; done
echo "[+] Emulator booted"

if [ -z "$PKG" ] && [ -x "$AAPT" ]; then
    PKG="$("$AAPT" dump badging "$APK" 2>/dev/null | sed -n "s/^package: name='\([^']*\)'.*/\1/p" | head -1)"
fi
echo "[*] Package: ${PKG:-unknown}"

INSTALL_APK="$APK"
if ! "$ADB" install -r -d "$INSTALL_APK" 2>&1 | tee "$LOGDIR/${NAME}_install.log" | grep -q "Success"; then
    if grep -q "NO_MATCHING_ABIS" "$LOGDIR/${NAME}_install.log"; then
        INSTALL_APK="$(fix_abi "$APK")"
        echo "[*] Retrying with ABI-fixed APK: $INSTALL_APK"
        "$ADB" install -r -d "$INSTALL_APK"
    else
        echo "[!] Install failed (see $LOGDIR/${NAME}_install.log)"; exit 1
    fi
fi
echo "[+] Installed"

if [ -n "$PKG" ]; then
    echo "[*] Launching $PKG..."
    "$ADB" shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1 || \
        "$ADB" shell am start -n "$PKG/.MainActivity" >/dev/null 2>&1 || true
    sleep 5
fi

echo "[*] Decompiling with jadx (background)..."
( "$JADX" -d "$DECOMP_DIR" "$APK" > "${DECOMP_DIR}.log" 2>&1 ) &

echo "[*] Capturing 60s of logcat to $LOG ..."
"$ADB" logcat -c
timeout 60 "$ADB" logcat > "$LOG" 2>&1 || true

echo "[+] Done."
echo "    decompiled: $DECOMP_DIR"
echo "    logcat:     $LOG"
"$ADB" shell dumpsys window windows 2>/dev/null | grep -iE "mCurrentFocus|mFocusedApp" || true
