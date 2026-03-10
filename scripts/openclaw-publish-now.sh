#!/usr/bin/env bash
# Uppdaterar publish-draft.sh i OpenClaw-containern och kör publicering för en slug.
# Användning: ./scripts/openclaw-publish-now.sh <slug>
# Exempel:   ./scripts/openclaw-publish-now.sh n8n-data-pipeline-tutorial

set -euo pipefail

SLUG="${1:-}"
if [[ -z "$SLUG" ]]; then
  echo "Användning: $0 <slug>" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PUBLISH_SCRIPT="$REPO_ROOT/openclaw/scripts/publish-draft.sh"

if [[ ! -f "$PUBLISH_SCRIPT" ]]; then
  echo "Hittar inte $PUBLISH_SCRIPT" >&2
  exit 1
fi

echo "Hämtar OpenClaw-container från tha..."
CONTAINER=$(ssh tha 'docker ps --format "{{.Names}}" | grep -i openclaw | head -1')
if [[ -z "$CONTAINER" ]]; then
  echo "Ingen OpenClaw-container på tha." >&2
  exit 1
fi

echo "Kopierar publish-draft.sh till $CONTAINER..."
scp -q "$PUBLISH_SCRIPT" "tha:/tmp/publish-draft.sh"
ssh tha "docker cp /tmp/publish-draft.sh $CONTAINER:/data/.openclaw/scripts/publish-draft.sh && docker exec $CONTAINER chmod +x /data/.openclaw/scripts/publish-draft.sh"
ssh tha "rm -f /tmp/publish-draft.sh"

echo "Kör publicering för slug: $SLUG"
ssh tha "docker exec $CONTAINER /data/.openclaw/scripts/publish-draft.sh $SLUG"

echo "Klar."
