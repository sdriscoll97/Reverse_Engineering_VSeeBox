# VSeeBox Reverse Engineering Findings

> Target: VSeeBox Android TV box firmware (`~/firstproject/VSeeBox_Files`)
> Date: 2026-10-08 · Tools: apktool, jadx 1.5.1, capstone/pyelftools (manual ELF/JNI analysis), python+cryptography

---

## Executive Summary

The VSeeBox runs a vendor OTT platform ("t101", domains **vseeott.com** / **mytv.xin**) with a
full remote-management stack:

- **Deviceheartbeat** (`com.android.deviceheartbeat`) — MQTT C2 client + AIDL command server.
  Connects to a plaintext-TCP MQTT broker, receives remote commands, reports telemetry.
- **BoxTools** (`com.qstar.apps.boxtools`, `sharedUserId=android.uid.system`) — command executor:
  log exfiltration, silent app install/uninstall, reboot, factory reset, app-market (MGA) client.
- All server endpoints are stored **AES-128-CBC encrypted** in `/etc/*.txt` and decrypted at
  runtime by `libnative-crypto.so`. **We recovered the key derivation and decrypted all of them.**

---

## 1. Architecture

| Component | Package | Role |
|---|---|---|
| Deviceheartbeat | `com.android.deviceheartbeat` | MQTT C2 client, heartbeat, AIDL server (`DeviceManagerService`), telemetry poster |
| BoxTools | `com.qstar.apps.boxtools` | Executes remote commands (logcat upload, uninstall, reboot, factory reset, notifications), silent installer, MGA market client |
| GrapeLauncher | `com.android.grapelauncher` | Launcher (shares QStar webapi lib) |
| AppStore | `com.qstar.app.appstore` | Vendor app store (shares QStar webapi lib) |
| Heat Live | `com.google.heatlive` | Live TV app (user's target; APK not in dump) |
| Heat VOD | `com.google.heatvod` / `com.google.heatvodultra` | VOD app (user's target; APK not in dump) |
| base-api | `android.base.api` (`/system/framework/base-api.jar`) | Vendor HAL: settings, device info, `android.auth.jni.AuthNative` |

Inter-process flow: **MQTT → Deviceheartbeat (DeviceManagerService, AIDL) → BoxTools
(AidlMessageService) → command handler → result encrypted with `java.security.Key` → AIDL callback
→ MQTT publish back**.

---

## 2. C2 Infrastructure (decrypted)

### Crypto scheme
- Payloads in config files are `base64url( IV(16) || AES-128-CBC ciphertext )`, PKCS7 padding.
- **Key = MD5(32-byte seed at rodata `0x9cf6a` of `libnative-crypto.so`)**
  - seed = `854ad206a0b2b3d52285aa4b0c535b897613488902414847031a7517ffa1ca30`
  - **key = `7fb39a43bcf3146d0d683713b79e11f0`**
- JNI entry: `com.qstar.lib.commons.crypto.NativeCrypto.DecryptTxt` →
  `Java_com_qstar_lib_commons_crypto_NativeCrypto_DecryptTxt` @ `0xf17f0` → core `sub_f255c` @ `0xf255c`.
  - The KDF contains 32 rounds of `SHA256` + a byte-shuffle loop (`buf[i] = buf[i^31] & mask[i%5]`,
    mask = `3d 96 21 df a8`) — **anti-analysis junk; result discarded**. Final key = `MD5(seed)`.
  - Decrypt: `EVP_aes_128_cbc`, IV = first 16 bytes of payload.
- Plaintext format: `<scheme><label><host>`, e.g. `abccms` + `mqtt.vseeott.com`.
  `wrapUri()` rewrites scheme `abc` → `tcp` (MQTT), `domain` → http(s).

### Decoded endpoints

| File | Plaintext | Meaning |
|---|---|---|
| `/etc/mqtt.txt` | `abc`+`cms`+`mqtt.vseeott.com` | **MQTT C2 broker: `tcp://mqtt.vseeott.com`** (fallback `mqtt.mytv.xin`) |
| `/etc/cms.txt` | `domain`+`cms`+`cms.vseeott.com` | **HTTP command/telemetry server: `cms.vseeott.com`** (fallback `cms.mytv.xin`) |
| `/etc/host_list.txt` | `domain`+`vsmga.mytv.xin` | **MGA app-market API host: `vsmga.mytv.xin`** |
| `/etc/mga_extra_host.conf` | (plaintext) `https://stalekrapi3.mytv.xin` | MGA extra API host |
| `/etc/appstore.conf` | 2 UUIDs | App-store app IDs: `2c6af6d9-287d-324b-bd5a-bf8423f79840`, `cb7104db-3ff8-3fa1-a0f2-aa1b5cc8f7fd` |
| `/etc/host_code.txt` | binary (device-specific) | Encrypted auth/host code (device-bound key; not needed) |
| fallback in BoxTools `l.smali` | `abccms`+`cms.mytv.xin` | Fallback CMS host |
| fallback in Deviceheartbeat `AndroidMQTT` | `abccms`+`mqtt.mytv.xin` | Fallback MQTT host |

Native heartbeat lib (`/system/lib/libheart_jni.so`) also references **`t101.cn`** and paths
`device/heartbeat/` (GET `%s?mac=%s`), `device/post-info/` (POST), with AES key
`GdzV3YiwiI2kjYxU` (16-byte ASCII, heartbeat channel).

---

## 3. MQTT Command Channel (`Deviceheartbeat`)

Class: `com.android.deviceheartbeat.mqtt.impl.AndroidMQTT` (Eclipse Paho v3, plaintext TCP).

- **Broker**: `tcp://mqtt.vseeott.com` (port 1883 default), from `/etc/mqtt.txt` (decrypted).
- **Client ID** = device MAC (from `android.base.api.IDeviceInfo.getMacAddress()`).
- **Username** = device MAC.
- **Password** = `MD5hex( basexxEncode( MAC + "|" + serial ) )`
  - serial from `IDeviceInfo.getSerialNumber()`; `basexxEncode` = JNI `android.auth.jni.AuthNative.basexxEncode`
    (impl in `/system/lib/libt101_auth_d.so`, custom base64 variant).
- **Publish topic** = `t101/device/<MAC>/publish`
- **Options**: cleanSession=false, automaticReconnect=false, keepAlive=60s, connTimeout=30s.
- DNS via DoH (`com.qstar.lib.commons.webapi.v5.doh.DnsApiExecutor`).
- Incoming messages are decrypted (NativeCrypto) → parsed as `MQTTCmd` → dispatched via AIDL to BoxTools.
- Message JSON fields seen: `identity`, `status`, `response`, `type`, `updateAtOnce`, `activity`.

## 4. Remote Command Surface (server → device)

`CmdType` enum (`b/f/b/b/a/b`, deobfuscated) + handler map in `AidlMessageService.onCreate()`:

| Code | Name | Cmd class | Handler | Effect |
|---|---|---|---|---|
| 0 | Unknown | NoActionCmd | — | — |
| 1 | Notification | (notification data) | `b/f/a/a/s/g` | Shows a notification |
| 4 | UninstallApp | UninstallAppCmd | `b/f/a/a/n/o` | Uninstalls an app (also holds `ISilentInstall`) |
| 5 | Reboot | RebootCmd | `b/f/a/a/n/m` | Reboots the box |
| 6 | ResetFactory | ResetFactoryCmd | `b/f/a/a/n/n` | Factory reset |
| 7 | Logcat | LogcatCmd | `b/f/a/a/n/l` | Captures logcat 5s → zip → **upload** |

Command result: JSON `{"identity":"<code>-<cmdId>","status":<int>}` wrapped in `AidlMessage`,
**encrypted with a `java.security.Key`** (`Lb/f/b/a/a/a/e;->n(Key, Msg)`), returned over the AIDL
callback, then published to MQTT.

## 5. Telemetry / Log Exfiltration (`BoxTools` `b/f/a/a/n/l`)

Triggered by a remote `LogcatCmd` (code 7):
1. `d(LogcatCmd)`: spawn thread → run logcat into `cache/logcat/logcat_<epochMs>.log`;
   after **5000 ms** post zip+upload runnable.
2. `h(LogcatCmd, File)`: resolve domain: first line of **`/etc/cms.txt`** (fallback hardcoded
   `abc://BDUQOcdBjXriHVcjRAWMIuiu3oJxywa7djFpVubX8GE=` → `cms.mytv.xin`) → `IDomainHttpClient.load()`.
3. POST `<domain>/device/cmd/logcat/upload/` (multipart form):
   - `mac` = device MAC (`MgaContext.getMac()`)
   - `logId` = command ID from server (`BaseCmd.b`)
   - `file` = zipped logcat

## 6. Silent Install / OTA Chain (`BoxTools`)

- `SilentInstallService` (`com.qstar.apps.boxtools.silentInstall`): receives an install request
  (intent data Uri, `content://` or `file://` only), copies the APK to `cache/apks/<name>/<file>`,
  then `ISilentInstall.install(identity, context, path)`. Results broadcast to
  `RemoteCallbackList<IAidInstallerListener>`.
- `onBind` is gated by permission `com.qstar.apps.boxtools.permission.SILENT_INSTALL_SERVICE`
  ("onBind, blocked/pass").
- BoxTools manifest: `sharedUserId="android.uid.system"`, `usesCleartextTraffic="true"`,
  permissions include `INSTALL_PACKAGES`, `DELETE_PACKAGES`, `WRITE_SECURE_SETTINGS`,
  `READ_PHONE_STATE`, `QUERY_ALL_PACKAGES`, `RECEIVE_BOOT_COMPLETED` (`BootReceiver`).
- MGA market (`com.qstar.lib.commons.mga.*`): app querying/download/install via `vsmga.mytv.xin`;
  `MgaService` = background market service; `appupdater` = OTA self-update.
- Separate channel: **`BleOTA.apk`** (Bluetooth OTA) also contains the webapi lib.

## 7. Native Libraries

| Library | Location | Role / exports |
|---|---|---|
| `libnative-crypto.so` (2.6MB arm64) | inside BoxTools/Deviceheartbeat/AppStore APKs | `NativeCrypto.Decrypt/DecryptTxt/isAppDataDecode`; AES-128-CBC (OpenSSL EVP); key derivation above |
| `libsecurityplugin_jni.so` | inside APKs | Decoy package `androidx.databinding.D`; native integrity checks `OoOoo*(Class,int)` |
| `libheart_jni.so` (17KB) | `/system/lib` | `HeartBeatNative`: `postDeviceInfo`, `startService`; `http_get/post` over raw sockets; AES key `GdzV3YiwiI2kjYxU`; reads `/sys/class/net/eth0/address`; local server on `127.0.0.1` |
| `libt101_auth_d.so` | `/system/lib` | Device auth: `basexx_encode/decode`, `check_auth`, `get_auth_code`, `get_key_data`, `read_activekeyHex`, `burn_keys` (nlohmann/json) |
| `base-api.jar` | `/system/framework` (`android.base.api`) | Vendor HAL: WiFi/Ethernet/display/audio settings, `AppManager`, `DeviceInfo`, `android.auth.jni.AuthNative`, Amlogic `unifykeys`, HDCP, recovery |

## 8. Device Identifiers Collected

- MAC address (with colons, uppercase) — MQTT client ID, username, telemetry field
- CPU serial (`CpuInfo.getSerialNo()`) — MQTT password derivation
- MD5 hex of `basexxEncode(MAC|serial)` — MQTT password

## 9. Other Config (`/system/etc/`)

`start_app_list.xml` (voice-search mapping incl. `com.google.heatlive`, `com.google.heatvod`),
`mga_resource.xml` (launcher assets), `remoter.xml` (IR remote pairing UI), `boxguide_config.xml`,
`recommend_apps.xml`, `lock_app_white_list.txt`, `permission_enable_list.conf`,
`download_state_boxtools.txt`, `refresh_boxtools.txt`, `reset_boxtools.txt`.

## 10. Media Capabilities

`media_codecs_amlogic_video.xml`: Amlogic C2 decoders — H.264/HEVC/VP9 up to 4096x4096, AV1
3840x3840, plus `.secure` variants (Widevine/DRM), adaptive/tunneled/low-latency.

## 11. Analysis Methods Used

- apktool decode → smali (obfuscated packages `b.f.*`, `a.*`)
- jadx 1.5.1 → Java (installed to `/home/sean/.local/opt/jadx`)
- Manual DEX string/flow analysis where obfuscation defeated jadx
- ELF: pyelftools + capstone (installed to `/home/sean/.local/pylibs`) — JNI function
  disassembly, PLT/GOT resolution via `.rela.plt`
- Crypto: key-derivation RE of `sub_f255c` → `MD5(seed)`; AES-128-CBC decrypt of `/etc/*.txt`
  with python `cryptography`

## 12. Vendor App-Market API (AppStore `com.qstar.app.appstore`)

The vendor app store talks to **`market.mytv.xin`** (decrypted from AppStore's
`domain://i411BAwYs8Ra_aNHgJ_JgX4TrJERmWveDoIXJ2vbR82ziflAfnf5WrJcdnah5F0q`).
Full request flow (all POST, form-encoded; response = `QstarApiResponse{code,msg,result}`):

1. `POST /api/auth/secret_key/` — form: `sai` (appstore.conf line 1 UUID), `mac` (lowercase),
   `sn` (CPU serial), `cpu` (`CpuInfo.hardware`) → `result: {host, secret_key}`.
   Defaults if `/etc/appstore.conf` missing: sai=`7aab0ee2-c020-3991-bef5-94f025d99bcf`,
   lib=`5160d832-2388-390f-8601-4195ff86c481`.
2. `POST <host>/market/api/token/` — form: `lib` (appstore.conf line 2 UUID), `mac`, `sn`,
   `cpu`, `secret_key` → `result: {token}`. (`host` comes from step 1.)
3. `POST <host>/market/api/all/` — form: `token` → categories with app lists (logos/icons
   are relative to `host`).
4. `POST <host>/market/api/app/url/` — form: `token`, `app_id` → `{url | chunkUrl}`;
   relative URLs are prefixed with `host`.

This API can serve **any app in the vendor catalog, including the Heat apps** —
a device-independent way to obtain the HeatLive/HeatVOD APKs.
See `scripts/market_api_download.sh`.

## 13. OTA / Firmware Update Channel

- **System OTA check** (`SettingsQ`, `android.settings.update.UpdateService`):
  `GET <host>/device/update/` with query params `mac`, `board` (`getBoardPlatform`),
  `platform` (`getProductModel`), `customer` (`getCustomerName`), `version` (firmware).
  Response JSON: `status`(1=ok), `update_version`, `package_path`, `chunk_url`,
  `package_md5`, `release_note`, `force_update`. Package downloads to `/cache/update_net.zip`.
- Host resolution: `SystemProperties.get("t101.cms.server.update",
  "domain://BxxDWU9hZaTcPdiUQrelGe07lmIxycrKpkILFiruHR8MhP8EoZ7EWL21SBQdvENx")`
  → decrypts to **`cms.mytv.xin`** (same AES key). The dump's `/etc/cms.txt` instead
  points at `cms.vseeott.com` (live Apache/2.4.52 Ubuntu server).
- Other `/device/...` endpoints (also GET via `HttpHelper.getText`):
  `/device/post-info/`, `/device/update/status/`, `/device/cmd/logcat/upload/` (POST).
- **Firmware file host**: `ota.mytv.xin` (http→https redirect; old packages 404).
  Package naming: `ota_package_<board>_<dvb?>_<product>_v<version>_<timestamp>.zip`
  (dump example: `ota_package_h616_dvb_Gigablud_S2_v10.1.19.63_2112141145.zip`).
- A firmware OTA zip contains the full system image → all preinstalled APKs
  (incl. HeatLive/HeatVOD). Extraction tooling verified locally: `7z`, `debugfs`.

## 14. Response Encoding (basexx)

- `android.auth.jni.AuthNative.basexxEncode/basexxDecode` (impl: `/system/lib/libt101_auth_d.so`).
- **encode** = standard base64 bit-layout with a **custom 64-char alphabet**
  (table @ `0x7EC66`): `/Quk6ItwxqgotRSxSyIoI5/y3/PVZ4pE89gib787nBfrre\n4u2Lxo5e30Nr/Y3tF`
  (`=` padding, standard).
- **decode** uses a 256-byte reverse table (@ `0x80C50`) that maps **standard**
  base64 chars (`+ / 0-9 A-Z a-z`, `=` special) — i.e. responses are standard-base64
  (possibly with a string-reversal step in the native decode; resolve empirically
  against a live response).
- Used by: MQTT password derivation (`MD5(basexxEncode(mac|serial))`),
  SettingsQ `HttpHelper.post` bodies and `getText`/`post` responses.

## 15. Vendor Host Map (DNS recon, 2026-10-08)

Families: `mytv.xin`, `vseeott.com`, `t101.cn` — many subdomains resolve
(ota, update, updater, fota, download, dl, cdn, api, app, market, vsmga, live,
heat, heatlive, vod, tv, appstore, store, config, img, static, file(s), package(s),
firmware) across a handful of CDN IPs (98.83.184.133, 100.28.104.175, 54.157.108.158,
104.x/172.67.x Cloudflare).
**App-store catalog search**: `POST /market/api/app/` supports `search_name`
(SettingsQ `getApps`: params `token`, `search_name`, `page`, `category`, `page_count`).

## 16. Live Traffic Capture (2026-10-08, box → PC proxy)

Captured by routing the VSeeBox through `scripts/logging_proxy.py` on the PC
(box Settings → network → proxy = 10.42.0.1:8080) while browsing + streaming HeatLive.

**The HeatLive APK is publicly downloadable:**
- `http://static.gixxig.com/app/heat-live-v5.9.4.1.apk` (the app's own update APK,
  fetched by the app itself during the session)

**Live backend domains (all HTTPS via CONNECT):**
- `api3.oplonx.com` — main app API (likely channel list / stream URLs)
- `cmsapi.vseeott.com` — CMS API (current generation; replaces cms.vseeott.com / cms.mytv.xin)
- `apk.qstar.video` — APK delivery
- `apkupdate.mytv.xin` — APK update check (mytv.xin serves TLS on some subdomains)
- `weather.qstar.video` — weather API
- `qsadmin.qstar.market`, `qsmarket.qstar.studio`, `qsadmin.qstar.video` — market/admin
- `static.gixxig.com` — static CDN: app APKs (`/app/`) + channel logos
  (`/images/logos/<channelId>.png?v=1.0.3`, http and https)

**Other observations:**
- App User-Agent: `Dalvik/2.1.0 (Linux; U; Android 14; V6 MAX Build/UD2A.240505.001.W1)`
- App uses hardcoded public DNS-over-TLS resolvers: 1.1.1.1, 8.8.8.8, 223.5.5.5, 185.222.222.222
- Device: V6 MAX, Android 14 (SDK 34), build `UD2A.240505.001.W1`, MAC `b4:5b:d6:b1:8d:36`
- `mytv.xin` appears **lapsed/parked** (CNAME chain → `*.molsoncoors.com`); the vendor's
  current domains are `vseeott.com`, `qstar.video` / `qstar.market` / `qstar.studio`,
  `oplonx.com`, `gixxig.com`. The firmware's hardcoded API hosts 404 because the
  backends moved.
- Channel logo IDs seen: 203082, 203056, 203132

## 17. HeatLive App (`com.google.heatlive` v5.9.4) — Acquired & Running

**Acquisition**: `http://static.gixxig.com/app/heat-live-v5.9.4.1.apk` (24MB,
the app's own update APK served by the vendor's CDN; found via live proxy capture).
Package `com.google.heatlive`, versionCode 594, minSdk 26 / targetSdk 29,
leanback TV app, launcher `com.huishine.traveler.page.SplashActivity`.
Native libs (ARM-only): `libffmpegJNI.so`, `libgojni.so` (Go runtime — core logic),
`libgooglejni.so`, `libjson.so`, `libobjectbox-jni.so` (ObjectBox DB), `libtvcore.so`.

**App backend (from live proxy capture + user's PCAPs):**
- `static.vseego.com` (HTTP, port 80) — EPG + data API:
  `GET /espn_epg/<feed>_MD5?t=<ts>` (EPG feeds: ESPN/Peacock/BTN+/NHL/NCAAF/NBA/MLB/
  MAX/FloSports/MLS/F1/Multiview...), `GET /espn_epg/<md5>.zip` (EPG DB zips,
  zip4j-AES encrypted — decrypted by the app), `GET /xtemp/<ts>_<id>_epg.db.zip`
- `vtcc_authn2.vseego.com` — authentication
- `broker.4kfibretv.com` — P2P broker
- `static.gixxig.com` — APK + channel logos (`/images/logos/<id>.png?v=1.0.3`)
- `api3.oplonx.com`, `cmsapi.vseeott.com`, `apk.qstar.video`, `qsmarket.qstar.studio`,
  `weather.qstar.video`, `apkupdate.mytv.xin` (HTTPS, opaque)
- Crash reporting (ACRA): `https://acrarium.tv1633.com/report` / `http://159.65.141.228:8081/report`
- Device registers its IP via DDNS: `xevksi3s2dz39.{myvnc.com,myftp.org,ddns.net,ddnsking.com,3utilities.com}`
- Hardcoded public DoT resolvers: 1.1.1.1, 8.8.8.8, 223.5.5.5, 185.222.222.222
- IP geolocation: `https://pro.ip-api.com/json/?key=26pQNlE2x9UwB66&fields=...`

**Streaming model**: P2P / peer-assisted (user's PCAP analysis: many high-port TCP
peers, substantial outbound = media sharing; no HLS/DASH/MPEG-TS signatures —
media is encrypted inside the custom P2P protocol, likely implemented in the
Go native lib `libgojni.so`). User's captures: `/home/sean/vseebox/private-captures/`
(131MB playback, 205MB startup, 25KB idle; analysis in `/home/sean/vseebox/docs/`).

**Emulator strategy**: x86_64 emulator can't run the ARM-only native libs
(app crashes: `UnsatisfiedLinkError libobjectbox-jni.so`). Solution: ARM64 emulator
(`system-images;android-31;default;arm64-v8a`, QEMU TCG) runs the ORIGINAL APK
with its real arm64 libs. x86_64 pipeline (strip lib/ + re-sign) still useful
for pure-Java analysis.

## 18. Open Items / Next Steps

- [ ] Obtain HeatLive (`com.google.heatlive`) + HeatVOD (`com.google.heatvod[_ultra]`) APKs:
      a. pull from device via adb (`scripts/pull_heatlive.sh`), **or**
      b. vendor market API (`scripts/market_api_download.sh`), **or**
      c. user-provided copy. (Not in firmware dump; avoid third-party APK mirrors —
         `com.google.*` is not a genuine Google package.)
- [ ] Run the APK in the Android emulator (`scripts/run_apk_in_emulator.sh`), extract its
      streaming API endpoints/auth, and get playback working on PC.
- [ ] Find MQTT subscribe topic (publish topic known: `t101/device/<MAC>/publish`).
- [ ] Reverse `basexxEncode` alphabet (`libt101_auth_d.so`) for full MQTT auth replication.
- [ ] `libultrahdr.so` / `libfec.so` video-processing analysis (Ghidra).
- [ ] `BleOTA.apk` (Bluetooth OTA) analysis.
- [ ] If device is connected: PCAP capture of MQTT/HTTP/MGA traffic; live logcat; pull HeatVOD
      app data (`/data/data/com.google.heatvod*/`) for API endpoints/tokens.
