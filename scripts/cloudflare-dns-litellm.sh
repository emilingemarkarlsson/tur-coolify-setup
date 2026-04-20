#!/usr/bin/env bash
# Skapa A-post litellm.theunnamedroads.com → Hetzner-IP (samma som webui).
# Kräver: CLOUDFLARE_API_TOKEN med Zone.DNS Edit för zonen.
#
#   export CLOUDFLARE_API_TOKEN="..."
#   ./scripts/cloudflare-dns-litellm.sh
#
# Hitta token: Cloudflare Dashboard → My Profile → API Tokens → Create Token
# (mall "Edit zone DNS" för theunnamedroads.com räcker).

set -euo pipefail

TOKEN="${CLOUDFLARE_API_TOKEN:?Sätt CLOUDFLARE_API_TOKEN}"
ZONE_NAME="${CLOUDFLARE_ZONE_NAME:-theunnamedroads.com}"
RECORD_NAME="${CLOUDFLARE_RECORD_NAME:-litellm}"
IP="${CLOUDFLARE_A_IP:-46.62.206.47}"
# true/false — false rekommenderas för Let's Encrypt HTTP-01 (samma som direkt A till origin).
PROXIED="${CLOUDFLARE_PROXIED:-false}"

API="https://api.cloudflare.com/client/v4"

zone_json=$(curl -sf -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  "$API/zones?name=$ZONE_NAME")
zone_id=$(python3 -c 'import json,sys; d=json.load(sys.stdin); print(d["result"][0]["id"] if d.get("result") else "")' <<<"$zone_json")

if [[ -z "$zone_id" ]]; then
  echo "Kunde inte hitta zone_id för $ZONE_NAME" >&2
  exit 1
fi

fqdn="${RECORD_NAME}.${ZONE_NAME}"
list_json=$(curl -sf -H "Authorization: Bearer $TOKEN" \
  "$API/zones/$zone_id/dns_records?type=A&name=$fqdn")
existing=$(python3 -c 'import json,sys; d=json.load(sys.stdin); print(d["result"][0]["id"] if d.get("result") else "")' <<<"$list_json")

payload=$(PROXIED="$PROXIED" python3 -c "import json,os; p=os.environ.get('PROXIED','false').lower()=='true'; print(json.dumps({'type':'A','name':'$fqdn','content':'$IP','ttl':120,'proxied':p}))")

if [[ -n "$existing" ]]; then
  resp=$(curl -sf -X PATCH -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
    -d "$payload" "$API/zones/$zone_id/dns_records/$existing")
  echo "Uppdaterade befintlig post: $fqdn → $IP"
else
  resp=$(curl -sf -X POST -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
    -d "$payload" "$API/zones/$zone_id/dns_records")
  echo "Skapade: $fqdn → $IP"
fi

python3 -c 'import json,sys; d=json.load(sys.stdin); sys.exit(0 if d.get("success") else 1)' <<<"$resp"
echo "Klart. Verifiera: dig +short A $fqdn"
