#!/usr/bin/env bash
# Hämtar gårdagens trafikstatistik från Umami API och skriver JSON till stdout.
# Avsedd att köras inifrån OpenClaw-containern (eller där Umami är nåbart).
# Kräver: curl, och antingen jq eller python3 (ingen jq behövs – scriptet använder python3 som fallback).
#
# Credentials: fil med {"username":"...","password":"..."} eller env UMAMI_USERNAME + UMAMI_PASSWORD.
# Base URL: UMAMI_BASE_URL (default https://umami.theunnamedroads.com)

set -euo pipefail

UMAMI_BASE="${UMAMI_BASE_URL:-https://umami.theunnamedroads.com}"
CRED_FILE="${UMAMI_CREDENTIALS_FILE:-/data/.openclaw/umami-credentials.json}"

if [[ -n "${UMAMI_USERNAME:-}" && -n "${UMAMI_PASSWORD:-}" ]]; then
  USERNAME="$UMAMI_USERNAME"
  PASSWORD="$UMAMI_PASSWORD"
elif [[ -f "$CRED_FILE" ]]; then
  if command -v jq &>/dev/null; then
    USERNAME=$(jq -r '.username // empty' "$CRED_FILE")
    PASSWORD=$(jq -r '.password // empty' "$CRED_FILE")
  else
    USERNAME=$(grep -o '"username"[[:space:]]*:[[:space:]]*"[^"]*"' "$CRED_FILE" | sed 's/.*"\([^"]*\)".*/\1/')
    PASSWORD=$(grep -o '"password"[[:space:]]*:[[:space:]]*"[^"]*"' "$CRED_FILE" | sed 's/.*"\([^"]*\)".*/\1/')
  fi
else
  echo '{"error":"Missing Umami credentials: set UMAMI_USERNAME/UMAMI_PASSWORD or create '"$CRED_FILE"' with {\"username\":\"...\",\"password\":\"...\"}"}' >&2
  exit 1
fi

if [[ -z "$USERNAME" || -z "$PASSWORD" ]]; then
  echo '{"error":"Empty username or password in credentials"}' >&2
  exit 1
fi

# Gårdagen 00:00–24:00 (millisekunder). Försök Europe/Stockholm, annars UTC-dag.
TODAY_START=$(TZ=Europe/Stockholm date -d "today 00:00:00" +%s 2>/dev/null)
if [[ -z "$TODAY_START" ]]; then
  NOW=$(date +%s)
  TODAY_START=$(( (NOW / 86400) * 86400 ))
fi
END_MS=$((TODAY_START * 1000))
START_MS=$(((TODAY_START - 86400) * 1000))

LOGIN_RESP=$(curl -sS -X POST "$UMAMI_BASE/api/auth/login" \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"$USERNAME\",\"password\":\"$PASSWORD\"}")

if command -v jq &>/dev/null; then
  TOKEN=$(echo "$LOGIN_RESP" | jq -r '.token // empty')
else
  TOKEN=$(echo "$LOGIN_RESP" | grep -o '"token"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"\([^"]*\)".*/\1/')
fi

if [[ -z "$TOKEN" ]]; then
  RESP_ESC=$(echo "$LOGIN_RESP" | jq -c . 2>/dev/null || echo "$LOGIN_RESP" | python3 -c 'import json,sys; d=sys.stdin.read(); print(json.dumps(json.loads(d)) if d.strip().startswith("{") else "null")' 2>/dev/null || echo "null")
  echo "{\"error\":\"Umami login failed\",\"response\":$RESP_ESC}" >&2
  exit 1
fi

WEBSITES_JSON=$(curl -sS -X GET "$UMAMI_BASE/api/websites" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Accept: application/json")

REPORT_DATE=$(TZ=Europe/Stockholm date -d "yesterday" +%Y-%m-%d 2>/dev/null || date -d "yesterday" +%Y-%m-%d 2>/dev/null || date +%Y-%m-%d)

# Bygg utdata: antingen med jq eller med python3 (ingen jq krävs)
if command -v jq &>/dev/null; then
  WEBSITE_NAMES=$(echo "$WEBSITES_JSON" | jq -r '.data[]? | "\(.id)|\(.name // .domain)"')
  OUTPUT='{"date":"'"$REPORT_DATE"'","startAt":'$START_MS',"endAt":'$END_MS',"websites":[]}'
  SITES_FILE=$(mktemp)
  trap 'rm -f "$SITES_FILE"' EXIT
  while IFS= read -r line; do
    ID="${line%%|*}"
    NAME="${line#*|}"
    [[ -z "$ID" ]] && continue
    STATS=$(curl -sS -X GET "$UMAMI_BASE/api/websites/$ID/stats?startAt=$START_MS&endAt=$END_MS" \
      -H "Authorization: Bearer $TOKEN" -H "Accept: application/json")
    echo "$STATS" | jq -c --arg n "$NAME" --arg id "$ID" '{id:$id,name:$n,pageviews:(.pageviews//0),visitors:(.visitors//0),visits:(.visits//0),bounces:(.bounces//0),totaltime:(.totaltime//0)}' >> "$SITES_FILE"
  done <<< "$WEBSITE_NAMES"
  if [[ -s "$SITES_FILE" ]]; then
    ARR=$(jq -s -c '.' "$SITES_FILE")
    OUTPUT=$(echo "$OUTPUT" | jq --argjson arr "$ARR" '.websites = $arr')
  fi
  echo "$OUTPUT"
else
  # Fallback utan jq: använd python3 för att parsa och bygga JSON
  python3 - "$UMAMI_BASE" "$TOKEN" "$START_MS" "$END_MS" "$REPORT_DATE" << 'PYTHON_SCRIPT'
import json, sys, urllib.request

base = sys.argv[1]
token = sys.argv[2]
start_ms = int(sys.argv[3])
end_ms = int(sys.argv[4])
report_date = sys.argv[5]

def get(url):
  req = urllib.request.Request(url, headers={"Authorization": "Bearer " + token, "Accept": "application/json"})
  with urllib.request.urlopen(req) as r:
    return json.loads(r.read().decode())

websites = get(base + "/api/websites")
sites = []
for w in websites.get("data") or []:
  wid = w.get("id")
  name = w.get("name") or w.get("domain") or wid
  if not wid:
    continue
  try:
    stats = get(base + "/api/websites/" + wid + "/stats?startAt=" + str(start_ms) + "&endAt=" + str(end_ms))
  except Exception:
    stats = {}
  sites.append({
    "id": wid,
    "name": name,
    "pageviews": stats.get("pageviews", 0) or 0,
    "visitors": stats.get("visitors", 0) or 0,
    "visits": stats.get("visits", 0) or 0,
    "bounces": stats.get("bounces", 0) or 0,
    "totaltime": stats.get("totaltime", 0) or 0,
  })
out = {"date": report_date, "startAt": int(start_ms), "endAt": int(end_ms), "websites": sites}
print(json.dumps(out))
PYTHON_SCRIPT
fi
