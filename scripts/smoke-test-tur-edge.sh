#!/usr/bin/env bash
# Smoke-test publika TUR-tjänster (webui + n8n) och valfritt LiteLLM via SSH till tha.
# Kör från dev-maskin: ./scripts/smoke-test-tur-edge.sh
# Med serverkoll:      ./scripts/smoke-test-tur-edge.sh --ssh

set -euo pipefail

WEBUI="https://webui.theunnamedroads.com"
N8N="https://n8n.theunnamedroads.com"
FAIL=0

check_http() {
  local url="$1" expect="${2:-200}"
  local code
  code=$(curl -sS -o /dev/null -w "%{http_code}" --connect-timeout 15 --max-time 30 "$url") || code="000"
  if [[ "$code" != "$expect" ]]; then
    echo "FAIL $url (got $code, expected $expect)"
    FAIL=1
  else
    echo "OK   $url -> $code"
  fi
}

echo "=== Edge smoke (HTTPS) ==="
check_http "$WEBUI"
check_http "$N8N"
check_http "$WEBUI/health"
check_http "$N8N/healthz"

ver=$(curl -sS --max-time 20 "$WEBUI/api/version" | python3 -c 'import sys,json; print(json.load(sys.stdin).get("version","?"))' 2>/dev/null || echo "?")
if [[ "$ver" == "0.8.12" ]]; then
  echo "OK   Open WebUI /api/version -> $ver"
else
  echo "WARN Open WebUI /api/version -> $ver (expected 0.8.12)"
fi

code=$(curl -sS -o /dev/null -w "%{http_code}" --max-time 15 "$N8N/rest/workflows" || echo 000)
if [[ "$code" == "401" ]] || [[ "$code" == "403" ]]; then
  echo "OK   n8n /rest/workflows -> $code (auth required, API up)"
else
  echo "WARN n8n /rest/workflows -> $code (expected 401/403 without session)"
fi

if [[ "${1:-}" == "--ssh" ]]; then
  echo ""
  echo "=== tha: Docker + LiteLLM (internal) ==="
  ssh tha "docker ps --filter name=open-webui-cckckggw44s8gkkkw008k4cs --filter name=n8n-j88kgkks44cc8wcc4kc8wkkk --filter name=litellm-kkswc8gokk84c0o8oo84w44w --format '{{.Names}} {{.Status}}'"
  IP=$(ssh tha 'docker inspect -f "{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}" litellm-kkswc8gokk84c0o8oo84w44w' 2>/dev/null || echo "")
  if [[ -n "$IP" ]]; then
    r=$(ssh tha "curl -sS --max-time 5 http://${IP}:4000/health/readiness" || true)
    if echo "$r" | grep -q '"status":"healthy"'; then
      echo "OK   LiteLLM readiness -> healthy"
    else
      echo "FAIL LiteLLM readiness: $r"
      FAIL=1
    fi
  fi
fi

if [[ "$FAIL" -ne 0 ]]; then
  exit 1
fi
echo ""
echo "All edge checks passed."
