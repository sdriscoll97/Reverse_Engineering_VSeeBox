# Heat Live app acquisition

> **Network note (2026-10-09).** The VSeeBox has moved to the home network and is now at `192.168.1.163` / `192.168.1.167` (MAC `b4:5b:d6:b1:8d:36`), reachable from the Optiplex over the same switch. ADB-over-TCP (5555) remains closed on the current addresses, same as on the old `192.168.50.130`. See `vseebox/NETWORK_STATUS.md`.

Status checked: 2026-09-23T22:13:18.112037+00:00

## Confirmed this session

- Existing Dellmicro SSH control connection works; remote hostname is `dellmicro`.
- Dellmicro reports its user `ghidra-mcp` service active. This does not yet verify a functioning Ghidra analysis backend.
- `adb`, `jadx`, `apktool`, and `java` were not found in Dellmicro's non-interactive PATH.
- Installed Google Android platform-tools locally at `/home/sean/.local/share/vseebox-tools/platform-tools` from `https://dl.google.com/android/repository/platform-tools-latest-linux.zip`.
- ADB reports version 1.0.41, build 37.0.1-15733141.
- Normal ADB connection to the previously observed device address `192.168.50.130:5555` returned Connection refused. This does not establish whether another debugging port is enabled. (2026-10-09: the box is now at `192.168.1.163` / `192.168.1.167`; ADB-over-TCP 5555/5037 remain closed there too.)
- `adb devices -l` and `adb mdns services` returned no devices or advertised services.
- Requested on-device confirmation of Ethernet IP and available developer/debugging settings. No debugging settings were changed remotely.
- Created private-apps directory and excluded it from Git. No APK has been acquired.

## Acquisition sequence after authorized debugging becomes available

1. Connect using the device-displayed debugging endpoint; pair first if the device requires wireless pairing. Approve the computer on the device if prompted.
2. Record selected build properties: manufacturer, model, Android release, SDK level, build fingerprint, and supported ABIs. Keep device metadata private.
3. List installed packages and identify Heat Live by correlating the foreground activity with a user-observed app launch; do not infer identity from package-name substrings alone.
4. Record package version and installed APK paths using `dumpsys package PACKAGE` and `pm path PACKAGE`.
5. Pull all reported APK paths, including split packages, into a new timestamped private-apps directory. Record original paths, acquisition UTC times, tool version, file sizes, and SHA-256 hashes. Where device permissions allow, compare device-side hashes.
6. Inspect copied manifests, DEX files, assets, and native libraries offline. Search for previously observed DNS names and trace response handling and high-port socket creation. Keep credentials and reusable URLs out of reports.

## Current dependency

Device-side access is needed before package/version identification and APK acquisition can proceed. No rooting, firmware flashing, authentication bypass, or remote endpoint probing has been performed.
