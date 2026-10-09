# Runbook: Get HeatLive running on this PC and watch streams

Goal: run the HeatLive (`com.google.heatlive`) / HeatVOD (`com.google.heatvod`) app
on this PC (Android emulator) and verify stream playback.

State: emulator `vseebox` (Android 12 x86_64, KVM) is running as `emulator-5554`.
Pipeline scripts are tested and ready (see `scripts/`). Findings: `docs/findings.md`.

## What's ready (no action needed)

- `scripts/run_apk_in_emulator.sh <apk> [pkg]` — decompile (jadx) + install + launch +
  60s logcat. Auto-fixes ARM-only APKs (strips `lib/`, re-signs with a debug key).
  Validated end-to-end with AppStore.apk (normal app, ARM libs).
- `scripts/market_api_download.sh` — downloads the Heat APK from the vendor store API.
  Validated end-to-end against a mock server (auth → token → search "heat" → APK).
- `scripts/logging_proxy.py [port]` — logging HTTP proxy to capture the box's app traffic.
- Static ffmpeg at `/home/sean/.local/opt/ffmpeg/ffmpeg` for direct stream playback tests.
- AES key + all vendor endpoints decrypted (see findings.md).

## Path 1 (fastest): vendor store API → APK → emulator

On this PC, in a terminal:

```bash
bash /home/sean/firstproject/scripts/market_api_download.sh
```

Better: use the box's real identifiers (grab them in Termux on the box first):

```sh
cat /sys/class/net/eth0/address      # MAC
getprop ro.serialno                  # or ro.boot.serialno
getprop ro.product.model             # e.g. oppen_wv4 / V6MAX
getprop ro.hardware                  # e.g. diablo
```

```bash
MAC=<mac> SN=<serial> CPU=<hw> bash /home/sean/firstproject/scripts/market_api_download.sh
```

The APK lands in `~/firstproject/heatlive_apks/app_<id>.apk`. Then:

```bash
/home/sean/firstproject/scripts/run_apk_in_emulator.sh ~/firstproject/heatlive_apks/app_<id>.apk com.google.heatlive
```

## Path 2: capture the box's app traffic (no root, no adb)

If the app needs its backend to work and we want to see exactly what it calls:

1. Start the proxy on this PC: `python3 /home/sean/firstproject/scripts/logging_proxy.py 8080`
2. On the box: Settings → Network & Internet → (your wifi network) → Advanced →
   **Proxy** → Manual → Hostname `10.42.0.1`, Port `8080` → Save
3. Open HeatLive on the box — its API calls and stream URLs appear in
   `~/firstproject/heatlive_apks/proxy.log`
4. Turn the proxy off on the box afterwards.

This reveals the app's API endpoints, auth tokens, and stream URLs — enough to
(a) make the emulator copy work against the real backend, and (b) play streams
on the PC directly with ffmpeg/mpv.

## Path 3: adb (only if Developer Options / wireless debugging is available)

If the box exposes Developer Options (Settings → Device Preferences → About →
Build number ×7 → Developer Options → Wireless debugging):

```bash
adb pair 10.42.0.130:<port>     # enter pairing code shown on the box
adb connect 10.42.0.130:<port>
/home/sean/firstproject/scripts/pull_heatlive.sh
```

Note: without root, adb gives a `shell`-uid session — package list + logcat + app
data via `adb backup`, but NOT the APK file itself (`/data/app` is system-only).

## Path 4: OTA firmware image (fallback)

The full firmware zip (from `ota.mytv.xin`) contains every preinstalled APK.
The check endpoint (`GET /device/update/`) host could not be confirmed from the
dump (404 on cms.mytv.xin / cms.vseeott.com / vsmga.mytv.xin). If the box's
Settings → Software Update shows a download, the package URL can be captured via
Path 2's proxy, or the OTA zip can be fetched once the check host is known.

## After the APK is installed

**Run it on the ARM64 emulator** (the app's native libs — Go runtime, ObjectBox,
ffmpeg — are ARM-only, so the x86_64 emulator crashes with UnsatisfiedLinkError;
the ARM64 emulator runs the ORIGINAL APK unmodified).

The current emulator (37.x) **removed ARM image support** ("CPU Architecture
'arm64' is not supported by the QEMU2 emulator"). Use the archived emulator
30.4.5 (build 7140946), which still runs arm64-v8a images under QEMU TCG:

```bash
# one-time setup (already done on this PC):
curl -sL -o /tmp/e.zip https://dl.google.com/android/repository/emulator-linux_x64-7140946.zip
unzip -q -o /tmp/e.zip -d /home/sean/.local/opt/emulator-old
sdkmanager "system-images;android-29;default;arm64-v8a"   # Android 10 = app's targetSdk
avdmanager create avd -n vseebox_arm29 -k "system-images;android-29;default;arm64-v8a" -d "pixel_3" --force
# tune: hw.ramSize=3072, disk.dataPartition.size=2G in ~/.android/avd/vseebox_arm29.avd/config.ini

# boot (TCG — slow, 5-20 min):
/home/sean/.local/opt/emulator-old/emulator/emulator -avd vseebox_arm29 -port 5556 \
    -no-window -no-audio -gpu swiftshader_indirect -no-snapshot-save &

# install + launch (original APK, real arm64 libs):
adb -s emulator-5556 install -r ~/firstproject/heatlive_apks/heat-live-v5.9.4.1.apk
adb -s emulator-5556 shell monkey -p com.google.heatlive -c android.intent.category.LAUNCHER 1
```

**Drive the headless UI** with `scripts/emu_ui.sh`:
`shot` (screenshot), `tap X Y`, `key DPAD_CENTER`/`BACK`/`DPAD_DOWN`, `swipe`, `focus`, `log`.

**Capture the app's API traffic**: set the emulator's proxy to the PC's logging proxy
(the emulator reaches the host PC at `10.0.2.2`):

```bash
python3 ~/firstproject/scripts/logging_proxy.py 8080 &
adb -s emulator-5556 shell settings put global http_proxy 10.0.2.2:8080
# browse/play in the app, then read ~/firstproject/heatlive_apks/proxy.log
adb -s emulator-5556 shell settings put global http_proxy :0   # clear afterwards
```

**App backend** (see findings.md §16–17): EPG/data API `static.vseego.com`
(`/espn_epg/<feed>_MD5?t=`, `/espn_epg/<md5>.zip` zip4j-AES, `/xtemp/..._epg.db.zip`),
auth `vtcc_authn2.vseego.com`, P2P broker `broker.4kfibretv.com`, APK/logos
`static.gixxig.com`. Streams are P2P-delivered and encrypted inside the custom
protocol (Go native lib) — NOT plain HLS. To watch a stream outside the app you
would have to reverse the P2P/media protocol from `libgojni.so`; running the app
itself (ARM64 emulator) is the practical path.

**Direct PC playback**: once any stream URL is known,
`/home/sean/.local/opt/ffmpeg/ffmpeg -i <url>` (static build, no install needed).
