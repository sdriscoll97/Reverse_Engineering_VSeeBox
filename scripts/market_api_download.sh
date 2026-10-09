#!/bin/bash
# Download the HeatLive/HeatVOD APK from the VSeeBox vendor app-market API.
# Reverse-engineered from AppStore.apk + SettingsQ.apk — see docs/findings.md.
#
# Flow:  secret_key (sai/mac/sn/cpu) -> token (lib/mac/sn/cpu/secret_key)
#        -> search catalog (search_name=heat) -> app/url (token + app_id) -> APK
#
# This talks to the vendor's own store servers (market.mytv.xin + returned host).
# Run it yourself at your own discretion. Requires: curl, python3.
#
# Usage: ./market_api_download.sh [app_id]     (app_id optional; auto-picks first heat* hit)
set -euo pipefail

API_HOST="${API_HOST:-http://market.mytv.xin}"  # decrypted from AppStore (domain://i411BAwY...); overridable for testing
SAI="2c6af6d9-287d-324b-bd5a-bf8423f79840" # /etc/appstore.conf line 1 (sai)
LIB="cb7104db-3ff8-3fa1-a0f2-aa1b5cc8f7fd" # /etc/appstore.conf line 2 (lib)
MAC="${MAC:-020000000001}"                # device mac (lowercase); may not be validated
SN="${SN:-0000000001}"                    # device serial
CPU="${CPU:-Amlogic}"                     # CpuInfo.hardware
WANT_APP="${1:-}"
SEARCH="${SEARCH:-heat}"
OUT="${HOME}/firstproject/heatlive_apks"
mkdir -p "$OUT"

echo "[1/5] secret_key auth..."
RESP="$(curl -s -m 20 -X POST "$API_HOST/api/auth/secret_key/" \
    -d "sai=$SAI" -d "mac=$MAC" -d "sn=$SN" -d "cpu=$CPU")"
echo "$RESP" | tee "$OUT/secret_key.json"; echo
HOST="$(echo "$RESP" | python3 -c 'import json,sys; print(json.load(sys.stdin)["result"]["host"])' 2>/dev/null || true)"
SECRET="$(echo "$RESP" | python3 -c 'import json,sys; print(json.load(sys.stdin)["result"]["secret_key"])' 2>/dev/null || true)"
[ -n "$HOST" ] || HOST="$API_HOST"
echo "    market host: $HOST"

echo "[2/5] token..."
RESP="$(curl -s -m 20 -X POST "$HOST/market/api/token/" \
    -d "lib=$LIB" -d "mac=$MAC" -d "sn=$SN" -d "cpu=$CPU" -d "secret_key=$SECRET")"
echo "$RESP" | tee "$OUT/token.json"; echo
TOKEN="$(echo "$RESP" | python3 -c 'import json,sys; print(json.load(sys.stdin)["result"]["token"])' 2>/dev/null || true)"

echo "[3/5] searching catalog for '$SEARCH'..."
RESP="$(curl -s -m 30 -X POST "$HOST/market/api/app/" \
    -d "token=$TOKEN" -d "search_name=$SEARCH" -d "page=1" -d "page_count=50" -d "category=0")"
echo "$RESP" > "$OUT/search_$SEARCH.json"
# fallback: full category list (AppStore endpoint)
if ! echo "$RESP" | grep -qi heat; then
    echo "    (no hit in search; trying /market/api/all/ ...)"
    RESP="$(curl -s -m 30 -X POST "$HOST/market/api/all/" -d "token=$TOKEN")"
    echo "$RESP" > "$OUT/catalog.json"
fi

echo "    catalog hits:"
python3 - "$OUT/search_$SEARCH.json" << 'PYEOF'
import json, sys
try:
    d = json.load(open(sys.argv[1]))
except Exception:
    d = {}
apps = []
def walk(o):
    if isinstance(o, dict):
        if 'id' in o and any(isinstance(v, str) and ('heat' in v.lower() or 'vod' in v.lower()) for v in o.values()):
            apps.append(o)
        for v in o.values(): walk(v)
    elif isinstance(o, list):
        for v in o: walk(v)
walk(d.get('result', d))
for a in apps:
    name = a.get('name') or a.get('appName') or ''
    pkg = a.get('packageName') or a.get('package_name') or a.get('pkg') or ''
    print(f"    {a.get('id')} | {name} | {pkg}")
if not apps:
    print('    (none parsed — inspect the raw JSON saved next to this script)')
PYEOF

if [ -z "$WANT_APP" ]; then
    WANT_APP="$(python3 - "$OUT/search_$SEARCH.json" << 'PYEOF'
import json, sys
try:
    d = json.load(open(sys.argv[1]))
except Exception:
    d = {}
apps = []
def walk(o):
    if isinstance(o, dict):
        if 'id' in o and any(isinstance(v, str) and ('heat' in v.lower() or 'vod' in v.lower()) for v in o.values()):
            apps.append(o)
        for v in o.values(): walk(v)
    elif isinstance(o, list):
        for v in o: walk(v)
walk(d.get('result', d))
# prefer heatlive, then heatvod, then anything heat
for a in apps:
    s = json.dumps(a).lower()
    if 'heatlive' in s or 'heat_live' in s or 'heat live' in s:
        print(a['id']); break
else:
    print(apps[0]['id'] if apps else '')
PYEOF
)"
fi
echo "[4/5] download url for app_id: ${WANT_APP:-<none found>}"
if [ -z "$WANT_APP" ]; then echo "[!] No heat app found in catalog; inspect $OUT/search_$SEARCH.json"; exit 1; fi
RESP="$(curl -s -m 20 -X POST "$HOST/market/api/app/url/" -d "token=$TOKEN" -d "app_id=$WANT_APP")"
echo "$RESP" | tee "$OUT/url.json"; echo
URL="$(echo "$RESP" | python3 -c 'import json,sys; r=json.load(sys.stdin)["result"]; print(r.get("url") or r.get("chunkUrl") or r.get("chunk_url") or "")' 2>/dev/null || true)"
case "$URL" in http*) ;; *) URL="$HOST$URL";; esac
echo "[5/5] downloading: $URL"
curl -sL -m 600 -o "$OUT/app_${WANT_APP}.apk" "$URL"
ls -la "$OUT/app_${WANT_APP}.apk"
file "$OUT/app_${WANT_APP}.apk" 2>/dev/null || true
