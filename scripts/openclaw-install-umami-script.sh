#!/usr/bin/env bash
# Kopierar umami-daily-stats.sh in i OpenClaw-containern och säkerställer att jq finns.
# Kör från repots rot: ./scripts/openclaw-install-umami-script.sh
# Kräver SSH-alias "tha" och att OpenClaw körs på servern.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
UMAMI_SCRIPT="$REPO_ROOT/openclaw/scripts/umami-daily-stats.sh"

if [[ ! -f "$UMAMI_SCRIPT" ]]; then
  echo "Hittar inte $UMAMI_SCRIPT"
  exit 1
fi

echo "Hämtar OpenClaw-container från tha..."
CONTAINER=$(ssh tha 'docker ps --format "{{.Names}}" | grep -i openclaw | head -1')
if [[ -z "$CONTAINER" ]]; then
  echo "Ingen OpenClaw-container hittad på tha. Kör: ssh tha 'docker ps | grep openclaw'"
  exit 1
fi

echo "Skapar /data/.openclaw/scripts i $CONTAINER..."
ssh tha "docker exec $CONTAINER mkdir -p /data/.openclaw/scripts"

echo "Kopierar umami-daily-stats.sh..."
scp -q "$UMAMI_SCRIPT" "tha:/tmp/umami-daily-stats.sh"
ssh tha "docker cp /tmp/umami-daily-stats.sh $CONTAINER:/data/.openclaw/scripts/umami-daily-stats.sh && docker exec $CONTAINER chmod +x /data/.openclaw/scripts/umami-daily-stats.sh"

echo "Kontrollerar jq..."
if ssh tha "docker exec $CONTAINER which jq" 2>/dev/null; then
  echo "jq finns redan."
else
  echo "Installerar jq i containern (apk eller apt)..."
  ssh tha "docker exec $CONTAINER sh -c 'which jq || (apk add --no-cache jq 2>/dev/null || apt-get update -qq && apt-get install -y -qq jq)'" || true
fi

echo "Klar. Testa med: ssh tha \"docker exec $CONTAINER /data/.openclaw/scripts/umami-daily-stats.sh\""
echo "Se openclaw/UMAMI-DIRECT.md för credentials och cron."
