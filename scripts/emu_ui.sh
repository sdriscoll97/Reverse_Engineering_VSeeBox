#!/bin/bash
# UI driver for the headless ARM64 emulator (emulator-5556) running HeatLive.
# Usage:
#   emu_ui.sh shot            -> screenshot to ~/firstproject/heatlive_apks/ui/
#   emu_ui.sh tap X Y         -> tap screen coordinates
#   emu_ui.sh key KEY         -> keyevent (e.g. DPAD_CENTER, DPAD_DOWN, BACK, ENTER)
#   emu_ui.sh text STR        -> input text
#   emu_ui.sh swipe X1 Y1 X2 Y2 -> swipe
#   emu_ui.sh focus           -> current focused window
#   emu_ui.sh log [N]         -> last N logcat lines (default 40)
set -euo pipefail
export ANDROID_HOME="${ANDROID_HOME:-/home/sean/android-sdk}"
ADB="$ANDROID_HOME/platform-tools/adb -s emulator-5556"
OUT="${HOME}/firstproject/heatlive_apks/ui"
mkdir -p "$OUT"
case "${1:-}" in
  shot)
    f="$OUT/shot_$(date +%s).png"
    "$ADB" shell screencap -p /sdcard/s.png
    "$ADB" pull /sdcard/s.png "$f"
    echo "saved: $f" ;;
  tap)   "$ADB" shell input tap "$2" "$3" ;;
  key)   "$ADB" shell input keyevent "$2" ;;
  text)  "$ADB" shell input text "$2" ;;
  swipe) "$ADB" shell input swipe "$2" "$3" "$4" "$5" ;;
  focus) "$ADB" shell dumpsys window windows | grep -E "mCurrentFocus|mFocusedApp" ;;
  log)   "$ADB" logcat -d | tail -"${2:-40}" ;;
  *) echo "usage: $0 shot|tap X Y|key KEY|text STR|swipe X1 Y1 X2 Y2|focus|log [N]" ;;
esac
